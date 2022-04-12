# Endpoint Cloud kit
Endpoint Cloud kit Module (ECK) is a set of cmdlet to help building scripts or applications deployed by your MDM (Intune/Workspace One...).
Built with Cloud in mind, every components are retrieved from the internet to be assembled on your PC.

## Description 
ECK can be used to:
- Run Powershell script or executable in User/System/Admin/Trusted Installer/System Interactive context
- Restart your script after reboot.
- Logging.
- set customizable reboot toast notifications.
- Detect execution context (Admin/System/User/Trusted Installer).
- Detect Pending reboot.
- Convert Windows Build number to friendly name (like 21H2)

## Installation
Endpoint cloud Kit is published to the [Powershell Gallery](https://www.powershellgallery.com/packages/EndpointCloudkit) and can be installed as a standard module:
```powershell
Install-Module EndpointCloudKit 
Import-module EndpointCloudKit
```
To embed ECK in scripts you wish to deliver to your endpoints, you should prefer [EndpointCloudKit-Bootstap](https://github.com/Diagg/EndPoint-CloudKit-Bootstrap), a robust helper script that takes care of every requirements on devices that are not yet ready to download modules from the Powershell Gallery !

Diagg/OSD-Couture.com

