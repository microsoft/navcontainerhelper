<# 
 .Synopsis
  Gets all available repositories for NAV / Business Central images
 .Description
  This command will create a new template entry in a JSON file. If no file is specified it will be created in the user's appdata folder.
#>

function Get-BCCSRepository {
    $repoList = @(
        [PSCustomObject]@{name = "OnPrem"; desc = "OnPrem Versions of Business Central"; baseUrl = "mcr.microsoft.com/businesscentral/onprem"; tagsUrl = "https://mcr.microsoft.com/v2/businesscentral/onprem/tags/list" },
        [PSCustomObject]@{name = "SaaS"; desc = "SaaS Versions of Business Central"; baseUrl = "mcr.microsoft.com/businesscentral/sandbox"; tagsUrl = "https://mcr.microsoft.com/v2/businesscentral/sandbox/tags/list" },
        [PSCustomObject]@{name = "NAV"; desc = "Old(er) versions of NAV"; baseUrl = "mcr.microsoft.com/dynamicsnav"; tagsUrl = "https://mcr.microsoft.com/v2/dynamicsnav/tags/list" }
    )

    return $repoList
}

Export-ModuleMember -Function Get-BCCSRepository