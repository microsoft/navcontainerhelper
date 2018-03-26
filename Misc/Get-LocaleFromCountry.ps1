function Get-LocaleFromCountry {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$country
    )

    $country = $country.ToLowerInvariant()
    if ($country.StartsWith("fin")) { $country = $country.Substring(3) }

    $locales = @{
        "at"    = "de-AT"
        "au"    = "en-AU" 
        "be"    = "nl-BE"
        "ch"    = "de-CH"
        "cz"    = "cs-CZ"
        "de"    = "de-DE"
        "dk"    = "da-DK"
        "es"    = "es-ES"
        "fi"    = "fi-FI"
        "fr"    = "fr-FR"
        "gb"    = "en-GB"
        "in"    = "en-IN"
        "is"    = "is-IS"
        "it"    = "it-IT"
        "na"    = "en-US"
        "nl"    = "nl-NL"
        "no"    = "nb-NO"
        "nz"    = "en-NZ"
        "ru"    = "ru-RU"
        "se"    = "sv-SE"
        "w1"    = "en-US"
        "us"    = "en-US"
        "mx"    = "es-MX"
        "ca"    = "en-CA"
        "dech"  = "de-CH"
        "frbe"  = "fr-BE"
        "frca"  = "fr-CA"
        "frch"  = "fr-CH"
        "itch"  = "it-CH"
        "nlbe"  = "nl-BE"
    }

    return $locales[$country]
}
Export-ModuleMember Get-LocaleFromCountry
