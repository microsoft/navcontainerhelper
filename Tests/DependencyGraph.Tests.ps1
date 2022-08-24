

. (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')

InModuleScope BcContainerHelper {
    Describe 'DependencyGraph General' {

        BeforeAll {
            $script:appInfos = @(
                @{
                    AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                    Version = "20.1.0.1"
                    Publisher = "BEYONDIT GmbH"
                    Name = "Best App"
                    Dependencies = @(
                    )
                },
                @{
                    AppId = "ce3a5b0f-cc56-490b-bdf7-363dc840de9d"
                    Version = "21.0.0.0"
                    Publisher = "BEYONDIT GmbH"
                    Name = "Third Best App"
                    Dependencies = @(
                        @{
                            AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                            Publisher = "BEYONDIT GmbH"
                            MinVersion = "20.0.0.0"
                        }
                    )
                },
                @{
                    AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                    Version = "20.1.0.1"
                    Publisher = "Microsoft"
                    Name = "Core App"
                    Dependencies = @(
                        @{
                            AppId = "ce3a5b0f-cc56-490b-bdf7-363dc840de9d"
                            Publisher = "BEYONDIT GmbH"
                            MinVersion = "21.0.0.0"
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
                            Publisher = "BEYONDIT GmbH"
                            MinVersion = "20.0.0.0"
                        },
                        @{
                            AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                            Publisher = "Microsoft"
                            MinVersion = "20.0.0.0"
                        }
                    )
                }
            )
            $script:dependencyGraph = Get-DependencyGraphFromAppInfos -appInfos $script:appInfos
        }

        It 'GetAllAppIds' {
            $apps = $script:dependencyGraph.GetAllAppIds()
            $apps.Count | Should Be 4
        }

        It 'GetAllLatestVersions' {
            $apps = $script:dependencyGraph.GetAllLatestVersions()
            $apps.Count | Should Be 4
            $apps[0].Id | Should Not Be $null
        }

        It 'GetAllVersions' {
            $appIds = $script:dependencyGraph.GetAllAppIds()
            foreach($appId in $appIds) {
                $script:dependencyGraph.GetAllVersions($appId).Count | Should Be 1 
            }
        }

        It 'GetNewerVersionThen find target' {
            $app = $script:dependencyGraph.GetNewerVersionThen("3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc", "20.0.0.0")
            $app.Version | Should Be "20.1.0.1"
        }

        It 'GetNewerVersionThen no target' {
            $app = $script:dependencyGraph.GetNewerVersionThen("3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc", "21.0.0.0")
            $app | Should Be $null
        }
        It 'GetNewerVersionThen no app found' {
            $app = $script:dependencyGraph.GetNewerVersionThen("3e8e", "20.0.0.0")
            $app | Should Be $null
        }
        It 'Filtered Graph ignoreMicrosoftApps' {
            $dependencyGraph = Get-DependencyGraphFromAppInfos -appInfos $script:appInfos -ignoreMicrosoftApps
            $dependencyGraph.GetLatestVersion("4d3506ca-458b-4bbc-b9e2-557562bf49be").dependencies.Count | Should Be 1
            $dependencyGraph.GetLatestVersion("4d3506ca-458b-4bbc-b9e2-557562bf49be").dependencies[0].Id | Should Be "9abe2dcb-1acc-460a-9c07-e110dc216540"
        }
        It 'Filtered Graph ignore custom filter' {
            $dependencyGraph = Get-DependencyGraphFromAppInfos -appInfos $script:appInfos -filter { $_.Publisher -ne "BEYONDIT GmbH" }
            $dependencyGraph.GetLatestVersion("4d3506ca-458b-4bbc-b9e2-557562bf49be").dependencies.Count | Should Be 1
            $dependencyGraph.GetLatestVersion("4d3506ca-458b-4bbc-b9e2-557562bf49be").dependencies[0].Id | Should Be "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"

        }

        
        It 'Version Compare versionA' {
            Get-NewerVersion -versionA "20.0.0.0" -versionB "20.0.0.0" | Should Be $null
            Get-NewerVersion -versionA "21.0.0.0" -versionB "20.0.0.0" | Should Be "21.0.0.0"
            Get-NewerVersion -versionA "20.1.0.0" -versionB "20.0.0.0" | Should Be "20.1.0.0"
            Get-NewerVersion -versionA "20.0.1.0" -versionB "20.0.0.0" | Should Be "20.0.1.0"
            Get-NewerVersion -versionA "20.0.0.1" -versionB "20.0.0.0" | Should Be "20.0.0.1"
        }

        It 'Version Compare versionB' {
            Get-NewerVersion -versionA "20.0.0.0" -versionB "20.0.0.0" | Should Be $null
            Get-NewerVersion -versionA "20.0.0.0" -versionB "21.0.0.0" | Should Be "21.0.0.0"
            Get-NewerVersion -versionA "20.0.0.0" -versionB "20.1.0.0" | Should Be "20.1.0.0"
            Get-NewerVersion -versionA "20.0.0.0" -versionB "20.0.1.0" | Should Be "20.0.1.0"
            Get-NewerVersion -versionA "20.0.0.0" -versionB "20.0.0.1" | Should Be "20.0.0.1"
        }
    }

    Describe "DependencyGraph SingleVersion" {

        It 'Dependents' {
            $dependents = $script:dependencyGraph.GetDependents("9abe2dcb-1acc-460a-9c07-e110dc216540","20.1.0.1")
            $dependents.Count | Should Be 3
            $dependents[0].id | Should Be "ce3a5b0f-cc56-490b-bdf7-363dc840de9d"
            $dependents[1].Id | Should Be "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
            $dependents[2].Id | Should Be "4d3506ca-458b-4bbc-b9e2-557562bf49be"
        }

        
        It 'Dependencies' {
            $dependents = $script:dependencyGraph.GetDependencies("4d3506ca-458b-4bbc-b9e2-557562bf49be","20.0.0.1")
            $dependents.Count | Should Be 3
            $dependents[0].Id | Should Be "9abe2dcb-1acc-460a-9c07-e110dc216540"
            $dependents[1].id | Should Be "ce3a5b0f-cc56-490b-bdf7-363dc840de9d"
            $dependents[2].Id | Should Be "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
        }
    }
    Describe 'DependencyGraph MultiVersions' {

        BeforeAll {
            $script:appInfos = @(
                @{
                    AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                    Version = "20.1.0.1"
                    Publisher = "BEYONDIT GmbH"
                    Name = "Best App"
                    Dependencies = @(
                    )
                },
                @{
                    AppId = "ce3a5b0f-cc56-490b-bdf7-363dc840de9d"
                    Version = "21.0.0.0"
                    Publisher = "BEYONDIT GmbH"
                    Name = "Third Best App"
                    Dependencies = @(
                        @{
                            AppId = "9abe2dcb-1acc-460a-9c07-e110dc216540"
                            Publisher = "BEYONDIT GmbH"
                            MinVersion = "20.0.0.0"
                        }
                    )
                },
                @{
                    AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                    Version = "20.1.0.1"
                    Publisher = "Microsoft"
                    Name = "Core App"
                    Dependencies = @(
                        @{
                            AppId = "ce3a5b0f-cc56-490b-bdf7-363dc840de9d"
                            Publisher = "BEYONDIT GmbH"
                            MinVersion = "21.0.0.0"
                        }
                    )
                },
                @{
                    AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                    Version = "30.0.0.1"
                    Publisher = "Microsoft"
                    Name = "Core App"
                    Dependencies = @(
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
                            Publisher = "BEYONDIT GmbH"
                            MinVersion = "20.0.0.0"
                        },
                        @{
                            AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                            Publisher = "Microsoft"
                            MinVersion = "20.0.0.0"
                        }
                    )
                },
                @{
                    AppId = "4d3506ca-458b-4bbc-b9e2-557562bf49be"
                    Version = "30.0.0.1"
                    Publisher = "BEYONDIT GmbH"
                    Name = "Second Best App"
                    Dependencies = @(
                        @{
                            AppId = "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
                            Publisher = "Microsoft"
                            MinVersion = "30.0.0.0"
                        }
                    )
                }
            )
            $script:dependencyGraph = Get-DependencyGraphFromAppInfos -appInfos $script:appInfos
        }
        It 'Dependents' {
            $dependents = $script:dependencyGraph.GetDependents("3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc","30.0.0.0")
            $dependents.Count | Should Be 1
            $dependents[0].Id | Should Be "4d3506ca-458b-4bbc-b9e2-557562bf49be"
        }

        
        It 'Dependencies' {
            $dependents = $script:dependencyGraph.GetDependencies("4d3506ca-458b-4bbc-b9e2-557562bf49be","30.0.0.0")
            $dependents.Count | Should Be 1
            $dependents[0].Id | Should Be "3e8e74a9-dd75-4fe2-acf9-0aae2cecdfbc"
        }
    }
}