Function Set-ECKPendingReboot
    {
        # Version 1.0 - 13/04/2022 - Initial release, set a registry key to notice that a reboot is requierd, and set a runonce key to remove it after reboot

        ##== Create Pending Reboot Key
        If (-not(test-path "HKLM:\SOFTWARE\ECK\PendingReboot")){New-item -Path "HKLM:\SOFTWARE\ECK\PendingReboot" -Force|Out-Null}
        New-ItemProperty -Path "HKLM:\SOFTWARE\ECK\PendingReboot" -Name "RebootRequired" -Value 1 -Force|Out-Null

        ##== Create Delete mecanism after reboot occurs.
        If (-not(test-path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce")){New-item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Force|Out-Null}
        New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "Run" -Value "reg.exe delete HKLM:\SOFTWARE\ECK\PendingReboot /v ""RebootRequired"" /f" -Force|Out-Null

        ##== Set $ECK 
        If ([string]::IsNullOrWhiteSpace($ECK.PendingReboot))
            {$ECK|Add-Member -MemberType NoteProperty -Name 'PendingReboot' -Value $true}
        else 
            {$ECK.PendingReboot = $true}
    }