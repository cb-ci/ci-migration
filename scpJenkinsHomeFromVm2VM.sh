#!/usr/bin/env bash
#
# Migrate JENKINS_HOME (excluding jobs/) from a source Jenkins VM
# to a target Jenkins controller.
#
# Steps:
#  1. SSH into source -> create tar.gz of JENKINS_HOME (exclude jobs/)
#  2. scp tar.gz from source -> target
#  3. SSH into target -> extract into JENKINS_HOME (overwrite existing files)
#
# Requirements:
#  - SSH key-based access from this host to both source and target
#  - 'tar' and 'scp' installed on all machines
#  - You probably want Jenkins stopped on both ends during migration

set -euo pipefail

########## CONFIGURE THESE ##########
# Source (current Jenkins)
SRC_USER="jenkins"
SRC_HOST="source-jenkins.example.com"
SRC_JENKINS_HOME="/var/lib/jenkins"

# Target (new controller)
DST_USER="jenkins"
DST_HOST="target-jenkins.example.com"
DST_JENKINS_HOME="/var/lib/jenkins"

# Archive name and path (used on both VMs)
ARCHIVE_NAME="jenkins_home_migration_$(date +%Y%m%d_%H%M%S).tar.gz"
SRC_ARCHIVE="/tmp/${ARCHIVE_NAME}"
DST_ARCHIVE="/tmp/${ARCHIVE_NAME}"
#####################################

echo "==> Source:   ${SRC_USER}@${SRC_HOST}, JENKINS_HOME=${SRC_JENKINS_HOME}"
echo "==> Target:   ${DST_USER}@${DST_HOST}, JENKINS_HOME=${DST_JENKINS_HOME}"
echo "==> Archive:  ${ARCHIVE_NAME}"
echo

#####################################
# 1) Create archive on source (excluding jobs/)
#####################################
echo "==> Creating tar.gz on source (excluding jobs/) ..."

ssh "${SRC_USER}@${SRC_HOST}" bash -c "'
  set -e

  echo \"[SOURCE] Creating archive at ${SRC_ARCHIVE}\"

  # Optional: stop Jenkins on source (uncomment if desired)
  # if systemctl is-enabled jenkins >/dev/null 2>&1; then
  #   echo \"[SOURCE] Stopping Jenkins service...\"
  #   sudo systemctl stop jenkins
  # fi

  # Create tar.gz from JENKINS_HOME, excluding jobs/ directory
  tar czf \"${SRC_ARCHIVE}\" \
    -C \"${SRC_JENKINS_HOME}\" \
    --exclude=\"jobs\" \
    --exclude=\"jobs/*\" \
    .

  echo \"[SOURCE] Archive created: ${SRC_ARCHIVE}\"
'"

#####################################
# 2) Copy archive from source to target
#####################################
echo
echo "==> Copying archive from source to target via scp ..."

# Remote-to-remote scp (executed from local machine)
scp "${SRC_USER}@${SRC_HOST}:${SRC_ARCHIVE}" "${DST_USER}@${DST_HOST}:${DST_ARCHIVE}"

echo "==> Archive copied to target: ${DST_HOST}:${DST_ARCHIVE}"

#####################################
# 3) Extract archive on target into JENKINS_HOME (overwrite mode)
#####################################
echo
echo "==> Extracting archive on target (overwrite into JENKINS_HOME) ..."

ssh "${DST_USER}@${DST_HOST}" bash -c "'
  set -e

  echo \"[TARGET] Archive: ${DST_ARCHIVE}\"
  echo \"[TARGET] JENKINS_HOME: ${DST_JENKINS_HOME}\"

  # Optional: stop Jenkins on target (recommended)
  # if systemctl is-enabled jenkins >/dev/null 2>&1; then
  #   echo \"[TARGET] Stopping Jenkins service...\"
  #   sudo systemctl stop jenkins
  # fi

  # Optional: create a quick backup of current config
  # BACKUP_DIR=\"${DST_JENKINS_HOME}_backup_$(date +%Y%m%d_%H%M%S)\"
  # echo \"[TARGET] Backing up current JENKINS_HOME to ${BACKUP_DIR}\"
  # cp -a \"${DST_JENKINS_HOME}\" \"${BACKUP_DIR}\"

  echo \"[TARGET] Extracting with overwrite...\"
  tar xzf \"${DST_ARCHIVE}\" \
    -C \"${DST_JENKINS_HOME}\" \
    --overwrite

  echo \"[TARGET] Cleaning up archive...\"
  rm -f \"${DST_ARCHIVE}\"

  echo \"[TARGET] Extraction complete.\"

  # Optional: start Jenkins on target
  # echo \"[TARGET] Starting Jenkins service...\"
  # sudo systemctl start jenkins
'"

echo
echo "✅ Migration completed (excluding jobs/)."
echo "   Source archive remains at: ${SRC_HOST}:${SRC_ARCHIVE} (you may delete it manually)."
