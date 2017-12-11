function Remove-NAVEnvironment
{

    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true, Position=0)]
        [System.String]
        $ServerInstance,

        [Parameter(Mandatory=$false, Position=1)]
        [Switch] $Force,

        [Parameter(Mandatory=$false, Position=2)]
        [String] $BackupModifiedObjectsPath=''

    )

    process{
        if (-not $Force) {
            if (!(Confirm-YesOrNo "Remove $ServerInstance ?" -message "Are you sure to remove $ServerInstance ?")){
                break
            }
        }
    
        write-Host -ForegroundColor Green "Removing ServerInstance $ServerInstance"
        $ServerInstanceObject = Get-NAVServerInstanceDetails -ServerInstance $ServerInstance -ErrorAction Stop
        
        if (!([String]::IsNullOrEmpty($BackupModifiedObjectsPath))){
            If (!(test-path $BackupModifiedObjectsPath)){new-item $BackupModifiedObjectsPath -ItemType directory | Out-Null}
            write-host -ForegroundColor Green "Backing up modified objects to $BackupModifiedObjectsPath"            
            Backup-NAVApplicationObjects -ServerInstance $ServerInstance -BackupOption OnlyModified -BackupPath $BackupModifiedObjectsPath -ErrorAction Stop
        }

        $WebServerInstance = Get-NAVWebServerInstance | Where ServerInstance -eq $ServerInstanceObject.ServerInstance
        if($WebServerInstance){
            write-host -ForegroundColor Green "Remove WebServerInstance $($WebServerInstance.WebServerInstance) (Uri: $($WebServerInstance.Uri))"
            Remove-NAVWebServerInstance -WebServerInstance $WebServerInstance.WebServerInstance -Force
        }

        [bool]$IsMultitenant = (((Get-NAVServerConfiguration2 -ServerInstance $ServerInstance) | Where Key -eq MultiTenant).Value -eq 'true')
        write-Host -ForegroundColor Green "MultiTenant: $IsMultitenant"
        if ($IsMultitenant) {
            $Tenants = Get-navtenant -ServerInstance $ServerInstance 
        }

        Set-NAVServerInstance -ServerInstance $ServerInstance -Stop -ErrorAction SilentlyContinue
        Remove-NAVServerInstance -ServerInstance $ServerInstance -Force
    
        if ($IsMultitenant) {
            foreach ($Tenant in $Tenants) { 
                write-Host -ForegroundColor Green "Removing (Tenant)DB $($Tenant.DatabaseName)"
                Remove-SQLDatabase -DatabaseServer $Tenant.DatabaseServer -DatabaseInstance $Tenant.DatabaseInstance -DatabaseName $Tenant.DatabaseName -ErrorAction Continue
            }
    
            if ($IsMultitenant) {
                write-Host -ForegroundColor Green "Removing ApplicationDB $($ServerInstanceObject.DatabaseName)"
                Remove-SQLDatabase -DatabaseServer $ServerInstanceObject.DatabaseServer -DatabaseInstance $ServerInstanceObject.DatabaseInstance -DatabaseName $ServerInstanceObject.DatabaseName 
            }
        } else {
            Remove-SQLDatabase -DatabaseServer $ServerInstanceObject.DatabaseServer -DatabaseInstance $ServerInstanceObject.DatabaseInstance -DatabaseName $ServerInstanceObject.DatabaseName 
        }
        
    }
}

