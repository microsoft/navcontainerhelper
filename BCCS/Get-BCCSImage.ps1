<# 
 .Synopsis
  Create a new template to be used with the Business Central Container Script
 .Description
  This command will create a new template entry in a JSON file. If no file is specified it will be created in the user's appdata folder.
 .Parameter file
  Name of the container in which you want to backup databases
 .Parameter prefix
  Prefix to use for any container's name created from the template
 .Example
  New-BCCSTemplate -prefix BC365 -name "Business Central" -image "mcr.microsoft.com/businesscentral/onprem"
#>

function Get-BCCSImage {
    Param (
        [Parameter(ValueFromPipeline = $true)]
        $repositoryObject
    )

    if (!$repositoryObject) {
        Write-Log "No repository in parameter set. Showing repository list..."
        $repositoryObject = Get-BCCSRepository | Out-GridView -Title "Select a repository" -OutputMode Single
    }

    try {
        $result = Invoke-WebRequest -Uri $repositoryObject.tagsUrl
        $JSON = ConvertFrom-Json -InputObject $result.Content
        $images = $JSON.tags | Where-Object { $_ -notmatch "ltsc" } | ForEach-Object {
            $repositoryObject.baseUrl + ":" + $_
        }
    }
    catch {
        throw "Could not retrieve images from $($repositoryObject.tagsUrl)"
    }

    return $images
}

Export-ModuleMember -Function Get-BCCSImage