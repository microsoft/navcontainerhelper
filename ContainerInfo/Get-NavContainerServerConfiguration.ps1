<# 
 .Synopsis
  Retrieve the NAV server configuration as a powershell object.
 .Description
  Returns all the settings of the middletier from a container.
 .Example
  Get-NavContainerServerConfiguration -ContainerName "MyContainer"
#>
Function Get-NavContainerServerConfiguration{
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ContainerName
    )

    $ResultObjectArray = @()
    $Session = Get-NavContainerSession -containerName $ContainerName -silent

    $Config = Invoke-Command -Session $Session -ScriptBlock{
        Get-NAVServerInstance -ServerInstance NAV | Get-NAVServerConfiguration -AsXml
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

Export-ModuleMember -function Get-NavContainerServerConfiguration