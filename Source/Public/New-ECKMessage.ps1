Function New-ECKMessage
    {
        # Check if function exists
        If (Get-ChildItem function:| Where-Object name -ne 'New-WPFMessageBox')
            {
                Write-ECKlog "New-WPFMessageBox function missing, trying to redownload"
                Try
                    {
                        $Fileraw = Get-ECKGithubContent -URI 'https://gist.github.com/SMSAgentSoftware/0c0eee98a673b6ac34f5215ea6841beb#file-new-wpfmessagebox'
                        Invoke-expression $Fileraw -ErrorAction stop  
                    }
                Catch
                    {Write-ECKlog "[ERROR] Unable to download New-WPFMessageBox function, New ECKMessage can't be used !" ; Return $False}
            }

        If (Get-ChildItem function:| Where-Object name -eq 'New-WPFMessageBox')
            {Write-ECKlog "New-WPFMessageBox function Loaded successfully"}
        Else
            {Write-ECKlog "[ERROR] Unable to download New-WPFMessageBox function, New ECKMessage can't be used !" ; Return $False}
        
        # Add TopMost 'on the fly' (alarache)
        
        $ErrorMsgParams = @{
            Title = "ERROR!"
            TitleBackground = "Red"
            TitleTextForeground = "WhiteSmoke"
            TitleFontWeight = "UltraBold"
            TitleFontSize = 20
            Sound = 'Windows Exclamation'
        }
        New-WPFMessageBox @ErrorMsgParams -Content "There was a problem connecting to the Exchange Server.
        Please try again later."
        
    }