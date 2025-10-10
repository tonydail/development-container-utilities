
# Start MongoDB aliases

mongo_connection_string(){
    echo "mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${SERVICE_NAME}_mongodb:27017?authSource=admin"
}

mongoshconnect () {
    if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] || [ -z "$SERVICE_NAME" ]; then
        echo "Error: MONGO_INITDB_ROOT_USERNAME, MONGO_INITDB_ROOT_PASSWORD, and SERVICE_NAME environment variables must be set."
        return 1
    fi

    FILE_TO_EXECUTE="$1"
    local mongo_connection_string="$(mongo_connection_string)"
    echo "$mongo_connection_string"

    if [ -z "$FILE_TO_EXECUTE" ]; then
        mongosh "$mongo_connection_string"
    else
        if [ -n "$FILE_TO_EXECUTE" ] && [ -f "$FILE_TO_EXECUTE" ]; then
            mongosh "$get_mongo_connection_string" --file "$FILE_TO_EXECUTE"
        fi
    fi

}

# End MongoDB aliases



