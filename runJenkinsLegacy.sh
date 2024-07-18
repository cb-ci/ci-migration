#! /bin/bash
mkdir -p jenkins-data 
chmod 777 jenkins-data
docker run \
  -e JENKINS_OPTS="--accessLoggerClassName=winstone.accesslog.SimpleAccessLogger --simpleAccessLogger.format=combined --simpleAccessLogger.file=/var/jenkins_home/access.log" \
  -u root \
  --rm \
  -p 8080:8080 \
  -v $(pwd)/jenkins-data:/var/jenkins_home \
  jenkins/jenkins:2.440.1-lts-jdk17  

  #-v /var/run/docker.sock:/var/run/docker.sock \
