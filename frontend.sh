#!/bin/bash

set -euo pipefail

#   VARIABLES
LOG_PATH="/var/log/wealth-monitoring-platform"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRIPT_NAME=$(basename $0 .sh)
LOG_FILE="$LOG_PATH/${SCRIPT_NAME}_${TIMESTAMP}.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
C="\e[36m"

#   Logging function
log() {
    echo -e "$1" | tee -a $LOG_FILE
}

#   CHECK_ROOT USER
CHECK_ROOT() {
if [ "$EUID" -ne 0 ]
then
    log "${R}Please execute the script with root permissions${N}"
    exit 1
fi
}

#   COMMAND RUNNER FUNCTION
RUN() {
    COMMAND=$1
    DESCRIPTION=$2

    echo -e "${Y}${DESCRIPTION}... ${N}" | tee -a $LOG_FILE

    eval "${COMMAND}" &>> tee -a $LOG_FILE

    if [ $? -ne 0 ]
    then
        echo -e "${R}DESCRIPTION... FAILED${N}" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "${Y}DESCRIPTION... SUCCESS${N}" | tee -a $LOG_FILE
    fi
}
CHECK_ROOT
#   Starting Script execution
RUN "dnf module disable nginx -y" "Disabling default Nginx"
RUN "dnf module enable nginx:1.26 -y" "Enabling 1.26 module version of Nginx"
RUN "dnf install nginx -y" "Installing Nginx"

RUN "systemctl enable nginx" "Enabling Nginx service"
RUN "systemctl start nginx" "Starting Nginx service"

RUN "curl -fsSL https://rpm.nodesource.com/setup-22.x | bash -" "Creating NodeSource repository as it in not available on the server"
RUN "dnf install nodejs -y" "Installing NodeJS"

RUN "node --version" "Validating the nodejs version"
RUN "npm --version" "Validating npm version"

#   DOWNLOAD and BUILD

RUN "curl -L -o /tmp/frontend.tar.gz https://raw.githubcontent.com/raghudevopsb88/wealth-project/main/artifacts/frontend.tar.gz" "Downloading the application Source code"
RUN "mkdir -p /tmp/frontend" "Creating tmp directory"
RUN "cd /tmp/frontend" "Move to frontend directory"
RUN "tar xzf /tmp/frontend.tar.gz" "Unzipping the application code"
RUN "cd /tmp/frontend" "Moving to tmp directory"
RUN "npm ci" "Installing ci dependencies"
RUN "npm run build" "Building the application"

#   DEPLOYING to NGINX
RUN "rm -rf /usr/share/nginx/html/*" "Removing default NGINX pages"
RUN "cp -r /tmp/frontend/dist/* /usr/share/nginx/html/" "Copying the application html pages"

RUN "rm -f /etc/nginx/nginx.conf" "Remove default configuration"
RUN "cp /opt/wealth-project-shell/nginx.conf /etc/nginx/nginx.conf" "Creating application configuration file"

RUN "rm -f /etc/nginx/conf.d/default.conf" "Removing default configuration"

RUN "nginx -t" "Testing Nginx configuration"
RUN "systemctl restart nginx" "Restarting nginx"