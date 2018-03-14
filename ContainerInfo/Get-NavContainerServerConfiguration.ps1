<# 
 .Synopsis
  Retrieve the NAV server configuration as a powershell object.
 .Description
  Returns all the settings of the middletier from a container.
 .Example
  Get-NavContainerServerConfiguration -ContainerName "MyContainer"
#>
Function Get-NavContainerServerConfiguration{
    [Cmdletbinding()]
    Param(
        [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][String]$ContainerName,
        [parameter(ValueFromPipelineByPropertyName=$true)][string]$ServerInstance="NAV"
    )

    begin
    {
        $ResultObjectArray = @()
    }

    process
    {
        $Session = Get-NavContainerSession -containerName $ContainerName -silent -ErrorAction:$ErrorActionPreference
        $Config = Invoke-Command -Session $Session -ScriptBlock{
            [Cmdletbinding()]
            Param(
                [Parameter(Mandatory=$true)][string]$ServerInstance
            )
    
            Get-NAVServerInstance -ServerInstance $ServerInstance | Get-NAVServerConfiguration -AsXml
    
        } -ArgumentList $ServerInstance -ErrorAction:$ErrorActionPreference
    
        $Object = New-Object -TypeName PSObject -Property @{
            ContainerName = $ContainerName
        }

        $Config.configuration.appSettings.add | ForEach-Object{
            $Object | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
        }

        $ResultObjectArray += $Object
    }

    end
    {
        Write-Output $ResultObjectArray
    }
}

Export-ModuleMember -function Get-NavContainerServerConfiguration