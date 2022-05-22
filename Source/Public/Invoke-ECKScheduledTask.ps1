Function Invoke-ECKScheduledTask
    {
        # Version 3.4 - 17/02/2022 - Tasks running imedialtly are deleted once launched
        # Version 3.5 - 08/03/2022 - Fixed a bug in task detection with argument 'Now', Removed parameter 'Interactive'
        # Version 3.6 - 21/03/2022 - Task can now run as trusted Installer
        # Version 3.7 - 30/03/2022 - Leverage ServiceUI.exe to run task interactivelly, added back parameter 'Interactive'
        # Version 3.8 - 05/04/2022 - ServiceUI is seeked in different location, thanks to Bertrand J.
        # Version 3.9 - 07/04/2022 - Added WaitFinised switch to allow tracking of the running task. also cast out return code.
        # Version 3.10 - 12/04/2022 - Added log warning if interactive commande contains spaces
        # Version 3.11 - 22/05/2022 - Fixed an issue where a task that should run now is executed twice        


        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [String]$HostScriptPath = $ECK.ScriptFullName,
            [Parameter(Mandatory = $true, ParameterSetName = 'Command')]
            [String]$command,
            [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
            [string]$ScriptPath,
            [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
            [ScriptBlock]$ScriptBlock,
            [Parameter(Mandatory = $true)]
            [String]$TaskName,
            [Parameter(ParameterSetName = 'Command')]
            [string]$Parameters,
            [object]$triggerObject,
            [ValidateSet("System","SYSTEM","system","User","USER","user","Admin","ADMIN","admin","TI","ti","Ti")]
            [String]$Context = "System",
            [String]$TaskNamePrefix = "ECK",
            [string]$Description = "Scheduled task created from Powershell by ECK Module",
            [switch]$now,
            [switch]$Interactive,
            [switch]$AtStartup, #Machine
            [switch]$AtLogon, #User
            [switch]$DontAutokilltask,
            [Switch]$WaitFinished, # wait for planed task to finish, and return exit code, works only with 'now' switch
            [Int]$WaitFinshedTimeout = 3600, # Default time out (in second) before stopping to wait after running task
            [int]$DefaultTaskExpiration = 120, # Default wait time before removing task after execution (expressed in second)
            [Switch]$NormalTaskName, #TaskName created without prefix and random GUID
            [Switch]$AllowUsersFullControl, #allow user to delete his own task
            [Switch]$ForceStandardPSConsole, #force use of Powershell.exe instead of Powershellw.exe
            [String]$AdminAccountName = 'SRVECK', #Temporary admin account used to run task as elevated user. (The account is created/managed by the function and does not need to exists already !)
            [String]$LogPath = $ECK.LogFullName
        )

        If ([string]::IsNullOrWhiteSpace($LogPath)){New-ECKEnvironment ; $LogPath = $ECK.LogFullName ; $HostScriptPath = $ECK.ScriptFullName}

        Try
            {
                #Created Scheduled Task
                $ToastGUID = ([guid]::NewGuid()).ToString().ToUpper()
                $Task_TimeToRun = (Get-Date).AddSeconds(5).ToString('s')
                $Task_TimeIsOut = (Get-date).AddSeconds(-120).ToString('s')
                $Task_Expiry = (Get-Date).AddSeconds($DefaultTaskExpiration).ToString('s')

                #Check interactive prereqs
                If ($Interactive.IsPresent)
                    {
                        Foreach ($SrvUItem in @("C:\Windows\System32\serviceUI.exe","$HostScriptPath\ServiceUI.exe")){If (Test-path $SrvUItem){$ServiceUIPath = $SrvUItem ; Break}}

                        If (-not ($ServiceUIPath))
                            {
                                Write-ECKLog "ServiceUI.exe is not found, Unable to work in interactive mode" -Type 3
                                Remove-Variable -Name "Interactive" -Force -Confirm:$false
                            }
                    }

                If ($Context.ToUpper() -eq "SYSTEM")
                    {$Task_Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -RunLevel Highest}
                ElseIf ($Context.ToUpper() -eq "TI")
                    {$Task_Principal = New-ScheduledTaskPrincipal -UserID "NT SERVICE\TrustedInstaller" -RunLevel Highest}
                elseif ($Context.ToUpper() -eq "ADMIN")
                    {
                        #Creat Admin Account
                        Add-Type -AssemblyName System.Web
                        $Newuserpassword = new-object System.Security.SecureString
                        foreach($char in $([System.Web.Security.Membership]::GeneratePassword(10,2)).ToCharArray()){$Newuserpassword.AppendChar($char)}

                        If (Get-LocalUser -Name $AdminAccountName -ErrorAction SilentlyContinue)
                            {Set-LocalUser -Name $AdminAccountName -Password $Newuserpassword}
                        Else
                            {New-LocalUser $AdminAccountName -Password $Newuserpassword -Description "Dev Account"|Out-Null}

                        $AdminAccountSID = (Get-LocalUser -Name $AdminAccountName).SID.value
                        Add-LocalGroupMember -SID 'S-1-5-32-544' -Member $AdminAccountName -ErrorAction SilentlyContinue

                        $Task_Principal = New-ScheduledTaskPrincipal -UserID $AdminAccountName -RunLevel Highest

                        #Update remaining task
                        $taskToUpdate = Get-ScheduledTask|Where-Object {$_.Principal.UserId -eq $AdminAccountName -or $_.Principal.UserId -eq $AdminAccountSID}
                        Foreach ($item in $taskToUpdate)
                            {
                                Write-ECKLog "Updating credentials for task $($item.taskname)"
                                Set-ScheduledTask -TaskName $item.taskname -Taskpath "\*" -User $AdminAccountName -Password $Newuserpassword -ErrorAction SilentlyContinue
                            }
                    }
                else
                    {$Task_Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited}


                If ($triggerObject)
                    {$Task_Trigger = $triggerObject}
                Elseif ($AtStartup.IsPresent)
                    {$Task_Trigger = New-ScheduledTaskTrigger -AtStartup ; $DontAutokilltask = $True}
                Elseif ($AtLogon.IsPresent)
                    {$Task_Trigger = New-ScheduledTaskTrigger -AtLogOn ; $DontAutokilltask = $True}
                Elseif ($Now.IsPresent)
                    {$Task_Trigger = New-ScheduledTaskTrigger -Once -At $Task_TimeIsOut} #task is set in the past to avoid double execution
                Else
                    {$Task_Trigger = New-ScheduledTaskTrigger -Once -At $Task_TimeToRun}

                If ($DontAutokilltask.IsPresent -or $WaitFinished.IsPresent)
                    {$Task_Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -StartWhenAvailable}
                Else
                    {
                        $Task_Trigger.EndBoundary = $Task_Expiry
                        $Task_Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 600) -AllowStartIfOnBatteries -StartWhenAvailable
                    }


                If ($command)
                    {
                        If([String]::IsNullOrWhiteSpace($Parameters))
                            {
                                If ($Interactive.IsPresent -and $Context.ToUpper() -eq "SYSTEM")
                                    {
                                        $Task_Action = New-ScheduledTaskAction -Execute $ServiceUIPath -Argument $( "-process:explorer.exe " + $command)
                                        If ($command.split(" ").count -gt 0){Write-ECKlog "[WARNING] the path to your Powershell script ($command) contains whitespace that ServiceUI does not support, your command won't run !" -Type 1}
                                    }
                                else
                                    {$Task_Action = New-ScheduledTaskAction -Execute $command}
                            }
                        Else
                            {
                                If ($Interactive.IsPresent -and $Context.ToUpper() -eq "SYSTEM")
                                    {$Task_Action = New-ScheduledTaskAction -Execute $ServiceUIPath -Argument $( "-process:explorer.exe " + $command + " " + $Parameters)}
                                else
                                    {$Task_Action = New-ScheduledTaskAction -Execute $command -Argument $Parameters}
                            }
                    }

                If ($ScriptBlock)
                    {
                        $ScriptGuid = new-guid
                        If ($Context.ToUpper() -eq "USER")
                            {
                                If ([string]::IsNullOrWhiteSpace($ECK.UserProfile)){Get-ECKExecutionContext}
                                $ScriptPath = "$($ECK.UserProfile)\AppData\Local\Temp\$ScriptGuid.ps1"
                            }
                        Else
                            {$ScriptPath = "$($ENV:TEMP)\$ScriptGuid.ps1"}
                        $ScriptBlock|Out-File -FilePath $ScriptPath -Encoding default -width 1000
                        Write-ECKLog "Script Block converted to file $ScriptPath"
                    }

                If ($ScriptPath)
                    {
                        If (($ScriptPath.Substring($ScriptPath.Length-4)).toUpper() -ne ".PS1"){Write-ECKLog "[Error] you must specify a powershell script, Aborting!!" ; Return}
                        If ((test-path "C:\Windows\System32\Windowspowershell\v1.0\powershellw.exe") -and (-not ($ForceStandardPSConsole)))
                            {$command = "C:\Windows\System32\Windowspowershell\v1.0\powershellw.exe"}
                        Else
                            {$command = "C:\Windows\System32\Windowspowershell\v1.0\powershell.exe"}

                        $Parameters = "-executionpolicy bypass -noprofile -WindowStyle Hidden -file ""$ScriptPath"""

                        If ($Interactive.IsPresent -and $Context.ToUpper() -eq "SYSTEM")
                            {
                                $Task_Action = New-ScheduledTaskAction -Execute "C:\Windows\system32\ServiceUI.exe" -Argument $( "-process:explorer.exe " + $command + " " + $Parameters)
                                If ($Parameters.split(" ").count -gt 0){Write-ECKlog "[WARNING] the path to your Powershell script ($Parameters) contains whitespace that ServiceUI does not support, your command won't run !" -Type 1}
                            }
                        else
                            {$Task_Action = New-ScheduledTaskAction -Execute $command -Argument $Parameters}
                    }


                $New_Task = New-ScheduledTask -Description $Description -Action $Task_Action -Principal $Task_Principal -Trigger $Task_Trigger -Settings $Task_Settings

                If ($NormalTaskName)
                    {$TaskFullName = $TaskName ; $PreviousTaskName = $TaskName}
                Else
                    {
                        $TaskName = $TaskName.Replace(" ","_")
                        $taskName = $TaskName + $(split-path $HostScriptPath -leaf).Replace("-","").replace(".ps1","").replace(" ","")
                        $TaskFullName = $($TaskNamePrefix + "_" + $TaskName + "_" + $ToastGuid)
                        $PreviousTaskName = $($TaskNamePrefix + "_" + $TaskName + "_" + "*-*-*-*-*")
                    }

                Write-ECKLog "Created Task name: $TaskFullName"
                Write-ECKLog "Command to run is: $command $Parameters"

                #Cleanup task with the same Name
                Get-ScheduledTask -TaskName $PreviousTaskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

                If ($Context.ToUpper() -eq "ADMIN")
                    {Register-ScheduledTask -TaskName $TaskFullName -InputObject $New_Task -User $Task_Principal.UserID -Password $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewuserPassword))) -ErrorAction SilentlyContinue|Out-Null}
                Else
                    {Register-ScheduledTask -TaskName $TaskFullName -InputObject $New_Task -ErrorAction SilentlyContinue|Out-Null}

                #Change Task ACL
                If($AllowUsersFullControl)
                    {
                        # David Segura to the rescue (Kind thanks)!!!
                        $Scheduler = New-Object -ComObject "Schedule.Service"
                        $Scheduler.Connect()
                        $GetTask = $Scheduler.GetFolder('\').GetTask($TaskFullname)
                        $GetSecurityDescriptor = $GetTask.GetSecurityDescriptor(0xF)
                        if ($GetSecurityDescriptor -notmatch 'A;;FA;;;AU')
                            {
                                $GetSecurityDescriptor = $GetSecurityDescriptor + '(A;;FA;;;AU)'
                                $GetTask.SetSecurityDescriptor($GetSecurityDescriptor, 0)
                            }
                    }


                If ($now)
                    {
                        Start-ScheduledTask -TaskName $TaskFullName|Out-Null

                        $Count = 0
                        While((Get-ScheduledTask $TaskFullName -ErrorAction SilentlyContinue).State -ne 'Running' -and $count -le 8){Start-Sleep -Seconds 1 ; $Count +=1 }
                        try
                            {
                                Get-ScheduledTask $TaskFullName -ErrorAction Stop|Out-Null
                                Write-ECKLog "Task $TaskFullName now launched in $context context !"

                                If ($WaitFinished.IsPresent)
                                    {
                                        While((Get-ScheduledTask $TaskFullName -ErrorAction SilentlyContinue).State -ne 'Ready' -and $count -le [int]($WaitFinshedTimeout/2))
                                            {
                                                Start-Sleep -Seconds 2 ; $Count +=1
                                                If  (($Count/60) -is [Int]){Write-ECKLog "Task $TaskFullName still running ! (Elapsed time $([math]::Round($Count/60,2)))"}
                                            }

                                        [int]$Runingtask = (Get-ScheduledTaskInfo -TaskName $TaskFullName).LastTaskResult
                                    }
                            }
                        Catch {Write-ECKLog "[ERROR] Unable to Launch Task $TaskFullName in $context context !" -Type 3}
                        If (-Not ($DontAutokilltask)) {Unregister-ScheduledTask -TaskName $TaskFullName -Confirm:$false -ErrorAction SilentlyContinue}

                    }
                Else
                    {Write-ECKLog "Task $TaskFullName scheduled sucessfully in $context context with a custom planed execution."}

                If ($Runingtask){$Runingtask} Else {Write-Output $TaskFullName}
            }
        Catch
            {
                Write-ECKLog   $_.Exception.Message.ToString() -Type 3
                Write-ECKLog   $_.InvocationInfo.PositionMessage.ToString() -Type 3
                Write-ECKLog "[Error], Unable to schedule task $taskName, Aborting !!!" -Type 3
                if ($Context.ToUpper() -eq "ADMIN"){Get-LocalUser $AdminAccountName -ErrorAction SilentlyContinue|Remove-LocalUser -Confirm:$false -ErrorAction SilentlyContinue}
                Write-Output "#ERROR"
            }
    }

