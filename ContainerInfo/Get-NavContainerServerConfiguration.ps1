<# 
 .Synopsis
  Retrieve the Server configuration from a NAV/BC Container as a powershell object
 .Description
  Returns all the settings of the middletier from a container.
 .Parameter containerName
  Name of the container for which you want to get the server configuration
 .Example
  Get-NavContainerServerConfiguration -ContainerName "MyContainer"
#>
Function Get-NavContainerServerConfiguration {
    Param (
        [Parameter(Mandatory=$true)]
        [String] $ContainerName
    )

    $ResultObjectArray = @()
    $config = Invoke-ScriptInNavContainer -containerName $containerName -ScriptBlock{
        Get-NAVServerConfiguration -ServerInstance $ServerInstance -AsXml
    }
    
    $Object = New-Object -TypeName PSObject -Property @{
        ContainerName = $ContainerName
    }

    $Config.configuration.appSettings.add | ForEach-Object{
        $Object | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value
    }

    $ResultObjectArray += $Object
    
    Write-Output $ResultObjectArray
}
Set-Alias -Name Get-BCContainerServerConfiguration -Value Get-NavContainerServerConfiguration
Export-ModuleMember -Function Get-NavContainerServerConfiguration -Alias Get-BCContainerServerConfiguration
