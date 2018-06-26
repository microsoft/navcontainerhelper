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
 .Example
  Invoke-NavContainerCodeunit -containerName test -codeunitId 50000
 .Example
  Invoke-NavContainerCodeunit -containerName test -codeunitId 50000 -methodName "doit" -argument "Hello"
#>
function Invoke-NavContainerCodeunit {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$false)]
        [string]$CompanyName,
        [Parameter(Mandatory=$true)]
        [int]$Codeunitid,
        [Parameter(Mandatory=$false)]
        [string]$MethodName,
        [Parameter(Mandatory=$false)]
        [string]$Argument
    )

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($tenant, $CompanyName, $Codeunitid, $MethodName, $Argument)
    
        $me = whoami
        $userexist = Get-NAVServerUser -ServerInstance NAV -Tenant $tenant | Where-Object username -eq $me
        if (!($userexist)) {
            New-NAVServerUser -ServerInstance NAV -Tenant $tenant -WindowsAccount $me
            New-NAVServerUserPermissionSet -ServerInstance NAV -Tenant $tenant -WindowsAccount $me -PermissionSetId SUPER
        } elseif ($userexist.state -eq "Disabled") {
            Set-NAVServerUser -ServerInstance NAV -Tenant $tenant -WindowsAccount $me -state Enabled
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
    
        Invoke-NAVCodeunit -ServerInstance NAV -Tenant $tenant @Params -CodeunitId $CodeUnitId
    
        if (!($userexist)) {
            Remove-NAVServerUser -ServerInstance NAV -Tenant $tenant -WindowsAccount $me -Force
        } elseif ($userexist.state -eq "Disabled") {
            Set-NAVServerUser -ServerInstance NAV -Tenant $tenant -WindowsAccount $me -state Disabled
        }

    } -ArgumentList $tenant, $CompanyName, $Codeunitid, $MethodName, $Argument
}
Export-ModuleMember -Function Invoke-NavContainerCodeunit
