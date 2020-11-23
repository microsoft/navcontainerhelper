Describe 'UserHandling' {
    
    $extraUser = New-Object pscredential -ArgumentList 'extrauser', $credential.Password

    It 'Get-BcContainerBcUser' {
        Get-BcContainerBcUser -containerName $bcContainerName | Where-Object { $_.UserName -eq $credential.Username } | Should -Not -BeNullOrEmpty
    }
    It 'New-BcContainerBcUser' {
        New-BcContainerBcUser -containerName $bcContainerName -Credential $extraUser -tenant default -PermissionSetId SUPER
    }
    It 'New-BcContainerWindowsUser' {
        New-BcContainerWindowsUser -containerName $bcContainerName -Credential $extraUser -group 'Administrators'
    }
    It 'Setup-BcContainerTestUsers' {
        Setup-BcContainerTestUsers -containerName $bcContainerName -tenant default -Password $credential.Password -credential $credential
        Get-BcContainerBcUser -containerName $bcContainerName | Where-Object { $_.UserName -eq 'ESSENTIAL' } | Should -Not -BeNullOrEmpty
    }

}
