# development-container-utilities
Scripts for bootstrapping development containers


# SSH Agent forwarding for Alpine containers

For anyone struggling to get ssh-agent forwarding to work for non-root container users, here's the workaround I came up with, running my entry point script as root, but using socat + su-exec to expose the socket to the non-root user and then run commands as that user:

Add socat and su-exec to the container in your Dockerfile (you might not need the later if you're not using alpine)

<u>**DockerFile**</u>
```
USER root
RUN apk add socat su-exec
# for my use case I need www-data to have access to SSH, so 
RUN \
    mkdir -p /home/www-data/.ssh && \
    chown www-data:www-data /home/www-data/.ssh/
```
<u>**entrypoint**</u>
```
#!/bin/sh
# Map docker's "magic" socket to one owned by www-data
socat UNIX-LISTEN:/home/www-data/.ssh/socket,fork,user=www-data,group=www-data,mode=777 \
    UNIX-CONNECT:/run/host-services/ssh-auth.sock \
    &
# set SSH_AUTH_SOCK to the new value
export SSH_AUTH_SOCK=/home/www-data/.ssh/socket
# exec commands as www-data via su-exec
su-exec www-data ssh-add -l
# SSH agent works for the www-data user, in reality you probably have something like su-exec www-data "$@" here
```
<u>**Run your container**</u>
```
docker run -it --rm -v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock -e SSH_AUTH_SOCK="/run/host-services/ssh-auth.sock" name cmd
```
# SSH debug packet types

| Message Name                          | Code | Context         |
|----------------------------------------|------|-----------------|
| SSH_MSG_DISCONNECT                    | 1    | SSH-TRANS       |
| SSH_MSG_IGNORE                        | 2    | SSH-TRANS       |
| SSH_MSG_UNIMPLEMENTED                 | 3    | SSH-TRANS       |
| SSH_MSG_DEBUG                         | 4    | SSH-TRANS       |
| SSH_MSG_SERVICE_REQUEST               | 5    | SSH-TRANS       |
| SSH_MSG_SERVICE_ACCEPT                | 6    | SSH-TRANS       |
| SSH_MSG_KEXINIT                       | 20   | SSH-TRANS       |
| SSH_MSG_NEWKEYS                       | 21   | SSH-TRANS       |
| SSH_MSG_USERAUTH_REQUEST              | 50   | SSH-USERAUTH    |
| SSH_MSG_USERAUTH_FAILURE              | 51   | SSH-USERAUTH    |
| SSH_MSG_USERAUTH_SUCCESS              | 52   | SSH-USERAUTH    |
| SSH_MSG_USERAUTH_BANNER               | 53   | SSH-USERAUTH    |
| SSH_MSG_GLOBAL_REQUEST                | 80   | SSH-CONNECT     |
| SSH_MSG_REQUEST_SUCCESS               | 81   | SSH-CONNECT     |
| SSH_MSG_REQUEST_FAILURE               | 82   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_OPEN                  | 90   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_OPEN_CONFIRMATION     | 91   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_OPEN_FAILURE          | 92   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_WINDOW_ADJUST         | 93   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_DATA                  | 94   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_EXTENDED_DATA         | 95   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_EOF                   | 96   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_CLOSE                 | 97   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_REQUEST               | 98   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_SUCCESS               | 99   | SSH-CONNECT     |
| SSH_MSG_CHANNEL_FAILURE               | 100  | SSH-CONNECT     |


# Github container package management

**Delete**
```
gh api graphql -f query='
mutation {
  deletePackageVersion(input:{packageVersionId:"PACKAGE_VERSION_ID"}) {
    success
  }
}'
```

**Get**
```
gh api --paginate "/orgs/ORG_NAME/packages?package_type=npmContainer" -q '.[] | .name + " " + .repository.name'

#get names
gh api "/users/tonydail/packages/container/unison-sync/versions" -q '.[] | .name'

#get list of container images
gh api --paginate "/users/tonydail/packages?package_type=container"

#get tags
gh api "/users/tonydail/packages/container/unison-sync/versions" | jq '.[].metadata.container.tags'

#get version id
gh api "/users/tonydail/packages/container/unison-sync/versions" | jq '.[].id'
```
