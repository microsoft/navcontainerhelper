function Get-NAVDataUpgradeContinuous {
    param(
        [Parameter(Mandatory=$true)]
        [String] $ServerInstance
    )

    $Stop = $false
    while (!$Stop){
        $NAVDataUpgradeStatus = Get-NAVDataUpgrade -ServerInstance $ServerInstance 
        Write-Host "$($NAVDataUpgradeStatus.State) -- $($NAVDataUpgradeStatus.Progress)" -ForeGroundColor Gray
        if ($NAVDataUpgradeStatus.State -eq 'Suspended') {
            Resume-NAVDataUpgrade -ServerInstance $ServerInstance 
        }
        if (($NAVDataUpgradeStatus.State -eq 'Stopped') -or ($NAVDataUpgradeStatus.State -eq 'Completed')) {
            $Stop = $true
        }
        $ErrorsDataUpgrade = Get-NAVDataUpgrade -ServerInstance $ServerInstance -ErrorOnly
        if ($ErrorsDataUpgrade) {
            foreach($ErrorDataUpgrade in $ErrorsDataUpgrade){
                Write-Error "Error in function $($ErrorDataUpgrade.FunctionName) and Company $($ErrorDataUpgrade.CompanyName)`r`n $($ErrorDataUpgrade.Error)"
            }
            $Stop = $true
        }
        Start-Sleep 2
    }

    write-host "Data upgrade status: $($NAVDataUpgradeStatus.State)" -ForegroundColor Green
}