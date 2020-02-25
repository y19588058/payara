FROM centos:6.9
 
EXPOSE 4848 4900 5701 5900 8080 28080 9009 29009 5200
 
ENV DEBIAN_FRONTEND noninteractive
 
# yum
RUN yum -y update && yum clean all
RUN yum -y upgrade && yum -y update && yum clean all
RUN yum install -y --setopt=protected_multilib=false epel-release ld-linux.so.2 libstdc++.so.6 libpng12
RUN yum install -y multitail ncurses-devel ncurses-static ncurses-term nc
 
# JDK
COPY jdk-11.0.6_linux-x64_bin.tar.gz /jdk-11.0.6_linux-x64_bin.tar.gz
#COPY jdk-8u191-linux-x64.tar.gz /jdk-8u191-linux-x64.tar.gz
COPY setup_jdk.sh /setup_jdk.sh
RUN chmod u+x /setup_jdk.sh
RUN /setup_jdk.sh
RUN rm -f /setup_jdk.sh
ENV JAVA_HOME /usr/local/java/jdk
ENV PATH /usr/local/java/jdk/bin:$PATH
RUN echo 'JAVA_HOME=/usr/local/java/jdk' >> /root/.bashrc
RUN echo 'PATH=$PATH:/usr/local/java/jdk/bin' >> /root/.bashrc
#RUN rm -f /jdk-8u191-linux-x64.tar.gz
RUN rm -f /jdk-11.0.6_linux-x64_bin.tar.gz
 
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