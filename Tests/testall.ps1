# Run all tests

Clear-Host
$global:testErrors = @()
$global:currentTest = ""
Clear-Content -Path "c:\temp\errors.txt" -ErrorAction Ignore

function randomchar([string]$str)
{
    $rnd = Get-Random -Maximum $str.length
    [string]$str[$rnd]
}

function Get-RandomPassword {
    $cons = 'bcdfghjklmnpqrstvwxz'
    $voc = 'aeiouy'
    $numbers = '0123456789'
    $special = '!*.:-$#@%'

    $password = (randomchar $cons).ToUpper() + `
                (randomchar $voc) + `
                (randomchar $cons) + `
                (randomchar $voc) + `
                (randomchar $special) + `
                (randomchar $numbers) + `
                (randomchar $numbers) + `
                (randomchar $numbers) + `
                (randomchar $numbers) + `
                (randomchar $special)
    Write-Host "Use password $password"
    $password
}

function Get-RandomPasswordAsSecureString {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification="Get Random password as secure string.")]
    Param()

    ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
}

function Head($text) {
    try {
        $s = (New-Object System.Net.WebClient).DownloadString("http://artii.herokuapp.com/make?text=$text")
    } catch {
        $s = $text
    }
    Write-Host -ForegroundColor Yellow $s
}

function Error($error) {
    $str = ("ERROR: " + $global:currentTest + ": " + $error)
    Write-Host -ForegroundColor Red $str
    $global:testErrors += @($str)
    Add-Content -Path "c:\temp\errors.txt" -Value $str
}

function Test($test) {
    Write-Host -ForegroundColor Yellow $test
    $global:currentTest = $test
}

function AreEqual($expr, $expected) {
    $result = (Invoke-Expression $expr)
    if ($result -ne $expected) {
        Error "$expr returns '$result', expected '$expected'"
    }
}

function IsUrl($expr) {
    $result = [string](Invoke-Expression $expr)
    $result = $result.ToString().ToLowerInvariant()
    if (!($result.startsWith("http://") -or $result.startsWith("https://"))) {
        Error "$expression returns '$result', expected a URL"
    }
    Download-File -sourceUrl $result -destinationFile (Join-Path $env:TEMP "Test.htm")
}

$genericImage = "microsoft/dynamics-nav:generic"
docker pull $genericImage
$genericTag = Get-NavContainerGenericTag -containerOrImageName $genericImage

$windowsCredential = get-credential -UserName $env:USERNAME -Message "Please enter your Windows credentials if you want to include Windows Auth testing"
$aadAdminCredential = get-credential -Message "Please enter your AAD Admin credentials if you want to include AAD auth testing"

$testParams = @(
    @{ "name" = "n2018w1"; "image" = "microsoft/dynamics-nav"                   ; "country" = "w1" },
    @{ "name" = "n2018de"; "image" = "microsoft/dynamics-nav:de"                ; "country" = "de" },
    @{ "name" = "bcshw1";  "image" = "microsoft/bcsandbox"                      ; "country" = "w1" },
    @{ "name" = "bcshnl";  "image" = "microsoft/bcsandbox:nl"                   ; "country" = "nl" },
    @{ "name" = "n2016w1"; "image" = "microsoft/dynamics-nav:2016"              ; "country" = "w1" },
    @{ "name" = "n2016dk"; "image" = "microsoft/dynamics-nav:2016-dk"           ; "country" = "dk" },
    @{ "name" = "n2017w1"; "image" = "microsoft/dynamics-nav:2017"              ; "country" = "w1" },
    @{ "name" = "n2017na"; "image" = "microsoft/dynamics-nav:2017-na"           ; "country" = "na" },
    @{ "name" = "n2018w1"; "image" = "microsoft/dynamics-nav"                   ; "country" = "w1" },
    @{ "name" = "n2018de"; "image" = "microsoft/dynamics-nav:de"                ; "country" = "de" },
    @{ "name" = "bcmjw1";  "image" = "bcinsider.azurecr.io/bcsandbox"           ; "country" = "w1" },
    @{ "name" = "bcmjw1";  "image" = "bcinsider.azurecr.io/bcsandbox:be"        ; "country" = "be" },
    @{ "name" = "bcmaw1";  "image" = "bcinsider.azurecr.io/bcsandbox-master"    ; "country" = "w1" },
    @{ "name" = "bcmaw1";  "image" = "bcinsider.azurecr.io/bcsandbox-master:es" ; "country" = "es" }
)

$testContainerInfo = $true
$testBacpac = $true
$testAppHandling = $true
$testObjectHandling = $true
$testContainerHandling = $true
$testTenantHandling = $true
$testUserHandling = $true
$useSSL = $false

$testParams | ForEach-Object {
    $name = $_.name
    $image = $_.image
    $country = $_.country
    $containerPath = Join-Path "C:\ProgramData\NavContainerHelper\Extensions" $name
    $myPath = Join-Path $containerPath "my"

    $false, $true | ForEach-Object {
        $multitenant = $_

        $testAuths = @("NavUserPassword")
        if ($windowsCredential) {
            $testAuths += @("Windows")
        }
        if ($aadAdminCredential) {
            $testAuths += @("AAD")
        }

        $testAuths | ForEach-Object {
            $auth = $_

            $addParams = @{}

            if ($auth -eq "Windows") {
                $credential = $windowsCredential
            } else {
                $credential = [PSCredential]::new("admin", (Get-RandomPasswordAsSecureString))
                if ($auth -eq "AAD") {
                    $protocol = "http://"
                    if ($useSSL) {
                        $protocol = "https://"
                    }
                    Create-AadAppsForNavContainer -AadAdminCredential $AadAdminCredential `
                                                  -appIdUri "$protocol$name/nav/" `
                                                  -iconPath "c:\temp\nav.png" | Out-Null
                    $addParams += @{ "authenticationEMail" = $AadAdminCredential.UserName }
                }
            }

            $mt = "Single tenant"
            if ($multitenant) {
                $mt = "Multi tenant"
            }

            Head $image.Substring(0,$image.IndexOf('/')+1)
            Head $image.Substring($image.IndexOf('/')+1)
            Head "$auth auth."
            Head $mt

            try {

                Test "New-NavContainer"
                New-NavContainer -accept_eula `
                                 -containerName $name `
                                 -imageName $image `
                                 -Credential $credential `
                                 -auth $auth @addParams `
                                 -multitenant:$multitenant `
                                 -updateHosts `
                                 -includecside `
                                 -licenseFile "C:\temp\mylicense.flf" `
                                 -timeout -1

                $navVersionStr = Get-NavContainerNavVersion -containerOrImageName $name
                $navVersion = [Version]($navVersionStr.subString(0,$navversionStr.indexOf('-')))
                $containerId = Get-NavContainerId -containerName $name

                if ($TestContainerInfo) {
    
                    Head -text "ContainerInfo"
    
                    try {
    
                        Test "Get-NavContainerCountry"
                        AreEqual -expr "Get-NavContainerCountry -containerOrImageName $image" -expected $country
                        AreEqual -expr "Get-NavContainerCountry -containerOrImageName $name" -expected $country
        
                        Test "Get-NavContainerEula"
                        IsUrl -expr "Get-NavContainerEula -containerOrImageName $image"
                        IsUrl -expr "Get-NavContainerEula -containerOrImageName $name"
        
                        Test "Get-NavContainerLegal"
                        IsUrl -expr "Get-NavContainerLegal -containerOrImageName $image"
                        IsUrl -expr "Get-NavContainerLegal -containerOrImageName $name"
        
                        Test "Get-NavContainerGenericTag"
                        AreEqual -expr "Get-NavContainerGenericTag -containerOrImageName $image" -expected $genericTag
                        AreEqual -expr "Get-NavContainerGenericTag -containerOrImageName $name" -expected $genericTag
        
                        Test "Get-NavContainerEventLog"
                        Get-NavContainerEventLog -containerName $name -doNotOpen
                        if (!(Test-Path -Path (Join-Path $myPath "*.evtx") -PathType Leaf)) {
                            Error "Get-NavContainerEventLog didn't create log file in $myPath"
                        }
        
                        Test "Get-NavContainerId"
                        Test "Get-NavContainerName"
                        AreEqual -expr "Get-NavContainerName -containerId $containerId" -expected $name
        
                        Test "Get-NavContainerImageName"
                        $image2 = $image
                        if (!($image2.Contains(":"))) {
                            $image2 = "${image}:latest"
                        }
                        AreEqual -expr "Get-NavContainerImageName -containerName $name" -expected $image2
        
                        Test "Get-NavContainerIpAddress"
                        $ip = Get-NavContainerIpAddress -containerName $name
                        $hostsFileName = "C:\Windows\System32\drivers\etc\hosts"
                        $hosts = Get-Content -Path $hostsFileName
                        if (!($hosts.Contains("$ip $name"))) {
                            Error "Hosts file does not contain $ip $name"
                        }
        
                        Test "Get-NavContainerPath"
                        AreEqual -expr "Get-NavContainerPath -containerName $name -path $hostsFileName" -expected "c:\driversetc\hosts"
        
                        Test "Get-NavContainerSharedFolders"
                        $sharedFolders = Get-NavContainerSharedFolders -containerName $name
                        $hostMyPath = foreach ($Key in ($sharedFolders.GetEnumerator() | Where-Object {$_.Value -eq "c:\run\my"})) { $Key.name }
                        AreEqual -expr '$hostMyPath' -expected $myPath
                        
                        Test "Get-NavContainerNavVersion"
                        $version = Get-NavContainerNavVersion -containerOrImageName $name
                        $temp = $image+':'
                        $image2 = $temp.subString(0,$temp.indexOf(':')+1)+$version.ToLowerInvariant()
                        docker pull $image2
                        AreEqual -expr "Get-NavContainerNavVersion -containerOrImageName $image2" -expected $version
                        AreEqual -expr "Get-NavContainerNavVersion -containerOrImageName $image" -expected $version
        
                        Test "Get-NavContainerOsVersion"
                        $osVersion = Get-NavContainerOsVersion -containerOrImageName $image
                        $version = [Version]$OsVersion
                        AreEqual -expr "Get-NavContainerOsVersion -containerOrImageName $name" -expected $osVersion
        
                        Test "Test-NavContainer"
                        AreEqual -expr "Test-NavContainer -containerName $name" -expected $true
                        AreEqual -expr "Test-NavContainer -containerName qwerty" -expected $false
        
                        Test "Get-NavContainerDebugInfo"
                        $debugInfo = Get-NavContainerDebugInfo -containerName $name | ConvertFrom-Json
                        AreEqual -expr '$debugInfo.''container.labels''.osversion' -expected $osVersion
                        AreEqual -expr '$debugInfo.''container.labels''.maintainer' -expected "Dynamics SMB"
    
                    } catch {
                        Error -error $_.Exception.Message
                    }
                }
 
                Test "Docker Restart"
                docker restart $containerId | Out-Null

                Test "Wait-ContainerReady"
                Wait-NavContainerReady -containerName $name -timeout 60
  
                Start-Sleep -Seconds 60

                if ($testAppHandling -and ($navVersion.Major -ge 11)) {
                    
                    Head -text "AppHandling"
    
                    try {

                        Test "Compile-AppInNavContainer"
                        Copy-Item -Path (Join-Path $PSScriptRoot "app") -Destination $containerPath -Recurse -Force
                        $appProjectFolder = Join-Path $containerPath "app"
                        $appOutputFolder = Join-Path $appProjectFolder "output"
                        $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

                        $appName = "Hello World"
                        $appPublisher = "Microsoft"
                        $appVersion = "1.0.0.0"

                        $appJson = Get-Content (Join-Path $appProjectFolder "app.json") | ConvertFrom-Json
                        $appJson.application = ($navVersion.Major.ToString()+".0.0.0")
                        $appJson.platform = ($navVersion.Major.ToString()+".0.0.0")
                        $appJson.id = [Guid]::NewGuid().ToString()
                        $appJson.name = $appName
                        $appJson.publisher = $appPublisher
                        $appJson.version = $appVersion
                        Add-Member -InputObject $appJson -NotePropertyName "dependencies" -NotePropertyValue @() -ErrorAction SilentlyContinue
                        $appJson | ConvertTo-Json | Set-content (Join-Path $appProjectFolder "app.json")

                        $authParam = @{}
                        if ($auth -ne "Windows") {
                            $authParam += @{ "Credential" = $credential }
                        }
                        Compile-AppInNavContainer -containerName $name -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols @authParam

                        Test "Get-NavContainerAppInfo"
                        $count = @(Get-NavContainerAppInfo -containerName $name).Count

                        Test "Publish-NavContainerApp"
                        $appFile = (Get-item "$appoutputfolder\*.app").FullName
                        Publish-NavContainerApp -containerName $name -appFile $appFile -skipVerification -sync -install

                        Test "Get-NavContainerAppInfo"
                        AreEqual -expr "@(Get-NavContainerAppInfo -containerName $name).Count" -expected ($count+1)

                        Test "Unpublish-NavContainerApp"
                        UnPublish-NavContainerApp -containerName $name -appName $appName -publisher $appPublisher -version $appVersion -unInstall

                        Test "Get-NavContainerAppInfo"
                        AreEqual -expr "@(Get-NavContainerAppInfo -containerName $name).Count" -expected $count
    
                    } catch {
                        Error -error $_.Exception.Message
                    }
                }

                if ($testObjectHandling) {
    
                    Head -text "ObjectHandling"
    
                    $txtFile = Join-Path $PSScriptRoot "test.txt"
                    $deltaFolder = Join-Path $PSScriptRoot "delta"
                    $myDeltaFolder = Join-Path $myPath "delta"
                    $objectsFolder = Join-Path $myPath "objects"
    
                    try {

                        Test "Import-ObjectsToNavContainer (.txt)"
                        Import-ObjectsToNavContainer -containerName $name `
                                                     -objectsFile $txtFile
    
                        Test "Compile-ObjectsInNavContainer"
                        Compile-ObjectsInNavContainer -containerName $name
    
                        Test "Export-NavContainerObjects (fob file)"
                        Export-NavContainerObjects -containerName $name -exportTo 'fob file' -objectsFolder $objectsFolder -filter "Modified=Yes"
    
                        $fobFile = Join-Path $objectsFolder "objects.fob"
                        Test "Import-ObjectsToNavContainer (.fob)"
                        Import-ObjectsToNavContainer -containerName $name `
                                                     -objectsFile $fobFile
    
                        Test "Import-DeltasToNavContainer"
                        if (Test-Path -Path $myDeltaFolder) {
                            Remove-Item -Path $myDeltaFolder -Recurse -Force
                        }
                        Copy-Item -Path $deltaFolder -Destination $myPath -Recurse
                        Import-DeltasToNavContainer -containerName $name `
                                                    -deltaFolder $myDeltaFolder
    
                        if ($auth -eq "Windows") {
                            Test "Compile-ObjectsInNavContainer"
                            Compile-ObjectsInNavContainer -containerName $name
                        }
    
                        if ($testAppHandling -and ($navVersion.Major -ge 11)) {

                            Test "Convert-ModifiedObjectsToAl"
                            Convert-ModifiedObjectsToAl -containerName $name `
                                                        -startId 50100

                            Test "New-NavContainer (compiler)"
                            New-NavContainer -accept_eula `
                                             -containerName compiler `
                                             -imageName $image `
                                             -Credential $credential `
                                             -auth $auth `
                                             -updateHosts `
                                             -licenseFile "C:\temp\mylicense.flf"


                            Test "Compile-AppInNavContainer"
                            $appProjectFolder = Join-Path $containerPath "al-newsyntax"
                            $appOutputFolder = Join-Path $appProjectFolder "output"
                            $appSymbolsFolder = Join-Path $appProjectFolder "symbols"

                            $appJson = Get-Content (Join-Path $PSScriptRoot "app.json") | ConvertFrom-Json
                            $appJson.application = ($navVersion.Major.ToString()+".0.0.0")
                            $appJson.platform = ($navVersion.Major.ToString()+".0.0.0")
                            $appJson.id = [Guid]::NewGuid().ToString()
                            $appJson | ConvertTo-Json | Set-content (Join-Path $appProjectFolder "app.json")

                            $authParam = @{}
                            if ($auth -ne "Windows") {
                                $authParam += @{ "Credential" = $credential }
                            }

                            Compile-AppInNavContainer -containerName compiler -appProjectFolder $appProjectFolder -appOutputFolder $appOutputFolder -appSymbolsFolder $appSymbolsFolder -UpdateSymbols @authParam

                            Test "Publish-NavContainerApp"
                            $appFile = (Get-item "$appoutputfolder\*.app").FullName
                            Publish-NavContainerApp -containerName compiler -appFile $appFile -skipVerification -sync -install

                            Test "Unpublish-NavContainerApp"
                            UnPublish-NavContainerApp -containerName compiler -appName TestApp -publisher TestApp -version "1.0.0.0" -unInstall

                            Test "Remove-NavContainer (compiler)"
                            Start-Sleep -Seconds 15
                            Remove-NavContainer -containerName compiler
                        }

                    } catch {
                        Error -error $_.Exception.Message

                        if (Test-NavContainer -containerName compiler) {
                            Start-Sleep -Seconds 15
                            Remove-NavContainer -containerName compiler
                        }
                    }
                }

                if ($testTenantHandling -and $multitenant)  {
    
                    Head -text "TenantHandling"
    
                    try {
    
                        AreEqual -expr "@(Get-NavContainerTenants -containerName $name).Count" -expected 1
        
                        1..3 | ForEach-Object { 
                            New-NavContainerTenant -containerName $name -tenantId "test$_"
                        }
        
                        AreEqual -expr "@(Get-NavContainerTenants -containerName $name).Count" -expected 4
        
                        1..3 | ForEach-Object { 
                            Remove-NavContainerTenant -containerName $name -tenantId "test$_"
                        }
        
                        AreEqual -expr "@(Get-NavContainerTenants -containerName $name).Count" -expected 1
    
                    } catch {
                        Error -error $_.Exception.Message
                    }
                }
    
                if ($testUserHandling) {
    
                    Head -text "UserHandling"
    
                    try {
    
                        $windowsusername = "user manager\containeradministrator"
                        $credential2 = [PSCredential]::new("extra", (Get-RandomPasswordAsSecureString))
        
                        if ($multitenant) {
                            Test "New-NavContainerTenant"
                            New-NavContainerTenant -containerName $name -tenantId UserTest
        
                            Test "Get-NavContainerNavUser"
                            $count = @(Get-NavContainerNavUser -containerName $name -tenant UserTest).Count

                            Test "New-NavContainerNavUser"
                            if ($auth -eq "Windows") {
                                New-NavContainerNavUser -containerName $name -tenant UserTest -WindowsAccount $windowsusername -PermissionSetId SUPER
                            } else {
                                New-NavContainerNavUser -containerName $name -tenant UserTest -Credential $credential2 -PermissionSetId SUPER
                            }
        
                            Test "Get-NavContainerNavUser"
                            AreEqual -expr "@(Get-NavContainerNavUser -containerName $name -tenant UserTest).Count" -expected ($count+1)
        
                            if ($navVersion.Major -ge 12) {
                                Test "Setup-NavContainerTestUsers"
                                Setup-NavContainerTestUsers -containerName $name -tenant UserTest -password $credential2.Password
                                AreEqual -expr "@(Get-NavContainerNavUser -containerName $name -tenant UserTest).Count" -expected ($count+7)
                            }
        
                        } else {
                            Test "Get-NavContainerNavUser"
                            $count = @(Get-NavContainerNavUser -containerName $name).Count

                            Test "New-NavContainerNavUser"
                            if ($auth -eq "Windows") {
                                New-NavContainerNavUser -containerName $name -WindowsAccount $windowsusername -PermissionSetId SUPER
                            } else {
                                New-NavContainerNavUser -containerName $name -Credential $credential2 -PermissionSetId SUPER
                            }
        
                            Test "Get-NavContainerNavUser"
                            AreEqual -expr "@(Get-NavContainerNavUser -containerName $name).Count" -expected ($count+1)
        
                            if ($navVersion.Major -ge 12) {
                                Test "Setup-NavContainerTestUsers"
                                Setup-NavContainerTestUsers -containerName $name -password $credential2.Password
                                AreEqual -expr "@(Get-NavContainerNavUser -containerName $name).Count" -expected ($count+7)
                            }
                        }
                    } catch {
                        Error -error $_.Exception.Message
                    }
                }
    
                if ($testBacpac) {

                    Head -text "Bacpac"
    
                    try {

                        $authParam = @{}
                        if ($auth -ne "Windows") {
                            $authParam += @{ "sqlCredential" = $credential }
                        }

                        Test "Export-NavContainerDatabasesAsBacpac"
                        Export-NavContainerDatabasesAsBacpac -containerName $name @authParam -bacpacFolder $containerPath -tenant default

                    } catch {
                        Error -error $_.Exception.Message
                    }
                }

                Test "Remove-NavContainer"
                Start-Sleep -Seconds 15
                Remove-NavContainer $name
    
            } catch {
                Error -error $_.Exception.Message
            }
        }
    }
}
