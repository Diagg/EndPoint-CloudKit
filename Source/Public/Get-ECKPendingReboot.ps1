﻿Function Get-ECKPendingReboot
    {
        # Version 1.1 - 13/04/2022 - Added support for Endpoint Cloud Kit own pending reboot
        # Version 1.2 - 13/04/2022 - Pending Reboot state is now included in $ECK environment variable
        # Version 1.3 - 23/05/2022 - Fixed a bug where parameter SkipfileRename was ignored !
        # Version 1.3.1 - 14/11/2022 - Fixed logging when registry value were empty !
        # Version 1.4 - 15/11/2022 - Fixed logic routine

        Param([switch]$SKipFileRename)

        [bool]$PendingReboot = $false
        $PendingTable = @{
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" = ""
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting" = ""
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" = ""
                "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts" = ""
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing" = "RebootInProgress;PackagesPending"
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" = "PendingFileRenameOperations;PendingFileRenameOperations2"
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" = "DVDRebootSignal"
                "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon" = "JoinDomain;AvoidSpnSet"
                "HKLM:\SOFTWARE\ECK\PendingReboot" = "RebootRequired"
            }

        ForEach ($Hash in $PendingTable.keys)
            {
                If ($PendingReboot -eq $True){Break}

                IF ($pendingTable[$Hash] -eq "")
                    {If ((Test-Path -Path $Hash) -eq $true){$PendingReboot = $true; Break}}
                Else
                    {
                        ForEach ($Item in $($pendingTable[$Hash]).Split(";"))
                            {
                                $pendingState = Get-ItemProperty -Path $Hash -name $item -ErrorAction SilentlyContinue
                                If ([string]::IsNullOrWhiteSpace($pendingState))
                                    {$PendingReboot = $false} 
                                ElseIf ($SKipFileRename -and $item -like "*PendingFileRenameOperations*")
                                    {$PendingReboot = $false}
                                Else
                                    {$PendingReboot = $true; Break}
                            }
                    }
            }

        ##== Set $ECK
        If ([string]::IsNullOrWhiteSpace($ECK.PendingReboot))
            {$ECK|Add-Member -MemberType NoteProperty -Name 'PendingReboot' -Value $PendingReboot}
        else
            {$ECK.PendingReboot = $PendingReboot}

        Write-ECKLog -Message "Pending reboot: $PendingReboot"
        Return $PendingReboot
    }