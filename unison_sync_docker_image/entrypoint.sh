#!/usr/bin/env bash
clear

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SSH_REMOTE_HOST=

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

ensure_file() {
    local file_path="$1"
    indent_logs="${2:-false}"
    
    if [ -f "$file_path" ]; then
      log_success "File exists: $file_path" $indent_logs
    else
      log_error "File does not exist: $file_path" $indent_logs 
      exit 1
    fi
}

ensure_directory() {
    local dir_path="$1"
    local create_if_missing="$2"
    indent_logs="${3:-false}"
    
    if [ -d "$dir_path" ]; then
        log_success "Directory exists: $dir_path" $indent_logs
    else
        if [ "$create_if_missing" = true ]; then
            if ! mkdir -p "$dir_path" 
            then
              log_error "Failed to create directory: $dir_path" $indent_logs 
            exit 1
            else
              log_success "Directory created: $dir_path" $indent_logs 
            fi
        
        else
            log_error "Directory does not exist: $dir_path" $indent_logs 
            exit 1
        fi
    fi
}

ensure_directory_symlink() {
    local dir_path="$1"
    local symlink_target="$2"
    indent_logs="${3:-false}"
    
    CREATE_SYMLINK=0

    if [[ -L "$symlink_target" ]]; then
      ACTUAL_TARGET=$(readlink -f "$symlink_target")
      if [[ "$ACTUAL_TARGET" == "$dir_path" ]]; then
        log_success "The symlink '$symlink_target' points to the correct directory: '$dir_path'." $indent_logs
        CREATE_SYMLINK=0
      else
        log_warning "The symlink '$symlink_target' points to '$ACTUAL_TARGET', but expected '$dir_path'.  Deleting and recreating." $indent_logs
        rm -f "$symlink_target"
        CREATE_SYMLINK=1
      fi
    else
      CREATE_SYMLINK=1
    fi

    if [[ $CREATE_SYMLINK -eq 1 ]]; then
      if ! ln -s "$dir_path" "$symlink_target"
      then
        log_error "Could not create symlink $dir_path -> $symlink_target" $indent_logs
      else
        log_success "Created symlink $dir_path -> $symlink_target" $indent_logs
      fi
    fi
    
}

setDirectoryOwnership() {
    local path="$1"
    local user="$2"
    local group="$3"
    log_info "Setting ownership..."

    if [ -d "$path" ] || [ -f "$path" ]; then
        if ! chown -R "$user":"$group" "$path"
        then
          log_error "Failed to set ownership of $path to $user:$group" true
          exit 1
        else
          log_success "Set ownership of $path to $user:$group, including all subdirectories and files." true
        fi
    else
        log_error "Path $path does not exist. Cannot set ownership." true
        exit 1
    fi
} 

configureSSH() {
  log_info "Configuring SSH..."
  
  if ! cp /ssh_config/id_unison_sync_key "$SSH_HOME/"
  then
    log_error "Could not copy private SSH key to $SSH_HOME" true
    exit 1
  else
    log_success "Copied private SSH key to $SSH_HOME" true
  fi

  if ! cp /ssh_config/id_unison_sync_key.pub "$SSH_HOME/"
  then
    log_error "Could not copy public SSH key to $SSH_HOME" true
    exit 1
  else
    log_success "Copied public SSH key to $SSH_HOME" true
  fi

  if ! chmod 400 "$SSH_HOME/id_unison_sync_key.pub"
  then
    log_error "Could not set permissions on public SSH key" true
    exit 1
  else
    log_success "Set permissions on public SSH key" true
  fi

  if ! chmod 400 "$SSH_HOME/id_unison_sync_key"
  then
    log_error "Could not set permissions on private SSH key" true
    exit 1
  else
    log_success "Set permissions on private SSH key" true
  fi


  log_info "Setting up SSH config for unison..."
  {
    echo "Host $SSH_REMOTE_HOST"
    echo "  HostName $SSH_REMOTE_HOST"
    echo "  User $SYNC_USER"
    echo "  StrictHostKeyChecking no"
    echo "  IdentityFile $SSH_HOME/id_unison_sync_key"
  } >> "$SSH_HOME/config"
 
  ensure_file "$SSH_HOME/config" true
}

createUser(){
  UNISON_USER="unison"
  UNISON_UID=1000
  UNISON_GROUP="sync"
  UNISON_GID=1001
  UNISON_HOME=

  log_info "Creating unison user and group..."


    if ! getent group "$UNISON_GROUP" >/dev/null 2>&1; then
        if ! addgroup -g "$UNISON_GID" "$UNISON_GROUP"
        then
            log_error "Failed to create group $UNISON_GROUP with GID $UNISON_GID." true
            exit 1
        else
            log_success "Group $UNISON_GROUP with GID $UNISON_GID created." true
        fi
    else
        log_success "Group $UNISON_GROUP already exists." true
    fi


    if ! id -u "$UNISON_USER" >/dev/null 2>&1; then
        if ! adduser -u "$UNISON_UID" -G "$UNISON_GROUP" -s /bin/bash -h "/home/$UNISON_USER" -D "$UNISON_USER" && echo "$UNISON_USER" | chpasswd
        then
            log_error "Failed to create user $UNISON_USER with UID $UNISON_UID and group name $UNISON_GROUP." true
            exit 1
        else
            log_success "User $UNISON_USER with UID $UNISON_UID and group name $UNISON_GROUP created." true
        fi
    else
        log_success "User $UNISON_USER already exists." true
    fi

    UNISON_HOME=$(getent passwd $UNISON_USER | cut -d: -f6)
    log_info "User $UNISON_USER home directory is $UNISON_HOME" true
}

executeSync() {
  UNISION_PROFILE_NAME="codesync"
  UNISON_PROFILE="$UNISON_META_HOME_LN/$UNISION_PROFILE_NAME.prf"

  EXCLUDES=($EXCLUDE_ARGS)

  if [ -f "$UNISON_PROFILE" ]; then
    rm -f "$UNISON_PROFILE"
    log_info "Removed existing unison profile at $UNISON_PROFILE"
  fi

  log_info "Creating unison profile at $UNISON_PROFILE"
  {
    echo "root = $SYNC_SERVER_WORKING_PATH"
    echo "root = ssh://$SSH_REMOTE_HOST/$SYNC_SERVER_DATA_PATH"
    echo ""
    for EXCLUDE in "${EXCLUDES[@]}"; do
    echo "ignore = Name ${EXCLUDE}"
    done
    echo ""
    echo "auto = true"
    echo "batch = true"
    echo "repeat = watch"
    echo "fastcheck = true"
    echo ""
    echo "servercmd = $SYNC_EXECUTABLE_PATH"
  } >> "$UNISON_PROFILE"

  log_success "Created unison profile at $UNISON_PROFILE" true

  exec su-exec $UNISON_USER unison $UNISION_PROFILE_NAME

}

## Main script execution starts here
log_info "Starting entrypoint script..."
echo ""
log_info "Checking required environment variables..."
REQUIRED_VARS=("SYNC_SERVER_DATA_PATH" "SYNC_SERVER_WORKING_PATH" "SYNC_EXECUTABLE_PATH" "SYNC_USER" "UNISON_META_HOME")

ENVIRONMENT_VARIABLE_ERROR=0
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var}" ]]; then
    log_error "Required environment variable '$var' is not set." true
    ENVIRONMENT_VARIABLE_ERROR=1
  fi
done

if [[ $ENVIRONMENT_VARIABLE_ERROR -eq 1 ]]; then
  exit 1
fi
log_success "All required environment variables are set."
echo "" 

if [ -z "$REMOTE_HOST" ]; then
  SSH_REMOTE_HOST="host.docker.internal"
else
  SSH_REMOTE_HOST="$REMOTE_HOST"
fi

createUser

# Ensure all required directories exist, creating them if necessary
log_info "Ensuring required directories exist, creating them if necessary..."
SYNC_DIRECTORIES=("$UNISON_HOME" "$UNISON_HOME/.ssh")
for dir in "${SYNC_DIRECTORIES[@]}"; do
    ensure_directory "$dir" true true
done

SSH_HOME=$(realpath "$UNISON_HOME"/.ssh)
UNISON_META_HOME_LN="$UNISON_HOME/.unison"


# Symlink .unison folder from user home directory to sync directory so that we only need 1 volume
#log_info "Ensuring symlink unison meta folder from $UNISON_HOME directory to $SYNC_SERVER_WORKING_PATH/.unison so we only need 1 volume..."

setDirectoryOwnership "$UNISON_META_HOME" "$UNISON_USER" "$UNISON_GROUP" 
log_info "Ensuring symlink from $UNISON_META_HOME to $UNISON_META_HOME_LN."
ensure_directory_symlink "$UNISON_META_HOME" "$UNISON_META_HOME_LN" true

configureSSH
# Change data owner
setDirectoryOwnership "$SYNC_SERVER_WORKING_PATH" "$UNISON_USER" "$UNISON_GROUP"



# Change to the sync directory

if ! cd "$SYNC_SERVER_WORKING_PATH"
then
  log_error "Could not change directory to $SYNC_SERVER_WORKING_PATH"
  exit 1
else
  log_success "Changed directory to $SYNC_SERVER_WORKING_PATH"
fi

setDirectoryOwnership "$UNISON_HOME" "$UNISON_USER" "$UNISON_GROUP"

executeSync