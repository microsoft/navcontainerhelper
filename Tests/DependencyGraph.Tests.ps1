Describe 'DependencyGraph' {

    BeforeAll {
        . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
    }
    
    AfterAll {
    }
    
    It 'SingleVersionDependencyGraph' {
        $appInfos = @(
            @{
                AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                Version = "20.1.0.1"
                Publisher = "BEYONDIT GmbH"
                Name = "Best App"
                Dependencies = @(
                )
            },
            @{
                AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                Version = "20.1.0.1"
                Publisher = "BEYONDIT GmbH"
                Name = "Core App"
                Dependencies = @(
                    @{
                        AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                        MinVersion = "20.0.0.0"
                    }
                )
            },
            @{
                AppId = "4d3506ca-458b-4bbc-b9e2-557562bf49be"
                Version = "20.0.0.1"
                Publisher = "BEYONDIT GmbH"
                Name = "Second Best App"
                Dependencies = @(
                    @{
                        AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                        MinVersion = "20.0.0.0"
                    },
                    @{
                        AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                        MinVersion = "20.0.0.0"
                    }
                )
            }
        )
        $dependencyGraph = Create-DependencyGraph -appInfos $appInfos

        $dependents = $dependencyGraph.GetDependents("9abe2dcb-1acc-460a-9c07-e110dc216540","20.1.0.1")
        Write-Host ($dependents | ConvertTo-Json)

        $dependents.Count | Should Be 2
        $dependents[0].Id | Should Be "4d3506ca-458b-4bbc-b9e2-557562bf49be"

        $dependents = $dependencyGraph.GetDependencies("9abe2dcb-1acc-460a-9c07-e110dc216540","20.1.0.1")
        $dependents.Count | Should Be 0

        $dependents = $dependencyGraph.GetDependents("4d3506ca-458b-4bbc-b9e2-557562bf49be","20.1.0.1")
        $dependents.Count | Should Be 0

        $dependents = $dependencyGraph.GetDependencies("4d3506ca-458b-4bbc-b9e2-557562bf49be","20.0.0.1")
        $dependents.Count | Should Be 2
        $dependents[0].Id | Should Be "9abe2dcb-1acc-460a-9c07-e110dc216540"
        $dependents[1].Id | Should Be "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
    }
}