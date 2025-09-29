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

writeEnvironmentFile() {
  log_info "Writing environment file to $ENVIRONMENT_FILE"
  mkdir -p "$(dirname "$ENVIRONMENT_FILE")"

  local EXCLUDES=()
  if [ -f "$EXCLUDES_FILE" ]; then
    log_info "Loading unison sync excludes from $EXCLUDES_FILE" true
    # read non-empty non-comment lines
    while IFS= read -r line; do
      line="${line%%#*}" # strip comments
      line="$(echo "$line" | xargs)" # trim
      [ -n "$line" ] && EXCLUDES+=("$line")
    done < "$EXCLUDES_FILE"
    log_success "Unison sync excludes loaded." true
  else
    log_warning "No excludes file at $EXCLUDES_FILE; continuing with no excludes." true
  fi

  local exclude_args="${EXCLUDES[*]:-}"

  # Determine local IP in a platform-aware way (macOS / Linux / WSL)
  detect_platform
  local remote_host
  remote_host=$(get_local_ip)

  local tmp
  tmp=$(mktemp) || die "Unable to create temp file"
  cat > "$tmp" <<EOL
# Unison Sync Environment Variables
SYNC_USER="$(whoami)"
SYNC_SERVER_DATA_PATH="$(pwd)"
SYNC_SERVER_WORKING_PATH="/$(basename "$(pwd)")"
SYNC_EXECUTABLE_PATH="$(command -v unison || true)"
UNISON_META_HOME="/unison"
EXCLUDE_ARGS="$exclude_args"
REMOTE_HOST="$remote_host"
SERVICE_NAME="$(basename "$(pwd)")"
EOL



  log_info "Checking for environment extension file at $ENVIROMENT_EXTENTSION_FILE" true
  if [ -f "$ENVIROMENT_EXTENTSION_FILE" ]; then
    cat "$ENVIROMENT_EXTENTSION_FILE" >> "$tmp"
    log_success "Appended contents from $ENVIROMENT_EXTENTSION_FILE TO $ENVIRONMENT_FILE." true
  else
    log_warning "No environment extension file at $ENVIROMENT_EXTENTSION_FILE; skipping." true
  fi

    mv "$tmp" "$ENVIRONMENT_FILE"
    chmod 644 "$ENVIRONMENT_FILE" || true
    log_success "Wrote environment file to $ENVIRONMENT_FILE" true
}



# Main  
installDependencies
create_sync_ssh_keys
writeEnvironmentFile






