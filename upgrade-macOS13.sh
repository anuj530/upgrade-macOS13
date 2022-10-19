#!/bin/bash


#!/bin/zsh
# shellcheck shell=bash
#AUTHOR-Anuj Chokshi
# Script Info variables
script_name="upgrade-macOS"
SCRIPTVER="1"


# Purpose: This script will be used to install macOS Ventura through self service. This script will be used with the macOS installer package and DEPNotify to display the progress during installation.
#This script was put together by using parts from the erase-install script by Graham Pugh. 
#   Special thanks to Graham Pugh's erase-install script for providing me with the inspiration 
#   and some of the frameworks of this script! Link: https://github.com/grahampugh/erase-install
#
#This script also uses parts from John Mahlman <john.mahlman@gmail.com> 's script to install larger packages from self service while showing DEPNotifty progress bar. 
# Please remember to update the PKG size below to calculate the progress properly. 

# Full credits to Apple for texts displayed during the progress bar to show some of the features of macOS Ventura. 

# Parameters -- MODIFY THIS BASED ON YOUR ENVIORNMENT 
# Parameter 4: Friendly Application Name
APPNAME="$4"
# Parameter 5: Jamf Trigger for caching package
JAMF_TRIGGER="$5"
# Parameter 6: Package Name (with .pkg)
PKG_NAME="$6"
# Parameter 7: Package size in KB (whole numebrs only)
# use this to get the correct package size --  ls -l $PACKAGENAME | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}'
PKG_Size="$7"



RUNTIME=$(/bin/date +'%Y-%m-%d_%H%M%S')
# all output from now on is written also to a log file
LOG_FILE="/var/tmp/install-helper.$RUNTIME.log"
exec > >(tee "${LOG_FILE}") 2>&1

# Grab currently logged in user to set the language for Dialogue messages
CURRENT_USER=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
	
	# Jamf Variables
	JAMFBINARY=/usr/local/jamf/bin/jamf
	JAMF_DOWNLOADS="/Library/Application Support/JAMF/Downloads"
	JAMF_WAITING_ROOM="/Library/Application Support/JAMF/Waiting Room"
	jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
	
	# DEPNotify varaibles
	DN_APP="/Applications/Utilities/DEPNotify.app"
	DNLOG="/var/tmp/depnotify.log"
	DN_CONFIRMATION="/var/tmp/com.depnotify.provisioning.done"
	DNPLIST="/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotify.plist"
	
	# DEPNotify UI Elements and text
	DOWNLOAD_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns"
	INSTALL_ICON="/System/Library/CoreServices/Installer.app/Contents/Resources/package.icns"
	DN_TITLE="$APPNAME Install Helper"
	DOWNLOAD_DESC="Your machine is currently downloading $APPNAME. This process will take a long time, please be patient.\n\nIf you want to cancel this process press CMD+CTRL+C."
	INSTALL_DESC="Your machine is now installing $APPNAME. This process may take a while, please be patient.\n\nIf you want to cancel this process press CMD+CTRL+C."
	IT_SUPPORT="IT Support"
	
	
	
	# shellcheck disable=SC2012
	CURRENT_PKG_SIZE=$(ls -l "$JAMF_WAITING_ROOM/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
	
	# icon for error dialog
	ALERT_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
	# Error dialogs
	FREESPACE_ERROR="There is not enough space on the drive to complete this install. You need to have at least ${min_drive_space} GB available."
	DL_ERROR="There was a problem starting the download, this process will now quit. Please try again or open a ticket with $IT_SUPPORT."
	INSTALL_ERROR="The installation failed. Please open a ticket with $IT_SUPPORT."
	
	
	# Grab currently logged in user to set the language for Dialogue messages
	current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
		current_uid=$(/usr/bin/id -u "$current_user")
		# Get proper home directory. Output of scutil might not reflect the canonical RecordName or the HomeDirectory at all, which might prevent us from detecting the language
		current_user_homedir=$(/usr/libexec/PlistBuddy -c 'Print :dsAttrTypeStandard\:NFSHomeDirectory:0' /dev/stdin <<< "$(/usr/bin/dscl -plist /Search -read "/Users/${current_user}" NFSHomeDirectory)")
		language=$(/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' "/${current_user_homedir}/Library/Preferences/.GlobalPreferences.plist")
		if [[ $language = de* ]]; then
			user_language="de"
		elif [[ $language = nl* ]]; then
			user_language="nl"
		elif [[ $language = fr* ]]; then
			user_language="fr"
		else
			user_language="en"
		fi
		
		
		dialog_dl_title_en="Downloading macOS"
		
		
		dialog_dl_desc_en="We need to download the macOS installer to your computer; this will take several minutes."
		
		# Dialogue localizations - erase lockscreen
		dialog_erase_title_en="Erasing macOS"
		
		
		dialog_erase_desc_en="Preparing the installer may take up to 30 minutes. Once completed your computer will reboot and continue the reinstallation."
		
		
		# Dialogue localizations - reinstall lockscreen
		dialog_reinstall_title_en="Upgrading macOS"
		
		dialog_reinstall_heading_en="Please wait as we prepare your computer for upgrading macOS."
		dialog_reinstall_desc_en="This process may take up to 30 minutes. Once completed your computer will reboot and begin the upgrade."
		dialog_reinstall_status_en="Preparing macOS for installation"
		dialog_rebooting_heading_en="The upgrade is now ready for installation. Please save your work!"
		dialog_rebooting_status_en="Preparation complete - restarting in"
		
		# Dialogue localizations - confirmation window (erase)
		dialog_erase_confirmation_desc_en="Please confirm t je ALLE GEGEVENS VAN DIT APPARAAT WILT WISSEN en macOS opnieuw installeert?"
		
		# Dialogue localizations - confirmation window (reinstall)
		dialog_reinstall_confirmation_desc_en="Please confirm that you want to upgrade macOS on this system now"
		
		# Dialogue localizations - confirmation window status
		dialog_confirmation_status_en="Press Cmd + Ctrl + C to Cancel"
		
		# Dialogue buttons
		dialog_confirmation_button_en="Confirm"
		
		dialog_cancel_button_en="Stop"
		dialog_enter_button_en="Enter"
		
		
		# Dialogue localizations - free space check
		dialog_check_desc_en="The macOS upgrade cannot be installed as there is not enough space left on the drive."
		
		# Dialogue localizations - power check
		dialog_power_title_en="Waiting for AC Power Connection"
		
		dialog_power_desc_en="Please connect your computer to power using an AC power adapter. This process will continue if AC power is detected within the next:"
		
		dialog_nopower_desc_en="Exiting. AC power was not connected after waiting for:"
		
		# Dialogue localizations - ask for short name
		dialog_short_name_en="Please enter your username to start the reinstallation process"
		
		# Dialogue localizations - not a volume owner
		dialog_not_volume_owner_en="Account is not a Volume Owner! Please login using one of the following accounts and try again"
		
		# Dialogue localizations - invalid user
		dialog_user_invalid_en="This account cannot be used to to perform the reinstall"
		
		# Dialogue localizations - invalid password
		dialog_invalid_password_en="ERROR: The password entered is NOT the login password for"
		
		# Dialogue localizations - ask for password
		dialog_get_password_en="Please enter the password for the account"
		
		# icon for download window
		dialog_dl_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns"
		
		# icon for confirmation dialog
		dialog_confirmation_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
		
		# set localisation variables
		dialog_dl_title=dialog_dl_title_${user_language}
		dialog_dl_desc=dialog_dl_desc_${user_language}
		dialog_erase_title=dialog_erase_title_${user_language}
		dialog_erase_desc=dialog_erase_desc_${user_language}
		dialog_reinstall_title=dialog_reinstall_title_${user_language}
		dialog_reinstall_heading=dialog_reinstall_heading_${user_language}
		dialog_reinstall_desc=dialog_reinstall_desc_${user_language}
		dialog_reinstall_status=dialog_reinstall_status_${user_language}
		dialog_rebooting_title=dialog_rebooting_title_${user_language}
		dialog_rebooting_heading=dialog_rebooting_heading_${user_language}
		dialog_rebooting_status=dialog_rebooting_status_${user_language}
		dialog_erase_confirmation_title=dialog_erase_confirmation_title_${user_language}
		dialog_erase_confirmation_desc=dialog_erase_confirmation_desc_${user_language}
		dialog_confirmation_status=dialog_confirmation_status_${user_language}
		dialog_confirmation_button=dialog_confirmation_button_${user_language}
		dialog_reinstall_confirmation_title=dialog_reinstall_confirmation_title_${user_language}
		dialog_reinstall_confirmation_desc=dialog_reinstall_confirmation_desc_${user_language}
		dialog_cancel_button=dialog_cancel_button_${user_language}
		dialog_enter_button=dialog_enter_button_${user_language}
		dialog_check_desc=dialog_check_desc_${user_language}
		dialog_power_desc=dialog_power_desc_${user_language}
		dialog_nopower_desc=dialog_nopower_desc_${user_language}
		dialog_power_title=dialog_power_title_${user_language}
		dialog_short_name=dialog_short_name_${user_language}
		dialog_user_invalid=dialog_user_invalid_${user_language}
		dialog_get_password=dialog_get_password_${user_language}
		dialog_invalid_password=dialog_invalid_password_${user_language}
		dialog_not_volume_owner=dialog_not_volume_owner_${user_language}
		
		
		open_osascript_dialog() {
			title="$1"
			message="$2"
			button1="$3"
			icon="$4"
			
			if [[ $message ]]; then
				/bin/launchctl asuser "$current_uid" /usr/bin/osascript <<-END
						display dialog "$message" ¬
						buttons {"$button1"} ¬
						default button 1 ¬
						with title "$title" ¬
						with icon $icon
END
			else
				/bin/launchctl asuser "$current_uid" /usr/bin/osascript <<-END
						display dialog "$title" ¬
						buttons {"$button1"} ¬
						default button 1 ¬
						with icon $icon
END
			fi
		}
		
		dep_notify_quit_for_install() {
			# quit DEP Notify
			echo "Command: Quit" >> "$DNLOG"
			# reset all the settings that might be used again
			/bin/rm "$DNLOG" "$DN_CONFIRMATION" 2>/dev/null
			# kill dep_notify_progress background job if it's already running
			if [ -f "/tmp/depnotify_progress_pid" ]; then
				while read -r i; do
					kill -9 "${i}"
				done < /tmp/depnotify_progress_pid
				/bin/rm /tmp/depnotify_progress_pid
			fi
		}
		
		
		# default max_password_attempts to 5
		max_password_attempts=5
		
		
		echo
		echo "   [$script_name] v$version script execution started: $(date)"
		
		########################Optional Check for backblaze backup stat###################
		######Feel free to remove this if you are not using backblaze in your org.#####################
		check_backupstat(){
			
			# credit to acidprime on jamfnation and Brad Pettit at Bexley Schools
			declare -x awk="/usr/bin/awk"
			declare -x sysctl="/usr/sbin/sysctl"
			declare -x perl="/usr/bin/perl"
			
			
			declare -xi DAY=86400
			declare -xi EPOCH="$($perl -e "print time")"
			declare -xi BACKUP="$(xmllint --xpath "string(//contents/lastbackupcompleted/@gmt_millis)" /Library/Backblaze.bzpkg/bzdata/bzreports/bzstat_lastbackupcompleted.xml)"
			
			
			declare -xi DIFF="$(($EPOCH - $BACKUP))"
			
			if [[ -d /Applications/Backblaze.app ]]; then
				echo "[check_backupstat] Backblaze is installed."
				if [ $DIFF -le $DAY ] ; then
					dayssincelastbackup=0
					echo "[check_backupstat] Backup status OK"
				fi
				
				if [ $dayssincelastbackup != "0" ]; then
					echo "[check_backupstat] Backblaze backup might be more than zero days old. Warned user to check."
					"$jamfHelper" -windowType "hud" -title "Check Backup!" -heading "Backup Error!" -alignHeading "natural" -description "Your Backblaze backup might be out of date. Please open the Backblaze app and select 'Backup Now'. Once the backup is complete, please try again! " -alignDescription "natural" -icon -button1 "Okay" -icon "/tmp/depimages/bb.png"
					exit 1
				fi
				
			else 
				"$jamfHelper" -windowType "hud" -title "Warning!" -heading "Backblaze Not Installed!" -alignHeading "natural" -description "It looks like Backblaze is not installed on this computer. Would you still like to proceed? " -alignDescription "natural" -icon -button1 "No" -button2 "Yes" -icon "/tmp/depimages/bb.png"
				if [ $? -eq 0 ];then
					echo "[check_backupstat] Backblaze is not installed. User decided to cancel."
					exit 1
				fi
			fi
		}
		
		
		ask_for_password() {
			# required for Silicon Macs
			if [[ $max_password_attempts == "infinite" ]]; then
				/bin/launchctl asuser "$current_uid" /usr/bin/osascript <<END
				set nameentry to text returned of (display dialog "${!dialog_get_password} ($account_shortname)" default answer "" with hidden answer buttons {"${!dialog_enter_button}"} default button 1 with icon 2)
END
			else
				/bin/launchctl asuser "$current_uid" /usr/bin/osascript <<END
				set nameentry to text returned of (display dialog "${!dialog_get_password} ($account_shortname)" default answer "" with hidden answer buttons {"${!dialog_cancel_button}", "${!dialog_enter_button}"} default button 2 with icon 2)
END
			fi
			
		}
		
		ask_for_shortname() {
			# required for Silicon Macs
			/bin/launchctl asuser "$current_uid" /usr/bin/osascript <<END
				set nameentry to text returned of (display dialog "${!dialog_short_name}" default answer "" buttons {"${!dialog_cancel_button}", "${!dialog_enter_button}"} default button 2 with icon 2)
END
		}
		
		
		
		check_password() {
			# Check that the password entered matches actual password
			# required for Silicon Macs
			# thanks to Dan Snelson for the idea
			user="$1"
			password="$2"
			password_matches=$( /usr/bin/dscl /Search -authonly "$user" "$password" )
			
			if [[ -z "$password_matches" ]]; then
				echo "   [check_password] Success: the password entered is the correct login password for $user."
				password_check="pass"
			else
				echo "   [check_password] ERROR: The password entered is NOT the login password for $user."
				password_check="fail"
				/usr/bin/afplay "/System/Library/Sounds/Basso.aiff"
			fi
		}
		
		user_invalid() {
			# required for Silicon Macs
			# open_osascript_dialog syntax: title, message, button1, icon
			open_osascript_dialog "$account_shortname: ${!dialog_user_invalid}" "" "OK" 2
		}
		
		user_not_volume_owner() {
			# required for Silicon Macs
			# open_osascript_dialog syntax: title, message, button1, icon
			open_osascript_dialog "$account_shortname ${!dialog_not_volume_owner}: ${enabled_users}" "" "OK" 2
		}
		
		
		get_user_details() {
			# Apple Silicon devices require a username and password to run startosinstall
			# get account name (short name)
			if [[ $use_current_user == "yes" ]]; then
				account_shortname="$current_user"
			fi
			
			if [[ $account_shortname == "" ]]; then
				account_shortname=$(ask_for_shortname)
				if [[ -z $account_shortname ]]; then
					echo "   [get_user_details] User cancelled."
					exit 1
				fi
			fi
			
			# check that this user exists
			if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" everyone ; then
				echo "   [get_user_details] $account_shortname account cannot be found!"
				user_invalid
				exit 1
			fi
			
			# check that the user is a Volume Owner
			user_is_volume_owner=0
			users=$(/usr/sbin/diskutil apfs listUsers /)
			enabled_users=""
			while read -r line ; do
				user=$(/usr/bin/cut -d, -f1 <<< "$line")
				guid=$(/usr/bin/cut -d, -f2 <<< "$line")
				# passwords are case sensitive, account names are not
				shopt -s nocasematch
				if [[ $(/usr/bin/grep -A2 "$guid" <<< "$users" | /usr/bin/tail -n1 | /usr/bin/awk '{print $NF}') == "Yes" ]]; then
					enabled_users+="$user "
					# The entered username might not match the output of fdesetup, so we compare
					# all RecordNames for the canonical name given by fdesetup against the entered
					# username, and then use the canonical version. The entered username might
					# even be the RealName, and we still would end up here.
					# Example:
					# RecordNames for user are "John.Doe@pretendco.com" and "John.Doe", fdesetup
					# says "John.Doe@pretendco.com", and account_shortname is "john.doe" or "Doe, John"
					user_record_names_xml=$(/usr/bin/dscl -plist /Search -read "Users/$user" RecordName dsAttrTypeStandard:RecordName)
					# loop through recordName array until error (we do not know the size of the array)
					record_name_index=0
					while true; do
						if ! user_record_name=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RecordName:${record_name_index}" /dev/stdin 2>/dev/null <<< "$user_record_names_xml") ; then
							break
						fi
						if [[ "$account_shortname" == "$user_record_name" ]]; then
							account_shortname=$user
							echo "   [get_user_details] $account_shortname is a Volume Owner"
							user_is_volume_owner=1
							break
						fi
						record_name_index=$((record_name_index+1))
					done
					# if needed, compare the RealName (which might contain spaces)
					if [[ $user_is_volume_owner = 0 ]]; then
						user_real_name=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RealName:0" /dev/stdin <<< "$(/usr/bin/dscl -plist /Search -read "Users/$user" RealName)")
						if [[ "$account_shortname" == "$user_real_name" ]]; then
							account_shortname=$user
							echo "   [get_user_details] $account_shortname is a Volume Owner"
							user_is_volume_owner=1
						fi
					fi
				fi
				shopt -u nocasematch
			done <<< "$(/usr/bin/fdesetup list)"
			if [[ $enabled_users != "" && $user_is_volume_owner = 0 ]]; then
				echo "   [get_user_details] $account_shortname is not a Volume Owner"
				user_not_volume_owner
				exit 1
			fi
			
			# get password and check that the password is correct
			password_attempts=1
			password_check="fail"
			while [[ "$password_check" != "pass" ]] ; do
				echo "   [get_user_details] ask for password (attempt $password_attempts/$max_password_attempts)"
				account_password=$(ask_for_password)
				ask_for_password_rc=$?
				# prevent accidental cancelling by simply pressing return (entering an empty password)
				if [[ "$ask_for_password_rc" != "0" ]]; then
					echo "   [get_user_details] User cancelled."
					exit 1
				fi
				check_password "$account_shortname" "$account_password"
				
				if [[ ( "$password_check" != "pass" ) && ( $max_password_attempts != "infinite" ) && ( $password_attempts -ge $max_password_attempts ) ]]; then
					# open_osascript_dialog syntax: title, message, button1, icon
					open_osascript_dialog "${!dialog_invalid_password}: $user" "" "OK" 2
					exit 1
				fi
				password_attempts=$((password_attempts+1))
			done
			
			
		}
		
		
		
		check_free_space() {
			# determine if the amount of free and purgable drive space is sufficient for the upgrade to take place.
			free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")  # with thanks to Pico
			
			if [[ ! "$free_disk_space" ]]; then
				# fall back to df -h if the above fails
				free_disk_space=$(df -Pk . | column -t | sed 1d | awk '{print $4}')
			fi
			
			if [[ $free_disk_space -ge $min_drive_space ]]; then
				echo "   [check_free_space] OK - $free_disk_space GB free/purgeable disk space detected"
			else
				echo "   [check_free_space] ERROR - $free_disk_space GB free/purgeable disk space detected"
				"$jamfHelper" -windowType "utility" -description "${FREESPACE_ERROR}" -alignDescription "left" -icon "$ALERT_ICON" -button1 "OK" -defaultButton "0" -cancelButton "1"
				exit 1
			fi
		}
		
		check_power_status() {
			# Check if device is on battery or AC power
			# If not, and our power_wait_timer is above 1, allow user to connect to power for specified time period
			# Acknowledgements: https://github.com/kc9wwh/macOSUpgrade/blob/master/macOSUpgrade.sh
			
			# default power_wait_timer to 60 seconds
			[[ ! $power_wait_timer ]] && power_wait_timer=60
			
			power_wait_timer_friendly=$( printf '%02dh:%02dm:%02ds\n' $((power_wait_timer/3600)) $((power_wait_timer%3600/60)) $((power_wait_timer%60)) )
			
			if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
				echo "   [check_power_status] OK - AC power detected"
			else
				echo "   [check_power_status] WARNING - No AC power detected"
				if [[ "$power_wait_timer" -gt 0 ]]; then
					if [[ -f "$jamfHelper" ]]; then
						# use jamfHelper if possible
						"$jamfHelper" -windowType "utility" -title "${!dialog_power_title}" -description "${!dialog_power_desc} ${power_wait_timer_friendly}" -alignDescription "left" -icon "$dialog_confirmation_icon" &
						wait_for_power "jamfHelper"
					else
						# open_osascript_dialog syntax: title, message, button1, icon
						open_osascript_dialog "${!dialog_power_desc}  ${power_wait_timer_friendly}" "" "OK" stop &
						wait_for_power "osascript"
					fi
				else
					echo "   [check_power_status] ERROR - No AC power detected after ${power_wait_timer_friendly}, cannot continue."
					exit 1
				fi
			fi
		}
		
		wait_for_power() {
			process="$1"
			## Loop for "power_wait_timer" seconds until either AC Power is detected or the timer is up
			echo "   [wait_for_power] Waiting for AC power..."
			while [[ "$power_wait_timer" -gt 0 ]]; do
				if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
					echo "   [wait_for_power] OK - AC power detected"
					kill_process "jamfHelper"
					return
				fi
				sleep 1
				((power_wait_timer--))
			done
			kill_process "$process"
			if [[ -f "$jamfHelper" ]]; then
				# use jamfHelper if possible
				"$jamfHelper" -windowType "utility" -title "${!dialog_power_title}" -description "${!dialog_nopower_desc} ${power_wait_timer_friendly}" -alignDescription "left" -icon "$dialog_confirmation_icon" -button1 "OK" -defaultButton 1 &
			else
				# open_osascript_dialog syntax: title, message, button1, icon
				open_osascript_dialog "${!dialog_nopower_desc}  ${power_wait_timer_friendly}" "" "OK" stop &
			fi
			echo "   [wait_for_power] ERROR - No AC power detected after waiting for ${power_wait_timer_friendly}, cannot continue."
			exit 1
		}
		
		
		# Check if DEPNotify is installed, if it's not install from Jamf.
		if [[ ! -d $DN_APP ]]; then
			echo "DEPNotify does not exist, installing."
			$JAMFBINARY policy -event DEPNotify-for-ventura
			if [[ ! -d $DN_APP ]]; then
				echo "DEPNotify Install failed, exiting"
				exit 20
			fi
		fi
		
		if [[ -f $DNLOG || -f $DN_CONFIRMATION ]]; then
			/bin/rm -f $DNLOG
			echo "Old DNLogs removed."
			/bin/rm -f $DN_CONFIRMATION
			echo "Old DN Confirmation removed."
		else 
			echo "no logs found!"
		fi
		
		
		jamf_helper_first_screen(){
			"$jamfHelper" -windowType "utility" -title "macOS Ventura" -heading "Upgrading macOS" -alignHeading "natural" -description "This process should take about 45 minutes to an hour to complete. In the next window, you will be asked to enter your username and password." -alignDescription "natural" -icon -button1 "Continue" -button2 "Cancel" -icon "/tmp/depimages/Ventura_logo.png"
			if [ $? != 0 ]; then
				echo "User cancelled at the first screen."
				exit 1
			fi
			
		}
		
		
		dep_notify_for_install() {
			# This function will open DEPNotify and set up the initial parameters.
			# configuration taken from https://github.com/jamf/DEPNotify-Starter
			/usr/bin/defaults write "$DNPLIST" statusTextAlignment "center"
			# Set the help bubble information
			/usr/bin/defaults write "$DNPLIST" helpBubble -array "Need Help?" \
			"If you experience any issues while upgrading your macOS, Please reach out to IT at it@simonsfoundation.org."
			chown "$CURRENT_USER":staff "$DNPLIST"
			
			# Configure the first page look
			
			echo "Command: Image: $DOWNLOAD_ICON" >> $DNLOG
			echo "Command: MainTitle: Downloading macOS Ventura!" >> $DNLOG
			echo "Command: MainText: This Process will take about 45 minutes to an hour to complete.\n \n Please make sure to save all of your open files and quit all applications.\n \n While the download is in progress, we will show you some exciting features coming your way with macOS Ventura!" >> $DNLOG			
			echo "Command: QuitKey: c" >> $DNLOG
			echo "Status: Preparing" >> $DNLOG
			
			# Launch DEPNotify if it's not open
			if ! pgrep DEPNotify ; then
				sudo -u "$CURRENT_USER" open -a "$DN_APP" --args -path "$DNLOG"
			fi
		}
		
		# Call this with "install" or "download" to update the DEPNotify window and progress dialogs
		depNotifyProgress_for_install() {
			last_progress_value=0
			current_progress_value=0
			
			if [[ "$1" == "download" ]]; then
				echo "Command: MainTitle: Downloading $APPNAME" >> $DNLOG
				
				# Wait for for the download to start, if it doesn't we'll bail out.
				while [ ! -f "$JAMF_DOWNLOADS/$PKG_NAME" ]; do
					userCancelProcess
					if [[ "$TIMEOUT" == 0 ]]; then
						echo "ERROR: (depNotifyProgress) Timeout while waiting for the download to start."
						{
							/bin/echo "Command: MainText: $DL_ERROR"
							echo "Status: Error downloading $PKG_NAME"
							echo "Command: DeterminateManualStep: 100"
							echo "Command: Quit: $DL_ERROR"
						} >> $DNLOG
						exit 1
					fi
					sleep 1
					((TIMEOUT--))
				done
				
				# Download started, lets set the progress bar
				echo "Status: Downloading - 0%" >> $DNLOG
				echo "Command: DeterminateManual: 100" >> $DNLOG
				
				# Until at least 100% is reached, calculate the downloading progress and move the bar accordingly
				until [[ "$current_progress_value" -ge 100 ]]; do
					# shellcheck disable=SC2012
					#				until [ "$current_progress_value" -gt "$last_progress_value" ]; do
					#					# Check if the download is in the waiting room (it moves from downloads to the waiting room after it's fully downloaded)
					#					if [[ ! -e "$JAMF_DOWNLOADS/$PKG_NAME" ]]; then
					#						CURRENT_DL_SIZE=$(ls -l "$JAMF_WAITING_ROOM/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
					#						userCancelProcess
					#						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
					#						sleep 2
					#					else
					#						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
					#						userCancelProcess
					#						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
					#						sleep 2
					
					#fi
					
					#Page 1
					until [ $current_progress_value -gt "20" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: Image: $DOWNLOAD_ICON" >> $DNLOG
						echo "Command: MainTitle: Downloading macOS Ventura!" >> $DNLOG
						echo "Command: MainText: This Process will take about 45 minutes to an hour to complete.\n \n Please make sure to save all of your open files and quit all applications.\n \n While the download is in progress, we will show you some exciting features coming your way with macOS Ventura!" >> $DNLOG
						echo "Command: QuitKey: c" >> $DNLOG
						
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
					done
					
					#Page 2
					until [ $current_progress_value -gt "30" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: System Settings" >> $DNLOG
						echo "Command: MainText: A new sidebar design in System Settings — instantly familiar to iPhone and iPad users — makes it easier than ever to navigate settings and configure your Mac." >> $DNLOG
						echo "Command: Image: /tmp/depimages/Ventura_logo.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
						
						
					done
					#Page 3
					until [ $current_progress_value -gt "40" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: Privacy and Security" >> $DNLOG
						echo "Command: MainText: Now your Mac will get important security improvements between normal software updates, so you automatically stay up to date and protected against security issues." >> $DNLOG
						echo "Command: Image: /tmp/depimages/Ventura_logo.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
						
					done
					
					#Page 4
					
					until [ $current_progress_value -gt "50" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: Safari and Passkeys" >> $DNLOG
						echo "Command: MainText: Passkeys introduce a new sign‑in method that is end-to-end encrypted and safe from phishing and data leaks.\n\nThis makes passkeys stronger than all common two‑factor authentication types. They also work on non‑Apple devices." >> $DNLOG
						echo "Command: Image: /tmp/depimages/passkeys.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
					done
					#Page 5
					until [ $current_progress_value -gt "60" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: Continuity Camera" >> $DNLOG
						echo "Command: MainText: Use the powerful camera system of iPhone with your Mac to do things never before possible with a webcam.\n\n Simply bring iPhone close to your Mac and it automatically switches to iPhone as the camera input. And it works wirelessly, so there’s nothing to plug in." >> $DNLOG
						echo "Command: Image: /tmp/depimages/camera.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
					done
					#Page 6
					until [ $current_progress_value -gt "70" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: Accessibility" >> $DNLOG
						echo "Command: MainText: Turn audio into text in real time and follow along more easily with conversations and media. " >> $DNLOG
						echo "Command: Image: /tmp/depimages/accessibility.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
					done
					#Page 7
					until [ $current_progress_value -gt "80" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: Freeform (Coming later this year)" >> $DNLOG
						echo "Command: MainText: Freeform is a productivity app where you and your collaborators can bring ideas to life.\n\nPlan projects, collect inspiration, brainstorm with your team, or draw with a friend.\n\nShare files and insert web links, documents, video, and audio." >> $DNLOG
						echo "Command: Image: /tmp/depimages/Ventura_logo.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
					done
					#Page 8
					until [ $current_progress_value -gt "90" ]; do
						CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
						userCancelProcess
						current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
						sleep 2
						echo "Command: MainTitle: Messages" >> $DNLOG
						echo "Command: MainText: You can now edit a message you just sent or unsend a recent message altogether.\n\n And you can mark a message as unread if you can’t respond in the moment and want to come back to it later" >> $DNLOG
						echo "Command: Image: /tmp/depimages/messages.png" >> $DNLOG
						
						echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
						echo "Status: Downloading - $current_progress_value%" >> $DNLOG
						last_progress_value=$current_progress_value
					done
					#Page 9
					until [ "$current_progress_value" -gt "$last_progress_value" ]; do
						# Check if the download is in the waiting room (it moves from downloads to the waiting room after it's fully downloaded)
						if [[ ! -e "$JAMF_DOWNLOADS/$PKG_NAME" ]]; then
							CURRENT_DL_SIZE=$(ls -l "$JAMF_WAITING_ROOM/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
							userCancelProcess
							current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
							sleep 2
						else
							CURRENT_DL_SIZE=$(ls -l "$JAMF_DOWNLOADS/$PKG_NAME" | awk '{ print $5 }' | awk '{$1/=1024;printf "%.i\n",$1}')
							userCancelProcess
							current_progress_value=$((CURRENT_DL_SIZE * 100 / PKG_Size))
							sleep 2
							echo "Command: MainTitle: Almost There!" >> $DNLOG
							echo "Command: MainText: We are getting ready to start preparing for installation. Once the installation begins, you will not be able to use your computer for a few minutes.\n\n Please close all of your open apps (except Self Service) and let the magic happen!" >> $DNLOG
							echo "Command: Image: /tmp/depimages/Ventura_logo.png" >> $DNLOG
							
						fi
						
						
					done
					
					echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
					echo "Status: Downloading - $current_progress_value%" >> $DNLOG
					last_progress_value=$current_progress_value
					
					
					
				done
				#done
				
				
			elif [[ "$1" == "install" ]]; then
				echo "Command: MainTitle: Installing $APPNAME" >> $DNLOG
				# Install started, lets set the progress bar
				{
					echo "Command: Image: $INSTALL_ICON"
					/bin/echo "Command: MainText: Install macOS Ventura installer"
					echo "Status: Preparing to Install $PKG_NAME"
					echo "Command: DeterminateManual: 100"
				} >> $DNLOG
				until grep -q "progress status" "$LOG_FILE" ; do
					sleep 2
				done
				# Update the progress using a timer until it's at 100%
				until [[ "$current_progress_value" -ge "100" ]]; do
					until [ "$current_progress_value" -gt "$last_progress_value" ]; do
						INSTALL_STATUS=$(sed -nE 's/installer:PHASE:(.*)/\1/p' < $LOG_FILE | tail -n 1)
						INSTALL_FAILED=$(sed -nE 's/installer:(.*)/\1/p' < $LOG_FILE | tail -n 1 | grep -c "The Installer encountered an error")
						if [[ $INSTALL_FAILED -ge "1" ]]; then
							echo "Install failed, notifying user."
							echo "Command: Quit: $INSTALL_ERROR" >> $DNLOG 
						fi
						userCancelProcess
						current_progress_value=$(sed -nE 's/installer:%([0-9]*).*/\1/p' < $LOG_FILE | tail -n 1)
						sleep 2
					done
					echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $DNLOG
					echo "Status: $INSTALL_STATUS - $current_progress_value%" >> $DNLOG
					last_progress_value=$current_progress_value
				done
				# The code below is the install logic to use when "estimating" the time of an install instead of using JAMF
				# It mostly works but I want to keep it for historical sake ;)
			elif [[ "$1" == "manualInstall" ]]; then
				echo "Command: MainTitle: Installing $APPNAME" >> $DNLOG
				# Install started, lets set the progress bar
				{
					echo "Command: Image: $INSTALL_ICON"
					/bin/echo "Command: MainText: $INSTALL_DESC"
					echo "Status: Preparing to Install $PKG_NAME"
					echo "Command: DeterminateManual: $INSTALL_TIMER"
				} >> $DNLOG
				
				# Update the progress using a timer until a receipt is found. If it gets full it'll just wait for a receipt.
				until [[ "$current_progress_value" -ge $INSTALL_TIMER ]] && [[ $(receiptIsPresent) -eq 1 ]]; do
					userCancelProcess
					sleep 5
					current_progress_value=$((current_progress_value + 5))
					echo "Command: DeterminateManualStep: 5" >> $DNLOG
					echo "Status: Installing $PKG_NAME" >> $DNLOG
					receiptIsPresent && break
					last_progress_value=$current_progress_value
				done
			fi
		}
		
		receiptIsPresent() {
			if [[ $(find "/Library/Application Support/JAMF/Receipts/$PKG_NAME" -type f -maxdepth 1) ]]; then
				current_progress_value="100"
				# If it finds the receipt, just set the progress bar to full
				{
					echo "Installer is not running, exiting."
					echo "Command: DeterminateManualStep: 100"
					echo "Status: $PKG_NAME successfully installed."
				} >> $DNLOG
				sleep 10
				return 0
			fi
			return 1
		}
		
		cachePackageWithJamf() {
			$JAMFBINARY policy -event "$1" &
			JAMF_PID=$!
			echo "Jamf policy running with a PID of $JAMF_PID"
		}
		
		installWithJamf() {
			$JAMFBINARY install -path "$JAMF_WAITING_ROOM" -package "$PKG_NAME" -showProgress -target / 2>&1 | tee $LOG_FILE &
			JAMF_PID=$!
			echo "Jamf install running with a PID of $JAMF_PID"
		}
		
		cleanupWaitingRoom() {
			echo "Sweeping up the waiting room..."
			rm -f "$JAMF_WAITING_ROOM/$PKG_NAME" &
			rm -f "$JAMF_WAITING_ROOM/$PKG_NAME".cache.xml
		}
		
		# Checks if DEPNotify is open, if it's not, it'll exit, causing the trap to run
		userCancelProcess () {
			if ! pgrep DEPNotify ; then
				kill -9 $JAMF_PID
				killall installer
				echo "User manually cancelled with the quit key."
				# We don't want to mark this as a failure, so let's exit gracefully.
				exit 0
			fi
		}
		
		
		kill_process() {
			process="$1"
			echo
			if process_pid=$(/usr/bin/pgrep -a "$process" 2>/dev/null) ; then 
				echo "   [$SCRIPT_NAME] attempting to terminate the '$process' process - Termination message indicates success"
				kill "$process_pid" 2> /dev/null
				if /usr/bin/pgrep -a "$process" >/dev/null ; then 
					echo "   [$SCRIPT_NAME] ERROR: '$process' could not be killed"
				fi
				echo
			fi
		}
		
		
		
		###############
		## MAIN BODY FOR INSTALL SCRIPT ##
		###############	
		check_power_status 
		check_backupstat 
		check_free_space 
		
		# Let's first check if the package existis in the downloads and it matches the size...
		# this avoids us having to run the policy again and causing the sceript to re-download the whole thing again.
		if [[ -e "$JAMF_WAITING_ROOM/$PKG_NAME" ]] && [[ $CURRENT_PKG_SIZE == "$PKG_Size" ]]; then
			echo "Package already download, installing with jamf binary."
			jamf_helper_first_screen 
			get_user_details
			dep_notify_for_install
			installWithJamf
			depNotifyProgress_for_install  install
			#cleanupWaitingRoom
			sleep 3
			dep_notify_quit_for_install 
			sleep 3
		else
			jamf_helper_first_screen 
			get_user_details
			dep_notify_for_install 
			cachePackageWithJamf "$JAMF_TRIGGER"
			depNotifyProgress_for_install  download
			sleep 5
			dep_notify_quit_for_install 
			dep_notify_for_install 
			installWithJamf
			depNotifyProgress_for_install  install
			cleanupWaitingRoom
			dep_notify_quit_for_install 
		fi
		
		
		################ Upgrade script ###########################
		
		# Dialog helper apps
		jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
		depnotify_app="/Applications/Utilities/DEPNotify.app"
		depnotify_log="/var/tmp/depnotify.log"
		depnotify_confirmation_file="/var/tmp/com.depnotify.provisioning.done"
		depnotify_download_url="https://files.nomad.menu/DEPNotify.pkg"
		
		
		
		# Default working directory 
		workdir="/Library/Management/erase-install"
		
		# ensure workdir exists
		
		if [[ ! -d "$workdir" ]]; then
			echo "   [$script_name] Making working directory at $workdir"
			/bin/mkdir -p "$workdir"
		fi
		
		# all output from now on is written also to a log file
		LOG_FILE="$workdir/erase-install.log"
		exec > >(tee "${LOG_FILE}") 2>&1
		
		
		# all output from now on is written also to a log file
		LOG_FILE="$workdir/erase-install.log"
		exec > >(tee "${LOG_FILE}") 2>&1
		
		
		# Directory in which to place the macOS installer. 
		installer_directory="/Applications"
		
		# ensure computer does not go to sleep while running this script
		echo "   [$script_name] Caffeinating this script (pid=$$)"
		/usr/bin/caffeinate -dimsu -w $$ &
		
		#Set DEPNotify Full screen.
		window_type="fs"
		
		#set reboot delay.
		rebootdelay=90
		
		
		create_launchdaemon_to_remove_workdir () {
			# Name of LaunchDaemon
			plist_label="com.simonsfoundation.erase-install.remove"
			launch_daemon="/Library/LaunchDaemons/$plist_label.plist"
			# Create the plist
			/usr/bin/defaults write "$launch_daemon" Label -string "$plist_label"
			/usr/bin/defaults write "$launch_daemon" ProgramArguments -array \
			-string /bin/rm \
			-string -Rf \
			-string "$workdir" \
			-string "$launch_daemon"
			/usr/bin/defaults write "$launch_daemon" RunAtLoad -boolean yes
			/usr/bin/defaults write "$launch_daemon" LaunchOnlyOnce -boolean yes
			
			/usr/sbin/chown root:wheel "$launch_daemon"
			/bin/chmod 644 "$launch_daemon"
		}
		
		
		dep_notify() {
			# configuration taken from https://github.com/jamf/DEPNotify-Starter
			DEP_NOTIFY_CONFIG_PLIST="/Users/$current_user/Library/Preferences/menu.nomad.DEPNotify.plist"
			# /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" pathToPlistFile "$DEP_NOTIFY_USER_INPUT_PLIST"
			STATUS_TEXT_ALIGN="center"
			/usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" statusTextAlignment "$STATUS_TEXT_ALIGN"
			chown "$current_user":staff "$DEP_NOTIFY_CONFIG_PLIST"
			
			# Configure the window's look
			{
				echo "Command: Image: $dn_icon_upgrade"
				echo "Command: MainTitle: $dn_title_upgrade"
				echo "Command: MainText: $dn_desc_upgrade"
			} >> "$depnotify_log"
			
			if [[ "$dn_button" ]]; then
				echo "Adding DEPNotify button $dn_button_upgrade" ## TEMP
				echo "Command: ContinueButton: $dn_button_upgrade" >> "$depnotify_log"
			fi
			
			if ! pgrep DEPNotify ; then
				# Opening the app after initial configuration
				if [[ "$window_type" == "fs" ]]; then
					sudo -u "$current_user" open -a "$depnotify_app" --args -path "$depnotify_log" -fullScreen
				else
					sudo -u "$current_user" open -a "$depnotify_app" --args -path "$depnotify_log"
				fi
			fi
			
			# set message below progress bar
			echo "Status: $dn_status_upgrade" >> "$depnotify_log"
			
			# set alternaitve quit key (default is X)
			if [[ $dn_quit_key ]]; then
				echo "Command: QuitKey: $dn_quit_key" >> "$depnotify_log"
			fi
		}
		
		dep_notify_progress() {
			# function for DEPNotify to show progress while the installer is being downloaded or prepared
			last_progress_value=0
			current_progress_value=0
			
			# Wait for the preparing process to start and set the progress bar to 100 steps
			until grep -q "Preparing: \d" "$LOG_FILE" ; do
				sleep 2
			done
			echo "Status: $dn_status_upgrade - 0%" >> $depnotify_log
			echo "Command: DeterminateManual: 100" >> $depnotify_log
			
			# Until at least 100% is reached, calculate the preparing progress and move the bar accordingly
			until [[ $current_progress_value -ge 100 ]]; do
				until [[ $current_progress_value -gt $last_progress_value ]]; do
					current_progress_value=$(tail -1 "$LOG_FILE" | awk 'END{print substr($NF, 1, length($NF)-3)}')
					sleep 2
				done
				echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $depnotify_log
				echo "Status: $dn_status_upgrade - $current_progress_value%" >> $depnotify_log
				last_progress_value=$current_progress_value
			done
			
		}
		
		dep_notify_quit() {
			# quit DEP Notify
			echo "Command: Quit" >> "$depnotify_log"
			# reset all the settings that might be used again
			/bin/rm "$depnotify_log" "$depnotify_confirmation_file" 2>/dev/null
			dn_button_upgrade=""
			dn_quit_key=""
			dn_cancel=""
			# kill dep_notify_progress background job if it's already running
			if [ -f "/tmp/depnotify_progress_pid" ]; then
				while read -r i; do
					kill -9 "${i}"
				done < /tmp/depnotify_progress_pid
				/bin/rm /tmp/depnotify_progress_pid
			fi
		}
		
		compare_build_versions() {
			first_build="$1"
			second_build="$2"
			
			first_build_darwin=${first_build:0:2}
			second_build_darwin=${second_build:0:2}
			first_build_letter=${first_build:2:1}
			second_build_letter=${second_build:2:1}
			first_build_minor=${first_build:3}
			second_build_minor=${second_build:3}
			first_build_minor_no=${first_build_minor//[!0-9]/}
			second_build_minor_no=${second_build_minor//[!0-9]/}
			first_build_minor_beta=${first_build_minor//[0-9]/}
			second_build_minor_beta=${second_build_minor//[0-9]/}
			
			builds_match="no"
			versions_match="no"
			os_matches="no"
			
			echo "   [compare_build_versions] Comparing (1) $first_build with (2) $second_build"
			if [[ "$first_build" == "$second_build" ]]; then
				echo "   [compare_build_versions] $first_build = $second_build"
				builds_match="yes"
				versions_match="yes"
				os_matches="yes"
				return
			elif [[ $first_build_darwin -gt $second_build_darwin ]]; then
				echo "   [compare_build_versions] $first_build > $second_build"
				first_build_newer="yes"
				first_build_major_newer="yes"
				return
			elif [[ $first_build_letter > $second_build_letter && $first_build_darwin -eq $second_build_darwin ]]; then
				echo "   [compare_build_versions] $first_build > $second_build"
				first_build_newer="yes"
				first_build_minor_newer="yes"
				os_matches="yes"
				return
			elif [[ ! $first_build_minor_beta && $second_build_minor_beta && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
				echo "   [compare_build_versions] $first_build > $second_build (production > beta)"
				first_build_newer="yes"
				first_build_patch_newer="yes"
				versions_match="yes"
				os_matches="yes"
				return
			elif [[ ! $first_build_minor_beta && ! $second_build_minor_beta && $first_build_minor_no -lt 1000 && $second_build_minor_no -lt 1000 && $first_build_minor_no -gt $second_build_minor_no && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
				echo "   [compare_build_versions] $first_build > $second_build"
				first_build_newer="yes"
				first_build_patch_newer="yes"
				versions_match="yes"
				os_matches="yes"
				return
			elif [[ ! $first_build_minor_beta && ! $second_build_minor_beta && $first_build_minor_no -ge 1000 && $second_build_minor_no -ge 1000 && $first_build_minor_no -gt $second_build_minor_no && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
				echo "   [compare_build_versions] $first_build > $second_build (both betas)"
				first_build_newer="yes"
				first_build_patch_newer="yes"
				versions_match="yes"
				os_matches="yes"
				return
			elif [[ $first_build_minor_beta && $second_build_minor_beta && $first_build_minor_no -ge 1000 && $second_build_minor_no -ge 1000 && $first_build_minor_no -gt $second_build_minor_no && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
				echo "   [compare_build_versions] $first_build > $second_build (both betas)"
				first_build_patch_newer="yes"
				first_build_newer="yes"
				versions_match="yes"
				os_matches="yes"
				return
			fi
			
		}
		
		
		
		
		check_installer_is_valid() {
			# check installer validity:
			# The Build version in the app Info.plist is often older than the advertised build,
			# so it's not a great check for validity
			# check if running --erase, where we might be using the same build.
			# The actual build number is found in the SharedSupport.dmg in com_apple_MobileAsset_MacSoftwareUpdate.xml (Big Sur and greater).
			# This is new from Big Sur, so we include a fallback to the Info.plist file just in case.
			echo "   [check_installer_is_valid] Checking validity of $existing_installer_app."
			
			# first ensure that some earlier instance is not still mounted as it might interfere with the check
			[[ -d "/Volumes/Shared Support" ]] && diskutil unmount force "/Volumes/Shared Support"
			# now attempt to mount
			if [[ -f "$existing_installer_app/Contents/SharedSupport/SharedSupport.dmg" ]]; then
				if hdiutil attach -quiet -noverify -nobrowse "$existing_installer_app/Contents/SharedSupport/SharedSupport.dmg" ; then
					echo "   [check_installer_is_valid] Mounting $existing_installer_app/Contents/SharedSupport/SharedSupport.dmg"
					sleep 1
					build_xml="/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
					if [[ -f "$build_xml" ]]; then
						echo "   [check_installer_is_valid] Using Build value from com_apple_MobileAsset_MacSoftwareUpdate.xml"
						installer_build=$(/usr/libexec/PlistBuddy -c "Print :Assets:0:Build" "$build_xml")
						sleep 1
						diskutil unmount force "/Volumes/Shared Support"
					else
						echo "   [check_installer_is_valid] ERROR: com_apple_MobileAsset_MacSoftwareUpdate.xml not found. Check the mount point at /Volumes/Shared Support"
					fi
				else
					echo "   [check_installer_is_valid] Mounting SharedSupport.dmg failed"
				fi
			else
				# if that fails, fallback to the method for 10.15 or less, which is less accurate
				echo "   [check_installer_is_valid] Using DTSDKBuild value from Info.plist"
				if [[ -f "$existing_installer_app/Contents/Info.plist" ]]; then
					installer_build=$( /usr/bin/defaults read "$existing_installer_app/Contents/Info.plist" DTSDKBuild )
				else
					echo "   [check_installer_is_valid] Installer Info.plist could not be found!"
				fi
			fi
			if [[ ! $installer_build ]]; then
				echo "   [check_installer_is_valid] Build of existing installer could not be found!"
				exit 1
			fi
			
			system_build=$( /usr/bin/sw_vers -buildVersion )
			
			compare_build_versions "$system_build" "$installer_build"
			if [[ $first_build_major_newer == "yes" || $first_build_minor_newer == "yes" ]]; then
				echo "   [check_installer_is_valid] Installer: $installer_build < System: $system_build : invalid build."
				invalid_installer_found="yes"
			elif [[ $first_build_patch_newer == "yes" ]]; then
				echo "   [check_installer_is_valid] Installer: $installer_build < System: $system_build : build might work but if it fails, please obtain a newer installer."
				warning_issued="yes"
				invalid_installer_found="no"
			else
				echo "   [check_installer_is_valid] Installer: $installer_build >= System: $system_build : valid build."
				invalid_installer_found="no"
			fi
			
			working_macos_app="$existing_installer_app"
		}
		
		find_existing_installer() {
			# Search for an existing download
			# First let's see if this script has been run before and left an installer
			existing_installer_app=$( find "$installer_directory/Install macOS"*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
			
			if [[ -d "$existing_installer_app" ]]; then
				echo "   [find_existing_installer] Installer found at $existing_installer_app."
				app_is_in_applications_folder="yes"
				check_installer_is_valid
			else
				echo "   [find_existing_installer] No valid installer found."
				exit
			fi
			
		}
		
		finish() {
			
			# kill caffeinate
			kill_process "caffeinate"
			
			# kill any dialogs if startosinstall ends before a reboot
			kill_process "jamfHelper"
			dep_notify_quit
			exit 0
		}
		
		post_prep_work() {
			# set DEPNotify status for rebootdelay if set
			if [[ "$rebootdelay" -gt 10 ]]; then
				dep_notify_quit
				echo "   [post_prep_work] Opening DEPNotify full screen message (language=$user_language)"
				dn_title="${!dialog_reinstall_title}"
				dn_desc="${!dialog_rebooting_heading}"
				dn_status="${!dialog_rebooting_status}"
				dn_button=""
				dep_notify
				dep_notify_progress reboot-delay >/dev/null 2>&1 &
				echo $! >> /tmp/depnotify_progress_pid
			fi
			
			# finish the delay
			sleep "$rebootdelay"
			
			# then shut everything down
			kill_process "Self Service"
			finish
			exit
		}
		
		
		
		
		# Silicon Macs require a username and password to run startosinstall
		# We therefore need to be logged in to proceed, if we are going to erase or reinstall
		# This goes before the download so users aren't waiting for the prompt for username
		# Check for Apple Silicon using sysctl, because arch will not report arm64 if running under Rosetta.
		[[ $(/usr/sbin/sysctl -q -n "hw.optional.arm64") -eq 1 ]] && arch="arm64" || arch=$(/usr/bin/arch)
		echo "   [$script_name] Running on architecture $arch"
		if [[ "$arch" == "arm64" ]]; then
			if ! pgrep -q Finder ; then
				echo "    [$script_name] ERROR! The startosinstall binary requires a user to be logged in."
				echo
				# kill caffeinate
				kill_process "caffeinate"
				exit 1
			fi
			#get_user_details
		fi
		
		
		find_existing_installer
		check_installer_is_valid
		
		echo "   [$script_name] Opening DEPNotify message (language=$user_language)"
		dn_title_upgrade="${!dialog_reinstall_title}"
		dn_desc_upgrade="${!dialog_reinstall_desc}"
		dn_status_upgrade="${!dialog_reinstall_status}"
		dn_icon_upgrade="$dialog_reinstall_icon"
		dn_button_upgrade=""
		create_launchdaemon_to_remove_workdir
		echo "[ $script_name] depnotify should start now"
		dep_notify
		dep_notify_progress startosinstall >/dev/null 2>&1 &
		echo $! >> /tmp/depnotify_progress_pid
		echo "[ $script_name] depnotify should be up now"
		if [[ -f "$depnotify_confirmation_file" ]]; then
			echo "[ $script_name] depnotify "
			dep_notify_quit
		fi
		
		if [ "$arch" == "arm64" ]; then
			
			# shellcheck disable=SC2086
			"$working_macos_app"/Contents/Resources/startosinstall  --pidtosignal $$ --agreetolicense --nointeraction --rebootdelay "$rebootdelay"  --user "$account_shortname" --stdinpass <<< "$account_password" & wait $!
		else
			"$working_macos_app"/Contents/Resources/startosinstall  --pidtosignal $$ --agreetolicense --nointeraction --rebootdelay "$rebootdelay"  & wait $!
		fi
		sleep 10
		post_prep_work
