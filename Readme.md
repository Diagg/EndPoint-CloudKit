# Endpoint Cloud kit

Endpoint Cloud kit Module (ECK) is a set of cmdlet to help building scripts or applications deployed by your MDM (Intune/Workspace One...)

<<<<<<< HEAD
- Run Powershell script or executable in User/system/admin/Trusted Installer/System Interactive context
- Restart your script after reboot
- Logging function
- Configurable reboot toast notifications
- Execution context (Admin/system/user) detection
- Pending reboot detection
- Windows Build converter to friendly name (like 21H2)
=======
## Description 

ECK can be used to:
- Run Powershell script or executable in User/system/admin context
- Restart your script after reboot.
- Logging.
- set customizable reboot toast notifications.
- Detect execution context (Admin/system/user).
- Detect Pending reboot.
- Converter Windows Build number to friendly name (like 21H2)

## Installation
Endpoint cloud Kit is published to the [Powershell Gallery](https://www.powershellgallery.com/packages/EndpointCloudkit) and can be installed as a standard module:
```powershell
Install-Module EndpointCloudKit 
Import-module EndpointCloudKit
```
To embed ECK in all of your script that are deployed from the cloud, you shoud prefer [EndpointCloudKit-Bootstap](https://github.com/Diagg/EndPoint-CloudKit-Bootstrap), a robust helper script that takes care of evey requeriements for you !

Diagg/OSD-Couture.com
>>>>>>> 38e03b3dfd4f892d1ddbdeb0da6bf6503f816ebd
