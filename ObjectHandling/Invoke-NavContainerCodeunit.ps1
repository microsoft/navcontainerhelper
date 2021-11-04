<# 
 .Synopsis
  Invoke codeunit in Nav Container
 .Description
  Invoke a codeunit in a NAV Container.
  Create and remove a temp. windows user if running NavUserPassword 
 .Parameter containerName
  Name of the container in which you want to invoke a codeunit
 .Parameter tenant
  Name of the tenant in which context you want to invoke a codeunit
 .Parameter CompanyName
  Name of the Company in which context you want to invoke a codeunit
 .Parameter Codeunitid
  Id of the codeunit you want to invoke
 .Parameter MethodName
  Name of the method you want to invoke (default is OnRun)
 .Parameter Argument
  Arguments for the method (default empty)
 .Parameter TimeZone
  TimeZone in which the codeunit will the invoked
 .Example
  Invoke-NavContainerCodeunit -containerName test -codeunitId 50000
 .Example
  Invoke-NavContainerCodeunit -containerName test -codeunitId 50000 -methodName "doit" -argument "Hello"
#>
function Invoke-NavContainerCodeunit {
    Param (
        [string] $containerName = $bcContainerHelperConfig.defaultContainerName,
        [Parameter(Mandatory=$false)]
        [string] $tenant = "default",
        [Parameter(Mandatory=$false)]
        [string] $CompanyName,
        [Parameter(Mandatory=$true)]
        [int] $Codeunitid,
        [Parameter(Mandatory=$false)]
        [string] $MethodName,
        [Parameter(Mandatory=$false)]
        [string] $Argument,
        [Parameter(Mandatory=$false)]
        [string] $TimeZone
    )

$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {

    $navversion = Get-NavContainerNavversion -containerOrImageName $containerName
    $version = [System.Version]($navversion.split('-')[0])

    Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock { Param($tenant, $CompanyName, $Codeunitid, $MethodName, $Argument, $Timezone, $version)
    
        $me = whoami
        $userexist = Get-NAVServerUser -ServerInstance $ServerInstance -Tenant $tenant | Where-Object username -eq $me
        $companyParam = @{}
        if ($companyName -and $version.Major -gt 9) {
            $companyParam += @{
                "Company" = $CompanyName
                "Force" = $true
            }
        }
        if (!($userexist)) {
            New-NAVServerUser -ServerInstance $ServerInstance -Tenant $tenant -WindowsAccount $me @companyParam
            New-NAVServerUserPermissionSet -ServerInstance $ServerInstance -Tenant $tenant -WindowsAccount $me -PermissionSetId SUPER
            Start-Sleep -Seconds 1
        } elseif ($userexist.state -eq "Disabled") {
            Set-NAVServerUser -ServerInstance $ServerInstance -Tenant $tenant -WindowsAccount $me -state Enabled @companyParam
        }
        
        $Params = @{}
        if ($CompanyName) {
            $Params += @{ "CompanyName" = $CompanyName }
        }
        if ($MethodName) {
            $Params += @{ "MethodName" = $MethodName }
        }
        if ($Argument) {
            $Params += @{ "Argument" = $Argument }
        }
        if ($Timezone) {
            $Params += @{ "TimeZone" = $TimeZone }
        }

        Invoke-NAVCodeunit -ServerInstance $ServerInstance -Tenant $tenant @Params -CodeunitId $CodeUnitId

        Set-NAVServerUser -ServerInstance $ServerInstance -Tenant $tenant -WindowsAccount $me -state Disabled

    } -ArgumentList $tenant, $CompanyName, $Codeunitid, $MethodName, $Argument, $TimeZone, $version
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Invoke-NavContainerCodeunit
