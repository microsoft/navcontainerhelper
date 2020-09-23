if (Test-Path .\.git) {
    try {
        $branch = &git -C $bccsScriptFolder rev-parse --abbrev-ref HEAD 
        $checkout = $true
        if ($branch -ne "master") {
            Write-host "You are currently not on master branch but $($branch). Do you want to checkout origin/master?" -ForegroundColor Yellow
            $ReadHost = Read-Host " ( y / n ) "
            Switch ($ReadHost) {
                y { $checkout = $true }
                n { $checkout = $false }
                Default { $checkout = $false }
            }
        }
        if ($checkout) {
            git -C $bccsScriptFolder fetch
            git -C $bccsScriptFolder checkout master
            git -C $bccsScriptFolder pull
        }
    }
    catch {
        Write-Log "Could not update using git"
    }
}