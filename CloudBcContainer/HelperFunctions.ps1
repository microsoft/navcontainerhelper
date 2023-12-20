function isCloudBcContainer {
    Param(
        [HashTable] $authContext = $null,
        [string] $containerId = ''
    )

    return (isAlpacaBcContainer -authContext $authContext -containerId $containerId)
}

function Get-WebClientUrlFromCloudBcContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId
    )

    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        Get-WebClientUrlFromAlpacaBcContainer -authContext $authContext -containerId $containerId
    }
    else {
        throw "Unknown cloud container"
    }

}

function Invoke-ScriptInCloudBcContainer {
    Param (
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $scriptblock,
        [Parameter(Mandatory=$false)]
        [Object[]] $argumentList,
        [switch] $silent
    )

    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        Invoke-ScriptInAlpacaBcContainer -authContext $authContext -containerId $containerId -scriptblock $scriptblock -argumentList $argumentList -silent:$silent
    }
    else {
        throw "Unknown cloud container"
    }
}

function Copy-FileFromCloudBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [string] $containerPath,
        [string] $localPath
    )

    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        Copy-FileFromAlpacaBcContainer -authContext $authContext -containerId $containerId -containerPath $containerPath -localPath $localPath
    }
    else {
        throw "Unknown cloud container"
    }
}

function Copy-FileToCloudBcContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [Alias('AlpacaAuthContext')]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $containerId,
        [string] $localPath,
        [string] $containerPath
    )
    
    if (isAlpacaBcContainer -authContext $authContext -containerId $containerId) {
        copy-FileToAlpacaBcContainer -authContext $authContext -containerId $containerId -localPath $localPath -containerPath $containerPath
    }
    else {
        throw "Unknown cloud container"
    }
}
