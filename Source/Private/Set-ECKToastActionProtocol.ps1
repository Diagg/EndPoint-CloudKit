Function Set-ECKToastActionProtocol
    {
        [CmdletBinding(SupportsShouldProcess)]
        Param
            (
                [Parameter(Mandatory = $True)]
                [String]$Action,
                [Parameter(Mandatory = $True)]
                [String]$PsFilePath
            )


        If (test-path $PsFilePath)
            {
                If ((Get-PSDrive).Name -notcontains "HKCR"){New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null}

                If (test-path "C:\Windows\System32\Windowspowershell\v1.0\powershellw.exe")
                    {$command = """C:\Windows\System32\Windowspowershell\v1.0\powershellw.exe"" -executionpolicy bypass -noprofile -WindowStyle Hidden -file ""$PsFilePath"""}
                Else
                    {$command = """C:\Windows\System32\Windowspowershell\v1.0\powershell.exe"" -executionpolicy bypass -noprofile -WindowStyle Hidden -file ""$PsFilePath"""}

                $Action = $Action.replace(" ","")
                $RegPath = "HKCR:\$Action\"
                New-Item -Path "$RegPath" -Force|Out-Null
                New-ItemProperty -Path "$RegPath" -Name "(Default)" -Value "URL:$Action Protocol" -PropertyType "String" -Force|Out-Null
                New-ItemProperty -Path "$RegPath" -Name "URL Protocol" -Value "" -PropertyType "String" -Force|Out-Null
                New-Item -Path "$RegPath\shell\open\command" -Force|Out-Null
                New-ItemProperty -Path "$RegPath\shell\open\command" -Name "(Default)" -Value $command -PropertyType "String" -Force|Out-Null
            }
    }