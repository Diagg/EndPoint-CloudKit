Function Invoke-ECKContinueOnNextReboot
    {
        #version 2.0
        Param
            (
                [Parameter(Mandatory = $true, Position=0)]
                [String]$HostScriptPath,
                [Parameter(Mandatory = $false)]
                [Switch]$ForceReboot,
                [Parameter(Mandatory = $false)]
                [Switch]$NoRebootPrompt,
                [Parameter(Mandatory = $false)]
                [String]$RebootMessage = "An application needs to restart.`r`n`r`nPlease, reboot to complete the installation !",
                [Parameter(Mandatory = $false)]
                [String]$RebootLogo = "",
                [Parameter(Mandatory = $false)]
                [String]$RebootImage = "",
                [Parameter(Mandatory = $false)]
                [String]$RegKeyCounter = "HKLM:\SOFTWARE\ECK\RebootCounter",
                [Parameter(Mandatory = $false)]
                [String]$LogPath,
                [Parameter(Mandatory = $false)]
                [String]$AdminAccountName

            )

        Write-ECKLog "Preparing Script $HostScriptPath to restart at next boot" -EventLogID 398
        If ($LogPath) {Write-ECKLog "Preparing Script $HostScriptPath to restart at next boot" -path $LogPath}

        $Context = Get-ECKExecutionContext
        $taskName = "ContinueOnReboot" + $(split-path $HostScriptPath -leaf).Replace("-","").replace(".ps1","").replace(" ","")

        If ($Context.UserIsAdmin -eq $false -and $Context.RunAsSystem -eq $false)
            {
                If ($Logpath){Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context User -AllowUsersFullControl -HostScriptPath $HostScriptPath -LogPath LogPath}
                Else {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context User -AllowUsersFullControl -HostScriptPath $HostScriptPath}
            }
        ElseIf ($Context.UserIsAdmin -eq $true -and $Context.RunAsSystem -eq $false)
            {
                If ($AdminAccountName)
                    {
                        If ($Logpath){Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context Admin -AdminAccountName $AdminAccountName -HostScriptPath $HostScriptPath -LogPath LogPath}
                        Else {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context Admin -AdminAccountName $AdminAccountName -HostScriptPath $HostScriptPath}
                    }
                Else
                    {
                        If ($Logpath){Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context Admin -HostScriptPath $HostScriptPath -LogPath LogPath}
                        Else {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context Admin -HostScriptPath $HostScriptPath}
                    }
            }
        ElseIf ($Context.RunAsSystem -eq $True)
            {
                If ($Logpath){Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context system -HostScriptPath $HostScriptPath -LogPath LogPath}
                Else {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $HostScriptPath -AtLogon -Context system -HostScriptPath $HostScriptPath}
            }

        # Set Reboot Counter
        If (-not (test-path $RegKeyCounter)){New-item -Path $RegKeyCounter -Force|Out-Null}
        If(Get-ItemProperty $RegKeyCounter -Name "RebootCount" -ErrorAction SilentlyContinue){[Int]$RebootCount = Get-ItemPropertyValue $RegKeyCounter -Name "RebootCount"} Else {$RebootCount = 0}
        $RebootCount += 1
        Set-ItemProperty $RegKeyCounter -Name "RebootCount" -Value $RebootCount -Force|Out-Null
        Set-ItemProperty $RegKeyCounter -Name "RebootDate" -Value "$(Get-date -Format d) - $(Get-date -Format T)" -Force|Out-Null

        If($ForceReboot)
            {
                If ($LogPath) {Write-ECKLog "Restarting computer Right Now!" -path $LogPath}
                Write-ECKLog "Restarting computer Right Now!" -EventLogID 399
                Restart-Computer -Confirm:$false -Force
            }
        ElseIf($NoRebootPrompt)
            {If ($LogPath) {Write-ECKLog "No Restart initated, user will reboot at his own pace" -path $LogPath}}
        Else
            {
                If ($LogPath) {Write-ECKLog "A toast notification will prompt user to set a restart" -path $LogPath}
                Invoke-ECKRebootToastNotification -SmallLogo $RebootLogo -Image $RebootImage -ToastMessage $RebootMessage -HostScriptPath $HostScriptPath
            }

        If ($LogPath) {Write-ECKLog "Exiting Program, see you on next boot !!!" -path $LogPath}
        Exit 0
    }