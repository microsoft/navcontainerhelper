<#
 .Synopsis
  Promote AppSource Submission from Preview to Production (aka. press the Go Live button)
  The Submission must be ReadyToPublish in order for this function to work
  You cannot cancel the promote - once promoted - you cannot re-submit or cancel until submission is live
 .Description
  Returns a PSCustomObject with submission details
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter productId
  Id of the product for which you want to promote a submission
 .Parameter submissionId
  Id of the submission you want to promote or leave empty for latest submission
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  $submission = Promote-AppSourceSubmission -authContext $authcontext -productId $productId -silent
#>
function Promote-AppSourceSubmission {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $productId,
        [Parameter(Mandatory=$false)]
        [string] $submissionId = '',
        [switch] $silent
    )
    
$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $authContext = Renew-BcAuthContext -bcAuthContext $authContext
    $submission = Get-AppSourceSubmission -authContext $authContext -productId $productId -submissionId $submissionId -silent:($silent.IsPresent)
    if ($submission.state -eq "Published" -and $submission.substate -eq "ReadyToPublish") {
        Invoke-IngestionApiPost -authContext $authContext -path "/products/$productId/submissions/$($submission.id)/promote" -silent:($silent.IsPresent)
    }
    else {
        throw "Submission $($submission.id) is not ready to publish"
    }
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Promote-AppSourceSubmission