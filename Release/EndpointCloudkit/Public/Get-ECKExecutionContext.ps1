Function Get-ECKExecutionContext
    {
        # Version 1.2 - 14/02/2022 - added back KeyRoot
        # Version 1.3 - 15/02/2020 - added a try/Catch
        # Version 1.4 - 21/03/2020 - added new detection methode, retrive user UPN, detect Trusted installer context

        [CmdletBinding()]
        [Alias('Get-ExecutionContext')]

        Param
            (
                [Parameter(Mandatory = $false)]
                [String]$LogPath
            )

            Try
                {
                    Do
                        {
                            # Get current logged on user. In some cases, WMI is not ready at first call, so we added some retries
                            $CurrentUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue|Select-Object -ExpandProperty UserName)
                            If ($null -eq $CurrentUser) {Start-Sleep -Seconds 5 ; $Counter +=1}
                        }
                    Until ($null -ne $CurrentUser -or $Counter -eq 5)

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
                            If($null -eq $CurrentUserID){$CurrentUserProfile = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'|Where-Object {$PSItem.pschildname -eq $CurrentUserID}|Get-ItemPropertyValue -Name PRofileImagePath}

                            $UPNKeys = $(reg query hklm\SOFTWARE\Microsoft\IdentityStore\LogonCache /reg:64).Split([Environment]::NewLine)| Where-Object{$_ -ne ""}
                            ForEach ($item in $UPNKeys)
                                {
                                    $UPN = reg @('query',"$item\Sid2Name\$CurrentUserID",'/v','IdentityName','/reg:64')
                                    If ($LASTEXITCODE -eq 0){$CurrentUserUPN = ($UPN[2] -split ' {2,}')[3] ; Break} Else {$CurrentUserUPN = "#NotAvailable#"}
                                }
                        }
                }
            Catch
                {
                    $CurrentUser = "#NotAvailable#"
                    $CurrentUserID = "#NotAvailable#"
                    $CurrentUserProfile = "#NotAvailable#"
                }

        If ($LogPath ){Write-ECKLog "Logged on user is: $CurrentUser" -Path $LogPath}
        If ($LogPath ){Write-ECKLog "User profile is: $CurrentUserProfile" -Path $LogPath}
        If ($LogPath ){Write-ECKLog "User UPN is: $CurrentUserUPN" -Path $LogPath}

        if (-NOT ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544')) {$IsAdmin = $False} else {$IsAdmin = $True}
        If ($LogPath){Write-ECKLog "User $CurrentUser is Admin: $IsAdmin" -Path $LogPath}

        If ($env:USERPROFILE -eq "C:\Windows\System32\Config\systemprofile") {$RunAsSystem = $True} else {$RunAsSystem = $False}
        If ($LogPath){Write-ECKLog "Currently running in System context: $RunAsSystem" -Path $LogPath}

        If (([System.Security.Principal.WindowsIdentity]::GetCurrent().groups.value -contains "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464") -eq $true){$RunAsTI = $True} else {$RunAsTI = $False}
        If ($LogPath){Write-ECKLog "Currently running in Trusted Installer context: $RunAsTI" -Path $LogPath}

        IF ($IsAdmin -eq $true -or $RunAsSystem -eq $true) {$KeyRoot = "HKLM:"} Else {$KeyRoot = "HKCU:"}
        If ($LogPath){Write-ECKLog "Allowed Registry key : $KeyRoot" -Path $LogPath}

        [PSCustomObject]@{ User = $CurrentUser ; UserID = $CurrentUserID ; UserUPN = $CurrentUserUPN ; UserProfile = $CurrentUserProfile ; UserIsAdmin = $IsAdmin ; RunAsSystem = $RunAsSystem ; RunAsTrustedInstaller = $RunAsTI ; KeyRoot = $KeyRoot }
    }
