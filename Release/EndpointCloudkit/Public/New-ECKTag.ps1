Function New-ECKTag
    {
        # Version 1.0 - 23/04/2022 - Initial release, change an object into regisrty keys

        Param(
                [String]$Regpath = "HKLM:\SOFTWARE\ECK",
                [Parameter(Mandatory = $true)][pscustomobject]$TagsObject
            )

        If (-not (test-path $RegPath)){New-item -Path $RegPath -Force|Out-Null}
        Write-ECKlog "Tagging Registry at path $RegPath"

        $objMembers = $TagsObject.psobject.Members | where-object membertype -like 'noteproperty'
        foreach ($obj in $objMembers)
            {
                Write-ECKlog "   $($obj.name) = $($obj.Value)"
                Set-ItemProperty $RegPath -name $obj.name -Value $obj.Value -Force -ErrorAction SilentlyContinue|out-null
            }
    }
