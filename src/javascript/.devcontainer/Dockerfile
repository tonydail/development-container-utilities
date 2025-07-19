FROM alpine:latest
LABEL description="Unison file sync docker image."

ARG UNISON_VERSION=2.53.7-r0


RUN apk add --update bash su-exec tini openssh && \
    apk add unison && \
    apk add openssh

# These can be overridden later
ENV TZ="America/New_York" \
    LANG="C.UTF-8" \
    UNISON_DIR="/development-container-utilities" \
    HOME="/tmp" \
    ##
    # Use 1000:1001 as default user
    ##
    UNISON_USER="unison" \
    UNISON_GROUP="sync" \
    UNISON_UID="1000" \
    UNISON_GID="1001" \
    REMOTE_UNISON_SERVER_PATH=/usr/local/bin/unison \
    REMOTE_UNISON_SERVER_SYNC_PATH=/Users/tony/projects/development-container-utilities \
    REMOTE_SSH_USER=tony \
    REMOTE_SSH_KEY_NAME=id_unison_sync_key \
    SYNC_PRIVATE_SSH_KEY_CONTENTS="LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNBRjZTNXBYbDgvUkNHZng5aGVHaGdDUWQ1MzJ1T3RKeGRHQlJWb09SNXd5QUFBQUlqTFJXWFZ5MFZsCjFRQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDQUY2UzVwWGw4L1JDR2Z4OWhlR2hnQ1FkNTMydU90SnhkR0JSVm9PUjV3eUEKQUFBRUJJY0QzMHlaWllpZnRUUWVPRGNVOXJZVDdiUlJHRExxd1VGY1c2bFViVnJRWHBMbWxlWHo5RUlaL0gyRjRhR0FKQgozbmZhNDYwbkYwWUZGV2c1SG5ESUFBQUFCSFJ2Ym5rQgotLS0tLUVORCBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K" \
    SYNC_PUBLIC_SSH_KEY_CONTENTS="c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUFYcExtbGVYejlFSVovSDJGNGFHQUpCM25mYTQ2MG5GMFlGRldnNUhuREkgdG9ueQo=" 


#COPY /Users/tony/.devcontainer_sync/ssh /.ssh

# Install unison server script
COPY entrypoint.sh /entrypoint.sh

VOLUME /unison

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

