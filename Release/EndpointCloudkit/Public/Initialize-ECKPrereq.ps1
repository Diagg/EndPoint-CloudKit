Function Initialize-ECKPrereq
    {
        # Version 1.1 - 16/04/2022 - Code cleanup
        # Version 1.2 - 28/04/2022 - Added support for ECK-Content
        # Version 1.3 - 03/05/2022 - Bug fix, Changed $ContentPath location and behavior, update Powershellget if needed
        # Version 1.4 - 12/05/2022 - Bug fix, file download was not using Get-ECKGithubContent
        # Version 1.5 - 22/05/2022 - Changed Logging messages on external downloads
        # Version 1.6 - 24/06/2022 - Added logic to logpath
        # Version 1.7 - 27/06/2022 - Added support fot Trevor Jones's Gist script New-WPFMessageBox
        # Version 1.8 - 10/11/2022 - Removed support fot Trevor Jones's Gist script New-WPFMessageBox

        Param (
                [String[]]$Module,                                                                              # List of module to import separated by coma
                [string]$LogPath,                                                                               # Defaut log file path
                [bool]$NugetDevTool = $false,                                                                   # Allow installation of nuget.exe,
                [Parameter(ParameterSetName="Contentload")][String[]]$ContentToLoad,                            # Download scripts form Github and place them in $ContentPath folder
                [Parameter(ParameterSetName="Contentload")][String]$ContentPath = 'C:\ProgramData\ECK-Content', # Path where script are downloaded
                [String[]]$ScriptToImport                                                                       # download scripts from Github and import them in the current Powershell session.
            )

        ## Set LogPath
        If ($null -eq $logpath)
            {
                If (-NOT ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544') -or ($env:USERPROFILE -eq "C:\Windows\System32\Config\systemprofile")) {$LogPath = "$($env:TMP)\ECK-Init.log"}
                Elseif ($null -ne $eck.LogFullName){$LogPath = $eck.LogFullName}
                Else {$LogPath = "C:\Windows\Logs\ECK\ECK-Init.log"}
            }
        ## Create Folders and registry keys
        If (-not (Test-Path $ContentPath)){New-Item $ContentPath -ItemType Directory -Force|Out-Null}
        If (-not (Test-Path $(Split-Path $LogPath ))){New-Item $(Split-Path $LogPath) -ItemType Directory -Force|Out-Null}
        If (-not (test-path "HKLM:\SOFTWARE\ECK\DependenciesCheck")){New-item -Path "HKLM:\SOFTWARE\ECK\DependenciesCheck" -Force|Out-Null}

        ## Allow read and execute for standard users on $ContentPath folder
        $Acl = Get-ACL $ContentPath
        If (($Acl.Access|Where-Object {$_.IdentityReference -eq "BUILTIN\$((Get-LocalGroup -SID S-1-5-32-545).Name)" -and $_.AccessControlType -eq "Allow" -and $_.FileSystemRights -like "*ReadAndExecute*"}).count -lt 1)
            {
                $AccessRule= New-Object System.Security.AccessControl.FileSystemAccessRule($((Get-LocalGroup -SID S-1-5-32-545).Name),"ReadAndExecute","ContainerInherit,Objectinherit","none","Allow")
                $Acl.AddAccessRule($AccessRule)
                Set-Acl $ContentPath $Acl
            }

        ## Set Tls to 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        ## Add Scripts path to $env:PSModulePath
        $CurrentValue = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
        If ($CurrentValue -notlike "*C:\Program Files\WindowsPowerShell\scripts*") {[Environment]::SetEnvironmentVariable("PSModulePath", $CurrentValue + [System.IO.Path]::PathSeparator + "C:\Program Files\WindowsPowerShell\Scripts", "Machine")}

        ## Unload Modules
        Remove-Module Powershellget -Force -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Module PackageManagement -Force -Confirm:$false -ErrorAction SilentlyContinue


        Try
            {
                ## install Nuget provider
                If (-not(Test-path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll"))
                    {
                        Try {Install-PackageProvider -Name 'nuget' -Force -ErrorAction stop |Out-Null}
                        Catch {Write-ECKlog -Message "[ERROR] No internet connection available, Unable to Download Nuget Provider, Aborting !!" -type 3 -Path $LogPath ; Exit 1}
                    }

                Write-ECKlog -Message "Nuget provider installed version: $(((Get-PackageProvider -Name 'nuget'|Sort-Object|Select-Object -First 1).version.tostring()))" -Path $LogPath

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
                            {Write-ECKlog -Message "[ERROR] No internet connection available, Unable to Download Nuget Provider, Aborting !!" -type 3 -Path $LogPath ; Exit 1}

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
                If (-not (Get-Module PowershellGet)) {Get-Module 'PowershellGet' -ListAvailable | Sort-Object Version -Descending  | Select-Object -First 1|Import-module}
                [Version]$PsGetVersion = $(((Get-Module PowerShellGet|Sort-Object|Select-Object -First 1).version.tostring()))
                Write-ECKlog -Message "PowershellGet module installed version: $PsGetVersion" -Path $LogPath

                ## Trust PSGallery
                If ((Get-PSRepository -Name "PsGallery").InstallationPolicy -ne "Trusted"){Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -SourceLocation 'https://www.powershellgallery.com/api/v2'}

                # Add mandatory modules
                If ('endpointcloudkit' -notin $Module){$Module += "endpointcloudkit" ; $Module = $Module|Sort-Object -Descending}
                If ($PsGetVersion -lt [version]"2.2.5" -and 'PowershellGet' -notin $Module){$Module += "PowershellGet" ; $Module = $Module|Sort-Object -Descending}

                # Installing modules
                Foreach ($mod in $Module)
                    {
                        $ModStatus = Get-ECKNewModuleVersion -modulename $Mod -LogPath $LogPath
                        If ($ModStatus.NeedUpdate -eq $True)
                            {
                                Remove-module $Mod -force -ErrorAction SilentlyContinue
                                $ImportedMod = Get-Module $mod -ListAvailable | Sort-Object Version -Descending  | Select-Object -First 1|Import-module -Force -Global -PassThru

                                Write-ECKlog -Message "$Mod module installed version: $($ImportedMod.Version.ToString())" -Path $LogPath

                                If ($Mod -eq 'endpointcloudkit'){New-ECKEnvironment -LogPath $LogPath -ContentPath $ContentPath ; $ModECK = $true}
                            }
                        ElseIf ($ModStatus.NeedUpdate -eq $false)
                            {Write-ECKlog -Message "Module $Mod aready up to date !" -Path $LogPath}
                        Else
                            {Write-ECKlog -Message "[Error] Unable to install Module $Mod, Aborting!!!" -type 3 -Path $LogPath; Exit 1}
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
                If (-not (test-path $PowershellwPath))
                    {
                        Invoke-WebRequest -Uri 'https://github.com/SeidChr/RunHiddenConsole/releases/download/1.0.0-alpha.2/hiddenw.exe' -OutFile $PowershellwPath -ErrorAction SilentlyContinue
                        If (test-path $PowershellwPath){Write-ECKlog -Message "Successfully Downloaded $PowershellwPath !" -Path $LogPath} Else {Write-ECKlog -Message "[ERROR] Unable to download $PowershellwPath !" -Path $LogPath}
                    }
                else
                    {Write-ECKlog -Message "$PowershellwPath Already downloaded!" -Path $LogPath}

                ##Install SerciceUI_X64.exe
                $SrvUIPath = 'C:\Windows\System32\ServiceUI.exe'
                If (-not (test-path $SrvUIPath))
                    {
                        Invoke-WebRequest -Uri $(Format-GitHubURL 'https://github.com/Diagg/EndPoint-CloudKit-Bootstrap/blob/master/ServiceUI/ServiceUI_x64.exe') -OutFile $SrvUIPath -ErrorAction SilentlyContinue
                        If (test-path $SrvUIPath){Write-ECKlog -Message "Successfully Downloaded $SrvUIPath !" -Path $LogPath} Else {Write-ECKlog -Message "[ERROR] Unable to download $SrvUIPath !" -Path $LogPath}
                    }
                else
                    {Write-ECKlog -Message "$SrvUIPath Already downloaded!"}


                ##Install SerciceUI_X86.exe
                $SrvUIPath = 'C:\Windows\SysWOW64\ServiceUI.exe'
                If (-not (test-path $SrvUIPath))
                    {
                        Invoke-WebRequest -Uri $(Format-GitHubURL 'https://github.com/Diagg/EndPoint-CloudKit-Bootstrap/blob/master/ServiceUI/ServiceUI_x86.exe') -OutFile $SrvUIPath -ErrorAction SilentlyContinue
                        If (test-path $SrvUIPath){Write-ECKlog -Message "Successfully Downloaded $SrvUIPath !"} Else {Write-ECKlog -Message "[ERROR] Unable to download $SrvUIPath !"}
                    }
                else
                    {Write-ECKlog -Message "$SrvUIPath Already downloaded!" -Path $LogPath}

                # Add mandatory Scripts
                #$Script_newwpfmessagebox = 'https://gist.github.com/SMSAgentSoftware/0c0eee98a673b6ac34f5215ea6841beb#file-new-wpfmessagebox'
                #If ($Script_newwpfmessagebox -notin $ScriptToImport){$ScriptToImport += $Script_newwpfmessagebox ; $ScriptToImport = $ScriptToImport|Sort-Object -Descending}

                # Download Script and execute
                Foreach ($cript in $ScriptToImport)
                    {
                        Try
                            {
                                $Fileraw = Get-ECKGithubContent -URI $cript
                                Write-ECKlog -Message "Running script $($Script.split("/")[-1]) !!!" -Path $LogPath
                                Invoke-expression $Fileraw -ErrorAction stop
                            }
                        Catch
                            {Write-ECKlog -Message "[ERROR] Unable to get script content or error in execution, Aborting !!!" -Path $LogPath ; Exit 1}
                    }


                # Download Script and store them
                Foreach ($File in $ContentToLoad)
                    {
                        Try
                            {
                                $Fileraw = Get-ECKGithubContent -URI $File
                                Write-ECKlog -Message "Succesfully downloaded content to $ContentPath\$($File.split("/")[-1]) !!!" -Path $LogPath
                                $Fileraw | Out-File -FilePath "$ContentPath\$($File.split("/")[-1])" -Encoding utf8 -force
                            }
                        Catch
                            {Write-ECKlog -Message "[ERROR] Unable to get content, Aborting !!!" -Path $LogPath ; Exit 1}
                    }

                Write-ECKlog -Message "All initialization operations finished, Endpoint Cloud Kit and other dependencies staged sucessfully!!!" -Path $LogPath
            }
        Catch
            {
                Write-ECKlog -Message $_.Exception.Message.ToString()-Type 3 -Path $LogPath
                Write-ECKlog -Message $_.InvocationInfo.PositionMessage.ToString() -Type 3 -Path $LogPath
                Write-ECKlog -Message "[Error] Unable to install default providers, Enpdoint Cloud Kit or Dependencies, Aborting!!!" -Type 3 -Path $LogPath
            }
    }