<#
 .Synopsis
  Get information about a submission of an AppSource product from the authenticated account
 .Description
  Returns a PSCustomObject with submission details
 .Parameter authContext
  Authentication Context from New-BcAuthContext
 .Parameter productId
  Id of the product for which you want to get a submission
 .Parameter submissionId
  Id of the submission for which you want to get information or leave empty for latest submission
 .Parameter includeWorkflowDetails
  Include this switch if you want to include workflow details for the submission
 .Parameter silent
  Include this switch if you do not want the method to display URLs etc.
 .Example
  Get-AppSourceSubmission -authContext $authcontext -productId $productId -includeWorkflowDetails
  GET https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions
  GET https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions/1152921505695125040
  GET https://api.partner.microsoft.com/v1.0/ingestion/products/5fbe0803-a545-4504-b41a-d9d158112360/submissions/1152921505695125040/workflowdetails

  resourceType       : Submission
  state              : Published
  substate           : InStore
  targets            : {@{type=Scope; value=Preview}}
  resources          : {@{type=Availability; value=4b8c7499-1cb3-acf6-9b5b-c45d2a7040e2}, @{type=Listing; value=0202f16e-e12b-a657-124e-27ed76542ad5}, @{type=Package; 
                       value=2d212b32-f3f4-4d43-ac9b-5783f7a6099f}, @{type=Property; value=ae0f3f9e-b893-bbde-4dd1-3ac0b50496ef}...}
  publishedTimeInUtc : 2022-08-04T13:53:31.2590809Z
  pendingUpdateInfo  : @{updateType=Create; status=Completed}
  releaseNumber      : 28
  friendlyName       : Submission 28
  areResourcesReady  : True
  id                 : 1152921505695125040
  WorkflowDetails    : {@{type=Push; state=Success; targetEnvironment=Preview; workflowSteps=System.Object[]; startDateTimeInUtc=2022-08-04T10:37:37.4038218; 
                       completeDateTimeInUtc=2022-08-04T10:51:26.8132496}, @{type=Push; state=Success; targetEnvironment=Live; workflowSteps=System.Object[]; 
                       startDateTimeInUtc=2022-08-04T10:51:57.0499235; completeDateTimeInUtc=2022-08-04T13:53:30.8277395}}

 .Example
  Get-AppSourceSubmission -authContext $authcontext -productId $productId -submissionid '1152921505695125040' -silent
  
  resourceType       : Submission
  state              : Published
  substate           : InStore
  targets            : {@{type=Scope; value=Preview}}
  resources          : {@{type=Availability; value=4b8c7499-1cb3-acf6-9b5b-c45d2a7040e2}, @{type=Listing; value=0202f16e-e12b-a657-124e-27ed76542ad5}, @{type=Package; 
                       value=2d212b32-f3f4-4d43-ac9b-5783f7a6099f}, @{type=Property; value=ae0f3f9e-b893-bbde-4dd1-3ac0b50496ef}...}
  publishedTimeInUtc : 2022-08-04T13:53:31.2590809Z
  pendingUpdateInfo  : @{updateType=Create; status=Completed}
  releaseNumber      : 28
  friendlyName       : Submission 28
  areResourcesReady  : True
  id                 : 1152921505695125040
#>
function Get-AppSourceSubmission {
    Param(
        [Parameter(Mandatory=$true)]
        [HashTable] $authContext,
        [Parameter(Mandatory=$true)]
        [string] $productId,
        [Parameter(Mandatory=$false)]
        [string] $submissionId = '',
        [switch] $includeWorkflowDetails,
        [switch] $silent
    )
    
$telemetryScope = InitTelemetryScope -name $MyInvocation.InvocationName -parameterValues $PSBoundParameters -includeParameters @()
try {
    $authContext = Renew-BcAuthContext -bcAuthContext $authContext
    if (-not $submissionId) {
        $submissions = @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$productId/submissions" -silent:($silent.IsPresent))
        if ($submissions.Count -eq 0) {
            return
        }
        $submissionId = ($submissions | Select-Object -Last 1).Id
    }
    $submission = Invoke-IngestionApiGet -authContext $authContext -path "/products/$productId/submissions/$submissionId" -silent:($silent.IsPresent)
    if (!$submission) {
        throw "Submission with ID $submissionId cannot be found"
    }
    if ($includeWorkflowDetails) {
        $submission | Add-Member -MemberType NoteProperty -Name "WorkflowDetails" -Value @(Invoke-IngestionApiGetCollection -authContext $authContext -path "/products/$($productId)/submissions/$($submission.id)/workflowdetails" -silent:($silent.IsPresent))
    }
    $submission
}
catch {
    TrackException -telemetryScope $telemetryScope -errorRecord $_
    throw
}
finally {
    TrackTrace -telemetryScope $telemetryScope
}
}
Export-ModuleMember -Function Get-AppSourceSubmission