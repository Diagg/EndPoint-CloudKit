Function Invoke-ECKRebootToastNotification
    {
        # Version 2.0 - 05/04/2022 - fixed a lot of bugs
        # Version 2.1 - 20/04/2022 - Start Time is now embedded in user script
        # Version 2.2 - 22/05/2022 - Time before reboot set to 0

        Param
            (
                [Parameter(Mandatory = $false)]
                [String]$HostScriptPath = $eck.ScriptFullName,
                [Parameter(Mandatory = $false)]
                [String]$SmallLogo, #Image Logo must be PNG and can be submitted as path or Base64
                [Parameter(Mandatory = $false)]
                [String]$Image, #Image Logo must be JPG and can be submitted as path or Base64
                [Parameter(Mandatory = $false)]
                [ValidateSet("top","TOP","Top","bottom","BOTTOM","Bottom")]
                [String]$ImagePosition = "top",
                [Parameter(Mandatory = $false)]
                [ValidateSet("default","DEFAULT","Default","reminder","REMINDER","Reminder")]
                [String]$ToastScenario = "reminder",
                [Parameter(Mandatory = $false)]
                [String]$ToastTitle = "Reboot requiered",
                [Parameter(Mandatory = $false)]
                [String]$ToastSubTitle,
                [Parameter(Mandatory = $false)]
                [String]$ToastMessage = "Important security updates will be installed after your device restart.`r`n`r`nPlease, reboot to complete the installation !",
                [Parameter(Mandatory = $false)]
                [String]$ToastMessage2 = "",
                [Parameter(Mandatory = $false)]
                [HashTable]$Buttons,
                [Parameter(Mandatory = $false)]
                [Int]$RepeatInterval = 30, #Default interval in minutes before user is prompted again
                [Parameter(Mandatory = $false)]
                [Int]$TimeLimit = 1440 # When this time limit is reached (in minutes), the user is forced to reboot
            )

        # Set Task names
        $TaskName = "RebootToast"
        $OldTaskName = "*_" + $TaskName + $(split-path $HostScriptPath -Leaf).Replace("-","").replace(".ps1","").replace(" ","") + "_*-*-*-*-*"


        # Set Action Folder
        $ActionFld = "C:\ProgramData\RebootToastUI"
        If (-not (test-path $ActionFld)){new-item -Path $ActionFld -ItemType Directory -Force|Out-Null}

        # Set Buttons
        If (-not $Buttons)
            {
                [HashTable]$Buttons = @{'Reboot Now' = @('rebootnow','protocol',"$ActionFld\Button1.ps1") ; "Snooze ($RepeatInterval Mins)" = @('dismiss','system','') ; 'Button3' = @('','','')}
                $script_Button1 = @"
                    Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue|Unregister-ScheduledTask -Confirm:`$false -ErrorAction SilentlyContinue
                    shutdown /g /t 0
"@
                $script_Button1|Out-File -FilePath "$ActionFld\Button1.ps1" -Encoding default -width 1000
            }


        # Register actions
        Foreach ($item in $Buttons.GetEnumerator()){If (($item.Value[0] -ne '') -and (($item.Value[0]).ToUpper() -ne 'DISMISS')){Set-ECKToasTActionProtocol -Action $item.Value[0] -PsFilePath $item.Value[2] }}

        # Convert Logo and Image
        If (-not ([string]::IsNullOrWhiteSpace($Image)))
            {
                $ImagePath = "$ActionFld\hero.jpg"
                If (([System.IO.Path]::GetExtension($Image)).toUpper() -eq ".JPG" -and (Test-path $Image))
                    {
                        Try{Copy-Item -Path $image -Destination $ImagePath -Force -Confirm:$false -ErrorAction SilentlyContinue}
                        Catch{$ImagePath = ""}
                    }
                Else
                    {
                        Try
                            {
                                $Content = [System.Convert]::FromBase64String($Image)
                                Set-Content -Path $ImagePath -Value $Content -Encoding Byte -Force -Confirm:$false
                            }
                        Catch
                            {$ImagePath = ""}
                    }
            }

        If (-not ([string]::IsNullOrWhiteSpace($SmallLogo)))
            {
                $LogoImagePath = "$ActionFld\logo.png"
                If (([System.IO.Path]::GetExtension($SmallLogo)).toUpper() -eq ".PNG" -and (Test-path $SmallLogo))
                    {
                        Try{Copy-Item -Path $SmallLogo -Destination $LogoImagePath -Force -Confirm:$false -ErrorAction SilentlyContinue}
                        Catch{$LogoImagePath = ""}
                    }
                Else
                    {
                        Try
                            {
                                $Content = [System.Convert]::FromBase64String($SmallLogo)
                                Set-Content -Path $LogoImagePath -Value $Content -Encoding Byte -Force -Confirm:$false
                            }
                        Catch
                            {$LogoImagePath = ""}
                    }
            }

        If($ImagePosition.ToUpper() -eq "TOP"){$ImagePos = "hero"} else {$ImagePos = "inline"}

        $Script_Variables = @"
        `$ToastTitle = "$ToastTitle"
        `$ToastSubTitle = "$ToastSubTitle"
        `$ToastMessage = "$ToastMessage"
        `$ToastMessage2 = "$ToastMessage2"
        `$ActionFld = "$ActionFld"
        `$LogoImagePath = "$LogoImagePath"
        `$ImagePath = "$ImagePath"
        `$ToastScenario = "$ToastScenario"
        `$RepeatInterval = $RepeatInterval
        `$TimeLimit = $TimeLimit
        `$OldTaskName = "$OldTaskName"
        `$TaskName = "$TaskName"
        `$Button3 = @('$($Buttons.GetEnumerator().Name[0])','$($Buttons[$Buttons.GetEnumerator().name[0]][0])','$($Buttons[$Buttons.GetEnumerator().name[0]][1])')
        `$Button2 = @('$($Buttons.GetEnumerator().Name[1])','$($Buttons[$Buttons.GetEnumerator().name[1]][0])','$($Buttons[$Buttons.GetEnumerator().name[1]][1])')
        `$Button1 = @('$($Buttons.GetEnumerator().Name[2])','$($Buttons[$Buttons.GetEnumerator().name[2]][0])','$($Buttons[$Buttons.GetEnumerator().name[2]][1])')
        [DateTime]`$StartTime = "$(Get-Date)"
"@

        $script_Notif = {

                # Check for required entries in registry when using Powershell as application for the toast
                $App = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
                $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
                if (-NOT(Test-Path -Path "$RegPath\$App")) {New-Item -Path "$RegPath\$App" -Force|Out-Null}
                New-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -Value 1 -PropertyType "DWORD" -Force|Out-Null

                # Checking  if reboot already occured
                $IsRebooted = (Get-ItemProperty "HKCU:\SOFTWARE\ECK\RebootToastNotification" -name 'IsRebooted'-ErrorAction SilentlyContinue).IsRebooted
                If (-not([String]::IsNullOrWhiteSpace($IsRebooted)) -and $IsRebooted.toUpper() -eq "TRUE")
                    {
                        Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue|Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
                        Remove-Item "HKCU:\SOFTWARE\ECK\RebootToastNotification" -Force -ErrorAction SilentlyContinue -Confirm:$false
                        Exit
                    }

                # Checking if time limit is exided
                If ($(Get-date) -ge $StartTime.addMinutes($TimeLimit))
                    {
                        Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue|Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
                        Remove-Item "HKCU:\SOFTWARE\ECK\RebootToastNotification" -Force -ErrorAction SilentlyContinue -Confirm:$false
                        shutdown /g /t 240
                        Exit
                    }


                $ToastMessage3 = "A Mandatory reboot is planned on $($StartTime.addMinutes($TimeLimit))"
                If ([String]::IsNullOrWhiteSpace($ToastMessage2)){$ToastMessage2 = $ToastMessage3} Else {$ToastMessage2 = "`r`n`r`n$ToastMessage2`r`n`r`n$ToastMessage3`r`n`r`n" }

                # Rebuild Buttons
                $SetButtons = $False
                $Buttons = "<actions>`r`n"
                If ($Button1[1] -ne ''){$Buttons = $Buttons + "<action arguments = '$($Button1[1]):' content = '$($Button1[0])' activationType='$($Button1[2])' />`r`n";$SetButtons = $True}
                If ($Button2[1] -ne ''){$Buttons = $Buttons + "<action arguments = '$($Button2[1]):' content = '$($Button2[0])' activationType='$($Button2[2])' />`r`n";$SetButtons = $True}
                If ($Button3[1] -ne ''){$Buttons = $Buttons + "<action arguments = '$($Button3[1]):' content = '$($Button3[0])' activationType='$($Button3[2])' />`r`n";$SetButtons = $True}
                If ($SetButtons -eq $True){$Buttons = $Buttons + "</actions>"}Else{$Buttons = ''}
                $Buttons = $Buttons.replace('dismiss:','dismiss')

                # Rebuild Images
                If (-not ([string]::IsNullOrWhiteSpace($ImagePath))){$Image = "<image placement='$ImagePos' src='$ImagePath'/>"} Else {$Image = ''}
                If (-not ([string]::IsNullOrWhiteSpace($LogoImagePath))){$LogoImage = "<image placement='appLogoOverride' hint-crop='circle' src='$LogoImagePath'/>"} Else {$LogoImage = ''}

                # Toast Notification (Visual)
                [String]$Toast = @"
                <toast scenario="$ToastScenario">
                    <visual>
                        <binding template="ToastGeneric">
                            <text>$ToastTitle</text>
                            <text>$ToastSubTitle</text>
                            $LogoImage
                            $Image
                            <group>
                                <subgroup>
                                    <text hint-style="body" hint-wrap="true" >$ToastMessage</text>
                                    <text hint-style="body" hint-wrap="true" >$ToastMessage2</text>
                                </subgroup>
                            </group>
                        </binding>
                    </visual>
                    $Buttons
                </toast>
"@

                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]|Out-Null
                [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]|Out-Null

                # Display Notificaton
                [XML]$Toast = $Toast
                $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
                $ToastXml.LoadXml($Toast.OuterXml)
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($App).Show($ToastXml)
            }

        $script_Notif = [ScriptBlock]::Create($Script_Variables.ToString() + $script_Notif.ToString())

        # Set Registry
        If($Null -eq $ECK.CurrentUserRegistry){Get-ECKExecutionContext}
        New-item -Path "$($ECK.CurrentUserRegistry)\SOFTWARE\ECK\RebootToastNotification" -Force|Out-Null
        New-ItemProperty -Path "$($ECK.CurrentUserRegistry)\SOFTWARE\ECK\RebootToastNotification" -Name "IsRebooted" -Value "FALSE" -Force|Out-Null
        If (-not(test-path "$($ECK.CurrentUserRegistry)\Software\Microsoft\Windows\CurrentVersion\RunOnce")){New-item -Path "$($ECK.CurrentUserRegistry)\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Force|Out-Null}
        New-ItemProperty -Path "$($ECK.CurrentUserRegistry)\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ToastReboot" -Value "cmd.exe /c reg.exe add HKCU\SOFTWARE\ECK\RebootToastNotification /v ""IsRebooted"" /d ""TRUE"" /f" -Force|Out-Null

        # Schedule Task
        Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue|Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        $trigger = New-ScheduledTaskTrigger -RepetitionInterval $(New-TimeSpan -Minutes $RepeatInterval) -At $((Get-Date).AddSeconds(5).ToString('s')) -Once
        Invoke-ECKScheduledTask -TaskName $TaskName -ScriptBlock $script_Notif -Context user -triggerObject $Trigger -DontAutokilltask -AllowUsersFullControl
    }