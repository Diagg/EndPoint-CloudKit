Function Get-ECKExecutionContext
    {
        # Version 1.2 - 14/02/2022 - added back KeyRoot
        # Version 1.3 - 15/02/2020 - added a try/Catch
        # Version 1.4 - 21/03/2020 - added new detection methode, retrive user UPN, detect Trusted installer context
        # Version 1.5 - 01/04/2020 - added Current logged on user registry key, Fixed bugs
        # Version 1.6 - 04/04/2022 - Added support For Set-ECKEnvironment.

        [CmdletBinding()]
        [Alias('Get-ExecutionContext')]

        Param
            (
                [Parameter(Mandatory = $false)]
                [String]$LogPath = $ECK.LogFullName
            )

        If ([string]::IsNullOrWhiteSpace($LogPath)){Set-ECKEnvironment ; $LogPath = $ECK.LogFullName}

        Try
            {
                # Get current logged on user. In some cases, WMI is not ready at first call, so we added some retries
                $CurrentUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue|Select-Object -ExpandProperty UserName)

                If ($null -eq $CurrentUser) {$CurrentUser = ((((query user) -replace '\s{20,39}', ',,') -replace '\s{2,}', ',') -replace '>','' | ConvertFrom-Csv).UserName}

                If ($null -eq $CurrentUser)
                    {
                        $CurrentUserInfo = Get-Itemproperty "Registry::\HKEY_USERS\*\Volatile Environment"
                        If (![String]::IsNullOrWhiteSpace($CurrentUserInfo))
                            {
                                $CurrentUser = "$($CurrentUserInfo.USERDOMAIN)\$($CurrentUserInfo.USERNAME)"
                                $CurrentUserID = split-path $CurrentUserInfo.PSParentPath -leaf
                                $CurrentUserProfile = $CurrentUserInfo.USERPROFILE
                            }
                    }

                If ($null -eq $CurrentUser)
                    {
                        $CurrentUser = "#NotAvailable#"
                        $CurrentUserID = "#NotAvailable#"
                        $CurrentUserProfile = "#NotAvailable#"
                    }
                else
                    {
                        If($null -eq $CurrentUserID){$CurrentUserID = (New-Object System.Security.Principal.NTAccount($CurrentUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value}
                        If($null -eq $CurrentUserProfile){$CurrentUserProfile = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'|Where-Object {$PSItem.pschildname -eq $CurrentUserID}|Get-ItemPropertyValue -Name PRofileImagePath}

                        $ErrSetting = $ErrorActionPreference
                        $ErrorActionPreference = 'SilentlyContinue'
                        $UPNKeys = $(reg query hklm\SOFTWARE\Microsoft\IdentityStore\LogonCache /reg:64).Split([Environment]::NewLine)| Where-Object{$_ -ne ""}
                        ForEach ($item in $UPNKeys)
                            {
                                $UPN = reg @('query',"$item\Sid2Name\$CurrentUserID",'/v','IdentityName','/reg:64')
                                If ($LASTEXITCODE -eq 0){$CurrentUserUPN = ($UPN[2] -split ' {2,}')[3] ; Break} Else {$CurrentUserUPN = "#NotAvailable#"}
                            }
                        $ErrorActionPreference = $ErrSetting

                        ##== Mount HKU reg Key in PSdrive
                        If([string]::IsNullOrWhiteSpace($(Get-PSDrive -Name HKU -ErrorAction SilentlyContinue))){New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -Scope global| out-null}
                        $CurrentUserReg = "HKU:\$CurrentUserID"
                    }
            }
        Catch
            {
                $CurrentUser = "#NotAvailable#"
                $CurrentUserID = "#NotAvailable#"
                $CurrentUserProfile = "#NotAvailable#"
                $CurrentUserUPN = "#NotAvailable#"
                $CurrentUserReg = "#NotAvailable#"
            }

        Write-ECKLog "Logged on user is: $CurrentUser" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'User' -Value $CurrentUser
        Write-ECKLog "user SID is: $CurrentUserID" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserID' -Value $CurrentUserID
        Write-ECKLog "User profile is: $CurrentUserProfile" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserProfile' -Value $CurrentUserProfile
        Write-ECKLog "User UPN is: $CurrentUserUPN" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserUPN' -Value $CurrentUserUPN
        Write-ECKLog "User Registry Profile is: $CurrentUserReg" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'CurrentUserRegistry' -Value $CurrentUserReg

        if (-NOT ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544')) {$IsAdmin = $False} else {$IsAdmin = $True}
        Write-ECKLog "User $CurrentUser is Admin: $IsAdmin" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserIsAdmin' -Value $IsAdmin

        If ($env:USERPROFILE -eq "C:\Windows\System32\Config\systemprofile") {$RunAsSystem = $True} else {$RunAsSystem = $False}
        Write-ECKLog "Currently running in System context: $RunAsSystem" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserIsSystem' -Value $RunAsSystem

        If (([System.Security.Principal.WindowsIdentity]::GetCurrent().groups.value -contains "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464") -eq $true){$RunAsTI = $True} else {$RunAsTI = $False}
        Write-ECKLog "Currently running in Trusted Installer context: $RunAsTI" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'RunAsTrustedInstaller' -Value $RunAsTI

        IF ($IsAdmin -eq $true -or $RunAsSystem -eq $true) {$KeyRoot = "HKLM:"} Else {$KeyRoot = "HKCU:"}
        Write-ECKLog "Allowed Registry key : $KeyRoot" -Path $LogPath
        $ECK|Add-Member -MemberType NoteProperty -Name 'KeyRoot' -Value $KeyRoot
    }