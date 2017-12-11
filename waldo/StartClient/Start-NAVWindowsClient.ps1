function Start-NAVWindowsClient
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$ServerInstance, 
        [string]$ServerName=([net.dns]::gethostname()), 
        [int]$Port=7046, 
        [String]$Companyname, 
        [string]$tenant='default'
        )

    $ServerinstanceDetails = Get-NAVServerInstanceDetails -ServerInstance $ServerInstance -ErrorAction SilentlyContinue
    if ($ServerinstanceDetails){
        $Port = $ServerinstanceDetails.ClientServicesPort    
        if ([string]::IsNullOrEmpty($Companyname)) {            $Companyname = (Get-NAVCompany -ServerInstance $ServerInstance -Tenant $tenant| select -First 1).CompanyName
        }
    }
    $WinClient = (Join-path (Get-Item $NavIde).Directory 'Microsoft.Dynamics.Nav.Client.exe')
    $ConnectionString = """DynamicsNAV://$($Servername):$($Port)/$($ServerInstance)/$($Companyname)/?tenant=$($tenant)"""
    Write-host -ForegroundColor green -object "Starting $WinClient $ConnectionString ..."
    Start-Process -FilePath $WinClient -ArgumentList $ConnectionString
}

