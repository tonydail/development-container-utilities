#!/bin/bash
SSH_KEY_FOLDER="$HOME/.ssh"
SYNC_SSH_KEY_NAME="id_unison_sync_key"
SYNC_PRIVATE_SSH_KEY="$SSH_KEY_FOLDER/$SYNC_SSH_KEY_NAME"
SYNC_PUBLIC_SSH_KEY="${SYNC_PRIVATE_SSH_KEY}.pub"

WORKING_FOLDER="$(pwd)/.devcontainer"
SSH_KEYS_FILE="$WORKING_FOLDER/.sshkeys"
ENVIRONMENT_FILE="$WORKING_FOLDER/.env"
EXCLUDES_FILE="$WORKING_FOLDER/sync_excludes"

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Success log
log_success() {
  echo -e "${GREEN}✅ Success:${NC} $1"
}

# Error log
log_error() {
  echo -e "${RED}❌ Error:${NC} $1"
}


# Warning log
log_warning() {
  echo -e "${YELLOW}⚠️ Warning:${NC} $1"
}

# Info log
log_info() {
  echo -e "${BLUE}📘 Info:${NC} $1"
}



installDependencies() {

  log_info "Installing dependencies..."
  local PACKAGE_NAME="unison"
  if ! brew list $PACKAGE_NAME &>/dev/null; then
    brew install $PACKAGE_NAME
    log_success "$PACKAGE_NAME installed successfully."
  else
    log_success "$PACKAGE_NAME is already installed."
  fi

  PACKAGE_NAME="unison-fsmonitor"
  if ! brew list $PACKAGE_NAME &>/dev/null; then
    brew install $PACKAGE_NAME
    log_success "$PACKAGE_NAME installed successfully."
  else
    log_success "$PACKAGE_NAME is already installed."
  fi
}


is_ssh_agent_running() {
  if [ -z "$SSH_AUTH_SOCK" ]; then
    return 1  # true
  else
    return 0  # false
  fi
}

create_sync_ssh_keys() {
  log_info "Verifying SSH keys for Unison Sync..."
  if [ ! -d "$SSH_KEY_FOLDER" ]; then
    mkdir -p "$SSH_KEY_FOLDER"
  fi

  if [ ! -f "$SYNC_PRIVATE_SSH_KEY" ] && [ ! -f "$SYNC_PUBLIC_SSH_KEY" ]; then
    ssh-keygen -t ed25519 -C "$USER" -f "$SYNC_PRIVATE_SSH_KEY" -N ""
    log_success "SSH keys created at $SYNC_PRIVATE_SSH_KEY and $SYNC_PUBLIC_SSH_KEY"
  else
    log_success "SSH keys already exist at $SYNC_PRIVATE_SSH_KEY and $SYNC_PUBLIC_SSH_KEY"
  fi


  cat $SYNC_PUBLIC_SSH_KEY >> $SSH_KEY_FOLDER/authorized_keys
  log_info "Added $SYNC_PUBLIC_SSH_KEY to $SSH_KEY_FOLDER/authorized_keys"
}

writeEnvironmentFile() {
  if [ -f "$ENVIRONMENT_FILE" ]; then
    log_info "Removing existing environment file at $ENVIRONMENT_FILE"
    rm -f "$ENVIRONMENT_FILE"
  fi

  if [ ! -f "$EXCLUDES_FILE" ]; then
    log_warning "Excludes file not found at $EXCLUDES_FILE. "
    EXCLUDES=()
  else
    mapfile -t EXCLUDES < $EXCLUDES_FILE
  fi
    
  rm -fv $ENVIRONMENT_FILE
  cat > $ENVIRONMENT_FILE <<EOL
  # Unison Sync Environment Variables
  SYNC_USER=$(whoami)
  SYNC_SERVER_DATA_PATH=$(pwd)
  SYNC_SERVER_WORKING_PATH="/$(basename "$(pwd)")"
  SYNC_EXECUTABLE_PATH=$(command -v unison)
  UNISON_META_HOME="/unison"
  EXCLUDE_ARGS="${EXCLUDES[@]}"
EOL
}

installDependencies
create_sync_ssh_keys
writeEnvironmentFile






