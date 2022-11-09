Function Get-ECKExecutionContext
    {
        # Version 1.2 - 14/02/2022 - added back KeyRoot
        # Version 1.3 - 15/02/2020 - added a try/Catch
        # Version 1.4 - 21/03/2020 - added new detection methode, retrive user UPN, detect Trusted installer context
        # Version 1.5 - 01/04/2020 - added Current logged on user registry key, Fixed bugs
        # Version 1.6 - 04/04/2022 - Added support For New-ECKEnvironment.
        # Version 1.7 - 26/04/2022 - Log file is no more managed by this function
        # Version 1.8 - 09/11/2022 - replacing reg.exe to query x64 registry with .Net method (reg.exe excution can be blocked by security policies)        

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

                        $HKLM64Key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
                        $UPNKeys =  $HKLM64Key.OpenSubKey("SOFTWARE\Microsoft\IdentityStore\LogonCache").getsubkeynames()                       

                        ForEach ($item in $UPNKeys)
                            {
                                $UPN = $HKLM64Key.OpenSubKey("SOFTWARE\Microsoft\IdentityStore\LogonCache\$item\Sid2Name\$CurrentUserID").getvalue("IdentityName")
                                If (-not ([String]::IsNullOrWhiteSpace($UPN))){$CurrentUserUPN = $UPN ; Break} Else {$CurrentUserUPN = "#NotAvailable#"}
                            }


                        ##== Mount HKU reg Key in PSdrive
                        If([string]::IsNullOrWhiteSpace($(Get-PSDrive -Name HKU -ErrorAction SilentlyContinue))){New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -Scope global| out-null}
                        $CurrentUserReg = "HKU:\$CurrentUserID"
                    }
            }
        Catch
            {
                if ([sting]::IsNullOrWhiteSpace($CurrentUser)){$CurrentUser = "#NotAvailable#"}
                if ([sting]::IsNullOrWhiteSpace($CurrentUserID)){$CurrentUserID = "#NotAvailable#"}
                if ([sting]::IsNullOrWhiteSpace($CurrentUserProfile)){$CurrentUserProfile = "#NotAvailable#"}
                if ([sting]::IsNullOrWhiteSpace($CurrentUserUPN)){$CurrentUserUPN = "#NotAvailable#"}
                if ([sting]::IsNullOrWhiteSpace($CurrentUserReg)){$CurrentUserReg = "#NotAvailable#"}
            }

        Write-ECKLog "Logged on user is: $CurrentUser"
        $ECK|Add-Member -MemberType NoteProperty -Name 'User' -Value $CurrentUser -Force
        Write-ECKLog "user SID is: $CurrentUserID"
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserID' -Value $CurrentUserID -Force
        Write-ECKLog "User profile is: $CurrentUserProfile"
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserProfile' -Value $CurrentUserProfile -Force
        Write-ECKLog "User UPN is: $CurrentUserUPN"
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserUPN' -Value $CurrentUserUPN -Force
        Write-ECKLog "User Registry Profile is: $CurrentUserReg"
        $ECK|Add-Member -MemberType NoteProperty -Name 'CurrentUserRegistry' -Value $CurrentUserReg -Force

        if (-NOT ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544')) {$IsAdmin = $False} else {$IsAdmin = $True}
        Write-ECKLog "User $CurrentUser is Admin: $IsAdmin"
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserIsAdmin' -Value $IsAdmin -Force

        If ($env:USERPROFILE -eq "C:\Windows\System32\Config\systemprofile") {$RunAsSystem = $True} else {$RunAsSystem = $False}
        Write-ECKLog "Currently running in System context: $RunAsSystem"
        $ECK|Add-Member -MemberType NoteProperty -Name 'UserIsSystem' -Value $RunAsSystem -Force

        If (([System.Security.Principal.WindowsIdentity]::GetCurrent().groups.value -contains "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464") -eq $true){$RunAsTI = $True} else {$RunAsTI = $False}
        Write-ECKLog "Currently running in Trusted Installer context: $RunAsTI"
        $ECK|Add-Member -MemberType NoteProperty -Name 'RunAsTrustedInstaller' -Value $RunAsTI -Force

        IF ($IsAdmin -eq $true -or $RunAsSystem -eq $true) {$KeyRoot = "HKLM:"} Else {$KeyRoot = "HKCU:"}
        Write-ECKLog "Allowed Registry key : $KeyRoot"
        $ECK|Add-Member -MemberType NoteProperty -Name 'KeyRoot' -Value $KeyRoot -Force
    }