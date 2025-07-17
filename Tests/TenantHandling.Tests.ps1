Param(
    [string] $licenseFile,
    [string] $buildlicenseFile
)

BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    . (Join-Path $PSScriptRoot '_CreateBcContainer.ps1') -sandbox
}

AfterAll {
    . (Join-Path $PSScriptRoot '_RemoveBcContainer.ps1')
}

Describe 'TenantHandling' -Skip {

    It 'Get-BcContainerTenants' {
        Get-BcContainerTenants -containerName $bcContainerName | Should -Not -BeNullOrEmpty
        (@(Get-BcContainerTenants -containerName $bcContainerName)).Count | should -Be 1
    }
    It 'New-BcContainerTenant' {
        New-BcContainerTenant -containerName $bcContainerName -tenantId "extra" -alternateId "mytenant"
        (@(Get-BcContainerTenants -containerName $bcContainerName)).Count | should -Be 2
        $hosts = [string]::Join(' ',(Get-Content -Path "c:\windows\system32\drivers\etc\hosts"))
        $hosts | Should -BeLike "*$bcContainerName-extra*"
        $hosts | Should -Not -BeLike "*$bcContainerName-mytenant*"
    }
    It 'Remove-BcContainerTenant' {
        Remove-BcContainerTenant -containerName $bcContainerName -tenantId "extra"
        (@(Get-BcContainerTenants -containerName $bcContainerName)).Count | should -Be 1
        $hosts = [string]::Join(' ',(Get-Content -Path "c:\windows\system32\drivers\etc\hosts"))
        $hosts | Should -Not -BeLike "*$bcContainerName-extra*"
    }

}
