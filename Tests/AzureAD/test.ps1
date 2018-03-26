if ($Credential -eq $null -or $credential -eq [System.Management.Automation.PSCredential]::Empty) {
    $credential = get-credential -UserName $env:USERNAME -Message "Using NavUserPassword Authentication. Please enter your Windows credentials."
}

if ($AadAdminCredential -eq $null -or $AadAdminCredential -eq [System.Management.Automation.PSCredential]::Empty) {
    $AadAdminCredential = Get-Credential
}

$protocol = "http://"
$https = ($protocol -eq "https://")

$containerName = "nav"
Create-AadAppsForNavContainer -AadAdminCredential $AadAdminCredential `
                              -appIdUri "$protocol$containerName/nav/" `
                              -iconPath "c:\temp\nav.png" | Out-Null
New-NavContainer -accept_eula `
                 -containerName $containerName `
                 -Credential $Credential `
                 -authenticationEMail $AadAdminCredential.UserName `
                 -auth aad `
                 -usessl:$https `
                 -imageName "microsoft/dynamics-nav:2018" `
                 -updateHosts `
                 -includeCSide `
                 -additionalParameters @("-e clickonce=Y") `
                 -doNotExportObjectsToText

Create-AadAppsForNavContainer -AadAdminCredential $AadAdminCredential `
                              -appIdUri "$protocol$containerName/nav/webclient/" `
                              -iconPath "c:\temp\nav.png" | Out-Null
New-NavContainer -accept_eula `
                 -containerName $containerName `
                 -Credential $Credential `
                 -authenticationEMail $AadAdminCredential.UserName `
                 -auth aad `
                 -usessl:$https `
                 -imageName "microsoft/dynamics-nav:2017" `
                 -updateHosts `
                 -includeCSide `
                 -additionalParameters @("-e clickonce=Y") `
                 -doNotExportObjectsToText

Create-AadAppsForNavContainer -AadAdminCredential $AadAdminCredential `
                              -appIdUri "$protocol$containerName/nav/webclient/" `
                              -iconPath "c:\temp\nav.png" | Out-Null
New-NavContainer -accept_eula `
                 -containerName $containerName `
                 -Credential $Credential `
                 -authenticationEMail $AadAdminCredential.UserName `
                 -auth aad `
                 -usessl:$https `
                 -imageName "microsoft/dynamics-nav:2016" `
                 -updateHosts `
                 -includeCSide `
                 -additionalParameters @("-e clickonce=Y") `
                 -doNotExportObjectsToText

Remove-NavContainer $containerName -ErrorAction Ignore
