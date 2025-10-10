#!/usr/bin/env bash

# Refactored init script: more readable, robust and idempotent.
set -euo pipefail
IFS=$'\n\t'

SSH_KEY_FOLDER="${HOME:-$USERPROFILE}/.ssh"
SYNC_SSH_KEY_NAME="id_unison_sync_key"
SYNC_PRIVATE_SSH_KEY="$SSH_KEY_FOLDER/$SYNC_SSH_KEY_NAME"
SYNC_PUBLIC_SSH_KEY="${SYNC_PRIVATE_SSH_KEY}.pub"

WORKING_FOLDER="$(pwd)/.devcontainer"
ENVIRONMENT_FILE="$WORKING_FOLDER/.env"
EXCLUDES_FILE="$WORKING_FOLDER/unison_sync_excludes"
ENVIROMENT_EXTENTSION_FILE="$WORKING_FOLDER/environment-overrides"

# Platform detection (macos | linux | wsl | unknown)
detect_platform() {
  local uname_s
  uname_s=$(uname -s | tr '[:upper:]' '[:lower:]')
  if echo "$uname_s" | grep -q "darwin"; then
    PLATFORM="macos"
  elif echo "$uname_s" | grep -q "linux"; then
    # detect WSL
    if grep -qi microsoft /proc/version 2>/dev/null || grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
      PLATFORM="wsl"
    else
      PLATFORM="linux"
    fi
  else
    PLATFORM="unknown"
  fi
}

# Get the machine's preferred IPv4 address. Returns 127.0.0.1 on failure.
get_local_ip() {
  local ip
  case "${PLATFORM:-}" in
    macos)
      local iface
      iface=$(route get default 2>/dev/null | awk -F': ' '/interface:/{print $2; exit}' || true)
      if [ -n "$iface" ]; then
        ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
      fi
      ;;
    linux|wsl)
      # Try ip route first
      if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1 || true)
      fi
      # Fallback to hostname -I or ifconfig
      if [ -z "${ip:-}" ]; then
        if command -v hostname >/dev/null 2>&1; then
          ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
        fi
      fi
      if [ -z "${ip:-}" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}' || true)
      fi
      ;;
    *)
      ip=127.0.0.1
      ;;
  esac
  ip=${ip:-127.0.0.1}
  printf "%s" "$ip"
}

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function getIndentation() {
  indent=${1:-"false"}
  if [ "$indent" == "true" ]; then
    num_spaces=4
  else
    num_spaces=0
  fi
  printf "%${num_spaces}s"
}

# Success log
log_success() {
  message="$1"
  spaces=$(getIndentation "${2:-"false"}")
  echo -e "${spaces}${GREEN}Success:${NC} $message"
}

# Error log
log_error() {
  message="$1"
  spaces=$(getIndentation "${2:-"false"}")
  echo -e "${spaces}${RED}Error:${NC} $message"
}


# Warning log
log_warning() {
  message="$1"
  spaces=$(getIndentation "${2:-"false"}")
  echo -e "${spaces}${YELLOW}Warning:${NC} $message"
}

# Info log
log_info() {
  message="$1"
  spaces=$(getIndentation "${2:-"false"}")
  echo -e "${spaces}${BLUE}Info:${NC} $message"
}

die() { log_error "$1"; exit ${2:-1}; }

escape_chars() {
  local input_string="$1"
  shift # Remove the first argument (input_string)
  local chars_to_escape=("$@") # Remaining arguments are the characters to escape
  local escaped_string="$input_string"

  for char in "${chars_to_escape[@]}"; do
    # Use parameter expansion to replace each character with its escaped version
    # The backslash needs to be escaped itself for the replacement pattern
    escaped_string="${escaped_string//"$char"/"\\$char"}"
  done

  echo "$escaped_string"
}


writeEnvironmentComment() {
    local comment="$1"
    local env_file="$2"

    sed -I '' "/${comment}/d" "$env_file" || die "Failed to update $var_name in $env_file"
    printf "\n\n# %s" "$comment" >> "$env_file" || die "Failed to write comment to $env_file"

}

writeEnvironmentFileEntry() {
  local var_name="$1"
  local var_value="$2"
  local env_file="$3"

  sed -I '' "/${var_name}/d" "$env_file" || die "Failed to update $var_name in $env_file"
  printf "\n%s=\"%s\"" "$var_name" "$var_value" >> "$env_file" || die "Failed to add $var_name to $env_file"  
}

writeEnvironmentFile() {
    detect_platform
    local remote_host
    remote_host=$(get_local_ip)

    local tmp
    tmp=$(mktemp) || die "Unable to create temp file"
    echo "$tmp"
    cat "$ENVIRONMENT_FILE" > "$tmp"

    writeEnvironmentComment "Unison Sync Environment Variables" "$tmp"
    writeEnvironmentFileEntry "SYNC_USER" "$(whoami)" "$tmp"
    writeEnvironmentFileEntry "SYNC_SERVER_DATA_PATH" "$(pwd)" "$tmp"
    writeEnvironmentFileEntry "SYNC_SERVER_WORKING_PATH" "/$(basename "$(pwd)")" "$tmp"
    writeEnvironmentFileEntry "SYNC_EXECUTABLE_PATH" "$(command -v unison || true)" "$tmp"
    writeEnvironmentFileEntry "UNISON_META_HOME" "/unison" "$tmp"
    writeEnvironmentFileEntry "REMOTE_HOST" "$remote_host" "$tmp"
    writeEnvironmentFileEntry "SERVICE_NAME" "$(basename "$(pwd)")" "$tmp"

    mv -f "$tmp" "$ENVIRONMENT_FILE"
    chmod 644 "$ENVIRONMENT_FILE" || true
    log_success "Wrote environment file to $ENVIRONMENT_FILE" true
    
}

installDependencies() {
  detect_platform
  log_info "Platform detected: ${PLATFORM:-unknown}"
  log_info "Checking and installing dependencies..."
  local packages=(unison unison-fsmonitor)

  if [ "${PLATFORM:-}" = "macos" ]; then
    if ! command -v brew &>/dev/null; then
      log_warning "Homebrew not found; skipping automatic install. Install 'unison' manually or add brew to PATH." true
      return
    fi
    for pkg in "${packages[@]}"; do
      if brew list --formula | grep -q "^${pkg}$"; then
        log_success "$pkg is already installed." true
      else
        brew install "$pkg"
        log_success "$pkg installed." true
      fi
    done
    return
  fi

  if [ "${PLATFORM:-}" = "linux" ] || [ "${PLATFORM:-}" = "wsl" ]; then
    # Try common Linux package managers
    if command -v apt-get &>/dev/null; then
      log_info "Using apt-get to install unison packages (may require sudo)..."
      sudo apt-get update && sudo apt-get install -y "${packages[@]}" || log_warning "apt-get install failed or was skipped"
      return
    elif command -v yum &>/dev/null; then
      log_info "Using yum to install unison packages (may require sudo)..."
      sudo yum install -y "${packages[@]}" || log_warning "yum install failed or was skipped"
      return
    elif command -v pacman &>/dev/null; then
      log_info "Using pacman to install unison packages (may require sudo)..."
      sudo pacman -S --noconfirm "${packages[@]}" || log_warning "pacman install failed or was skipped"
      return
    else
      log_warning "No known package manager found; please install unison manually."
      return
    fi
  fi

  log_warning "Unknown platform; skipping automatic dependency installation."
}

is_ssh_agent_running() {
  [ -n "${SSH_AUTH_SOCK:-}" ] && return 0 || return 1
}

create_sync_ssh_keys() {
  log_info "Ensuring SSH keys for Unison sync..."
  mkdir -p "$SSH_KEY_FOLDER"
  chmod 700 "$SSH_KEY_FOLDER" || true

  if [ ! -f "$SYNC_PRIVATE_SSH_KEY" ] || [ ! -f "$SYNC_PUBLIC_SSH_KEY" ]; then
    log_info "SSH keys not found. Generating new SSH key pair..."
    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$SYNC_PRIVATE_SSH_KEY" -N "" || die "ssh-keygen failed"
    log_success "SSH key pair created." true
  else
    log_success "SSH key pair already exists." true
  fi

  local auth_file="$SSH_KEY_FOLDER/authorized_keys"
  touch "$auth_file"
  chmod 600 "$auth_file" || true

  log_info "Adding public key to authorized_keys if not already present..."
  if ! grep -Fqx "$(cat "$SYNC_PUBLIC_SSH_KEY")" "$auth_file" 2>/dev/null; then
    cat "$SYNC_PUBLIC_SSH_KEY" >> "$auth_file"
    log_success "Added public key to $auth_file" true
  else
    log_success "Public key already present in $auth_file" true
  fi

  if is_ssh_agent_running; then
  log_info "ssh-agent is running. Adding private key to ssh-agent..."
    if ! ssh-add -l 2>/dev/null | grep -q "$SYNC_PRIVATE_SSH_KEY"; then
      ssh-add "$SYNC_PRIVATE_SSH_KEY" 2>/dev/null || log_warning "Could not add key to ssh-agent." true
    fi
  else
    log_warning "ssh-agent not running; skipping ssh-add." true
  fi
}


# Main  
installDependencies
create_sync_ssh_keys
writeEnvironmentFile
find . -type f -name '*.DS_Store' -ls -delete