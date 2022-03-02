Function Write-ECKlog
    {
        # Version 1.3   - 14/02/2022 - replaced write-host by Write-output
        # Version 1.4.1 - 21/02/2022 - removed $Script scoped variable to work with Module
        # Version 1.5   - 22/02/2022 - reworked logic
        # Version 1.6   - 25/02/2022 - Bug fix: you could not write only event

        [CmdletBinding()]
        [Alias('Write-Log')]
        Param(
              [parameter()]
              [String]$Path,
              [parameter(Position=0, Mandatory=$true, HelpMessage="Please provide a message to log !")]
              [String]$Message,
              [parameter()]
              [String]$OutputToConsole = $true,
              [parameter()]
              [String]$EventLogID,
              [parameter()]
              [Switch]$EventLogOnly,
		      #Severity  Type(1 - Information, 2- Warning, 3 - Error)
		      [parameter(Mandatory=$False)]
		      [ValidateRange(1,3)]
		      [Int]$Type = 1
        )

        If (-Not $path -and -not $EventLogOnly)
            {Write-Warning "[Warning] No Log path or EventLogOnly specified, nothing logged !!"}
        Else
            {
                $oDate = $(Get-Date -Format "M-d-yyyy")
                $oHour = $(Get-Date -Format "HH:mm:ss")
                $MessageType = @{1 = "Information"; 2 = "Warning"; 3 = "Error"}
                $Tab = [char]9

                # Write the line to the log file
                $Content = "$oDate $oHour, $($MessageType[$type]) $Tab $($Message -replace "`r`n", ", ")"
                $Content| Out-file -FilePath $Path -Encoding UTF8 -Append -ErrorAction SilentlyContinue
                If ($OutputToConsole -eq $true){Write-output $Content}
             }

        If ($EventLogID)
            {
                $AppriendlyName = $(Split-Path $Path -Leaf) -replace "-" ,"" -replace ".ps1","" -replace " ",""
                If ([System.Diagnostics.EventLog]::SourceExists($AppriendlyName) -eq $false){New-EventLog -LogName "Application" -Source $AppriendlyName}
                Write-EventLog -LogName "Application" -Source $AppriendlyName -EventID $EventLogID -EntryType $($MessageType[$type]) -Message $Message -Category 0
            }
            
    }