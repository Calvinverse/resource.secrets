BeforeAll {
    $ufwOutput = & sudo ufw status
}

Describe 'The firewall' {
    Context 'on the machine' {
        It 'should return a status' {
            $ufwOutput | Should -Not -Be $null
            $ufwOutput.GetType().FullName | Should -Be 'System.Object[]'
            # $ufwOutput.Length | Should -Be 27 # On Azure when running with Packer we get 29 but when building a machine from the base image we get 27 ..???
        }

        It 'Should -Be enabled' {
            $ufwOutput[0] | Should -Be 'Status: active'
        }
    }

    Context 'should allow SSH' {
        It 'on port 22' {
            ($ufwOutput | Where-Object {$_ -match '(22/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }
    }

    Context 'should allow consul' {
        It 'on port 8300' {
            ($ufwOutput | Where-Object {$_ -match '(8300/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on TCP port 8301' {
            ($ufwOutput | Where-Object {$_ -match '(8301/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on UDP port 8301' {
            ($ufwOutput | Where-Object {$_ -match '(8301/udp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on TCP port 8302' {
            ($ufwOutput | Where-Object {$_ -match '(8302/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on UDP port 8302' {
            ($ufwOutput | Where-Object {$_ -match '(8302/udp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on port 8500' {
            ($ufwOutput | Where-Object {$_ -match '(8500/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on UDP port 8600' {
            ($ufwOutput | Where-Object {$_ -match '(8600/udp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }
    }

    Context 'should allow telegraf' {
        It 'on TCP port 8125' {
            ($ufwOutput | Where-Object {$_ -match '(8125/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }
    }

    Context 'should allow unbound' {
        It 'on TCP port 53' {
            ($ufwOutput | Where-Object {$_ -match '(53/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on UDP port 53' {
            ($ufwOutput | Where-Object {$_ -match '(53/udp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }
    }

    Context 'should allow vault' {
        It 'on port 8200' {
            ($ufwOutput | Where-Object {$_ -match '(8200/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }

        It 'on port 8201' {
            ($ufwOutput | Where-Object {$_ -match '(8201/tcp)\s*(ALLOW)\s*(Anywhere)'} ) | Should -Not -Be $null
        }
    }
}
