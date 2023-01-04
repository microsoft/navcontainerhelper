if (Test-Path "$($bccsScriptFolder)\.git") {
    try {
        $branch = &git -C $bccsScriptFolder rev-parse --abbrev-ref HEAD 
        $checkout = $true
        if ($branch -ne "master") {
            Write-Host "You are currently not on master branch but $($branch). Do you want to checkout origin/master?" -ForegroundColor Yellow
            $ReadHost = Read-Host " ( y / n ) "
            Switch ($ReadHost) {
                y { $checkout = $true }
                n { $checkout = $false }
                Default { $checkout = $false }
            }
        }
        if ($checkout) {
			Write-Host "Fetching..."
            git -C $bccsScriptFolder fetch
			Write-Host "Checking out master and/or pulling changes..."
            git -C $bccsScriptFolder checkout master
            git -C $bccsScriptFolder pull
        }
    }
    catch {
        Write-Host "Could not update using git"
    }
}