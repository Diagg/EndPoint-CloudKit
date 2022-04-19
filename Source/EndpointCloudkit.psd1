#
# Module manifest for module 'EndpointCloudkit'
#
# Generated by: Diagg
#
# Generated on: 19/04/2022
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'EndpointCloudkit.psm1'

# Version number of this module.
ModuleVersion = '0.0.12.7'

# Supported PSEditions
CompatiblePSEditions = 'Desktop'

# ID used to uniquely identify this module
GUID = 'd1488437-3d1f-439e-b188-30e208cbd9df'

# Author of this module
Author = 'Diagg'

# Company or vendor of this module
CompanyName = 'OSD-Couture.com'

# Copyright statement for this module
Copyright = '(c) 2022 Diagg/OSD-Couture.com. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Endpoint Cloud kit Module (ECK), a set of cmdlet to help building scripts or application deployed by your MDM (Intune/Workspace One...)

- Run Powershell script or executable in User/system/admin/trusted installer/System Interactive context
- Restart your script after reboot
- Logging function
- Configurable reboot toast notifications
- Execution context (Admin/system/user/TI) detection
- Pending reboot detection
- Windows Build converter to friendly name (like 21H2)
- Download from Git/Github on public/private repo
- Auto update ECK module
'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Get-ECKExecutionContext', 'Get-ECKOsFriendlyName', 
               'Get-ECKPendingReboot', 'Invoke-ECKContinueOnNextReboot', 
               'Invoke-ECKRebootToastNotification', 'Invoke-ECKScheduledTask', 
               'Write-ECKLog', 'New-ECKEnvironment', 'Get-ECKGithubContent', 
               'Initialize-ECKPrereq', 'Add-ECKPendingReboot'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'PSEdition_Desktop', 'Windows'

        # A URL to the license for this module.
        LicenseUri = 'https://raw.githubusercontent.com/Diagg/EndPoint-CloudKit/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/Diagg/EndPoint-CloudKit'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '0.0.1   2022/02/18 * Initial beta release to PS Gallery
0.0.2   2022/02/21 * beta release - Removed all $script: scoped variables
0.0.3   2022/02/21 * beta release - Invoke-ECKScheduledTask was missing
0.0.4   2022/02/22 * beta release - Reworked Write-ECKlog
0.0.5   2022/02/23 * beta release - First stable version
0.0.6   2022/03/02 * Beta version - Fixed a bug in Write-ECKlog
0.0.7.0 2022/03/08 * Beta version - Fixed a bug in Invoke-ECKScheduledTask
0.0.8.0 2022/03/10 * Beta version - Removed parameter ''interactive'' in Invoke-ECKScheduledTask.
0.0.9.0 2022/03/30 * Beta version - Added back ''interactive'' parameter in Invoke-ECKScheduledTask with support ServiceUI.exe
0.0.10.0 2022/04/04 * Beta version - Added function Set-ECKEnvironment to Gather local informations In a script scoped objet variable
0.0.11.0 2022/04/12 * Beta version - Invoke-ECKScheduledTask can now monitor running scheduled task
0.0.11.1 2022/04/12 * Beta version - Fixed bugs in Set-ECKEnvironment
0.0.12.0 2022/04/16 * Beta version - Added Functions Get-ECKGithubContent, Initialize-ECKPrereq, Add-ECKPendingReboot, Set-ECKEnvironment is renamed New-ECKEnvironment
0.0.12.5 2022/04/18 * Beta version - fixed a Hell lots of bugs !
0.0.12.6 2022/04/16 * Beta version - fixed even more bugs !
0.0.12.7 2022/04/16 * Beta version - fixed a bugs in module scope !'

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

