Function Get-ECKNewModuleVersion
    {
        # Most code by https://blog.it-koehler.com/en/Archive/3359
        # Version 1.1 - 10/03/2022 - Added check for Internet connection
        # Version 1.2 - 14/04/2022 - Module version is now returned
        # Version 1.3 - 16/04/2022 - returned value is now an object
        # Version 1.4 - 22/04/2022 - Added checks if $Lasteval doesn't retun anything !
        # Version 1.5 - 26/04/20224 - Code cleanup

        Param(
                [Parameter(Mandatory = $true)][String]$ModuleName,
                [String]$LogPath
            )

        # Check if we need to update today
        Try{[DateTime]$lastEval = (Get-ItemProperty "HKLM:\SOFTWARE\ECK\DependenciesCheck" -name $ModuleName -ErrorAction SilentlyContinue).$ModuleName}
        Catch{$lastEval = $Null}
        If (![String]::IsNullOrWhiteSpace($lastEval))
            {
                If ((Get-date -Date $LastEval) -eq ((get-date).date))
                    {
                        Write-ECKlog -Message "[Warning] Module $ModuleName, was already downloaded today, to save bandwidth, now new download will occurs until tomorrow !" -type 2
                        return [PSCustomObject]@{NeedUpdate = $False ; ModuleName = $ModuleName}
                    }
            }


        #getting version of installed module
        $version = (Get-Module -ListAvailable $ModuleName) | Sort-Object Version -Descending  | Select-Object Version -First 1
        If (-not ($null -eq $version))
            {
                $stringver = $version | Select-Object @{n='ModuleVersion'; e={$_.Version -as [string]}}
                $a = $stringver | Select-Object Moduleversion -ExpandProperty Moduleversion
                $version = $version.version.tostring()
            }
        Else
        {$a = "0.0" ; $version = "0.0.0.0"}

        #getting latest module version from ps gallery
        Try {$psgalleryversion = Find-Module -Name $ModuleName -ErrorAction stop| Sort-Object Version -Descending | Select-Object Version -First 1}
        Catch
            {
                If (-not ($null -eq $version) -and $version -ne "0.0.0.0")
                    {Write-ECKlog -Message "[Warning] No internet connection available, continuing with local version $version of $ModuleName" -type 2}
                Else
                    {Write-ECKlog -Message "[ERROR] No internet connection available, unable to load module $ModuleName !!!" -type 3 ; Exit 1}
            }


        If (-not ($null -eq $psgalleryversion))
            {
                $onlinever = $psgalleryversion | Select-Object @{n='OnlineVersion'; e={$_.Version -as [string]}}
                $b = $onlinever | Select-Object OnlineVersion -ExpandProperty OnlineVersion
                $psgalleryversion = $psgalleryversion.version.tostring()
            }
        Else
        {$b = "0.0" ; $psgalleryversion = "0.0.0.0"}

        if ([version]"$a" -ge [version]"$b")
            {
                Write-ECKlog -Message "Module $ModuleName Local version [$a] is equal or greater than online version [$b], no update requiered"
                return [PSCustomObject]@{NeedUpdate = $False ; ModuleName = $ModuleName ; LocalVersion = $version ; OnlineVersion = $psgalleryversion}
            }
        else
            {
                If ($b -ne "0.0")
                    {
                        Write-ECKlog -Message "Module $ModuleName Local version [$a] is lower than online version [$b], Updating Module !"
                        If ($a -eq "0.0")
                            {Install-Module -Name $ModuleName -Force}
                        Else
                            {
                                Remove-module -Name $ModuleName -ErrorAction SilentlyContinue -Force
                                Uninstall-Module -Name $ModuleName -AllVersions -Force -Confirm:$false -ErrorAction SilentlyContinue
                                Install-Module -Name $ModuleName -Force
                            }
                        Set-ItemProperty "HKLM:\SOFTWARE\ECK\DependenciesCheck" -Name $ModuleName -value $((get-date).date)
                        return [PSCustomObject]@{NeedUpdate = $True ; ModuleName = $ModuleName ; LocalVersion = $version ; OnlineVersion = $psgalleryversion}
                    }
                Else
                    {
                        Write-ECKlog -Message "[ERROR] Module $ModuleName not found online, unable to download, aborting!" -level 3
                        return $false
                    }
            }
    }