#!/usr/bin/env bash


setup_ssh_config() {

    SSH_HOME=/home/$UNISON_USER/.ssh
    SSH_KEY_PATH=$SSH_HOME/id_unison_sync_key
    # Generate SSH key if it doesn't exist


    if [ ! -d $SSH_HOME ]; then
        mkdir -p $SSH_HOME
    fi

    echo "$SYNC_PRIVATE_SSH_KEY_CONTENTS" | base64 -d > $SSH_KEY_PATH
    echo "$SYNC_PUBLIC_SSH_KEY_CONTENTS" | base64 -d > $SSH_KEY_PATH.pub

    if [ ! -f $SSH_HOME/config ]; then
        touch $SSH_HOME/config
    fi

    if ! grep -q "Host host.docker.internal" $SSH_HOME/config; then
        echo "Host host.docker.internal" >> $SSH_HOME/config
        echo "  HostName host.docker.internal" >> $SSH_HOME/config
        echo "  User $REMOTE_SSH_USER" >> $SSH_HOME/config
        echo "  IdentityFile $SSH_KEY_PATH" >> $SSH_HOME/config
        echo "  StrictHostKeyChecking no" >> $SSH_HOME/config
    fi
}

# Create unison user and group
addgroup -g $UNISON_GID $UNISON_GROUP
adduser -u $UNISON_UID -G $UNISON_GROUP -s /bin/bash $UNISON_USER

# Create directory for filesync
if [ ! -d "$UNISON_DIR" ]; then
    echo "Creating $UNISON_DIR directory for sync..."
    mkdir -p $UNISON_DIR >> /dev/null 2>&1
fi

# Create directory for unison meta
if [ ! -d "$UNISON_DIR/.unison" ]; then
    mkdir -p /unison >> /dev/null 2>&1
    chown -R $UNISON_USER:$UNISON_GROUP /unison
fi

# Symlink .unison folder from user home directory to sync directory so that we only need 1 volume
if [ ! -h "$UNISON_DIR/.unison" ]; then
    ln -s /unison /home/$UNISON_USER/.unison >> /dev/null 2>&1
fi



setup_ssh_config


# Change data owner
chown -R $UNISON_USER:$UNISON_GROUP $UNISON_DIR

# Start process on path which we want to sync
cd $UNISON_DIR



# Run unison server as UNISON_USER and pass signals through
#exec su-exec $UNISON_USER unison . ssh://$REMOTE_SSH_USER@host.docker.internal/$REMOTE_UNISON_SERVER_SYNC_PATH -sshargs "-i ~/.ssh/id_unison_sync_key -o StrictHostKeyChecking=no" -servercmd $REMOTE_UNISON_SERVER_PATH -ignore 'Name node_modules' -ignore 'Name dist' -ignore 'Name .turbo' -ignore 'Name .DS_Store' -ignore 'Name ._.DS_Store' -auto -batch -repeat watch
exec su-exec $UNISON_USER unison . ssh://$REMOTE_SSH_USER@host.docker.internal/$REMOTE_UNISON_SERVER_SYNC_PATH  -servercmd $REMOTE_UNISON_SERVER_PATH -ignore 'Name node_modules' -ignore 'Name dist' -ignore 'Name .turbo' -ignore 'Name .DS_Store' -ignore 'Name ._.DS_Store' -auto -batch -repeat watch

