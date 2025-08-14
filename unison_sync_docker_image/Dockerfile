FROM alpine:latest
LABEL description="Unison file sync docker image."

ARG UNISON_VERSION=2.53.7-r0


RUN apk add --update bash su-exec tini openssh && \
    apk add unison && \
    apk add openssh 

# These can be overridden later
ENV TZ="America/New_York" \
    LANG="C.UTF-8" \

    REMOTE_UNISON_SERVER_PATH= \
    REMOTE_UNISON_SERVER_SYNC_PATH= \
    REMOTE_SSH_USER= \
    SYNC_FOLDER= \
    UNISON_SSH_KEY_NAME= 

# Install unison server script
COPY entrypoint.sh /entrypoint.sh

VOLUME /unison

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

