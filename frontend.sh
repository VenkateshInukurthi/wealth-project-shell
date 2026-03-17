#!/usr/bin/env bash
set -Exeuo pipefail

#############################################
# VARIABLES
#############################################

APP_NAME="wealth-project"
LOG_DIR="/var/log/$APP_NAME"
TMP_DIR="/tmp/$APP_NAME"
ARTIFACT="$TMP_DIR/frontend.tar.gz"
EXTRACT_DIR="$TMP_DIR/frontend"
NGINX_HTML="/usr/share/nginx/html"

ARTIFACT_URL="https://raw.githubusercontent.com/raghudevopsb88/wealth-project/main/artifacts/frontend.tar.gz"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOG_DIR/${SCRIPT_NAME}_${TIMESTAMP}.log"

#############################################
# COLORS
#############################################

R="\e[31m"
G="\e[32m"
Y="\e[33m"
C="\e[36m"
N="\e[0m"

#############################################
# LOGGING
#############################################

mkdir -p "$LOG_DIR"
mkdir -p "$EXTRACT_DIR"
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

#############################################
# ERROR HANDLING
#############################################

trap 'log "${R}Error occurred at line $LINENO${N}"' ERR

#############################################
# ROOT CHECK
#############################################

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log "${R}Run this script as root${N}"
        exit 1
    fi
}

#############################################
# COMMAND RUNNER
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
# INSTALL PACKAGES (IDEMPOTENT)
#############################################

install_nginx() {

    run "Disabling default nginx module" dnf module disable nginx -y
    run "Enabling nginx 1.26 module" dnf module enable nginx:1.26 -y
    run "Installing nginx" dnf install nginx -y

}

install_node() {

    run "Adding NodeJS repo" bash -c "curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -"
    run "Installing NodeJS" dnf install nodejs -y

}

#############################################
# SERVICE MANAGEMENT
#############################################

setup_nginx_service() {

    if ! systemctl is-enabled nginx &>/dev/null; then
        run "Enabling nginx service" systemctl enable nginx
    fi

    if ! systemctl is-active nginx &>/dev/null; then
        run "Starting nginx service" systemctl start nginx
    fi
}

#############################################
# DOWNLOAD ARTIFACT
#############################################

download_artifact() {

    mkdir -p "$TMP_DIR"

    run "Downloading application artifact" \
    curl -L -o "$ARTIFACT" "$ARTIFACT_URL"

}

#############################################
# EXTRACT ARTIFACT
#############################################

extract_artifact() {
    # cd "$EXTRACT_DIR"
    run "Extracting artifact" tar -xzf "$ARTIFACT" -C "$EXTRACT_DIR"
}

#############################################
# BUILD APPLICATION
#############################################

build_app() {

    cd "$EXTRACT_DIR"

    run "Installing dependencies" npm ci
    run "Building application" npm run build
}

#############################################
# DEPLOY APPLICATION
#############################################

deploy_app() {

    if [[ ! -d "$NGINX_HTML" ]]; then
        run "Creating nginx html directory" mkdir -p "$NGINX_HTML"
    fi

    run "Cleaning nginx html directory" rm -rf ${NGINX_HTML}/*

    run "Deploying application files" \
    cp -r ${EXTRACT_DIR}/dist/* "$NGINX_HTML/"
}

#############################################
# Configuring NGIN
#############################################

configure_nginx() {
    run "Removing default configuration" rm -rf /etc/nginx/nginx.conf
    run "Copying nginx configuration file" cp -r /opt/wealth-project-shell/nginx.conf /etc/nginx/nginx.conf
    run "removing default.config file" rm -f /etc/nginx/conf.d/default.conf
}

#############################################
# VALIDATE NGINX
#############################################

validate_nginx() {

    run "Testing nginx configuration" nginx -t
    run "Restarting nginx" systemctl restart nginx
}

#############################################
# MAIN
#############################################

main() {

    log "${C}================================${N}"
    log "${C}Starting deployment: $APP_NAME${N}"
    log "${C}Log file: $LOG_FILE${N}"
    log "${C}================================${N}"

    check_root

    install_nginx
    install_node
    setup_nginx_service

    download_artifact
    extract_artifact
    build_app
    deploy_app
    configure_nginx
    validate_nginx

    log "${G}Deployment completed successfully 🚀${N}"
}

main