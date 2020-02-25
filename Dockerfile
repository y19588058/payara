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

# Payara
COPY payara-5.194.zip /payara-5.194.zip
#COPY payara-5.184.zip /payara-5.184.zip
COPY setup_payara.sh /setup_payara.sh
RUN chmod u+x /setup_payara.sh
RUN /setup_payara.sh
RUN rm -f /payara-5.184.zip
 
COPY ojdbc8.jar /var/payara/payara/glassfish/lib/ojdbc8.jar
COPY postgresql-42.2.2.jar /var/payara/payara/glassfish/lib/postgresql-42.2.2.jar
COPY sqljdbc42.jar /var/payara/payara/glassfish/lib/sqljdbc42.jar
 
COPY run.sh /run.sh
RUN chmod +x /run.sh
 
RUN updatedb
 
CMD /run.sh
