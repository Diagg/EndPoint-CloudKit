Function Get-ECKGithubContent
    {
        
        # Script Version 1.1 - 27/06/2022 - Fixed access to Raw Gist

        param(

            [Parameter(Mandatory = $true, Position=0, ParameterSetName = 'Public')]
            [Parameter(Mandatory = $true, Position=0, ParameterSetName = 'Private')]
            [string]$URI,
            [Parameter(Mandatory = $true, ParameterSetName = 'Private')]
            [string]$GithubToken,
            [Parameter(Mandatory = $true, ParameterSetName = 'Private')]
            [string]$ScriptName
         )

        If([string]::IsNullOrWhiteSpace($GithubToken))
            {
                ## This a public Repo/Gist
                If(-not (($URI -like '*//gist.github.com*') -or ($URI -like '*//gist.githubusercontent.com*') -or ($URI -like '*//github.com*'))){Write-ECKlog "[ERROR] Unsupported URI $URI, Aborting !!!" -Type 3 ; Return $false}
                
                If($URI -like '*/github.com*'){$URI = $URI -replace "blob/","raw/"} # This is a Github Repo

                If ($URI -like '*//gist.github.com*') # this is a gist
                    {
                        $Content = Invoke-WebRequest -Uri $URI -UseBasicParsing -ErrorAction Stop
                        $URI = "https://gist.githubusercontent.com" + $($content.Links|Where-Object outerHTML -match "Raw" |Select-Object -ExpandProperty href)
                    }


                Try
                    {
                        $fileraw = (Invoke-WebRequest -Uri $URI -UseBasicParsing -ErrorAction Stop).Content
                        Return $fileraw
                    }
                Catch
                    {
                        Write-ECKlog "[ERROR] Unable to grab file from URI $URI, Aborting !!!" -Type 3
                        Return $false
                    }
            }
        Else
            {
                ## This a private Repo/Gist

                # Authenticate
                $clientID = $URI.split("/")[3]
                $GistID = $URI.split("/")[4]

                # Basic Auth
                $Bytes = [System.Text.Encoding]::utf8.GetBytes("$($clientID):$($GithubToken)")
                $encodedAuth = [Convert]::ToBase64String($Bytes)

                $Headers = @{Authorization = "Basic $($encodedAuth)"; Accept = 'application/vnd.github.v3+json'}
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $githubURI = "https://api.github.com/user"

                $githubBaseURI = "https://api.github.com"
                $auth = Invoke-RestMethod -Method Get -Uri $githubURI -Headers $Headers -SessionVariable GITHUB -ErrorAction SilentlyContinue

                if ($auth)
                    {
                        If($URI -like '*/gist.github.com*')
                            {
                                # Get my GISTS
                                $myGists = Invoke-RestMethod -method Get -Uri "$($githubBaseURI)/users/$($clientID)/gists" -Headers $Headers -WebSession $GITHUB
                                $script = $myGists | Select-Object | Where-Object {$_.id -eq $GistID}

                                if ($script)
                                    {
                                        foreach ($fileObj in ($script.files| Get-Member  | Where-Object {$_.memberType -eq "NoteProperty"}))
                                            {
                                                $File = $fileObj.definition

                                                $File = $File -split("@")
                                                $File = ($File[1]).replace("{","").replace("}","")
                                                $File = ($File.split(";")).trim()|ConvertFrom-StringData

                                                # Get File
                                                If (($File.Filename).ToUpper() -eq $ScriptName.ToUpper())
                                                    {
                                                        $rawURL = $File.raw_url
                                                        $fileraw = Invoke-RestMethod -Method Get -Uri $rawURL -WebSession $GITHUB
                                                        Return $fileraw
                                                    }
                                            }
                                    }
                            }
                        ElseIf($URI -like '*/github.com*')
                            {
                                Function Local:Get-RepositoryContent
                                    {
                                        param (
                                            [Parameter( Position = 0, Mandatory = $True )]
                                            [String]$Path
                                        )


                                        $myGithubRepos = Invoke-RestMethod -method Get -Uri $path -Headers $Headers -WebSession $GITHUB

	                                    $files = $myGithubRepos | Where-Object {$_.type -eq "file"}
	                                    $directories = $myGithubRepos | Where-Object {$_.type -eq "dir"}

                                        $directories | ForEach-Object {Get-RepositoryContent -path ($_._links).self}

                                        foreach ($file in $files)
                                            {
                                                If (($File.Name).toUpper() -eq $ScriptName.ToUpper())
                                                    {
                                                        $rawURL = $File.download_url
                                                        $fileraw = Invoke-RestMethod -Method Get -Uri $rawURL -WebSession $GITHUB
                                                        $fileraw
                                                        break
                                                    }
                                            }
                                        Return
                                    }

                                # Get my GItHub
                                $SelectedFile = Get-RepositoryContent -path "$($githubBaseURI)/repos/$($clientID)/$($GistID)/contents"
                                Return $SelectedFile
                            }
                        Else
                            {
                                Write-ECKlog "[ERROR] Unsupported URI $URI, Aborting !!!" -Type 3
                               Return $false
                            }
                    }
                Else
                    {
                        Write-ECKlog "[ERROR] Unable to authenticate to github, Aborting !!!" -Type 3
                        Write-ECKlog $Error[0].InvocationInfo.PositionMessage.ToString() -Type 3
                        Write-ECKlog $Error[0].Exception.Message.ToString() -Type 3
                        Return $false
                    }
            }
    }