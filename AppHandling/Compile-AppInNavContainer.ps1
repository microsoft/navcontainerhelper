<# 
 .Synopsis
  Use Nav Container to Compile App
 .Description
 .Parameter containerName
  Name of the container which you want to use to compile the app
 .Parameter tenant
  tenant to use if container is multitenant
 .Parameter credential
  Credentials of the NAV SUPER user if using NavUserPassword authentication
 .Parameter appProjectFolder
  Location of the project. This folder (or any of its parents) needs to be shared with the container.
 .Parameter appOutputFolder
  Folder in which the output will be placed. This folder (or any of its parents) needs to be shared with the container. Default is $appProjectFolder\output.
 .Parameter appSymbolsFolder
  Folder in which the symbols of dependent apps will be placed. This folder (or any of its parents) needs to be shared with the container. Default is $appProjectFolder\symbols.
 .Parameter UpdateSymbols
  Add this switch to indicate that you want to download symbols for all dependent apps.
 .Example
  Compile-AppInNavContainer -containerName test -credential $credential -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"
 .Example
  Compile-AppInNavContainer -containerName test -appProjectFolder "C:\Users\freddyk\Documents\AL\Test"

#>
function Compile-AppInNavContainer {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$containerName,
        [Parameter(Mandatory=$false)]
        [string]$tenant = "default",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$credential,
        [Parameter(Mandatory=$true)]
        [string]$appProjectFolder,
        [Parameter(Mandatory=$false)]
        [string]$appOutputFolder = (Join-Path $appProjectFolder "output"),
        [Parameter(Mandatory=$false)]
        [string]$appSymbolsFolder = (Join-Path $appProjectFolder "symbols"),
        [switch]$UpdateSymbols
    )

    $startTime = [DateTime]::Now

    $containerProjectFolder = Get-NavContainerPath -containerName $containerName -path $appProjectFolder
    if ("$containerProjectFolder" -eq "") {
        throw "The appProjectFolder ($appProjectFolder) is not shared with the container."
    }

    $containerOutputFolder = Get-NavContainerPath -containerName $containerName -path $appOutputFolder
    if ("$containerOutputFolder" -eq "") {
        throw "The appOutputFolder ($appOutputFolder) is not shared with the container."
    }

    $containerSymbolsFolder = Get-NavContainerPath -containerName $containerName -path $appSymbolsFolder
    if ("$containerSymbolsFolder" -eq "") {
        throw "The appSymbolsFolder ($appSymbolsFolder) is not shared with the container."
    }

    if (!(Test-Path $appOutputFolder -PathType Container)) {
        New-Item $appOutputFolder -ItemType Directory | Out-Null
    }

    $appJsonFile = Join-Path $appProjectFolder 'app.json'
    $appJsonObject = Get-Content -Raw -Path $appJsonFile | ConvertFrom-Json
    $appName = $appJsonObject.Publisher + '_' + $appJsonObject.Name + '_' + $appJsonObject.Version + '.app'

    Write-Host "Using Symbols Folder: " $appSymbolsFolder
    if (!(Test-Path -Path $appSymbolsFolder -PathType Container)) {
        New-Item -Path $appSymbolsFolder -ItemType Directory | Out-Null
    }

    $dependencies = @(
        @{"publisher" = "Microsoft"; "name" = "Application"; "version" = $appJsonObject.application }
        @{"publisher" = "Microsoft"; "name" = "System"; "version" = $appJsonObject.platform }
    )

    $appJsonObject.dependencies | ForEach-Object {
        $dependencies += @{ "publisher" = $_.publisher; "name" = $_.name; "version" = $_.version }
    }
    
    $dependencies | ForEach-Object {
        $symbolsFile = Join-Path $appSymbolsFolder "$($_.name).app"
        if ($updateSymbols -or !(Test-Path -Path $symbolsFile -PathType Leaf)) {
            Write-Host "Downloading symbols: $($_.name).app"

            $session = Get-NavContainerSession -containerName $containerName -silent
            [xml]$customConfig = Invoke-Command -Session $session -ScriptBlock { 
                $customConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
                [System.IO.File]::ReadAllText($customConfigFile)
            }
            $serverInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value

            $DeveloperServicesPort = $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']").Value
            $DeveloperServicesSSLEnabled = $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesSSLEnabled']").Value
            if ($DeveloperServicesSSLEnabled -eq "true") {
                $protocol = "https://"
            } else {
                $protocol = "http://"
            }
            $devServerUrl = "${protocol}${containerName}:${DeveloperServicesPort}/${serverInstance}"
            $auth = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value

            $authParam = @{}
            if ($credential) {
                if ($auth -eq "Windows") {
                    Throw "You should not specify credentials when using Windows Authentication"
                }
                $pair = ("$($Credential.UserName):"+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)))
                $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
                $base64 = [System.Convert]::ToBase64String($bytes)
                $basicAuthValue = "Basic $base64"
                $headers = @{ Authorization = $basicAuthValue }
                $authParam += @{"headers" = $headers}
            } else {
                if ($auth -ne "Windows") {
                    Throw "You need to specify credentials when you are not using Windows Authentication"
                }
                $authParam += @{"usedefaultcredential" = $true}
            }

            $url = "$devServerUrl/dev/packages?publisher=$($_.publisher)&appName=$($_.name)&versionText=$($_.Version)&tenant=$tenant"
            Invoke-RestMethod -Method Get -Uri $url @AuthParam -OutFile $symbolsFile
        }
    }

    $session = Get-NavContainerSession -containerName $containerName -silent
    Invoke-Command -Session $session -ScriptBlock { Param($appProjectFolder, $appSymbolsFolder, $appOutputFile )

        if (!(Test-Path "c:\build" -PathType Container)) {
            Write-Host "Unpacking .vsix file"
            $tempZip = Join-Path $env:TEMP "alc.zip"
            Copy-item -Path (Get-Item -Path "c:\run\*.vsix").FullName -Destination $tempZip
            Expand-Archive -Path $tempZip -DestinationPath "c:\build\vsix"
        }
        $alcPath = 'C:\build\vsix\extension\bin'

        if (Test-Path -Path $appOutputFile -PathType Leaf) {
            Remove-Item -Path $appOutputFile -Force
        }

        Write-Host "Compiling..."
        Set-Location -Path $alcPath
        & .\alc.exe /project:$appProjectFolder /packagecachepath:$appSymbolsFolder /out:$appOutputFile | Out-Host

        if (!(Test-Path -Path $appOutputFile)) {
            throw "App generation failed"
        }

    } -ArgumentList $containerProjectFolder, $containerSymbolsFolder, (Join-Path $containerOutputFolder $appName)
    
    $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
    $appFile = Join-Path $appOutputFolder $appName
    Write-Host "$appFile successfully created in $timespend seconds"
    $appFile
}
Export-ModuleMember -Function Compile-AppInNavContainer
