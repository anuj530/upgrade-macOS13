# upgrade-macOS13
The purpose of this script is to upgrade to macOS Ventura using the full app installer via Jamf Self-Service. 
 
This script uses some parts of the erase-install script created by Graham Pugh and the script created by John Mahlman, 'use DEPNotify for installer progress.' 
 
This script is only designed to work with Jamf Pro, DEPNotify, and the macOS Ventura App installer.
This script will check for power and disk space and then ask for a username and password.
 
There is also a check to verify the Backblaze backup status. Please feel free to remove this if you are not using Backblaze in your environment. 
 
This script will display a progress bar using DEPNotify while downloading the macOS Ventura package. It will also show some of the upcoming features with macOS Ventura. Once the package is downloaded, it will install the installer App. 
 
Once the app is installed, it will check the installer validity and start the upgrade process using depnotify full screen, and then the computer will reboot to perform the upgrade. 
 
Jamf Setup:
 
Upload this script to jamf. 
Upload the macOS Ventura package to Jamf.
Upload the customized DEPNotify package to jamf.
 
Create a policy that deploys the following items: 
	1. The custom dep-notify package installs the DEPNotify app and some logos used during the installation.
	2. The script that you uploaded in the previous step. 
	3. Make this policy available in self-service.
 
Create a policy that deploys the macOS Ventura package that you previously uploaded. 
Make sure to set this package action as a cache. This is important because our script will install this cached package on the user endpoint.
 
 
 
Work in progress: 
 
	· Way to report successful installation in jamf policy log. Please have an inventory update at the startup policy to ensure the endpoint is updated successfully. 
 

