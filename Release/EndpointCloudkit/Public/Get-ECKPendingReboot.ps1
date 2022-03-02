Function Get-ECKPendingReboot
    {
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
            }

        ForEach ($Hash in $PendingTable.keys)
            {
                IF ($pendingTable[$Hash] -eq "")
                    {If ((Test-Path -Path $Hash) -eq $true){$PendingReboot = $true; Break}}
                Else
                    {
                        ForEach ($Item in $($pendingTable[$Hash]).Split(";"))
                            {
                                try {Get-ItemProperty -Path $Hash -name $item -ErrorAction Stop | Out-Null; $PendingReboot = $true ; Break}
                                catch {$PendingReboot = $false}
                                If ($SKipFileRename -and $item -like "*PendingFileRenameOperations*" -and $PendingReboot -eq $true){$PendingReboot = $false}
                            }
                    }
            }

        Return $PendingReboot
    }