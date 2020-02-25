FROM centos:6.9
 
EXPOSE 4848 4900 5701 5900 8080 28080 9009 29009 5200
 
ENV DEBIAN_FRONTEND noninteractive
 
# yum
RUN yum -y update && yum clean all
RUN yum -y upgrade && yum -y update && yum clean all
RUN yum install -y --setopt=protected_multilib=false epel-release ld-linux.so.2 libstdc++.so.6 libpng12
RUN yum install -y multitail ncurses-devel ncurses-static ncurses-term nc
 
# JDK
ENV JAVA_VERSION jdk-11.0.6+10_openj9-0.18.1

RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
       ppc64el|ppc64le) \
         ESUM='942436d908aea973a661df080e32ea88a3819b4d50b95d502c140fb0a0e43fdb'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.6%2B10_openj9-0.18.1/OpenJDK11U-jdk_ppc64le_linux_openj9_11.0.6_10_openj9-0.18.1.tar.gz'; \
         ;; \
       s390x) \
         ESUM='a255f620a971f4f537b729d53b4ad6433cb579ce3f929a19b572cfcdacb6ec93'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.6%2B10_openj9-0.18.1/OpenJDK11U-jdk_s390x_linux_openj9_11.0.6_10_openj9-0.18.1.tar.gz'; \
         ;; \
       amd64|x86_64) \
         ESUM='1530172ee98edd129954fcdca1bf725f7b30c8bfc3cdc381c88de96b7d19e690'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.6%2B10_openj9-0.18.1/OpenJDK11U-jdk_x64_linux_openj9_11.0.6_10_openj9-0.18.1.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}; \
    echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/java/openjdk; \
    cd /opt/java/openjdk; \
    tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
    rm -rf /tmp/openjdk.tar.gz;

ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"
ENV JAVA_TOOL_OPTIONS="-XX:+IgnoreUnrecognizedVMOptions -XX:+UseContainerSupport -XX:+IdleTuningCompactOnIdle -XX:+IdleTuningGcOnIdle"

# Initialize the configurable environment variables
ENV HOME_DIR=/opt/payara\
    PAYARA_DIR=/opt/payara/appserver\
    SCRIPT_DIR=/opt/payara/scripts\
    CONFIG_DIR=/opt/payara/config\
    DEPLOY_DIR=/opt/payara/deployments\
    PASSWORD_FILE=/opt/payara/passwordFile\
    # Payara version (5.183+)
    PAYARA_VERSION=5.183\
    # Payara Server Domain options
    DOMAIN_NAME=production\
    ADMIN_USER=admin\
    ADMIN_PASSWORD=admin12345 \
    # Utility environment variables
    JVM_ARGS=\
    DEPLOY_PROPS=\
    POSTBOOT_COMMANDS=/opt/payara/config/post-boot-commands.asadmin\
    PREBOOT_COMMANDS=/opt/payara/config/pre-boot-commands.asadmin

# Create and set the Payara user and working directory owned by the new user
RUN groupadd payara && \
    useradd -b ${HOME_DIR} -M -s /bin/bash -d ${HOME_DIR} payara -g payara && \
    echo payara:payara | chpasswd && \
    mkdir -p ${DEPLOY_DIR} && \
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${SCRIPT_DIR} && \
    chown -R payara:payara ${HOME_DIR}
USER payara
WORKDIR ${HOME_DIR}

# Download and unzip the Payara distribution
RUN wget --no-verbose -O payara.zip https://s3-eu-west-1.amazonaws.com/payara.fish/payara-prerelease.zip && \
    chown payara:payara payara.zip && \
    unzip -qq payara.zip -d ./ && \
    mv payara*/ appserver && \
    # Configure the password file for configuring Payara
    echo "AS_ADMIN_PASSWORD=\nAS_ADMIN_MASTERPASSWORD=${ADMIN_PASSWORD}\nAS_ADMIN_SSHPASSWORD=${ADMIN_PASSWORD}" > /tmp/tmpfile && \	
    cat /tmp/tmpfile && \	
    echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> ${PASSWORD_FILE} && \
    cat ${PASSWORD_FILE} && \	
    chmod 600 /tmp/tmpfile && \	
    chmod 600 ${PASSWORD_FILE} && \
    # Configure the payara domain
    echo --user ${ADMIN_USER} --passwordfile=/tmp/tmpfile change-admin-password --domain_name=${DOMAIN_NAME} && \
    od -c /tmp/tmpfile && \	
    ${PAYARA_DIR}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/tmp/tmpfile change-admin-password --domain_name=${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} start-domain ${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} enable-secure-admin && \
    for MEMORY_JVM_OPTION in $(${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} list-jvm-options | grep "Xm[sx]"); do\
        ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} delete-jvm-options $MEMORY_JVM_OPTION;\
    done && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} create-jvm-options '-XX\:+UnlockExperimentalVMOptions:-XX\:+UseCGroupMemoryLimitForHeap' && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.logtoFile=false && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} stop-domain ${DOMAIN_NAME} && \
    # Cleanup unused files
    rm -rf \
        /tmp/tmpFile \
        payara.zip \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/osgi-cache \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/logs \
        ${PAYARA_DIR}/glassfish/domains/domain1

# Copy across docker scripts
COPY --chown=payara:payara bin/*.sh ${SCRIPT_DIR}/
RUN chmod +x ${SCRIPT_DIR}/*

CMD ${SCRIPT_DIR}/generate_deploy_commands.sh && exec ${SCRIPT_DIR}/startInForeground.sh
