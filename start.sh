#!/bin/bash

export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:jre/bin/java::")  
export HADOOP_HOME=/opt/hadoop-2.8.1  
export HADOOP_PREFIX=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME  
export HADOOP_COMMON_HOME=$HADOOP_HOME  
export HADOOP_HDFS_HOME=/data/hdfs
export YARN_HOME=$HADOOP_HOME  
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop  
export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop  
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin 

service ssh start

# Hadoop relies on name resolution all over the place
# So what we do is query the resin.io application to get a list of all the
# devices, parse the json output to get their UUIDs (which are conveniently
# a superset of their hostnames) and their IP addresses.
# Because a device could potentially have multiple IP addresses, we'll just
# get the first one.  (Hence why we get the data as
#   hostname ip [ip...]
# but then use awk to reverse it -- it's way easier to just grab the first
# IP address that way.)
# Once we have all of that, it goes to /etc/hosts
if [ -z "$USER_API_KEY" ]
then
  echo "USER_API_KEY not set!  Set this as a fleet-wide application variable and populate"
  echo "it with your resin.io API key."
  echo "Then restart the application container(s) on the fleet."
  echo "(Intentionally stopping now)"
  sleep infinity
fi

echo 127.0.0.1 localhost.localdomain localhost > /etc/hosts
curl "https://api.resin.io/v1/application($RESIN_APP_ID)?\$expand=device" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_API_KEY" \
  | jq -r '.d[].device[] | "\(.uuid) \(.ip_address)"' \
  | awk '{ print $2 " " substr($1, 0, 8) " " substr($1, 0, 8) ".local" }' \
  >> /etc/hosts


# Configure the cluster
if [ -z "$MASTER_NODE" ]
then
  echo "MASTER_NODE not set!  Set this as a fleet-wide application variable and populate"
  echo "it with the hostname of the master node.  (You can copy this from the resin.io"
  echo "dashboard for one of the hosts.)"
  echo "Then restart the application container(s) on the fleet."
  echo "(Intentionally stopping now)"
  sleep infinity
fi

echo "<?xml version=\"1.0\"?>
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>4</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>128</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-vcores</name>
    <value>1</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-vcores</name>
    <value>4</value>
  </property>
  <property>
    <name>yarn.resourcemanager.resource-tracker.address</name>
    <value>$MASTER_NODE:8025</value>
  </property>
  <property>
    <name>yarn.resourcemanager.scheduler.address</name>
    <value>$MASTER_NODE:8030</value>
  </property>
  <property>
    <name>yarn.resourcemanager.address</name>
    <value>$MASTER_NODE:8040</value>
  </property>
  <property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>false</value>
  </property>
</configuration>" > etc/hadoop/yarn-site.xml


echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://$MASTER_NODE:54310</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/hdfs/tmp</value>
  </property>
</configuration>" > etc/hadoop/core-site.xml

# Finally, if we're on the master node we need to configure the master/slave files
if [ $(hostname) == "$MASTER_NODE" ]
then
  echo I am the master node -- configuring slaves
  echo $(hostname) > etc/hadoop/masters
  grep -v localhost /etc/hosts | grep -v $MASTER_NODE | awk '{ print $2 }' > etc/hadoop/slaves
fi

# Disable ssh key verification
echo StrictHostKeyChecking no > /root/.ssh/config
echo UserKnownHostsFile /dev/null >> /root/.ssh/config


# TODO: Set a flag so that this doesn't get blown away every time!
echo Setting up HDFS...
# Put HDFS jars where they are expected
mkdir -p /data/hdfs/share/hadoop
mkdir -p /data/hdfs/bin
mkdir -p /data/hdfs/libexec
mv /opt/hadoop-2.8.1/share/hadoop/hdfs /data/hdfs/share/hadoop
cp /opt/hadoop-2.8.1/bin/hdfs /data/hdfs/bin/
cp /opt/hadoop-2.8.1/libexec/hdfs-config.sh /data/hdfs/libexec/
mkdir -p /data/hdfs/tmp
chmod 750 /data/hdfs/tmp

echo Hadoop install:
hadoop version

if [ $(hostname) == "$MASTER_NODE" ]
then
  if [ ! -e /data/hdfs/tmp ]
  then
    echo "Formatting HDFS"
    hdfs namenode -format
  else
    echo "HDFS data found; not formatting"
  fi
  start-dfs.sh
  start-yarn.sh
  sleep 5
  echo ""
  echo "Ready to receive jobs"
else
  # Wait while hdfs is formatted
  echo "Waiting for master node to format HDFS..."
  sleep 300
fi

echo Hadoop services:
jps | grep -v Jps

sleep infinity
