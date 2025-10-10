
# ==============================================================================
# Container Post-Create Script - MongoDB Components
# ==============================================================================
# This script installs MongoDB shell (mongosh) and related MongoDB tools
# in a development container.
#
# Dependencies:
#   - Debian-based Linux distribution (Ubuntu/Debian)
#   - sudo access for package installation
#   - Internet connectivity for package downloads
# ==============================================================================

# Configuration constants
readonly MONGODB_VERSION="7.0"
readonly MONGODB_GPG_KEY_URL="https://pgp.mongodb.com/server-${MONGODB_VERSION}.asc"
readonly MONGODB_KEYRING="/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg"
readonly MONGODB_REPO_LIST="/etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list"


# ==============================================================================
# Installation functions
# ==============================================================================


# Import MongoDB GPG key
import_mongodb_gpg_key() {
    log_info "Importing MongoDB GPG key from $MONGODB_GPG_KEY_URL"
    
    # Remove existing keyring if it exists
    if [[ -f "$MONGODB_KEYRING" ]]; then
        log_info "Removing existing MongoDB keyring"
        sudo rm -f "$MONGODB_KEYRING"
    fi
    
    # Import the GPG key
    if curl -fsSL "$MONGODB_GPG_KEY_URL" | sudo gpg -o "$MONGODB_KEYRING" --dearmor >/dev/null 2>&1; then
        log_success "MongoDB GPG key imported successfully"
    else
        log_error "Failed to import MongoDB GPG key"
        return 1
    fi
}

# Add MongoDB repository
add_mongodb_repository() {
    log_info "Adding MongoDB repository to sources list"
    
    # Detect architecture
    local arch
    arch=$(dpkg --print-architecture)
    
    # Detect codename for repository URL
    local codename
    codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    
    # Fallback for Ubuntu if VERSION_CODENAME not found
    if [[ -z "$codename" ]] && command -v lsb_release >/dev/null 2>&1; then
        codename=$(lsb_release -cs)
    fi
    
    # Default to bookworm for Debian-based systems
    if [[ -z "$codename" ]]; then
        codename="bookworm"
        log_warning "Could not detect OS codename, defaulting to: $codename"
    fi
    
    local repo_line="deb [ arch=${arch} signed-by=${MONGODB_KEYRING} ] https://repo.mongodb.org/apt/debian ${codename}/mongodb-org/${MONGODB_VERSION} main"
    
    log_info "Adding repository: $repo_line"
    
    if echo "$repo_line" | sudo tee "$MONGODB_REPO_LIST" >/dev/null; then
        log_success "MongoDB repository added successfully"
    else
        log_error "Failed to add MongoDB repository"
        return 1
    fi
}

# Install MongoDB shell
install_mongosh() {
    log_info "Installing MongoDB shell (mongosh)..."
    
    # Update package list to include MongoDB packages
 	update_package_lists || exit 1
	install_packages "mongodb-mongosh"
	verify_command_installation "mongosh" "MongoDB shell" || exit 1

	log_success "MongoDB components installation completed successfully"
}

# ==============================================================================
# Main execution
# ==============================================================================

mongo_main() {
    log_info "Starting MongoDB components installation..."

	validate_environment_variables "MONGO_INITDB_ROOT_USERNAME" "MONGO_INITDB_ROOT_PASSWORD" || exit 1
    
    # Perform installation steps
    update_package_lists || exit 1
    install_packages "gnupg" "curl" || exit 1
	verify_command_installation "curl" "cURL" || exit 1
	verify_command_installation "gpg" "GnuPG" || exit 1
    import_mongodb_gpg_key || exit 1
    add_mongodb_repository || exit 1
    install_mongosh || exit 1 
}

# Only run main function if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    mongo_main "$@"
fi

# END MongoDB scripts
