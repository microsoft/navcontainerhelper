Describe 'TenantHandling' {

    It 'Get-BcContainerTenants' {
        Get-BcContainerTenants -containerName $bcsContainerName | Should -Not -BeNullOrEmpty
        (@(Get-BcContainerTenants -containerName $bcsContainerName)).Count | should -Be 1
    }
    It 'New-BcContainerTenant' {
        New-BcContainerTenant -containerName $bcsContainerName -tenantId "extra" -alternateId "mytenant"
        (@(Get-BcContainerTenants -containerName $bcsContainerName)).Count | should -Be 2
        $hosts = [string]::Join(' ',(Get-Content -Path "c:\windows\system32\drivers\etc\hosts"))
        $hosts | Should -BeLike "*$bcsContainerName-extra*"
        $hosts | Should -Not -BeLike "*$bcsContainerName-mytenant*"
    }
    It 'Remove-BcContainerTenant' {
        Remove-BcContainerTenant -containerName $bcsContainerName -tenantId "extra"
        (@(Get-BcContainerTenants -containerName $bcsContainerName)).Count | should -Be 1
        $hosts = [string]::Join(' ',(Get-Content -Path "c:\windows\system32\drivers\etc\hosts"))
        $hosts | Should -Not -BeLike "*$bcsContainerName-extra*"
    }

}
