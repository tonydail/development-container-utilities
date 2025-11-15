#!/usr/local/bin/bash

CLEANUP_TEMPDIR=
MAIN_PATH="$(realpath "$(dirname "$0")/../..")"  #path to root of project
CURRENT_DIR="$PWD"             #where this is executed from
SOURCE_PATH="$MAIN_PATH/blueprints" #the source path for the templates
TEMPLATES_PATH="$SOURCE_PATH/templates"
COMPONENTS_PATH="$SOURCE_PATH/components"

WORK_DIR_NAME_FORMAT="work_dir.XXXXXX"
BUILD_DIR_NAME_FORMAT="build_dir.XXXXXX"
BUILD_OUTPUT_DIR_NAME_FORMAT="build_output_dir.XXXXXX"

# Set this to true to keep the build directory for debugging purposes.
# This will create the build directory in the current working directory with a unique name.
# This is useful for debugging the build process and inspecting the contents of the build directory while debugging this script.
# If set to false, the build directory will be created in the system's temporary directory and will be automatically cleaned up after this script execution completes.
DEBUG_BUILD_LOCATION=false

#main working directory
WORK_DIR=
#build directory
BUILD_DIR=
#build output directory
BUILD_OUTPUT_DIR=

TEMPLATE_COMPONENTS=

# region utility functions
get_unique_filenames() {
	local DIRECTORIES=("$@")
	local temp_file
	temp_file="$(get_temp_file "$BUILD_DIR")"
	for DIRECTORY in "${DIRECTORIES[@]}"; do
		if [ -d "$DIRECTORY" ]; then
			find "$DIRECTORY" -maxdepth 1 -type f -exec basename {} \; >>"$temp_file"
		fi
	done

	sort "$temp_file" | uniq
	rm "$temp_file"
}

get_temp_file() {
	local create_in_dir="$1"
	local name_format="${2:-"temp-file.XXXXXX"}"
	local extenstion="${3:-".temp"}"
	if [[ -z "$create_in_dir" ]]; then
		temp_file=$(mktemp)
	else
		temp_file=$(mktemp -p "$create_in_dir/" "$name_format")
	fi
	temp_file_extension="${temp_file}${extenstion}"
	mv "$temp_file" "$temp_file_extension"
	echo "$temp_file_extension"
}

get_temp_dir() {
	local create_in_dir="$1"
	local name_format="${2:-"temp-dir.XXXXXX"}"

	if [[ -z "$create_in_dir" ]]; then
		temp_dir=$(mktemp -d)
	else
		temp_dir=$(mktemp -d -p "$create_in_dir/" "$name_format")
	fi
	echo "$temp_dir"
}

cleanup_temps() {
	if [[ "$DEBUG_BUILD_LOCATION" == "true" ]]; then
		echo "Debug mode is enabled. Skipping cleanup of temp directories. Temp directory location: $CLEANUP_TEMPDIR"
		return
	fi
	if [[ -z "$CLEANUP_TEMPDIR" ]]; then
		echo "No temp directory to clean up."
		return
	fi
	rm -rf "$CLEANUP_TEMPDIR"
	echo "Removed temp dir: $CLEANUP_TEMPDIR"
}

escape_string() {
	local stringToEscape=$1
	echo "$stringToEscape" | jq -R '@json'
}

unescape_string() {
	local stringToUnescape=$1
	echo "$stringToUnescape" | jq -r '.'
}

join_json_files() {
	local input_file1="$1"
	local input_file2="$2"
	local output_file="$3"

	if [ -f "$input_file1" ] && [ ! -f "$input_file2" ]; then
		cp "$input_file1" "$output_file"
		echo "$output_file"
		return
	fi

	jq -n '
def deepmerge(a;b):
  reduce b[] as $item (a;
    reduce ($item | keys_unsorted[]) as $key (.;
      $item[$key] as $val | ($val | type) as $type |
      .[$key] = if ($type == "object") then deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val])
                elif ($type == "array") then (.[$key] + $val) # Concatenate arrays
                elif ($type == "null") then .[$key]
                else $val
                end
    )
  );
deepmerge({}; [input, input])' "$input_file1" "$input_file2" >"$output_file" 2>/dev/null
	echo "$output_file"
}
join_yaml_files() {
	local input_file1="$1"
	local input_file2="$2"
	local output_file="$3"

	if [ -f "$input_file1" ] && [ ! -f "$input_file2" ]; then
		cp "$input_file1" "$output_file"
		echo "$output_file"
		return
	fi

	yq eval-all '. as $item ireduce ({}; . *+ $item)' "$input_file1" "$input_file2" > "$output_file"
	echo "$output_file"

	
}

concatenate_files() {
	local work_dir="$1"
	local input_file1="$2"
	local input_file2="$3"
	local output_file=

	file_extension_1=".${input_file1##*.}"
	file_extension_2=".${input_file2##*.}"

	output_file="$(get_temp_file "$work_dir" "temp-file.XXXXXX" "$file_extension_1")"

	if [ -f "$input_file1" ] && [ ! -f "$input_file2" ]; then
		cp "$input_file1" "$output_file"
		echo "$output_file"
		return
	fi


	if [ "$file_extension_1" == "$file_extension_2" ]; then
		case $file_extension_1 in
		".json")
			output_file=$(join_json_files "$input_file1" "$input_file2" "$output_file")
			;;
		 ".yaml")
		 	output_file=$(join_yaml_files "$input_file1" "$input_file2" "$output_file")
		 	;;
		*)
			cat "$input_file2" "$input_file1" >"$output_file"
			;;
		esac	
	fi

	echo "$output_file"
}

convert_json_to_yaml() {
	local inputJsonFile="$1"
	local outputYamlFile="$2"
	yq -p json -o yaml "$inputJsonFile" >"$outputYamlFile"
}

convert_yaml_to_json() {
	local inputYamlFile="$1"
	local outputJsonFile="$2"
	yq -o=json "$inputYamlFile" >"$outputJsonFile"
}


join_files() {
	local FILE_1=
	local FILE_2=
	local COMPONENT_ARRAY=()


	IFS=',' read -ra COMPONENT_ARRAY <<<"$TEMPLATE_COMPONENTS"

	DIRECTORIES=()
	# Loop through the original array and prepend the WORK_DIR to each element
	for DIRECTORY in "${COMPONENT_ARRAY[@]}"; do
		DIRECTORIES+=("${WORK_DIR}/${DIRECTORY}")
	done

	for COMPONENT in "${COMPONENT_ARRAY[@]}"; do
		mapfile -t UNIQUE_FILES < <(get_unique_filenames "${DIRECTORIES[@]}")
	done

	

	for UNIQUE_FILE in "${UNIQUE_FILES[@]}"; do
		COMPONENT_ARRAY=("${COMPONENT_ARRAY[@]}")
		for COMPONENT in "${COMPONENT_ARRAY[@]}"; do
			FILE_1="$WORK_DIR/$COMPONENT/$UNIQUE_FILE"
			if [ -f "$FILE_1" ]; then
				FILE_2=$(concatenate_files "$BUILD_DIR" "$FILE_1" "$FILE_2")
			fi
		done
		if [ -f "$FILE_2" ]; then
			UNIQUE_FILE_OUTPUT="$BUILD_OUTPUT_DIR/$UNIQUE_FILE"
			cp "$FILE_2" "$UNIQUE_FILE_OUTPUT"

			#make shell scripts executable
			if [ ".${UNIQUE_FILE_OUTPUT##*.}" == ".sh" ]; then
				chmod +x "$UNIQUE_FILE_OUTPUT"
			fi
		fi
		FILE_1=
		FILE_2=
	done

}

handle_secret_files() {
	local COMPONENT_ARRAY=()

	IFS=',' read -ra COMPONENT_ARRAY <<<"$TEMPLATE_COMPONENTS"

	DIRECTORIES=()
	# Loop through the original array and prepend the WORK_DIR and append /secrets to each element
	for DIRECTORY in "${COMPONENT_ARRAY[@]}"; do
		DIRECTORIES+=("${WORK_DIR}/${DIRECTORY}/secrets")
	done

	for secretfolder in "${DIRECTORIES[@]}"; do
		if [ -d "$secretfolder" ]; then
			cp -r "$secretfolder" "$BUILD_OUTPUT_DIR/secrets/"
		fi

	done

}
# end region utility functions

set_template_file_components() {
	local json_file="$1"
	# Use jq to extract components, sort by build-order, and create comma-separated string
	TEMPLATE_COMPONENTS="$(
		jq -r '.components | sort_by(."build-order") | map(.component) | join(",")' "$json_file"
	)"
}

create_template_directory_structure() {
	local COMPONENT_ARRAY=()
	IFS=',' read -ra COMPONENT_ARRAY <<<"$TEMPLATE_COMPONENTS"

	for component in "${COMPONENT_ARRAY[@]}"; do
		cp -r "$COMPONENTS_PATH/$component" "$WORK_DIR/"
	done
}

# end region template build functions
build_devcontainer_config() {
	local template_file="$1"
	
	# Validate input
	if [[ -z "$template_file" ]]; then
		echo "Error: Template file not specified" >&2
		return 1
	fi

	TEMPLATE_BUILD_FILE="$TEMPLATES_PATH/$template_file"
	
	# Check if template file exists
	if [[ ! -f "$TEMPLATE_BUILD_FILE" ]]; then
		echo "Error: Template file does not exist: $TEMPLATE_BUILD_FILE" >&2
		return 1
	fi
	
	# Set up directories
	if [[ "$DEBUG_BUILD_LOCATION" == "true" ]]; then
		WORK_DIR="$(get_temp_dir "$CURRENT_DIR" "$WORK_DIR_NAME_FORMAT")"
	else
		WORK_DIR="$(get_temp_dir)"
	fi

	BUILD_DIR="$(get_temp_dir "$WORK_DIR" "$BUILD_DIR_NAME_FORMAT")"
	BUILD_OUTPUT_DIR="$(get_temp_dir "$WORK_DIR" "$BUILD_OUTPUT_DIR_NAME_FORMAT")"

	CLEANUP_TEMPDIR="$WORK_DIR"

	# Process template
	set_template_file_components "$TEMPLATE_BUILD_FILE"
	create_template_directory_structure

	join_files
	handle_secret_files

	# Create output directory if it doesn't exist
	# mkdir -p "$PWD/.devcontainer"
	# cp -r "$BUILD_OUTPUT_DIR"/* "$PWD/.devcontainer/"

	cp -r "$BUILD_OUTPUT_DIR"/ "$PWD/.devcontainer/"

	cleanup_temps
	
	echo "Successfully built devcontainer configuration from template: $template_file"
}

#main entry point
ACTION=$1

case $ACTION in
"build")
	if [[ -z "$2" ]]; then
		echo "Error: Template file not specified for build action" >&2
		echo "Usage: $0 build <template_file.json>" >&2
		exit 1
	fi
	build_devcontainer_config "$2"
	;;
"jsontoyaml")
	if [[ -z "$2" ]] || [[ -z "$3" ]]; then
		echo "Error: Input and output files required for jsontoyaml action" >&2
		echo "Usage: $0 jsontoyaml <input.json> <output.yaml>" >&2
		exit 1
	fi
	convert_json_to_yaml "$2" "$3"
	;;
"yamltojson")
	if [[ -z "$2" ]] || [[ -z "$3" ]]; then
		echo "Error: Input and output files required for yamltojson action" >&2
		echo "Usage: $0 yamltojson <input.yaml> <output.json>" >&2
		exit 1
	fi
	convert_yaml_to_json "$2" "$3"
	;;
*)
	echo "Error: Unknown action '$ACTION'" >&2
	echo "Usage: $0 {build|jsontoyaml|yamltojson} [arguments...]" >&2
	echo "  build <template_file.json>        - Build devcontainer from template"
	echo "  jsontoyaml <input.json> <output.yaml> - Convert JSON to YAML"
	echo "  yamltojson <input.yaml> <output.json> - Convert YAML to JSON"
	exit 1
	;;
esac
