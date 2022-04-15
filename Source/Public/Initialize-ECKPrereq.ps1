Function Initialize-ECKPrereq
    {
        Param (
                [String[]]$Module,                                                                          # List of module to import separated by coma
                [string]$LogPath = "C:\Windows\Logs\ECK\ECK-Init.log",                                      # Defaut log file path
                [bool]$NugetDevTool = $false,                                                               # Allow installation of nuget.exe, 
                [Parameter(ParameterSetName="Contentload")][String[]]$ContentToLoad,                        # Download scripts form Github and place them in $ContentPath folder
                [Parameter(ParameterSetName="Contentload")][String]$ContentPath = "$env:temp\ECK-Content",  # Path where script are downloaded
                [String[]]$ScriptToImport                                                                   # download scripts from Github and import them in the current Powershell session.
            )

        ## Create Folders and registry keys
        If (-not (Test-Path $ContentPath)){New-Item $ContentPath -ItemType Directory -Force|Out-Null}
        If (-not (Test-Path $(Split-Path $LogPath ))){New-Item $(Split-Path $LogPath) -ItemType Directory -Force|Out-Null}
        If (-not (test-path "HKLM:\SOFTWARE\ECK\DependenciesCheck")){New-item -Path "HKLM:\SOFTWARE\ECK\DependenciesCheck" -Force|Out-Null} 

        ## Set Tls to 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        ## Add Scripts path to $env:PSModulePath
        $CurrentValue = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
        If ($CurrentValue -notlike "*C:\Program Files\WindowsPowerShell\scripts*") {[Environment]::SetEnvironmentVariable("PSModulePath", $CurrentValue + [System.IO.Path]::PathSeparator + "C:\Program Files\WindowsPowerShell\Scripts", "Machine")}

        Try 
            {
                $ModECK = $true

                ## install Nuget provider
                If (-not(Test-path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll"))
                    {
                        Try{Install-PackageProvider -Name 'nuget' -Force -ErrorAction stop |Out-Null}
                        Catch
                            {
                                $Message = "[ERROR] No internet connection available, Unable to Download Nuget Provider, Aborting !!"
                                If ($ModECK -eq $true){Write-ECKlog -Message $Message} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}
                                Exit 1
                            }
                    }
                $Message = "Nuget provider installed version: $(((Get-PackageProvider -Name 'nuget'|Sort-Object|Select-Object -First 1).version.tostring()))"
                If ($ModECK -eq $true){Write-ECKlog -Message $Message} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}

                ## Install Packagemangment Module dependencie of Powershell Get if we are under system account
                IF ((get-module PackageManagement -ListAvailable|Select-Object -first 1).version -notlike "1.4*" -and $env:UserProfile -eq 'C:\Windows\system32\config\systemprofile')
                    {
                        Try
                            {
                                $FileURI = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.7.nupkg"
                                $Nupkg = "$ContentPath\$(($FileURI.split("/")[-1]).replace(".nupkg",".zip"))"
                                Invoke-WebRequest -URI $FileURI -UseBasicParsing -ErrorAction Stop -OutFile $Nupkg
                                Unblock-File -Path $Nupkg
                            }
                        Catch
                            {
                                $Message = "[ERROR] No internet connection available, Unable to Download Nuget Provider, Aborting !!"
                                If ($ModECK -eq $true){Write-ECKlog -Message $Message} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}
                                Exit 1
                            }

                        ## Create Destination folder structure
                        $ModulePath = "C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.4.7"
                        If (-not(test-path $ModulePath)){New-item -Path $ModulePath -ItemType Directory -Force|Out-Null} 

                        ## Uniziping File
                        Expand-Archive -LiteralPath $Nupkg -DestinationPath $ModulePath -Force
                        Remove-Item $Nupkg -Force -ErrorAction SilentlyContinue|Out-Null
                        
                        ## Clean bloatwares
                        Remove-Item "$ModulePath\_rels" -Recurse -Force -ErrorAction SilentlyContinue|Out-Null
                        Remove-Item "$ModulePath\package" -Recurse -Force -ErrorAction SilentlyContinue|Out-Null
                        Remove-Item "$ModulePath\``[Content_Types``].xml"  -Force -ErrorAction SilentlyContinue|Out-Null
                        Remove-Item "$ModulePath\PackageManagement.nuspec"  -Force -ErrorAction SilentlyContinue|Out-Null
                    }

                ## Import Powershell Get
                If (-not (Get-Module PowershellGet)) {Import-Module PowershellGet}
                $Message = "PowershellGet module installed version: $(((Get-Module PowerShellGet|Sort-Object|Select-Object -First 1).version.tostring()))"
                If ($ModECK -eq $true){Write-ECKlog -Message $Message} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}

                ## Trust PSGallery
                If ((Get-PSRepository -Name "PsGallery").InstallationPolicy -ne "Trusted"){Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -SourceLocation 'https://www.powershellgallery.com/api/v2'} 

                # Installing Endpoint Cloud Kit
                $Module += "endpointcloudkit"
                $Module = $Module[-1..0]

                # Installing modules
                Foreach ($mod in $Module)
                    {
                        $ModStatus = Get-ECKNewModuleVersion -modulename $Mod -LogPath $LogPath
                        If ($ModStatus -eq $true)
                            {
                                Import-Module $Mod -Force
                                If ($Mod -eq 'endpointcloudkit' -and $ModECK -ne $true){Set-ECKEnvironment -FullGather -LogPath $LogPath ; $ModECK = $true} 
                                Write-ECKlog -Message "$Mod module installed version: $(((Get-Module $mod|Sort-Object|Select-Object -last 1).version.tostring()))"
                            }
                        Else
                            {Write-ECKlog -Message "[Error] Unable to install Module $Mod, Aborting!!!" ; Exit 1}
                    }


                ##Install Nuget.Exe
                If ($NugetDevTool -eq $true)
                    {
                        $NugetPath = 'C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet'
                        If (-not (test-path $NugetPath)){New-item $NugetPath -ItemType Directory -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null}
                        If (-not (test-path "$NugetPath\Nuget.exe")){Invoke-WebRequest -Uri 'https://aka.ms/psget-nugetexe' -OutFile "$NugetPath\Nuget.exe" -ErrorAction SilentlyContinue}
                    }
                
                ##Install Hiddenw.exe
                $PowershellwPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\Powershellw.exe'
                If (-not (test-path $PowershellwPath)){Invoke-WebRequest -Uri 'https://github.com/SeidChr/RunHiddenConsole/releases/download/1.0.0-alpha.2/hiddenw.exe' -OutFile $PowershellwPath -ErrorAction SilentlyContinue}
                If (test-path $PowershellwPath){Write-ECKlog -Message "Successfully Downloaded $PowershellwPath !"}    

                ##Install SerciceUI_X64.exe
                $SrvUIPath = 'C:\Windows\System32\ServiceUI.exe'
                If (-not (test-path $SrvUIPath)){Invoke-WebRequest -Uri $(Format-GitHubURL 'https://github.com/Diagg/EndPoint-CloudKit-Bootstrap/blob/master/ServiceUI/ServiceUI_x64.exe') -OutFile $SrvUIPath -ErrorAction SilentlyContinue}
                If (test-path $SrvUIPath){Write-ECKlog -Message "Successfully Downloaded $SrvUIPath !"} 

                ##Install SerciceUI_X86.exe                
                $SrvUIPath = 'C:\Windows\SysWOW64\ServiceUI.exe'
                If (-not (test-path $SrvUIPath)){Invoke-WebRequest -Uri $(Format-GitHubURL 'https://github.com/Diagg/EndPoint-CloudKit-Bootstrap/blob/master/ServiceUI/ServiceUI_x86.exe') -OutFile $SrvUIPath -ErrorAction SilentlyContinue}
                If (test-path $SrvUIPath){Write-ECKlog -Message "Successfully Downloaded $SrvUIPath !"} 

                # Download Script and execute
                Foreach ($cript in $ScriptToImport)
                    {
                        $ScriptURI = Format-GitHubURL -URI $cript -LogPath $LogPath
                        Try 
                            {
                                $Fileraw = (Invoke-WebRequest -URI $ScriptURI -UseBasicParsing -ErrorAction Stop).content
                                Write-ECKlog -Message "Running script $($ScriptURI.split("/")[-1]) !!!"
                                Invoke-expression $Fileraw -ErrorAction stop 
                            }
                        Catch
                            {Write-ECKlog -Message "[ERROR] Unable to get script content or error in execution, Aborting !!!" ; Exit 1}
                    }

                
                # Download Script and store them
                Foreach ($File in $ContentToLoad)
                    {
                        $FiletURI = Format-GitHubURL -URI $File -LogPath $LogPath
                        Try 
                            {
                                $Fileraw = (Invoke-WebRequest -URI $FiletURI -UseBasicParsing -ErrorAction Stop).content
                                Write-ECKlog -Message "Succesfully downloaded content to $ContentPath\$($FiletURI.split("/")[-1]) !!!"
                                $Fileraw | Out-File -FilePath "$ContentPath\$($FiletURI.split("/")[-1])" -Encoding utf8 -force
                            }
                        Catch
                            {Write-ECKlog -Message "[ERROR] Unable to get content, Aborting !!!" ; Exit 1}
                    }

                Write-ECKlog -Message "All initialization operations finished, Endpoint Cloud Kit and other dependencies staged sucessfully!!!"
            } 
        Catch 
            {
                $Message = $_.Exception.Message.ToString()
                If ($ModECK -eq $true){Write-ECKlog -Message $Message -Type 3} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}
                $Message =  $_.InvocationInfo.PositionMessage.ToString()
                If ($ModECK -eq $true){Write-ECKlog -Message $Message -Type 3} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}
                $Message = "[Error] Unable to install default providers, Enpdoint Cloud Kit or Dependencies, Aborting!!!"
                If ($ModECK -eq $true){Write-ECKlog -Message $Message -Type 3} else {$Message|Out-file -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue}
            }
    }