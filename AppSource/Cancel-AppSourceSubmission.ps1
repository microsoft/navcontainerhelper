<#
 .Synopsis
  Cancel AppSource Submission (aka. press the Cancel publish link)
  The Submission must be InProgress in order for this function to work
  After you promote a submission - you cannot re-submit or cancel until submission is live
 .Description
  Cancel AppSource Submission (aka. press the Cancel publish link)
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter productId
  Id of the product for which you want to cancel a submission
 .Parameter submissionId
  Id of the submission you want to cancel or leave empty for latest submission
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  Cancel-AppSourceSubmission -authContext $authcontext -productId $productId
  GET https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions
  GET https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions/1152921505695131548
  DELETE https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions/1152921505695131548
#>
function Cancel-AppSourceSubmission {
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
    if ($submission.state -eq "InProgress") {
        Invoke-IngestionApiDelete -authContext $authContext -path "/products/$productId/submissions/$($submission.id)" -silent:($silent.IsPresent)
    }
    else {
        throw "Submission $($submission.id) is not in progress. You cannot cancel a submission, which isn't in progress"
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
Export-ModuleMember -Function Cancel-AppSourceSubmission