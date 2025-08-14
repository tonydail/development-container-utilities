#!/usr/bin/env bash
clear

echo "Starting unison sync entrypoint script..."
echo ""
echo "Checking required environment variables..."

if [ -z "$REMOTE_UNISON_SERVER_PATH" ]; then
    echo "Error: REMOTE_UNISON_SERVER_PATH environment variable is not set."
    exit 1 # Exit with a non-zero status code to indicate an error
else
    echo "REMOTE_UNISON_SERVER_PATH is set to: $REMOTE_UNISON_SERVER_PATH"    
fi

if [ -z "$REMOTE_UNISON_SERVER_SYNC_PATH" ]; then
    echo "Error: REMOTE_UNISON_SERVER_SYNC_PATH environment variable is not set."
    exit 1
else
    echo "REMOTE_UNISON_SERVER_SYNC_PATH is set to: $REMOTE_UNISON_SERVER_SYNC_PATH"
fi

if [ -z "$REMOTE_SSH_USER" ]; then
    echo "Error: REMOTE_SSH_USER environment variable is not set."
    exit 1
else
    echo "REMOTE_SSH_USER is set to: $REMOTE_SSH_USER"  
fi

if [ -z "$SYNC_FOLDER" ]; then
    echo "Error: SYNC_FOLDER environment variable is not set."
    exit 1
else
    echo "SYNC_FOLDER is set to: $SYNC_FOLDER"
fi

if [ -z "$UNISON_SSH_KEY_NAME" ]; then
    echo "Error: UNISON_SSH_KEY_NAME environment variable is not set."
    exit 1
else
    echo "UNISON_SSH_KEY_NAME is set to: $UNISON_SSH_KEY_NAME"
fi

# If all required variables are set, proceed with the main command
echo "All required environment variables are set. Proceeding with unison sync setup..."
exec "$@" # This executes the command passed to the entrypoint




#unison user and group
UNISON_USER="unison"
UNISON_UID=1000
UNISON_GROUP="sync"
UNISON_GID=1001
UNISON_HOME=

# Create unison user and group
echo "Creating unison user and group..."
addgroup -g $UNISON_GID $UNISON_GROUP
adduser -D -u $UNISON_UID -G $UNISON_GROUP -s /bin/bash $UNISON_USER

UNISON_HOME=$(getent passwd $UNISON_USER | cut -d: -f6)


# Create directory for filesync
echo "Ensuring sync folder exists at: $SYNC_FOLDER"
if [ ! -d "$SYNC_FOLDER" ]; then
    echo "Creating $SYNC_FOLDER directory for sync..."
    mkdir -p "$SYNC_FOLDER" >> /dev/null 2>&1
else
    echo "$SYNC_FOLDER already exists."
fi

# Create directory for unison meta
echo "Ensuring unison meta folder exists at: $UNISON_HOME/.unison"
if [ ! -d "$UNISON_HOME/.unison" ]; then
    mkdir -p $UNISON_HOME/.unison >> /dev/null 2>&1
else
    echo "$UNISON_HOME/.unison already exists." 
fi

# Symlink .unison folder from user home directory to sync directory so that we only need 1 volume
echo "Creating symlink for unison meta folder in sync folder..."
if [ ! -h "$SYNC_FOLDER/.unison" ]; then
    ln -s $UNISON_HOME/.unison $SYNC_FOLDER/.unison  >> /dev/null 2>&1
fi

# Change data owner
echo "Setting ownership of $SYNC_FOLDER to $UNISON_USER:$UNISON_GROUP"
chown -R $UNISON_USER:$UNISON_GROUP $SYNC_FOLDER

# Change to the sync directory
echo "Changing directory to sync folder: $SYNC_FOLDER"
cd $SYNC_FOLDER
echo "Current directory: $(pwd)"

SSH_HOME=$(realpath $UNISON_HOME/.ssh)

# add ssh config for unison user so that we can connect to the remote host without passing credentials each time

if ! grep -q "Host host.docker.internal" $SSH_HOME/config; then
        echo "Host host.docker.internal" >> $SSH_HOME/config
        echo "  HostName host.docker.internal" >> $SSH_HOME/config
        echo "  User $REMOTE_SSH_USER" >> $SSH_HOME/config
        echo "  IdentityFile $SSH_HOME/$UNISON_SSH_KEY_NAME" >> $SSH_HOME/config
        echo "  StrictHostKeyChecking no" >> $SSH_HOME/config
    fi

echo "Setting ownership of $UNISON_HOME to $UNISON_USER:$UNISON_GROUP"
chown -R $UNISON_USER:$UNISON_GROUP $UNISON_HOME


echo "Running unison sync..."
# Start the unison sync process now, as the Unison user. This will run indefinitely, syncing changes as they occur.
exec su-exec $UNISON_USER unison . ssh://$REMOTE_SSH_USER@host.docker.internal/$REMOTE_UNISON_SERVER_SYNC_PATH  -servercmd $REMOTE_UNISON_SERVER_PATH -ignore 'Name node_modules' -ignore 'Name dist' -ignore 'Name .turbo' -ignore 'Name .DS_Store' -ignore 'Name ._.DS_Store' -auto -batch -repeat watch
