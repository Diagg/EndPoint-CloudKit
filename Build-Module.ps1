##== Global Variables
$Script:CurrentScriptName = $MyInvocation.MyCommand.Name
$Script:CurrentScriptFullName = $MyInvocation.MyCommand.Path
$Script:CurrentScriptPath = split-path $MyInvocation.MyCommand.Path
$apiKey = ''


$Params = @{
    "ModuleVersion"         = '0.0.12.1'
    "RootModule" = 'EndpointCloudkit.psm1'
    "GUID"                  = 'd1488437-3d1f-439e-b188-30e208cbd9df'
    "Path" 				    = "$($Script:CurrentScriptPath)\Source\EndpointCloudkit.psd1"
    "Author" 			    = 'Diagg'
    "CompanyName" 			= 'OSD-Couture.com'
    "Copyright"             = '(c) 2022 Diagg/OSD-Couture.com. All rights reserved.'
    "CompatiblePSEditions" 	= @('Desktop')
    "FunctionsToExport" 	= @('Get-ECKExecutionContext','Get-ECKOsFriendlyName','Get-ECKPendingReboot','Invoke-ECKContinueOnNextReboot','Invoke-ECKRebootToastNotification','Invoke-ECKScheduledTask','Write-ECKLog','Set-ECKEnvironment','Get-ECKGithubContent','Initialize-ECKPrereq','Set-ECKPendingReboot')
    "CmdletsToExport" 		= @()
    "VariablesToExport" 	= ''
    "AliasesToExport" 		= @()
    "PowerShellVersion"     = '5.1'
    "Tags"                  = @('PSEdition_Desktop', 'Windows')
    "ProjectUri"            = 'https://github.com/Diagg/EndPoint-CloudKit'
    "LicenseUri"            = 'https://raw.githubusercontent.com/Diagg/EndPoint-CloudKit/main/LICENSE'
    "Description"           = @'
Endpoint Cloud kit Module (ECK), a set of cmdlet to help building scripts or application deployed by your MDM (Intune/Workspace One...)

- Run Powershell script or executable in User/system/admin/tusted installer/System Interactive context
- Restart your script after reboot
- Logging function
- Configurable reboot toast notifications
- Execution context (Admin/system/user/TI) detection
- Pending reboot detection
- Windows Build converter to friendly name (like 21H2)
- Download from Git/Github on public/private repo
- Auto update ECK module

'@
    "ReleaseNotes"          = @'
0.0.1   2022/02/18 * Initial beta release to PS Gallery
0.0.2   2022/02/21 * beta release - Removed all $script: scoped variables
0.0.3   2022/02/21 * beta release - Invoke-ECKScheduledTask was missing
0.0.4   2022/02/22 * beta release - Reworked Write-ECKlog
0.0.5   2022/02/23 * beta release - First stable version
0.0.6   2022/03/02 * Beta version - Fixed a bug in Write-ECKlog
0.0.7.0 2022/03/08 * Beta version - Fixed a bug in Invoke-ECKScheduledTask
0.0.8.0 2022/03/10 * Beta version - Removed parameter 'interactive' in Invoke-ECKScheduledTask.
0.0.9.0 2022/03/30 * Beta version - Added back 'interactive' parameter in Invoke-ECKScheduledTask with support ServiceUI.exe
0.0.10.0 2022/04/04 * Beta version - Added function Set-ECKEnvironment to Gather local informations In a script scoped objet variable
0.0.11.0 2022/04/12 * Beta version - Invoke-ECKScheduledTask can now monitor running scheduled task
0.0.11.1 2022/04/12 * Beta version - Fixed bugs in Set-ECKEnvironment
0.0.12.0 2022/04/12 * Beta version - Added Functions Get-ECKGithubContent, Initialize-ECKPrereq, Set-ECKPendingReboot
'@
}

# Creat Manifest
New-ModuleManifest @Params -Confirm:$false
Test-ModuleManifest -Path "$($Script:CurrentScriptPath)\Source\EndpointCloudkit.psd1" -Verbose

## Set Tls to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

## install providers
If (-not(Test-path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll")){Install-PackageProvider -Name 'nuget' -Force |Out-Null}
Write-Output "Nuget provider installed version: $(((Get-PackageProvider -Name 'nuget'|Sort-Object|Select-Object -First 1).version.tostring()))"

Import-Module PowershellGet
Write-OutPut "PowershellGet module installed version: $(((Get-Module PowerShellGet|Sort-Object|Select-Object -First 1).version.tostring()))"

##Install Nuget.Exe
$NugetPath = 'C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet'
If (-not (test-path $NugetPath)){New-item $NugetPath -ItemType Directory -Force -Confirm:$false}
If (-not (test-path "$NugetPath\Nuget.exe")){Invoke-WebRequest -Uri 'https://aka.ms/psget-nugetexe' -OutFile "$NugetPath\Nuget.exe"}

## Install PSScriptAnalyzer & Analyse
Install-Module -Name PSScriptAnalyzer
Get-ChildItem $Script:CurrentScriptPath -Filter '*.ps1' -Recurse | Invoke-ScriptAnalyzer -Fix

#Copy Module to release folder
$ReleasePath = "$($Script:CurrentScriptPath)\Release"
remove-item "$ReleasePath\EndpointCloudkit" -Force -Recurse -ErrorAction SilentlyContinue|Out-Null
Copy-Item "$($Script:CurrentScriptPath)\Source\" "$ReleasePath\" -Recurse -Force|Out-Null
Rename-Item "$ReleasePath\Source" -NewName "EndpointCloudkit"|Out-Null



## Test before Publishing module
Publish-Module -Path "$ReleasePath\EndpointCloudkit" -NuGetApiKey $apiKey -Verbose -whatIf
Publish-Module -Path "$ReleasePath\EndpointCloudkit" -NuGetApiKey $apiKey -Verbose