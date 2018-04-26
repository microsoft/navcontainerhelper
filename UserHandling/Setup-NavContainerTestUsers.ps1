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
 .Parameter sqlCredential
  Credentials for the SQL admin user if using NavUserPassword authentication. User will be prompted if not provided
 .Example
  Setup-NavContainerTestUsers -password $securePassword
 .Example
  Setup-NavContainerTestUsers containerName test -tenant default -password $securePassword -sqlcredential $databaseCredential
#>
function Setup-NavContainerTestUsers {
Param
    (
        [Parameter(Mandatory=$false)]
        [string]$containerName = "navserver",
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$true)]
        [SecureString]$password,
        [System.Management.Automation.PSCredential]$sqlCredential = $null
    )

    $fobfile = Join-Path $env:TEMP "CreateTestUsers.fob"
    Download-File -sourceUrl "http://aka.ms/createtestusersfob" -destinationFile $fobfile
    Import-ObjectsToNavContainer -containerName $containerName -objectsFile $fobfile -sqlCredential $sqlCredential
    Invoke-NavContainerCodeunit -containerName $containerName -tenant $tenant -CodeunitId 50000 -MethodName CreateTestUsers -Argument ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)))
}
Export-ModuleMember -Function Setup-NavContainerTestUsers
