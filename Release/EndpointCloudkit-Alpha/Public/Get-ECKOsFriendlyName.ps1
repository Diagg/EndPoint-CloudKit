Function Get-ECKOsFriendlyName
    {
        Param(
                [Parameter(Mandatory = $false)]
                [string]$BuildNumber = $((Get-ItemProperty 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild)
            )

        $OSBuild = @{}
        IF ([int]($BuildNumber) -lt 22000){$URL = 'https://docs.microsoft.com/en-us/windows/release-health/release-information'}
        else {$URL = 'https://docs.microsoft.com/en-us/windows/release-health/windows11-release-information'}

        Try {
                $HTML = Invoke-RestMethod $URL
                $Pattern =  '<strong>(?<version>.*)<\/strong>'
                $AllMatches = ($HTML | Select-String $Pattern -AllMatches).Matches
                ($AllMatches.Groups | Where-Object {$_.name -eq 'version'}).value -replace "Version " -replace "\(RTM\) " -replace "\(original release\) " -replace "\(OS build" -replace "\)"| ForEach-Object {$Htbl = $_ -split " "; $OSBuild[$Htbl[2]] = $Htbl[0]}
            }
        Catch{Return "NoInternet"}

        Return $OSBuild[$buildnumber]
    }