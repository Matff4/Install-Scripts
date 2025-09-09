#!/usr/bin/env bash

# Ubuntu Post-Install Interactive Setup Script
# Execution: bash -c "$(curl -fsSL https://raw.githubusercontent.com/Matff4/Install-Scripts/refs/heads/main/ubuntu-fresh-install.sh)"

set -euo pipefail

# ─── 1) Helpers ──────────────────────────────────────────────────────────────────
GREEN=$(tput setaf 2); BLUE=$(tput setaf 4); RESET=$(tput sgr0)
print_success() { echo "${GREEN}[✓]${RESET} $1"; }
print_info() { echo "${BLUE}[?]${RESET} $1"; }

# ─── 2) Silent APT update & upgrade ─────────────────────────────────────────────
print_info "Updating software..."
apt-get update  -y > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1
print_success "Software updated."

# ─── 3) Ensure dialog is installed ───────────────────────────────────────────────
if ! command -v dialog &>/dev/null; then
  apt-get install -y dialog > /dev/null 2>&1
fi

# ─── 4) Installer functions ──────────────────────────────────────────────────────
install_basic_software() {
  print_info "Installing basic software..."
  apt-get install -y \
    fastfetch \
    btop \
    git \
    tree \
    ncdu \
    > /dev/null 2>&1
  print_success "Basic software installed."
}

install_qemu_guest_agent() {
  print_info "Installing QEMU Guest Agent..."
  apt-get install -y qemu-guest-agent > /dev/null 2>&1
  systemctl enable --now qemu-guest-agent > /dev/null 2>&1
  print_success "QEMU Guest Agent installed and enabled."
}

install_auto_updates() {
  print_info "Enabling automatic apt updates..."
  apt-get install -y unattended-upgrades apt-listchanges > /dev/null 2>&1
  dpkg-reconfigure --frontend noninteractive unattended-upgrades > /dev/null 2>&1
  systemctl enable --now unattended-upgrades > /dev/null 2>&1
  # Ensure all updates, not just security
  sed -i 's@//\s*"\${distro_id}:\${distro_codename}";@"${distro_id}:${distro_codename}";@' /etc/apt/apt.conf.d/50unattended-upgrades
  print_success "Automatic apt updates enabled and configured to install all updates."
}

install_docker() {
  print_info "Installing Docker Engine..."

  apt-get install -y ca-certificates curl gnupg > /dev/null 2>&1
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y > /dev/null 2>&1
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1

  usermod -aG docker "$SUDO_USER"

  print_success "Docker installed and user '$SUDO_USER' added to docker group."
}


# ─── 5) Show checklist ───────────────────────────────────────────────────────────
HEIGHT=15; WIDTH=75; LIST_HEIGHT=8

dialog --clear \
  --title "Ubuntu Fresh Setup" \
  --checklist "Select items to install:" \
    $HEIGHT $WIDTH $LIST_HEIGHT \
    1 "[Basic software] (fastfetch, btop, git, tree, ncdu)" ON \
    2 "[QEMU Guest Agent] (qemu-guest-agent)" ON \
    3 "[Automatic updates] (unattended-upgrades)" ON \
    4 "[Docker] (Engine, CLI, containerd)" OFF \
  2> /tmp/choices.$$

# ─── 6) Read & dispatch ──────────────────────────────────────────────────────────
SELECTIONS=$(< /tmp/choices.$$)
rm /tmp/choices.$$

for tag in $SELECTIONS; do
  case "$tag" in
    1) install_basic_software ;;
    2) install_qemu_guest_agent ;;
    3) install_auto_updates ;;
    4) install_docker ;;
  esac
done

print_success "All selected items have been installed!"
