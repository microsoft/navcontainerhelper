<# 
 .Synopsis
  Setup test users in Container
 .Description
  Setup test users in Container:
  Username             User Groups              Permission Sets
  EXTERNALACCOUNTANT   D365 EXT. ACCOUNTANT     D365 BUS FULL ACCESS
                       D365 EXTENSION MGT       D365 EXTENSION MGT
                                                D365 READ
                                                LOCAL

  PREMIUM              D365 BUS PREMIUM         D365 BUS PREMIUM
                       D365 EXTENSION MGT       D365 EXTENSION MGT
                                                LOCAL

  ESSENTIAL            D365 BUS FULL ACCESS     D365 BUS FULL ACCESS
                       D365 EXTENSION MGT       D365 EXTENSION MGT
                                                LOCAL

  INTERNALADMIN        D365 INTERNAL ADMIN      D365 READ
                                                LOCAL
                                                SECURITY

  TEAMMEMBER           D365 TEAM MEMBER         D365 READ
                                                D365 TEAM MEMBER
                                                LOCAL

  DELEGATEDADMIN       D365 EXTENSION MGT       D365 BASIC
                       D365 FULL ACCESS         D365 EXTENSION MGT
                       D365 RAPIDSTART          D365 FULL ACCESS
                                                D365 RAPIDSTART
                                                LOCAL

 .Parameter containerName
  Name of the container in which you want to add test users (default navserver)
 .Parameter tenant
  Name of tenant in which you want to add test users (default defeault)
 .Parameter password
  The password for all test users created
 .Parameter Credential
  Credentials for the admin user if using NavUserPassword authentication
 .Example
  Setup-NavContainerTestUsers -password $securePassword
 .Example
  Setup-NavContainerTestUsers containerName test -tenant default -password $Credential.Password -credential $Credential
#>
function Setup-NavContainerTestUsers {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [securestring] $Password,
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential
    )

    $inspect = docker inspect $containerName | ConvertFrom-Json
    $version = [Version]$($inspect.Config.Labels.version)

    if ($version.Major -ge 13) {

        $appfile = Join-Path $env:TEMP "CreateTestUsers.app"
        Download-File -sourceUrl "http://aka.ms/Microsoft_createtestusers_13.0.0.0.app" -destinationFile $appfile

        Publish-NavContainerApp -containerName $containerName -appFile $appFile -skipVerification -install -sync

        $companyId = Get-NavContainerApiCompanyId -containerName $containerName -tenant $tenant -credential $credential

        $parameters = @{ 
            "name" = "CreateTestUsers"
            "value" = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)))
        }
        Invoke-NavContainerApi -containerName $containerName -tenant $tenant -credential $credential -APIPublisher "Microsoft" -APIGroup "Setup" -APIVersion "beta" -CompanyId $companyId -Method "POST" -Query "testUsers" -body $parameters | Out-Null

        UnPublish-NavContainerApp -containerName $containerName -appName CreateTestUsers -unInstall
    }
}
Set-Alias -Name Setup-BCContainerTestUsers -Value Setup-NavContainerTestUsers
Export-ModuleMember -Function Setup-NavContainerTestUsers -Alias Setup-BCContainerTestUsers
