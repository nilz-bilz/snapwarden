# SnapWarden - Automated snapshots for your Bitwarden vault

**SnapWarden** is a bash script that uses the [Bitwarden CLI](https://bitwarden.com/help/cli/) to take a snapshot (export) of your vault, and upload an encrypted copy of it to a remote cloud storage provider using [rclone](https://rclone.org/). 

It also uses [ntfy.sh](https://ntfy.sh) to send notifications to your phone via push notifications and email, to indicate when the snapshot has been exported successfully, or if any errors have occurred during the process.

** This script doesn't yet work for backing up organization vaults & attatchments. It is only meant for personal use to backup passwords, TOTP codes, and other custom fields such as notes. 

**Passkeys and some other custom fields may not be exported to the .csv file.**

## Problem Statement
- Bitwarden only lets you export your vault data to a .json or .csv, manually via their web vault interface. 
- Considering that Bitwarden is a third party hosted service (assuming that you are not self hosting it), it is imperative to have a copy of all your passwords in another location as well, in case you lose access to your account for any reason, or the service eventually shuts down. 
- In this way, you will have your own copy of your passwords, and will be able to move them to another service if the need ever arises. 
- Having a recent export of your vault would also prove useful if you accidentally delete/modify some records from your vault, and need to regain access to a previous version of that vault. 

## Prerequisite software to be installed & setup
Main packages used:
- [Bitwarden CLI](https://bitwarden.com/help/cli/)
- [rclone](https://rclone.org/)
- [ntfy.sh](https://ntfy.sh) (using curl)

Essential dependencies:
- bash
- curl
- git

[Bitwarden CLI](https://bitwarden.com/help/cli/) can be installed using "snap" on ubuntu, or via "npm" on other unix based systems. You can also transfer the executable binary to your machine manually (not recommended as automatic updates might not work).

### Download & Install

#### Bitwarden CLI

To install with NPM:
```
npm install -g @bitwarden/cli
```
View the package on [npmjs.org](https://www.npmjs.com/package/@bitwarden/cli)

To install with snap:
```
sudo snap install bw
```
View the package on [snapcraft.io](https://snapcraft.io/bw)

A version of this is also available in the [Nix package manager](https://search.nixos.org/packages?query=bitwarden-cli) (not tested)

Nix-Shell install (temporary):
```
nix-shell -p bitwarden-cli
```

Nix-Env install (permanent) on NixOS:
```
nix-env -iA nixos.bitwarden-cli
```

Nix-Env install (permanent) on Non NixOS:
```
nix-env -iA nixpkgs.bitwarden-cli
```

#### Rclone

Please refer to the [rclone docs](https://rclone.org/docs/) to install and configure rclone on your machine. 

You can refer to the [downloads](https://rclone.org/downloads/) page for rclone to see all available platforms & verisons.

To install rclone on Linux/macOS/BSD systems, run:
```
sudo -v ; curl https://rclone.org/install.sh | sudo bash
```

You can also find rclone in your distro's package manager.

### Setup

You will first need to add a remote such as Amazon S3 for example, and setup another remote called [crypt](https://rclone.org/crypt/), which helps in encrypting a portion of an existing remote.

You can choose to setup a specific folder within the original remote as a "crypt" remote.

Download the [ntfy.sh](https://ntfy.sh) app on your phone, and follow a specific "topic". You can name this topic anything. If you are using the free public version of ntfy.

I would suggest randomizing the topic name a little, as anyone is allowed to follow any topic on a public instance. This way you can ensure that no one is likely to eavesdrop on your notifications. 

## List of operations performed by the script
1. Login to Bitwarden using API keys (to avoid having to enter 2fa each time the script runs)
2. Unlock the vault using the master password (set as an env variable)
3. Grab a session key
4. Sync the vault to the latest version
5. Export vault as a .json to a local directory
6. Export vault as a .csv to a local directory
7. Use rclone to send the above files to a remote cloud storage with a [crypt remote](https://rclone.org/crypt/) configured (has to be setup before running the script)
8. Compares the checksum/hash of the files in the local directory, with the files uploaded to the cloud
9. Sends a notification using ntfy.sh with a success message, or with a description of the error.
10. Clears the local directory upon exit, and log out of bitwarden.

## Usage
1. Clone this script to the directory where you would like to run this. Use the command below to clone this repository:
   ```
   git clone https://github.com/nilz-bilz/snapwarden.git
   ```
2. Set appropriate file permissions to execute the script for the relevant user.
3. Open the script in a text editor and enter your: 
	- Bitwarden API keys ([reference](https://bitwarden.com/help/public-api/))
	- Master Password 
	- Export Directory (the directory you would like the exports to be temporarily stored in)
	- Name of your remote as recognized by rclone.
4. Change the curl command for ntfy.sh. 
   1. Change the email address (or remove entirely if you do not want email notifs)
   2. Last part of the command by entering your ntfy topic name after "ntfy.sh/" (in order to receive notifs on the topic you are following)
5. Save the changes
6. run the script with the command `bash snapwarden.sh`
7. Confirm that the script & notifications are working. 
8. Setup a cron job by typing `crontab -e` and enter the cron schedule, followed by `bash /path/to/script/snapwarden.sh`
	- Refer to [this website](https://crontab.guru/) to figure out the syntax needed for your specific job schedule. 
	- You can setup multiple cron jobs with different versions of the script, to setup a daily, weekly, and monthly snapshots that get stored in different folders within your remote storage.

## Potential vulnerabilities
- This script requires you to enter your Bitwarden API keys and Master Password. It is highly suggested to use this with a secrets manager. Storing these credentials in clear text is a security risk. You can also store the master password in a hidden directory, and modify the script to unlock the vault using the --passwordfile flag ([reference](https://bitwarden.com/help/cli/#unlock-options)).
- Anyone who gains access to the server where this is being run, will get access to the rclone crypt mount, where all the decrypted files can be retrieved locally. This can be protected by setting up a password for rclone, but that will result in the script manually asking you to enter the password each time it tries to upload the exported files. 
	- Make sure to harden your server as much as possible. And if possible try and run this on your own Hardware/VM/Container at home, or at least on a private subnet... to make sure that you are not running this on a publicly accessible server. (setup a VPN for remote access if needed).
- The script exports the vault as an unencrypted .json and .csv for a few seconds to a local directory for a few seconds. As soon as the script exits, it deletes these local files.

## Disclaimer
Please use this script at your own risk. The potential flaws have been mentioned above, and I or anyone who contributes to this project shall take no responsibility for anything going wrong with your Bitwarden Account or Vault. 

## Contact
If you have any suggestions to improve this project, please share your thoughts in the Discussions and Issues section. 

You can reach out to me on nihal.atwal@gmail.com & nihal_atwal@protonmail.com