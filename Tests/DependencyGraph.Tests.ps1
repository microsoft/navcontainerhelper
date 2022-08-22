BeforeAll {
    . (Join-Path $PSScriptRoot '_TestHelperFunctions.ps1')
}

AfterAll {
}

Describe 'DependencyGraph' {

    It 'SingleVersionDependencyGraph' {
        $appInfos = @(
            @{
                Id = ""
                Version = "20.1.0.1"
                Publisher = ""
                Name = ""
                Dependencies = @(
                    @{
                        AppId = ""
                        MinVersion = ""
                    }, 
                    @{
                        AppId = ""
                        MinVersion = ""
                    }
                )
            },
            @{
                Id = ""
                Version = ""
                Publisher = ""
                Name = ""
                Dependencies = @(
                    @{
                        AppId = ""
                        MinVersion = ""
                    }, 
                    @{
                        AppId = ""
                        MinVersion = ""
                    }
                )
            },
            @{
                Id = ""
                Version = ""
                Publisher = ""
                Name = ""
                Dependencies = @(
                    @{
                        AppId = ""
                        MinVersion = ""
                    }, 
                    @{
                        AppId = ""
                        MinVersion = ""
                    }
                )
            }
        )
        Create-DependencyGraph -appInfos $appInfos
    }
}