#!/usr/bin/env bash

set -Eeuo pipefail

#############################################
# VARIABLES
#############################################

APP_NAME="wealth-project"
LOG_DIR="/var/log/$APP_NAME"
TMP_DIR="/tmp/frontend"
NGINX_HTML="/usr/share/nginx/html"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}_${TIMESTAMP}.log"

ARTIFACT_URL="https://raw.githubusercontent.com/raghudevopsb88/wealth-project/main/artifacts/frontend.tar.gz"

#############################################
# COLORS
#############################################

R="\e[31m"
G="\e[32m"
Y="\e[33m"
B="\e[34m"
C="\e[36m"
N="\e[0m"

#############################################
# PREPARE LOGGING
#############################################

mkdir -p "$LOG_DIR"

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

#############################################
# ERROR HANDLING
#############################################

trap 'log "${R}ERROR occurred at line $LINENO${N}"' ERR

#############################################
# ROOT CHECK
#############################################

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log "${R}Please run as root${N}"
        exit 1
    fi
}

#############################################
# RETRY FUNCTION
#############################################

retry() {
    local retries=3
    local count=0
    local delay=5

    until "$@"; do
        exit_code=$?
        count=$((count+1))

        if [[ $count -lt $retries ]]; then
            log "${Y}Command failed. Retrying in $delay seconds...${N}"
            sleep $delay
        else
            log "${R}Command failed after $retries attempts.${N}"
            return $exit_code
        fi
    done
}

#############################################
# RUN COMMAND
#############################################

run() {

    local description=$1
    shift

    log "${C}▶ $description${N}"

    if "$@" &>> "$LOG_FILE"; then
        log "${G}✔ SUCCESS: $description${N}"
    else
        log "${R}✖ FAILED: $description${N}"
        exit 1
    fi
}

#############################################
# INSTALL PACKAGES
#############################################

install_packages() {

    run "Disabling default nginx module" \
        dnf module disable nginx -y

    run "Enabling nginx 1.26 module" \
        dnf module enable nginx:1.26 -y

    run "Installing nginx" \
        dnf install nginx -y

    run "Installing NodeJS repo" \
        bash -c "curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -"

    run "Installing NodeJS" \
        dnf install nodejs -y
}

#############################################
# START SERVICES
#############################################

start_services() {

    run "Enabling nginx service" \
        systemctl enable nginx

    run "Starting nginx service" \
        systemctl start nginx
}

#############################################
# DOWNLOAD APPLICATION
#############################################

download_artifacts() {

    mkdir -p "$TMP_DIR"

    run "Downloading application artifact" \
        retry curl -L -o "$TMP_DIR/frontend.tar.gz" "$ARTIFACT_URL"

    run "Extracting application files" \
        tar -xzf "$TMP_DIR/frontend.tar.gz" -C "$TMP_DIR"
}

#############################################
# BUILD APPLICATION
#############################################

build_app() {

    cd "$TMP_DIR/frontend"

    run "Installing dependencies" \
        npm ci

    run "Building application" \
        npm run build
}

#############################################
# DEPLOY APPLICATION
#############################################

deploy_app() {

    run "Cleaning nginx html directory" \
        rm -rf "$NGINX_HTML"/*

    run "Deploying application files" \
        cp -r "$TMP_DIR/frontend/dist/"* "$NGINX_HTML/"
}

#############################################
# VALIDATE NGINX
#############################################

validate_nginx() {

    run "Validating nginx configuration" \
        nginx -t

    run "Restarting nginx" \
        systemctl restart nginx
}

#############################################
# MAIN
#############################################

main() {

    log "${B}====================================${N}"
    log "${B}Starting deployment: $APP_NAME${N}"
    log "${B}Log file: $LOG_FILE${N}"
    log "${B}====================================${N}"

    check_root

    install_packages
    start_services
    download_artifacts
    build_app
    deploy_app
    validate_nginx

    log "${G}Deployment completed successfully 🚀${N}"
}

main