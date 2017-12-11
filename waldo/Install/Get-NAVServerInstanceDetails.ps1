<#
.Synopsis
   Get all details from an NAV ServerInstance
.DESCRIPTION
   Combination of the output of Get-NAVServerInstance and Get-NAVServerConfiguration
.NOTES
   Use only when needed - slower as the original CmdLets
.PREREQUISITES
   Use Microsoft.Dynamics.NAV.Management module
#>

function Get-NAVServerInstanceDetails
 {
     [CmdletBinding()]
     Param
     (
         [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
         $ServerInstance
     )

     Process
     {
         $ServerInstance | Get-NAVServerInstance | Foreach {
             $ServerConfig = New-Object PSObject
             
             foreach ($Attribute in $_.Attributes) {
                $ServerConfig | Add-Member -MemberType NoteProperty -Name $Attribute.Name -Value $Attribute.Value -Force
             }
             
             foreach ($Node in ($_ | Get-NavServerConfiguration -AsXml).configuration.appSettings.add) {
                $ServerConfig | Add-Member -MemberType NoteProperty -Name $Node.key -Value $Node.value -Force
             }
                
             $ServerConfig
         }
     }
}
