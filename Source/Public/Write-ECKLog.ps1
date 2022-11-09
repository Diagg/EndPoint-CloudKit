Function Write-ECKlog
    {
        # Version 1.3   - 14/02/2022 - replaced write-host by Write-output
        # Version 1.4.1 - 21/02/2022 - removed $Script scoped variable to work with Module
        # Version 1.5   - 22/02/2022 - reworked logic
        # Version 1.6   - 25/02/2022 - Bug fix: you could not write only event
        # Version 1.7   - 05/04/2022 - Added support for New-ECKEnvironment
        # Version 1.8   - 26/04/2022 - Bug fix: parameter EventLogOnly is now functional
        # Version 1.9   - 27/06/2022 - No more fatal error if unable to write to log file         

        [CmdletBinding()]
        [Alias('Write-Log')]
        Param(
                [parameter()]
                [String]$Path = $ECK.LogFullName,
                [parameter(Position=0, Mandatory=$true, HelpMessage="Please provide a message to log !")]
                [String]$Message,
                [parameter()]
                [String]$OutputToConsole = $true,
                [parameter()]
                [String]$EventLogID,
                [parameter()]
                [Switch]$EventLogOnly,
                [parameter(Mandatory=$False)]     #Severity  Type(1 - Information, 2- Warning, 3 - Error)
                [ValidateRange(1,3)]
                [Int]$Type = 1
            )

        If (-Not $path -and -not $EventLogOnly){New-ECKEnvironment ; $Path = $ECK.LogFullName}

        $oDate = $(Get-Date -Format "M-d-yyyy")
        $oHour = $(Get-Date -Format "HH:mm:ss")
        $MessageType = @{1 = "Information"; 2 = "Warning"; 3 = "Error"}
        $Tab = [char]9
        $Content = "$oDate $oHour, $($MessageType[$type]) $Tab $($Message -replace "`r`n", ", ")"

        # Write the line to the log file and to the console
        If (-not $EventLogOnly.IsPresent)
            {
                Try{$Content| Out-file -FilePath $Path -Encoding UTF8 -Append -width 1000 -ErrorAction SilentlyContinue}
                Catch{If ($OutputToConsole -eq $true){Write-host "[WARNING] Could not write to log file $Path"}}
            }
        
        If ($OutputToConsole -eq $true){Write-host $Content}

        # Write to Event log
        If ($EventLogID)
            {
                $AppriendlyName = $(Split-Path $Path -Leaf) -replace "-" ,"" -replace ".ps1","" -replace " ",""
                If ([System.Diagnostics.EventLog]::SourceExists($AppriendlyName) -eq $false){New-EventLog -LogName "Application" -Source $AppriendlyName}
                Write-EventLog -LogName "Application" -Source $AppriendlyName -EventID $EventLogID -EntryType $($MessageType[$type]) -Message $Message -Category 0
            }

    }