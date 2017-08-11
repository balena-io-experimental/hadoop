FROM resin/rpi-raspbian:jessie-20160511

ENV INITSYSTEM=on

RUN apt-get update \
  && apt-get -y install wget openjdk-8-jre openjdk-8-jdk openssh-server jq curl

# For simplicity, copy the same SSH key to every device in the cluster
# (Not a good idea for a production environment!)
WORKDIR /root/.ssh
COPY id_rsa ./
COPY id_rsa.pub ./
COPY id_rsa.pub ./authorized_keys
RUN chmod 600 id_rsa

# IPv6 seems to confuse hadoop
WORKDIR /etc
COPY hosts ./

WORKDIR /opt
RUN wget ftp://apache.belnet.be/mirrors/ftp.apache.org/hadoop/common/hadoop-2.8.1/hadoop-2.8.1.tar.gz
RUN tar zxvf hadoop-2.8.1.tar.gz

WORKDIR /opt/hadoop-2.8.1/etc/hadoop
COPY hdfs-site.xml ./
COPY mapred-site.xml ./

WORKDIR /root
COPY bashrc ./.bashrc

WORKDIR /opt/hadoop-2.8.1
COPY start.sh ./

CMD ./start.sh
