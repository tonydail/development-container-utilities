# BEGIN Chrome script

chrome_main() {
	update_package_lists
	install_packages "dbus" "chromium" "chromium-driver"

	sudo service dbus start

	# Update package lists
	echo "-------------------------------------"
	echo "Installing Chromium and Chromedriver..."
	echo "-------------------------------------"

	update_package_lists
	install_packages "dbus" "chromium" "chromium-driver"

	# Try to find Chromium
	CHROMIUM_PATH=$(which chromium 2>/dev/null)
	if [ -z "$CHROMIUM_PATH" ]; then
		CHROMIUM_PATH=$(which chromium-browser 2>/dev/null)
	fi

	if [ -z "$CHROMIUM_PATH" ]; then
		echo "Chromium not found in PATH."
		exit 1
	fi

	# Create symlink named 'chrome' in /usr/local/bin
	ensure_symlink "$CHROMIUM_PATH" "/usr/local/bin/chrome" "sudo"
}

# Only run main function if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	chrome_main "$@"
fi
#END Chrome scripts
