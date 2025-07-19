#!/bin/bash
WORKSPACE_NAME="$1"
CONTAINER_NAME="${WORKSPACE_NAME,,}"
WORKSPACE_FOLDER="$2"
UNISON_VERSION=2.53.7-r0
SYNC_SSH_KEY_FOLDER="$HOME/.devcontainer_sync/ssh"
SYNC_SSH_KEY_NAME="id_unison_sync_key"
SYNC_PRIVATE_SSH_KEY="$SYNC_SSH_KEY_FOLDER/$SYNC_SSH_KEY_NAME"
SYNC_PUBLIC_SSH_KEY="${SYNC_PRIVATE_SSH_KEY}.pub"
SYNC_PRIVATE_SSH_KEY_CONTENTS=
SYNC_PUBLIC_SSH_KEY_CONTENTS=


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

configureSSH() {
echo "Configuring SSH ..."

  if [  -d $SYNC_SSH_KEY_FOLDER ]; then
    echo "Removing existing SSH key folder: $SYNC_SSH_KEY_FOLDER"
    rm -rfv $SYNC_SSH_KEY_FOLDER
  fi
  echo "Creating SSH key folder: $SYNC_SSH_KEY_FOLDER"
  mkdir -p $SYNC_SSH_KEY_FOLDER

  echo "Creating SSH keys in: $SYNC_SSH_KEY_FOLDER"
  ssh-keygen -C "$USER" -f $SYNC_PRIVATE_SSH_KEY -q -N ""
  echo "SSH keys created: $SYNC_PRIVATE_SSH_KEY and $SYNC_PUBLIC_SSH_KEY"
  echo "Adding $SYNC_PUBLIC_SSH_KEY to authorized_keys"
  cat $SYNC_PUBLIC_SSH_KEY > $HOME/.ssh/authorized_keys
  SYNC_PRIVATE_SSH_KEY_CONTENTS=$(cat "$SYNC_PRIVATE_SSH_KEY" | base64)
  SYNC_PUBLIC_SSH_KEY_CONTENTS=$(cat "$SYNC_PUBLIC_SSH_KEY" | base64)


   # Check for a currently running instance of the agent
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
     ssh-add --apple-use-keychain "${key%.pub}"
   done
   ssh-add -l



}

writeDockerFile() {
rm .devcontainer/Dockerfile
cat <<EOF >".devcontainer/Dockerfile"
FROM alpine:latest
LABEL description="Unison file sync docker image."

ARG UNISON_VERSION=2.53.7-r0


RUN apk add --update bash su-exec tini openssh && \\
    apk add unison && \\
    apk add openssh

# These can be overridden later
ENV TZ="America/New_York" \\
    LANG="C.UTF-8" \\
    UNISON_DIR="/$WORKSPACE_NAME" \\
    HOME="/tmp" \\
    ##
    # Use 1000:1001 as default user
    ##
    UNISON_USER="unison" \\
    UNISON_GROUP="sync" \\
    UNISON_UID="1000" \\
    UNISON_GID="1001" \\
    REMOTE_UNISON_SERVER_PATH=$(command -v unison) \\
    REMOTE_UNISON_SERVER_SYNC_PATH=$WORKSPACE_FOLDER \\
    REMOTE_SSH_USER=$USER \\
    REMOTE_SSH_KEY_NAME=$SYNC_SSH_KEY_NAME \\
    SYNC_PRIVATE_SSH_KEY_CONTENTS="$SYNC_PRIVATE_SSH_KEY_CONTENTS" \\
    SYNC_PUBLIC_SSH_KEY_CONTENTS="$SYNC_PUBLIC_SSH_KEY_CONTENTS" 


#COPY /Users/tony/.devcontainer_sync/ssh /.ssh

# Install unison server script
COPY entrypoint.sh /entrypoint.sh

VOLUME /unison

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

EOF
}

writeDockerComposeFile() {
rm .devcontainer/docker-compose.yaml
cat <<EOF >".devcontainer/docker-compose.yaml"
services:
  code_container:
    image: mcr.microsoft.com/devcontainers/base:bullseye
    tty: true
    command: sh
    volumes_from:
      - code_sync
    # volumes:
    #   - type: bind
    #     source: /Users/tony/.ssh
    #     target: /home/vscode/.ssh
  code_sync:
    build: .
    volumes:
      - sync_data:/$WORKSPACE_NAME
      - unison:/unison
      # - type: bind
      #   source: $SSH_KEY_FOLDER
      #   target: /home/unison/.ssh
    ports:
      - 5555:5555
volumes:
  sync_data:
  unison:
EOF
}
installDependencies
configureSSH
writeDockerFile
writeDockerComposeFile


rm -rfv $HOME/.unison
rm -rfv $SYNC_SSH_KEY_FOLDER


