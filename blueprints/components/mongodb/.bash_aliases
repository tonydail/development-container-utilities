# Start MongoDB aliases

mongo_connection_string(){
    local username=$( read_env_var "MONGO_INITDB_ROOT_USERNAME")
    local password=$(read_env_var "MONGO_INITDB_ROOT_PASSWORD")
    
    if [ -z "$username" ] || [ -z "$password" ] || [ -z "$SERVICE_NAME" ]; then
        echo ""
        return 1
    fi
    
    echo "mongodb://${username}:${password}@${SERVICE_NAME}_mongodb:27017?authSource=admin"
}

mongoshconnect () {

    FILE_TO_EXECUTE="$1"
    local mongo_connection_string="$(mongo_connection_string)"
    
    if [ -z "$mongo_connection_string" ]; then
        echo "Error: Could not build MongoDB connection string"
        return 1
    fi


    if [ -z "$FILE_TO_EXECUTE" ]; then
        mongosh "$mongo_connection_string"
    else
        if [ -n "$FILE_TO_EXECUTE" ] && [ -f "$FILE_TO_EXECUTE" ]; then
            mongosh "$mongo_connection_string" --file "$FILE_TO_EXECUTE"
        fi
    fi
}

# End MongoDB aliases