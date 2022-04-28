Function New-ECKEnvironment
    {
        # Version 1.0 - 04/04/2022 - Set Script name and logfile for in and outside the module
        # Version 1.1 - 08/04/2022 - Script and Log path are now logged
        # Version 1.2 - 12/04/2022 - bug fix
        # Version 1.3 - 14/04/2022 - Added pending reboot state to Full Gather evaluation
        # Version 1.5 - 22/04/2022 - Added Hostname, Ip Address, OS Architecture, OS version
        # Version 1.6 - 26/04/2022 - Detection is now done in full scope by default. FullGather parameter is removed

        Param ([string]$LogPath = "C:\Windows\Logs\ECK")

        Remove-Variable ECK -Scope global -ErrorAction SilentlyContinue -force
        $MyInvoc = $global:PSCommandPath
        If ([string]::IsNullOrWhiteSpace($MyInvoc)){$MyInvoc = "$($env:temp)\TempScript-$((new-guid).guid.split('-')[0]).ps1"}

        If (-not($LogPath.toUpper().EndsWith(".LOG"))){$LogPath = "$LogPath\$((split-path $MyInvoc -leaf).replace("ps1","log"))"}
        If (-not(Test-path $(split-path $LogPath))){New-Item -Path $(split-path $LogPath) -ItemType Directory -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}

        [Int]$BuildNumber = $((Get-ItemProperty 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild)
        IF ([int]($BuildNumber) -lt 22000){$OSVersion = 10 } Else {$OSVersion = 11 }

        $Global:ECK = [PSCustomObject]@{
                ModVersion = $(((Get-Module "endpointcloudkit*"|Sort-Object|Select-Object -last 1).version.tostring()))
                ScriptName = $(split-path $MyInvoc -leaf)
                ScriptPath = $(split-path $MyInvoc)
                ScriptFullName =  $MyInvoc
                LogName = $(split-path $LogPath -leaf)
                LogPath = $(split-path $LogPath)
                LogFullName = $LogPath
                SystemHostName = $([System.Environment]::MachineName)
                SystemIPAddress = $((Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp -AddressState Preferred).IPAddress)
                OSArchitectureIsX64 = $([System.Environment]::Is64BitOperatingSystem)
                OSVersion = $OSVersion
                OSBuild = $((Get-ItemProperty 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild)
            }

        Write-ECKlog "Script Path is: $($ECK.ScriptFullName)"
        Write-ECKlog "Log Path is: $($ECK.LogFullName)"

        Get-ECKExecutionContext
        $ECK|Add-Member -MemberType NoteProperty -Name 'OsFriendlyName' -Value $(Get-ECKOsFriendlyName)
        Get-ECKPendingReboot|Out-Null
    }
