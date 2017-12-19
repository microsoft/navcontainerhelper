<# 
 .Synopsis
  Create or refresh a CSide Development container
 .Description
  Creates a new container based on a Nav Docker Image
  Adds shortcut on the desktop for CSIDE, Windows Client, Web Client and Container PowerShell prompt.
  The command also exports all objects to a baseline folder to be used for delta creation
 .Parameter accept_eula
  Switch, which you need to specify if you accept the eula for running Nav on Docker containers (See https://go.microsoft.com/fwlink/?linkid=861843)
 .Parameter containerName
  Name of the new CSide Development container (if the container already exists it will be replaced)
 .Parameter imageName
  Name of the image you want to use for your CSide Development container (default is to grab the imagename from the navserver container)
 .Parameter licenseFile
  Path or Secure Url of the licenseFile you want to use (default c:\programdata\navcontainerhelper\license.flf)
 .Parameter credential
  Username and Password for the NAV Container
 .Parameter memoryLimit
  Memory limit for the container (default 4G)
 .Parameter updateHosts
  Include this switch if you want to update the hosts file with the IP address of the container
 .Parameter useSSL
  Include this switch if you want to use SSL (https) with a self-signed certificate
 .Parameter doNotExportObjectsToText
  Avoid exporting objects for baseline from the container (Saves time, but you will not be able to use the object handling functions without the baseline)
 .Parameter alwaysPull
  Always pull latest version of the docker image
 .Parameter auth
  Set auth to Windows or NavUserPassword depending on which authentication mechanism your container should use
 .Parameter additionalParameters
  This allows you to transfer an additional number of parameters to the docker run
 .Parameter myscripts
  This allows you to specify a number of scripts you want to copy to the c:\run\my folder in the container (override functionality)
 .Example
  New-CSideDevContainer -containerName test
 .Example
  New-CSideDevContainer -containerName test -memoryLimit 3G -imageName "microsoft/dynamics-nav:2017" -updateHosts
 .Example
  New-CSideDevContainer -containerName test -adminPassword <mypassword> -licenseFile "https://www.dropbox.com/s/fhwfwjfjwhff/license.flf?dl=1" -imageName "microsoft/dynamics-nav:devpreview-finus"
#>
function New-CSideDevContainer {
    Param(
        [switch]$accept_eula,
        [switch]$accept_outdated,
        [Parameter(Mandatory=$true)]
        [string]$containerName, 
        [string]$imageName = "", 
        [string]$licenseFile = "",
        [System.Management.Automation.PSCredential]$Credential = $null,
        [string]$memoryLimit = "4G",
        [switch]$updateHosts,
        [switch]$useSSL,
        [switch]$doNotExportObjectsToText,
        [switch]$alwaysPull,
        [ValidateSet('Windows','NavUserPassword')]
        [string]$auth='Windows',
        [string[]]$additionalParameters = @(),
        [string[]]$myScripts = @()
    )

    New-NavContainer -accept_eula:$accept_eula `
                     -accept_outdated:$accept_outdated `
                     -containerName $containerName `
                     -imageName $imageName `
                     -licenseFile $licenseFile `
                     -credential $credential `
                     -memoryLimit $memoryLimit `
                     -includeCSide `
                     -doNotExportObjectsToText:$doNotExportObjectsToText `
                     -alwaysPull:$alwaysPull `
                     -updateHosts:$updateHosts `
                     -useSSL:$useSSL `
                     -auth $auth `
                     -additionalParameters $additionalParameters `
                     -myScripts $myScripts
}
Export-ModuleMember -function New-CSideDevContainer
