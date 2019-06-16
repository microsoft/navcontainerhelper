Describe 'Basic Pester Tests' {
    It 'A test that should be true' {
      $true | Should -Be $true
    }
    It 'A test that should fail' {
      $fail | Should -Be $true
    }
  }
  