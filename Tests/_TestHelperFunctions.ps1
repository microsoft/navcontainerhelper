$modulePath = Join-Path $PSScriptRoot "..\BcContainerHelper.psm1"
Remove-Module BcContainerHelper -ErrorAction Ignore
Import-Module $modulePath -DisableNameChecking

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
    $password
}

function Get-RandomPasswordAsSecureString {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification="Get Random password as secure string.")]
    Param()

    ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
}

$credential = [PSCredential]::new("admin", (Get-RandomPasswordAsSecureString))
