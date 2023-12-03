#!/bin/bash

# SnapWarden: Automated Vault Snapshot & Remote Backup script
# Author: Nihal Atwal (@nilz-bilz)

# Set Bitwarden API credentials as environment variables
export BW_CLIENTID="your_client_id"
export BW_CLIENTSECRET="your_client_secret"

# Set these Variables
BITWARDEN_PASSWORD="your_master_password"
EXPORT_DIRECTORY="/path/to/exports"
RC_REMOTE="your_rclone_crypt_remote_name"

# Leave these as is
TODAY=$(date '+%Y-%m-%d_%H-%M-%S')
EXPORT_JSON="$EXPORT_DIRECTORY/bwexport_$TODAY.json"
EXPORT_CSV="$EXPORT_DIRECTORY/bwexport_$TODAY.csv"


# Function to send success notification
send_success_notification() {
    curl -H "mail: mail@user.com" -H "Tags: floppy_disk,white_check_mark" -H "Title: Bitwarden Export Successful" -d "Bitwarden export completed successfully" ntfy.sh/<your-topic-name>
} # Change the mail: section, and add your ntfy topic name at the end

# Function to send specific failure notifications
send_notification() {
    local title=$1
    local body=$2
    curl -H "mail: mail@user.com" -H "Tags: floppy_disk,x" -H "Title: $title" -d "$body" ntfy.sh/<your-topic-name>
} # Change the mail: section, and add your ntfy topic name at the end

# Function to perform cleanup
cleanup_export_directory() {
    echo "Performing cleanup and logout from Bitwarden..."
    # Empty export directory after completion or failure
    rm -rf $EXPORT_DIRECTORY/*
    # Logout from Bitwarden
    bw logout
}

# Trap to perform cleanup on script exit
trap cleanup_export_directory EXIT

# Function to perform Bitwarden export
perform_export() {
    # Login to Bitwarden using API key
    bw login --apikey

    # Check if login was successful
    if [ $? -eq 0 ]; then
        # Unlock Bitwarden vault and get session key in one step
        SESSION_KEY=$(bw unlock $BITWARDEN_PASSWORD --raw)

        # Check if session key retrieval was successful
        if [ -n "$SESSION_KEY" ]; then
            # Sync vault using the obtained session key
            bw sync --session $SESSION_KEY

            # Check if sync was successful
            if [ $? -eq 0 ]; then
                # Export vault as JSON
                bw export --format json --output $EXPORT_JSON --session $SESSION_KEY

                # Check if JSON export was successful
                if [ $? -eq 0 ]; then
                    # Export vault as CSV
                    bw export --format csv --output $EXPORT_CSV --session $SESSION_KEY

                    # Move exports to S3 with checksum verification (verbose mode)
                    rclone_output=$(rclone copy $EXPORT_DIRECTORY $RC_REMOTE --checksum --verbose 2>&1)

                    # Check if rclone copy was successful
                    if [ $? -eq 0 ]; then
                        send_success_notification
                        exit 0
                    else
                        # Check for checksum mismatch error in rclone output
                        if grep -q "checksum mismatch" <<< "$rclone_output"; then
                            send_notification "Bitwarden Export Failed" "Checksum mismatch detected during file transfer to S3."
                            exit 1
                        else
                            send_notification "Bitwarden Export Failed" "Failed to copy export files to S3 using rclone."
                            exit 1
                        fi
                    fi
                else
                    send_notification "Bitwarden Export Failed" "Failed to export Bitwarden vault as JSON."
                    exit 1
                fi
            else
                send_notification "Bitwarden Export Failed" "Failed to sync Bitwarden vault."
                exit 1
            fi
        else
            send_notification "Bitwarden Export Failed" "Failed to retrieve Bitwarden session key."
            exit 1
        fi
    else
        send_notification "Bitwarden Export Failed" "Failed to login to Bitwarden."
        exit 1
    fi
}

# Perform the export process
perform_export

