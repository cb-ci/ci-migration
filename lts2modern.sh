#! /bin/bash
set +x
#This script contains some scripted approaches for controller migration (k8s)
#links i followed:
#https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/migrating-jenkins-instances
#https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/migrating-jenkins-to-a-new-machine
#https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/
#https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/cloudbees-jenkins-platform-to-cloudbees-ci/
#https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/jenkins-to-ci-trad-migration/
#https://www.youtube.com/watch?v=urmNi61PDbc
#https://docs.cloudbees.com/docs/cloudbees-ci-api/latest/bundle-management-api

#TARGET
export BASE_URL="https://yourcloudbeesciurl.org"
#Token must be created on CJOC level, not on Controller level
export TOKEN="user:token"
export CJOC_URL=${BASE_URL}"/cjoc"
export CONTROLLER_NAME_TARGET="mytest-casc"
export CONTROLLER_URL_TARGET=${BASE_URL}"/"${CONTROLLER_NAME_TARGET}
export CONTROLLER_IMAGE_VERSION_TARGET="latest"
export CONTROLLER_TOKEN_TARGET=$TOKEN
#export BUNDLE_NAME="" # ore just "none"?  
export BUNDLE_NAME="master/rs-jenkins-global"
export STORAGE_CLASS=ssd-cloudbees-ci-cloudbees-core

#SOURCE
#Update to legacy controller name later on, not used yet
export CONTROLLER_NAME_SOURCE=$CONTROLLER_NAME_TARGET
#Update to legacy controller URL later on
#export CONTROLLER_URL_SOURCE"https://yourkenkinsossurl.org"
export CONTROLLER_URL_SOURCE=${CONTROLLER_URL_TARGET}
export CONTROLLER_TOKEN_SOURCE=$TOKEN

BACKUP_FILE=controller-backup.tar.gz



echo "------------------  CREATE BACKUP ------------------"
#Create a backup from the legacy controller

#TODO: Set legacy Controller in quit mode when running a backup
#see https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/how-to-start-stop-or-restart-your-instance
#TODO: Legacy controller on-prem might require ssh exec to create a backup remotely
#see https://www.cyberciti.biz/faq/unix-linux-execute-command-using-ssh/

#For testing purposes we create a backup locally from an OSS Controller
CUR_DIR=$(pwd)
cd /Users/XXX/projects/docker-jenkins-oss-controller/jenkins-data
#when using a casc-bundle, we might define our plugins in plugins.yaml. If so, we can exclude them from the backup using the  --exclude=plugins/ \
#remove the  --exclude=plugins/  filter if you want to get the plugins also in your backup (f.e. when not using plugins.yaml for the target controller provisioning)
tar -cvzf  $CUR_DIR/$BACKUP_FILE \
    --exclude=cache/ \
    --exclude=plugins/ \
    --exclude=builds/ \
    --exclude=secret.key \
    --exclude=secret.key.not-so-secret \
    --exclude=secrets \
    --exclude=identity.key.enc .
cd $CUR_DIR


echo "------------------  DELETE MANAGED CONTROLLER $CONTROLLER_NAME_TARGET------------------"
#Release and delete the target Controller from Cjoc and delete PVC if  exist
curl  -Ls -XPOST  -u $CONTROLLER_TOKEN_TARGET "$CJOC_URL/job/$CONTROLLER_NAME_TARGET/stopAction"  2>&1 > /dev/null
sleep 10
curl  -Ls -XPOST -u $CONTROLLER_TOKEN_TARGET "$CJOC_URL/job/$CONTROLLER_NAME_TARGET/doDelete"  2>&1 > /dev/null
#see https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/operations-center/how-to-delete-a-managed-controller-in-cloudbees-jenkins-enterprise-and-cloudbees-core
kubectl delete pvc jenkins-home-$CONTROLLER_NAME_TARGET-0  2>&1 > /dev/null
sleep 10

echo "------------------  CREATING MANAGED CONTROLLER ------------------"
#Create a target controller (Kubernetes)
GEN_DIR=gen
rm -rf $GEN_DIR
mkdir -p $GEN_DIR
# We render the CasC template instances for cjoc-controller-items.yaml
# All variables will be substituted
#Use existing casc bundle with plugins
envsubst < templates/create-mm.yaml > $GEN_DIR/${CONTROLLER_NAME_TARGET}.yaml
cat $GEN_DIR/${CONTROLLER_NAME_TARGET}.yaml
#see https://docs.cloudbees.com/docs/cloudbees-ci-api/latest/bundle-management-api
curl -Ls -XPOST \
   --user $CONTROLLER_TOKEN_TARGET \
   "${CJOC_URL}/casc-items/create-items" \
    -H "Content-Type:text/yaml" \
   --data-binary @$GEN_DIR/${CONTROLLER_NAME_TARGET}.yaml
#Wait until pod is up
sleep 60
kubectl wait pod/${CONTROLLER_NAME_TARGET}-0  --for condition=ready --timeout=120s
#wait until LB is ready
LB_IP=""
while [ -z "$LB_IP" ]
do
    echo "LB_IP is null, wait........"
    LB_IP=$(kubectl get ing ${CONTROLLER_NAME_TARGET}  -o json | jq -r '.status.loadBalancer.ingress[0].ip')
    LB_IP=$(echo $LB_IP | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    [ -z "$$LB_IP" ] && sleep 30
done
echo "Ingress created LB_IP: $LB_IP"


echo "------------------  COPY BACKUP TO ${CONTROLLER_NAME_TARGET} ------------------"
#Copy the backup to the target controller
#TODO: If possible, directly retrieve the backup via ssh, s3, gcp-bucket, or whatever from a remote storage.
#Download/Upload from the workstation is not efficient/performant!

#TODO: Check if tmp has sufficient capacity, use maybe mounted volume/pvc better instead
kubectl cp $BACKUP_FILE ${CONTROLLER_NAME_TARGET}-0:/tmp/ || false

#Extract the backup and overwrite JENKINS_HOME on the target
kubectl exec  ${CONTROLLER_NAME_TARGET}-0 -- tar -xvzf /tmp/$BACKUP_FILE --directory /var/jenkins_home/ || false

echo "------------------  RESTART ${CONTROLLER_NAME_TARGET} ------------------"
#Restart the Controller
#TODO: maybe better quitRestart? see https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/client-and-managed-controllers/how-to-start-stop-or-restart-your-instance
echo "force stop Controller $CONTROLLER_NAME_TARGET"
curl  -Ls -XPOST  -u $CONTROLLER_TOKEN_TARGET "$CJOC_URL/job/$CONTROLLER_NAME_TARGET/stopAction"  2>&1 > /dev/null
sleep 10
echo "start Controller $CONTROLLER_NAME_TARGET"
curl  -Ls -XPOST -u $CONTROLLER_TOKEN_TARGET "$CJOC_URL/job/$CONTROLLER_NAME_TARGET/startAction"  2>&1 > /dev/null
sleep 60
kubectl wait pod/${CONTROLLER_NAME_TARGET}-0  --for condition=ready --timeout=120s
#wait until LB is ready
LB_IP=""
while [ -z "$LB_IP" ]
do
    echo "LB_IP is null, wait........"
    LB_IP=$(kubectl get ing ${CONTROLLER_NAME_TARGET}  -o json | jq -r '.status.loadBalancer.ingress[0].ip')
    LB_IP=$(echo $LB_IP | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    [ -z "$$LB_IP" ] && sleep 30
done
echo "Ingress created LB_IP: $LB_IP"


echo "------------------  MIGRATE CREDENTIALS ------------------"
# EXPORT FOLDER CREDENTIALS
echo "------------------  EXPORT FOLDER CREDENTIALS  ------------------"
curl -o gen/export-credentials-folder-level.groovy https://raw.githubusercontent.com/cloudbees/jenkins-scripts/master/credentials-migration/export-credentials-folder-level.groovy
curl --data-urlencode "script=$(cat gen/export-credentials-folder-level.groovy)" \
--user $CONTROLLER_TOKEN_SOURCE ${CONTROLLER_URL_SOURCE}/scriptText  -o gen/folder.creds
tail -n 1  gen/folder.creds | sed  -e "s#\[\"##g"  -e "s#\"\]##g"  | tee  gen/folder-imports.txt

# IMPORT FOLDER CREDENTIALS
echo "------------------  IMPORT FOLDER CREDENTIALS  ------------------"
kubectl cp gen/folder-imports.txt ${CONTROLLER_NAME_TARGET}-0:/var/jenkins_home/
curl -o gen/update-credentials-folder-level.groovy https://raw.githubusercontent.com/cloudbees/jenkins-scripts/master/credentials-migration/update-credentials-folder-level.groovy
cat gen/update-credentials-folder-level.groovy | sed  "s#^\/\/ encoded.*#encoded = [new File(\"/var\/jenkins_home\/folder-imports.txt\").text]#g" >  gen/update-credentials-folder-level-mod.groovy
curl --data-urlencode "script=$(cat gen/update-credentials-folder-level-mod.groovy)" \
--user $CONTROLLER_TOKEN_TARGET ${CONTROLLER_URL_TARGET}/scriptText

# EXPORT SYSTEM CREDENTIALS
echo "------------------  EXPORT SYSTEM CREDENTIALS  ------------------"
curl -o gen/export-credentials-system-level.groovy https://raw.githubusercontent.com/cloudbees/jenkins-scripts/master/credentials-migration/export-credentials-system-level.groovy
curl --data-urlencode "script=$(cat gen/export-credentials-system-level.groovy)" \
--user $CONTROLLER_TOKEN_SOURCE  ${CONTROLLER_URL_SOURCE}/scriptText   -o gen/system.creds
tail -n 1  gen/system.creds | sed  -e "s#\[\"##g"  -e "s#\"\]##g"  | tee  gen/system-imports.txt

# IMPORT SYSTEM CREDENTIALS
echo "-------------------- IMPORT SYSTEM CREDENTIALS  ------------------"
kubectl cp gen/system-imports.txt ${CONTROLLER_NAME_TARGET}-0:/var/jenkins_home/
curl -o gen/update-credentials-system-level.groovy https://raw.githubusercontent.com/cloudbees/jenkins-scripts/master/credentials-migration/update-credentials-system-level.groovy
cat gen/update-credentials-system-level.groovy | sed  "s#^\/\/ encoded.*#encoded = [new File(\"/var\/jenkins_home\/system-imports.txt\").text]#g" >  gen/update-credentials-system-level-mod.groovy
curl --data-urlencode "script=$(cat gen/update-credentials-system-level-mod.groovy)" \
--user $CONTROLLER_TOKEN_TARGET ${CONTROLLER_URL_TARGET}/scriptText

#reload new Jobs from the disk
# curl -L -s -u $CONTROLLER_TOKEN_TARGET -XPOST  "$CONTROLLER_URL_TARGET/reload" 2>&1 > /dev/null

#Acceptance test
##Run jobs (static agent)
##Verify credentials

#Export the new casc bundle including everything
#Jenkins
#Plugins
#Items
#Optional: RBAC

#Start a new controller for the testing approach
