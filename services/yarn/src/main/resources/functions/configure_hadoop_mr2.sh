#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -x

function configure_hadoop_mr2() {
  local OPTIND
  local OPTARG

  if [ "$CONFIGURE_HADOOP_DONE" == "1" ]; then
    echo "Hadoop is already configured."
    return;
  fi

  ROLES=$1
  shift

  case $CLOUD_PROVIDER in
    ec2 | aws-ec2 )
      # Alias /mnt as /data
      ln -s /mnt /data
      ;;
    *)
      ;;
  esac
  
  HADOOP_COMMON_HOME=$HADOOP_HOME
  HADOOP_HDFS_HOME=$HADOOP_HOME
  HADOOP_HOME=/usr/local/hadoop
  HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

  mkdir -p /data/hadoop
  chown hadoop:hadoop /data/hadoop
  if [ ! -e /data/tmp ]; then
    mkdir /data/tmp
    chmod a+rwxt /data/tmp
  fi
  mkdir /etc/hadoop
  ln -s $HADOOP_CONF_DIR /etc/hadoop/conf

  # Copy generated configuration files in place
  cp /tmp/{core,hdfs,mapred}-site.xml $HADOOP_CONF_DIR

  # Keep PID files in a non-temporary directory
#  sed -i -e "s|# export HADOOP_PID_DIR=.*|export HADOOP_PID_DIR=/var/run/hadoop|" \
#    $HADOOP_CONF_DIR/hadoop-env.sh
#  mkdir -p /var/run/hadoop
#  chown -R hadoop:hadoop /var/run/hadoop

  # Set SSH options within the cluster
#  sed -i -e 's|# export HADOOP_SSH_OPTS=.*|export HADOOP_SSH_OPTS="-o StrictHostKeyChecking=no"|' \
#    $HADOOP_CONF_DIR/hadoop-env.sh
    
  # Disable IPv6
#  sed -i -e 's|# export HADOOP_OPTS=.*|export HADOOP_OPTS="-Djava.net.preferIPv4Stack=true"|' \
#    $HADOOP_CONF_DIR/hadoop-env.sh

  # Hadoop logs should be on the /data partition
#  sed -i -e 's|# export HADOOP_LOG_DIR=.*|export HADOOP_LOG_DIR=/var/log/hadoop/logs|' \
#    $HADOOP_CONF_DIR/hadoop-env.sh
#  rm -rf /var/log/hadoop
#  mkdir /data/hadoop/logs
#  chown hadoop:hadoop /data/hadoop/logs
#  ln -s /data/hadoop/logs /var/log/hadoop
#  chown -R hadoop:hadoop /var/log/hadoop
  
  for role in $(echo "$ROLES" | tr "," "\n"); do
    case $role in
    hadoop-namenode)
      start_namenode
      ;;
    hadoop-secondarynamenode)
      start_hadoop_daemon secondarynamenode
      ;;
    hadoop-jobtracker)
      start_hadoop_daemon jobtracker
      ;;
    hadoop-datanode)
      start_hadoop_daemon datanode
      ;;
    hadoop-tasktracker)
      start_hadoop_daemon tasktracker
      ;;
    esac
  done

  CONFIGURE_HADOOP_DONE=1

}

function start_namenode() {
  if which dpkg &> /dev/null; then
    AS_HADOOP="su -s /bin/bash - hadoop -c"
  elif which rpm &> /dev/null; then
    AS_HADOOP="/sbin/runuser -s /bin/bash - hadoop -c"
  fi

  # Format HDFS
  [ ! -e /data/hadoop/hdfs ] && $AS_HADOOP "$HADOOP_HOME/bin/hadoop namenode -format"

  $AS_HADOOP "$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode"

  $AS_HADOOP "$HADOOP_HOME/bin/hadoop dfsadmin -safemode wait"
  $AS_HADOOP "$HADOOP_HOME/bin/hadoop fs -mkdir /user"
  # The following is questionable, as it allows a user to delete another user
  # It's needed to allow users to create their own user directories
  $AS_HADOOP "$HADOOP_HOME/bin/hadoop fs -chmod +w /user"
  
  # Create temporary directory for Pig and Hive in HDFS
  $AS_HADOOP "$HADOOP_HOME/bin/hadoop fs -mkdir /tmp"
  $AS_HADOOP "$HADOOP_HOME/bin/hadoop fs -chmod +w /tmp"
  $AS_HADOOP "$HADOOP_HOME/bin/hadoop fs -mkdir /user/hive/warehouse"
  $AS_HADOOP "$HADOOP_HOME/bin/hadoop fs -chmod +w /user/hive/warehouse"

}

function start_hadoop_daemon() {
  if which dpkg &> /dev/null; then
    AS_HADOOP="su -s /bin/bash - hadoop -c"
  elif which rpm &> /dev/null; then
    AS_HADOOP="/sbin/runuser -s /bin/bash - hadoop -c"
  fi
  $AS_HADOOP "$HADOOP_HOME/sbin/hadoop-daemon.sh start $1"
}

