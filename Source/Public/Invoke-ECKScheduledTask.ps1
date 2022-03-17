Function Invoke-ECKScheduledTask
    {
        # Version 3.4 - 17/02/2022 - Tasks run imedialtly are deleted once launched
        # Version 3.5 - 08/03/2022 - Fixed a bug in task detection with argument 'Now', Removed parameter 'Interactive'

        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position=0)]
            [String]$HostScriptPath,
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
            [ValidateSet("System","SYSTEM","system","User","USER","user","Admin","ADMIN","admin")]
            [String]$Context = "System",
            [String]$TaskNamePrefix = "ECK",
            [string]$Description = "Scheduled task created from Powershell",
            [switch]$now,
            [switch]$AtStartup, #Machine
            [switch]$AtLogon, #User
            [switch]$DontAutokilltask,
            [int]$DefaultTaskExpiration = 120,
            [Switch]$NormalTaskName, #TaskName created without prefix and random GUID
            [Switch]$AllowUsersFullControl, #allow user to delete his own task
            [Switch]$ForceStandardPSConsole, #force use of Powershell.exe instead of Powershellw.exe
            [String]$AdminAccountName = 'SRVECK', #Temporary admin account used to run task as elevated user. (The account is created/managed by the function and does not need to exists already !)
            [String]$LogPath
        )

        Try
            {
                #Created Scheduled Task
                $ToastGUID = ([guid]::NewGuid()).ToString().ToUpper()
                $Task_TimeToRun = (Get-Date).AddSeconds(5).ToString('s')
                $Task_Expiry = (Get-Date).AddSeconds($DefaultTaskExpiration).ToString('s')

                If ($Context.ToUpper() -eq "SYSTEM")
                    {$Task_Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -RunLevel Highest}
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
                                If ($LogPath) {Write-ECKLog "Updating credentials for task $($item.taskname)" -Path $LogPath}
                                Set-ScheduledTask -TaskName $item.taskname -Taskpath "\*" -User $AdminAccountName -Password $Newuserpassword -ErrorAction SilentlyContinue
                            }
                    }
                else
                    {$Task_Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited}


                If ($triggerObject)
                    {$Task_Trigger = $triggerObject}
                elseif ($AtStartup)
                    {$Task_Trigger = New-ScheduledTaskTrigger -AtStartup ; $DontAutokilltask = $True}
                elseif ($AtLogon)
                    {$Task_Trigger = New-ScheduledTaskTrigger -AtLogOn ; $DontAutokilltask = $True}
                Else
                    {$Task_Trigger = New-ScheduledTaskTrigger -Once -At $Task_TimeToRun}

                If ($DontAutokilltask)
                    {$Task_Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -StartWhenAvailable}
                Else
                    {
                        $Task_Trigger.EndBoundary = $Task_Expiry
                        $Task_Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 600) -AllowStartIfOnBatteries -StartWhenAvailable
                    }


                If ($command)
                    {
                        If([String]::IsNullOrWhiteSpace($Parameters))
                            {$Task_Action = New-ScheduledTaskAction -Execute $command}
                        Else
                            {$Task_Action = New-ScheduledTaskAction -Execute $command -Argument $Parameters}
                    }

                If ($ScriptBlock)
                    {
                        $ScriptGuid = new-guid
                        If ($Context.ToUpper() -eq "USER")
                            {
                                $ExecContext = Get-ECKExecutionContext
                                $ScriptPath = "$($ExecContext.UserProfile)\AppData\Local\Temp\$ScriptGuid.ps1"
                            }
                        Else
                            {$ScriptPath = "$($ENV:TEMP)\$ScriptGuid.ps1"}
                        $ScriptBlock|Out-File -FilePath $ScriptPath -Encoding default
                        If ($LogPath) {Write-ECKLog "Script Block converted to file $ScriptPath" -Path $LogPath}
                    }

                If ($ScriptPath)
                    {
                        If (($ScriptPath.Substring($ScriptPath.Length-4)).toUpper() -ne ".PS1"){If ($LogPath) {Write-ECKLog "[Error] you must specify a powershell script, Aborting!!" -Path $LogPath}; Return}
                        If ((test-path "C:\Windows\System32\Windowspowershell\v1.0\powershellw.exe") -and (-not ($ForceStandardPSConsole)))
                            {$command = "C:\Windows\System32\Windowspowershell\v1.0\powershellw.exe"}
                        Else
                            {$command = "C:\Windows\System32\Windowspowershell\v1.0\powershell.exe"}

                        $Parameters = "-executionpolicy bypass -noprofile -WindowStyle Hidden -file ""$ScriptPath"""
                        $Task_Action = New-ScheduledTaskAction -Execute $command -Argument $Parameters
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

                If ($LogPath) {Write-ECKLog "Created Task name: $TaskFullName" -Path $LogPath}
                If ($LogPath) {Write-ECKLog "Command to run is: $command $Parameters" -Path $LogPath}

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
                        Start-ScheduledTask -TaskName $TaskFullName

                        $Count = 0
                        While((Get-ScheduledTask $TaskFullName -ErrorAction SilentlyContinue).State -ne 'Running' -and $count -le 8){Start-Sleep -Seconds 1 ; $Count +=1 }
                        try
                            {
                                Get-ScheduledTask $TaskFullName -ErrorAction Stop
                                If ($LogPath) {Write-ECKLog "Task $TaskFullName now launched in $context context !" -Path $LogPath}
                            }
                        Catch {If ($LogPath) {Write-ECKLog "[ERROR] Unable to Launch Task $TaskFullName in $context context !" -Path $LogPath -Type 3}}
                        If (-Not ($DontAutokilltask)) {Unregister-ScheduledTask -TaskName $TaskFullName -Confirm:$false -ErrorAction SilentlyContinue}

                    }
                Else
                    {If ($LogPath) {Write-ECKLog "Task $TaskFullName scheduled sucessfully in $context context with a custom planed execution." -Path $LogPath}}

                Write-Output $TaskFullName
            }
        Catch
            {
                If ($LogPath) {Write-ECKLog   $_.Exception.Message.ToString() -Type 3 -Path $LogPath}
                If ($LogPath) {Write-ECKLog   $_.InvocationInfo.PositionMessage.ToString() -Type 3 -Path $LogPath}
                If ($LogPath) {Write-ECKLog "[Error], Unable to schedule task $taskName, Aborting !!!" -Type 3 -Path $LogPath}
                if ($Context.ToUpper() -eq "ADMIN"){Get-LocalUser $AdminAccountName -ErrorAction SilentlyContinue|Remove-LocalUser -Confirm:$false -ErrorAction SilentlyContinue}
                Write-Output "#ERROR"
            }
    }

