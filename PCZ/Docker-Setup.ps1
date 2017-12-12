# Invoke default behavior
. (Join-Path $runPath $MyInvocation.MyCommand.Name)

# additional setups
$UseSSL = "N" 
$accept_eula = "Y"
$ExitOnError = "N"
$ClickOnce = "Y"
$licensefile = (Join-Path $myPath "license.flf")

