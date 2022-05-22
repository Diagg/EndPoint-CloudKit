Function Invoke-ECKContinueOnNextReboot
    {
        # version 2.0
        # version 3.0 - 26/04/2022 - big code refactoring/cleanup, a lot of legacy code and prameters removed
        # version 4.0 - 21/05/2022 - Now use $ECK variable
        Param
            (
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
                [String]$RegKeyCounter = "HKLM:\SOFTWARE\OSDC\ECK\RebootCounter"
            )

        Write-ECKLog "Preparing Script $($ECK.ScriptName) to restart at next boot" -EventLogID 398

        $taskName = "ContinueOnReboot"

        If ($ECK.UserIsAdmin -eq $false -and $ECK.UserIsSystem -eq $false)
            {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $ECK.ScriptFullName -AtLogon -Context User -AllowUsersFullControl}
        ElseIf ($ECK.UserIsAdmin -eq $true -and $Context.UserIsSystem -eq $false)
            {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $ECK.ScriptFullName -AtLogon -Context Admin}
        ElseIf ($Context.UserIsSystem -eq $True)
            {Invoke-ECKScheduledTask -TaskName $taskName -ScriptPath $ECK.ScriptFullName -AtLogon -Context system}

        # Set Reboot Counter
        If (-not (test-path $RegKeyCounter)){New-item -Path $RegKeyCounter -Force|Out-Null}
        If(Get-ItemProperty $RegKeyCounter -Name "RebootCount" -ErrorAction SilentlyContinue){[Int]$RebootCount = Get-ItemPropertyValue $RegKeyCounter -Name "RebootCount"} Else {$RebootCount = 0}
        $RebootCount += 1
        Set-ItemProperty $RegKeyCounter -Name "RebootCount" -Value $RebootCount -Force|Out-Null
        Set-ItemProperty $RegKeyCounter -Name "RebootDate" -Value "$(Get-date -Format d) - $(Get-date -Format T)" -Force|Out-Null

        If($ForceReboot)
            {
                Write-ECKLog "Restarting computer Right Now!" -EventLogID 399
                Restart-Computer -Confirm:$false -Force
            }
        ElseIf($NoRebootPrompt)
            {Write-ECKLog "No Restart initated, user will reboot at his own pace"}
        Else
            {
                Write-ECKLog "A toast notification will prompt user to set a restart"
                Invoke-ECKRebootToastNotification -SmallLogo $RebootLogo -Image $RebootImage -ToastMessage $RebootMessage
            }

        Write-ECKLog "Exiting Program, see you on next boot !!!"
        Exit 0
    }