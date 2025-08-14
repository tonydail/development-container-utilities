#!/bin/bash
WORKSPACE_NAME="$1"
CONTAINER_NAME="${WORKSPACE_NAME,,}"
WORKSPACE_FOLDER="$2"
UNISON_VERSION=2.53.7-r0
SYNC_SSH_KEY_FOLDER="$HOME/.ssh"
SYNC_SSH_KEY_NAME="id_unison_sync_key"
SYNC_PRIVATE_SSH_KEY="$SYNC_SSH_KEY_FOLDER/$SYNC_SSH_KEY_NAME"
SYNC_PUBLIC_SSH_KEY="${SYNC_PRIVATE_SSH_KEY}.pub"


SSH_KEY_FOLDER="$HOME/.ssh"

installDependencies() {

  echo "Installing dependencies..."
  local PACKAGE_NAME="unison"
  if ! brew list $PACKAGE_NAME &>/dev/null; then
    echo "Installing $PACKAGE_NAME..."
    brew install $PACKAGE_NAME
  else
    echo "$PACKAGE_NAME is already installed."
  fi
  PACKAGE_NAME="unison-fsmonitor"
  if ! brew list $PACKAGE_NAME &>/dev/null; then
    echo "Installing $PACKAGE_NAME..."
    brew install $PACKAGE_NAME
  else
    echo "$PACKAGE_NAME is already installed."
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
  echo "Verifying SSH keys or Unison Sync..."
  if [ ! -d "$SYNC_SSH_KEY_FOLDER" ]; then
    mkdir -p "$SYNC_SSH_KEY_FOLDER"
  fi

  if [ ! -f "$SYNC_PRIVATE_SSH_KEY" ] && [ ! -f "$SYNC_PUBLIC_SSH_KEY" ]; then
    ssh-keygen -t ed25519 -C "$USER" -f "$SYNC_PRIVATE_SSH_KEY" -N ""
    echo "SSH keys created at $SYNC_PRIVATE_SSH_KEY and $SYNC_PUBLIC_SSH_KEY"
  else
    echo "SSH keys already exist at $SYNC_PRIVATE_SSH_KEY and $SYNC_PUBLIC_SSH_KEY"
  fi

  echo "Adding $SYNC_PUBLIC_SSH_KEY to authorized_keys"
  cat $SYNC_PUBLIC_SSH_KEY > $HOME/.ssh/authorized_keys
}

configureSSH() {
  echo "Configuring SSH ..."
  create_sync_ssh_keys

  # Check for a currently running instance of the agent
  echo "Checking for existing SSH agent..."
  if ! is_ssh_agent_running; then
    echo "No SSH agent found. Starting a new SSH agent..."
    echo $(ssh-agent -s) > $HOME/.ssh/ssh-agent
    eval $(cat $HOME/.ssh/ssh-agent)
  fi

  if is_ssh_agent_running; then
      echo "SSH agent is running"
      echo "PID: $SSH_AGENT_PID"
      echo "Socket: $SSH_AUTH_SOCK"
  fi

    echo ""
    echo "Adding SSH keys to the agent..."
    SSH_KEY_FOLDER="$HOME/.ssh"
    for key in $SSH_KEY_FOLDER/*.pub; do
      echo "Adding key: ${key%.pub}"
      ssh-add --apple-use-keychain "${key%.pub}"
    done
    ssh-add -l
}


installDependencies
configureSSH





