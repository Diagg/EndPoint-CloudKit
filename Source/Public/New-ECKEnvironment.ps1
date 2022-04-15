Function New-ECKEnvironment
    {
        # Version 1.0 - 04/04/2022 - Set Script name and logfile for in and outside the module
        # Version 1.1 - 08/04/2022 - Script and Log path are now logged
        # Version 1.2 - 12/04/2022 - bug fix
        # Version 1.3 - 14/04/2022 - Added pending reboot state to Full Gather evaluation

        Param (
                [string]$LogPath = "C:\Windows\Logs\ECK",
                [switch]$FullGather
            )

        Remove-Variable ECK -Scope global -ErrorAction SilentlyContinue -force
        $MyInvoc = $global:PSCommandPath
        If ([string]::IsNullOrWhiteSpace($MyInvoc)){$MyInvoc = "$($env:temp)\TempScript-$((new-guid).guid.split('-')[0]).ps1"}

        If (-not($LogPath.toUpper().EndsWith(".LOG"))){$LogPath = "$LogPath\$((split-path $MyInvoc -leaf).replace("ps1","log"))"}
        If (-not(Test-path $(split-path $LogPath))){New-Item -Path $(split-path $LogPath) -ItemType Directory -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}

        $Global:ECK = [PSCustomObject]@{
                ModVersion = $(((Get-Module endpointcloudkit|Sort-Object|Select-Object -last 1).version.tostring()))
                ScriptName = $(split-path $MyInvoc -leaf)
                ScriptPath = $(split-path $MyInvoc)
                ScriptFullName =  $MyInvoc
                LogName = $(split-path $LogPath -leaf)
                LogPath = $(split-path $LogPath)
                LogFullName = $LogPath
            }

        Write-ECKlog "Script Path is: $($ECK.ScriptFullName)"
        Write-ECKlog "Log Path is: $($ECK.LogFullName)"

        If ($FullGather.IsPresent)
            {
                Get-ECKExecutionContext
                $ECK|Add-Member -MemberType NoteProperty -Name 'OsBuild' -Value $((Get-ItemProperty 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild)
                $ECK|Add-Member -MemberType NoteProperty -Name 'OsFriendlyName' -Value $(Get-ECKOsFriendlyName)
                Get-ECKPendingReboot|Out-Null
            }
    }
