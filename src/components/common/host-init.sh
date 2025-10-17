#!/bin/bash

echo $PWD
devcontainer_path="$PWD/.devcontainer"
log_path="$devcontainer_path/logs"
mutagen_log_path="$log_path/mutagen.log"
pid_log_path="$log_path/mutagen_pid.log"

mutagen_script_path="$devcontainer_path/mutagen_start.sh"

rm -rf $log_path
mkdir -p $log_path

if [ -f "$mutagen_script_path" ]; then
	echo "!!!!!DO NOT MODIFY THIS LOG FILE!!!!!" | tee -a $pid_log_path
	echo "It is used during the cleanup process!" | tee -a $pid_log_path
	echo "--------------------------------------" | tee -a $pid_log_path
	echo "" | tee -a $pid_log_path
	echo "Starting mutagen_sync.sh in background..." | tee -a $pid_log_path

	echo "!!!!!DO NOT MODIFY THIS LOG FILE!!!!!" | tee -a $mutagen_log_path
	echo "It is used during the cleanup process!" | tee -a $mutagen_log_path
	echo "--------------------------------------" | tee -a $mutagen_log_path
	echo "" | tee -a $mutagen_log_path
	
	nohup bash $mutagen_script_path "$PWD"  >> $mutagen_log_path 2>&1 &
	nohup_pid=$!

	echo "$(date): Started mutagen_sync.sh with nohup, PID: $nohup_pid" | tee -a $pid_log_path
	echo "Process PID: $nohup_pid" | tee -a $pid_log_path
	echo "To check if running: ps -p $nohup_pid" | tee -a $pid_log_path
	echo "To kill process: kill $nohup_pid" | tee -a $pid_log_path
else
	echo "Warning: mutagen_sync.sh not found at $devcontainer_path/mutagen_sync.sh" | tee -a $pid_log_path
fi
