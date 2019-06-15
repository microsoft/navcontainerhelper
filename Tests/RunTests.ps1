$ErrorActionPreference = "Stop"
$WarningPreference = "Stop"

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

AreEqual -expr "5+5" -expected "10"
