Function Set-ECKEnvironment
    {
        # Version 1.0 - 04/04/2022 - Set Script name and logfile for in and outside the module
        
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
                ScriptName = $(split-path $MyInvoc -leaf)
                ScriptPath = $(split-path $MyInvoc) 
                ScriptFullName =  $MyInvoc
                LogName = $(split-path $LogPath -leaf)
                LogPath = $(split-path $LogPath)
                LogFullName = $LogPath
            }

        If ($FullGather.IsPresent)
            {
                Get-ECKExecutionContext
                $ECK|Add-Member -MemberType NoteProperty -Name 'OsBuild' -Value $((Get-ItemProperty 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild)
                $ECK|Add-Member -MemberType NoteProperty -Name 'OsFriendlyName' -Value $(Get-ECKOsFriendlyName)
            }
    }
