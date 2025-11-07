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
  apt-get remove -y \
    vim-common \
    vim-tiny \
    > /dev/null 2>&1
    
  apt-get install -y \
    fastfetch \
    vim \
    btop \
    git \
    tree \
    ncdu \
    bat \
    nfs-common \
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
  # Ensure apt lists are fresh to get metadata for all repos
  apt-get update > /dev/null 2>&1
  # Purge first to ensure a clean default config file on install
  apt-get purge -y unattended-upgrades > /dev/null 2>&1
  apt-get install -y unattended-upgrades apt-listchanges > /dev/null 2>&1

  # This step may not be necessary if the purge/install works, but is safe to keep.
  dpkg-reconfigure --frontend noninteractive unattended-upgrades > /dev/null 2>&1

  local CONFIG_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"

  # --- Part 1: Enable standard OS updates in Origins-Pattern ---
  print_info "Enabling standard OS updates via Origins-Pattern..."
  # Uncomment the default lines for security and standard updates.
  sed -i -E 's#^//\s*("origin=.*-security.*);#\1;#' "$CONFIG_FILE"
  sed -i -E 's#^//\s*("origin=.*-updates.*);#\1;#' "$CONFIG_FILE"

  # --- Part 2: Explicitly disable proposed updates for stability ---
  print_info "Disabling proposed-updates..."
  # Finds any active 'proposed-updates' line and comments it out.
  # This is idempotent - running it multiple times won't break the file.
  sed -i -E 's/^(\s*".*proposed-updates.*);/\/\/ \1;/' "$CONFIG_FILE"

  # --- Part 3: Dynamically add all other configured repositories ---
  print_info "Scanning for third-party repositories to add to Origins-Pattern..."
  
  # Loop through all Release files to find Origin and Suite info
  for release_file in /var/lib/apt/lists/*Release; do
    [ -f "$release_file" ] || continue
    
    local origin=$(grep -oP '^Origin: \K.*' "$release_file" | head -n1)
    local suite=$(grep -oP '^(Suite|Codename): \K.*' "$release_file" | head -n1)

    if [ -n "$origin" ] && [ -n "$suite" ]; then
      local origin_pattern="\"origin=${origin},codename=${suite}\";"
      
      if ! grep -q -F "${origin_pattern}" "$CONFIG_FILE"; then
        print_info "Adding pattern: ${origin_pattern}"
        sed -i '/^Unattended-Upgrade::Origins-Pattern\s*{/a \        '"${origin_pattern}"'' "$CONFIG_FILE"
      fi
    fi
  done

  # --- Part 4: Finalize and restart the service ---
  systemctl enable --now unattended-upgrades > /dev/null 2>&1
  systemctl restart unattended-upgrades

  print_success "Automatic apt updates enabled for all configured sources."
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
HEIGHT=15; WIDTH=85; LIST_HEIGHT=8

dialog --clear \
  --title "Ubuntu Fresh Setup" \
  --checklist "Select items to install:" \
    $HEIGHT $WIDTH $LIST_HEIGHT \
    1 "[Basic software]" ON \
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
