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
  Setup-BcContainerTestUsers -password $securePassword
 .Example
  Setup-BcContainerTestUsers containerName test -tenant default -password $Credential.Password -credential $Credential
#>
function Setup-BcContainerTestUsers {
    Param (
        [Parameter(Mandatory=$false)]
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$true)]
        [securestring] $Password,
        [Parameter(Mandatory=$false)]
        [PSCredential] $credential,
        [hashtable] $replaceDependencies = $null
    )

    $inspect = docker inspect $containerName | ConvertFrom-Json
    $version = [Version]$($inspect.Config.Labels.version)
    $systemAppTestLibrary = $null

    if ($version.Major -ge 13) {

        $appfile = Join-Path $env:TEMP "CreateTestUsers.app"
        if (([System.Version]$version).Major -ge 15) {

            $systemAppTestLibrary = get-BcContainerappinfo -containername $containerName | Where-Object { $_.Name -eq "System Application Test Library" }
            if (!($systemAppTestLibrary)) {
                $testAppFile = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock {
                    $mockAssembliesPath = "C:\Test Assemblies\Mock Assemblies"
                    $serviceTierAddInsFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins").FullName
                    if (!(Test-Path (Join-Path $serviceTierAddInsFolder "Mock Assemblies"))) {
                        new-item -itemtype symboliclink -path $serviceTierAddInsFolder -name "Mock Assemblies" -value $mockAssembliesPath | Out-Null
                        Set-NavServerInstance $serverInstance -restart
                        while (Get-NavTenant $serverInstance | Where-Object { $_.State -eq "Mounting" }) {
                            Start-Sleep -Seconds 1
                        }
                    }
                    get-childitem -Path "C:\Applications\*.*" -recurse -filter "Microsoft_System Application Test Library.app"
                }
                if ($testAppFile) {
                    Publish-BcContainerApp -containerName $containerName -appFile ":$testAppFile" -skipVerification -sync -install -replaceDependencies $replaceDependencies
                }
            }
            Download-File -sourceUrl "http://aka.ms/Microsoft_createtestusers_15.0.app" -destinationFile $appfile
        }
        else {
            Download-File -sourceUrl "http://aka.ms/Microsoft_createtestusers_13.0.0.0.app" -destinationFile $appfile
        }

        Publish-BcContainerApp -containerName $containerName -appFile $appFile -skipVerification -install -sync -replaceDependencies $replaceDependencies

        $companyId = Get-BcContainerApiCompanyId -containerName $containerName -tenant $tenant -credential $credential

        $parameters = @{ 
            "name" = "CreateTestUsers"
            "value" = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)))
        }
        Invoke-BcContainerApi -containerName $containerName -tenant $tenant -credential $credential -APIPublisher "Microsoft" -APIGroup "Setup" -APIVersion "beta" -CompanyId $companyId -Method "POST" -Query "testUsers" -body $parameters | Out-Null

        UnPublish-BcContainerApp -containerName $containerName -appName "CreateTestUsers" -unInstall
        if ((([System.Version]$version).Major -ge 15) -and (!($systemAppTestLibrary))) {
            UnPublish-BcContainerApp -containerName $containerName -appName "System Application Test Library" -unInstall
        }
    }
}
Set-Alias -Name Setup-NavContainerTestUsers -Value Setup-BcContainerTestUsers
Export-ModuleMember -Function Setup-BcContainerTestUsers -Alias Setup-NavContainerTestUsers
