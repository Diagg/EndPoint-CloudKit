# Endpoint Cloud kit

Endpoint Cloud kit Module (ECK) is a set of cmdlet to help building scripts or applications deployed by your MDM (Intune/Workspace One...)

## Description 

ECK can be used to:
- Run Powershell script or executable in User/system/admin context
- Restart your script after reboot
- Logging function
- Configurable reboot toast notifications
- Execution context (Admin/system/user) detection
- Pending reboot detection
- Windows Build converter to friendly name (like 21H2)

## Installation
Endpoint cloud Kit is published to the [Powershell Gallery](https://www.powershellgallery.com/packages/EndpointCloudkit) and can installed as a standard module:
```powershell
Install-Module EndpointCloudKit 
Import-module EndpointCloudKit
```
To embed ECK in all of your script that are deployed from the cloud, you shoud prefer to use [EndpointCloudKit-Bootstap](https://github.com/Diagg/EndPoint-CloudKit-Bootstrap), an helper script that takes care of evey requeriements for you !

Diagg/OSD-Couture.com
