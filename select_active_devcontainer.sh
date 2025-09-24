#!/bin/bash
#DO NOT USE THIS SCRIPT, IT IS DEPRECATED. USE devcontainer_templatemanager INSTEAD.
clear
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output


print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info .
# Directory containing subfolders
BASE_DIR="./templates"

# Get list of subfolders
folders=("$BASE_DIR"/*/)
if [ ${#folders[@]} -eq 0 ]; then
    echo "No subfolders found in $BASE_DIR"
    exit 1
fi

# Display numbered list
echo "Select a devcontainer tenplate to make active:"
for i in "${!folders[@]}"; do
    folder_name=$(basename "${folders[$i]}")
    echo "$((i+1)). $folder_name"
done

# Prompt user for selection
read -p "Enter the number of the devcontainer: " selection

# Validate input
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#folders[@]}" ]; then
    print_error "Invalid selection."
    exit 1
fi

echo "You selected option $selection: $(realpath ${folders[$((selection-1))]})"
exit
# Get selected folder
selected_folder="${folders[$((selection-1))]}"
fullpath_source=$(realpath $selected_folder)
fullpath_target=$(realpath .)
fullpath_target="$fullpath_target/.devcontainer"
createlink="n"

if [ -d "$fullpath_target" ] && [ -L "$fullpath_target" ]; then
    print_info "$fullpath_target already exists and is a symlink to $(readlink $fullpath_target)"
    read -p "Would you like to replace it it? (y/n) " replace_choice
    if [[ "$replace_choice" == "y" ]]; then
        print_info "Removed $(rm -rfv $fullpath_target) and will create a new symlink."
        createlink="y"
    else
        createlink="n"
    fi
else
    createlink="y"
fi


if [[ "$createlink" == "y" ]]; then


    ln -s $fullpath_source $fullpath_target >> /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Symlink created successfully: $fullpath_target -> $fullpath_source"
    else
        print_error "Failed to create symlink."
        exit 1
    fi
    
fi

find . -type l >> .gitignore



