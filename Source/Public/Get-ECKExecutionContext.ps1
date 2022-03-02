Function Get-ECKExecutionContext
    {
        # Version 1.2 - 14/02/2022 - added back KeyRoot
        # Version 1.3 - 15/02/2020 - added a try/Catch

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
                            $CurrentUser = "#NotAvailable#"
                            $CurrentUserID = "#NotAvailable#"
                            $CurrentUserProfile = "#NotAvailable#"
                        }
                    else
                        {
                            $CurrentUserID = (New-Object System.Security.Principal.NTAccount($CurrentUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
                            $CurrentUserProfile = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'|Where-Object {$PSItem.pschildname -eq $CurrentUserID}|Get-ItemPropertyValue -Name PRofileImagePath
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

        if (-NOT ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544')) {$IsAdmin = $False} else {$IsAdmin = $True}
        If ($LogPath){Write-ECKLog "User $CurrentUser is Admin: $IsAdmin" -Path $LogPath}

        If ($env:USERPROFILE -eq "C:\Windows\System32\Config\systemprofile") {$RunAsSystem = $True} else {$RunAsSystem = $False}
        If ($LogPath){Write-ECKLog "Currently running in System context: $RunAsSystem" -Path $LogPath}

        IF ($IsAdmin -eq $true -or $RunAsSystem -eq $true) {$KeyRoot = "HKLM:"} Else {$KeyRoot = "HKCU:"}
        If ($LogPath){Write-ECKLog "Allowed Registry key : $KeyRoot" -Path $LogPath}

        [PSCustomObject]@{ User = $CurrentUser ; UserID = $CurrentUserID ; UserProfile = $CurrentUserProfile ; UserIsAdmin = $IsAdmin ; RunAsSystem = $RunAsSystem ; KeyRoot = $KeyRoot }
    }
