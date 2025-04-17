#!/usr/bin/env bash

# Ubuntu Post-Install Interactive Setup Script
# Execution: bash -c "$(curl -fsSL https://raw.githubusercontent.com/Matff4/Install-Scripts/refs/heads/main/ubuntu-fresh-install.sh)"

set -e

# Colors for output
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

# Utility functions
function print_success() {
  echo "${GREEN}[✓]${RESET} $1"
}

# Initial update and upgrade (no prompt)
function initial_update_upgrade() {
  print_success "Updating package lists..."
  apt-get update -y
  print_success "Upgrading packages..."
  apt-get upgrade -y
}

# Individual software installation functions
function install_docker() {
  print_success "Installing Docker..."
  apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io
  usermod -aG docker "$SUDO_USER"
  print_success "Docker has been installed."
}

function install_cockpit() {
  print_success "Installing Cockpit..."
  apt-get install -y cockpit cockpit-podman cockpit-networkmanager
  systemctl enable --now cockpit.socket
  print_success "Cockpit is now installed and enabled."
}

function install_zfs() {
  print_success "Installing ZFS..."
  apt-get install -y zfsutils-linux
  print_success "ZFS utilities installed."
}

function install_common_tools() {
  print_success "Installing common CLI tools..."
  apt-get install -y htop vim curl wget git net-tools unzip gnupg2
  print_success "Common utilities installed."
}

# Add more software installation functions here as needed

# Display prompt for user to select software to install
function show_install_menu() {
  OPTIONS=$(whiptail --title "Ubuntu Fresh Setup" --checklist \
  "Select software to install (use space to select):" 20 78 10 \
  "docker"   "Install Docker"      ON \
  "cockpit"  "Install Cockpit"     ON \
  "zfs"      "Install ZFS tools"   OFF \
  "tools"    "Install common tools" ON \
  3>&1 1>&2 2>&3)

  # Check for the selected options and run corresponding functions
  for option in $OPTIONS; do
    case $option in
      \"docker\") install_docker ;;
      \"cockpit\") install_cockpit ;;
      \"zfs\") install_zfs ;;
      \"tools\") install_common_tools ;;
    esac
  done

  print_success "All selected packages have been installed!"
}

# Main execution flow
initial_update_upgrade
show_install_menu
