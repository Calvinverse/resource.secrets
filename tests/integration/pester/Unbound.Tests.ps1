BeforeAll {
    $serviceConfigurationPath = '/etc/systemd/system/unbound.service'
    $localIpAddress = & ip a show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
}

Describe 'The unbound application' {
    Context 'is installed' {
        It 'with binaries in /usr/sbin' {
            '/usr/sbin/unbound' | Should -Exist
        }

        It 'with default configuration in /etc/unbound' {
            '/etc/unbound/unbound.conf' | Should -Exist
        }

        It 'with environment configuration in /etc/unbound.d' {
            '/etc/unbound/unbound.conf.d/unbound_zones.conf' | Should -Exist
        }
    }

    Context 'has been daemonized' {

        It 'has a systemd configuration' {
            if (-not (Test-Path $serviceConfigurationPath))
            {
                $false | Should -Be $true
            }
        }

        It 'with a systemd service' {
            $expectedContent = @'
[Service]
ExecStart = /usr/sbin/unbound -d -c /etc/unbound/unbound.conf
Restart = on-failure

[Unit]
Description = Unbound DNS proxy
Documentation = http://www.unbound.net
Requires = multi-user.target
After = multi-user.target

[Install]
WantedBy = multi-user.target

'@
            $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
            $systemctlOutput = & systemctl status unbound
            $serviceFileContent | Should -Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should -Not -Be $null
            $systemctlOutput.GetType().FullName | Should -Be 'System.Object[]'
            $systemctlOutput.Length | Should -BeGreaterThan 5
            $systemctlOutput[0] | Should -Match 'unbound.service - Unbound DNS proxy'
        }

        It 'that is enabled' {
            $systemctlOutput = & systemctl status unbound
            $systemctlOutput[1] | Should -Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput = & systemctl status unbound
            $systemctlOutput[2] | Should -Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'allows resolution of addresses' {
        It 'should resolve www.google.com' {
            $result = & dig +short www.google.com
            $result | Should -Not -Be $null
        }

        It 'should resolve consul addresses' {
            $result = & dig +short consul.service.integrationtest
            $result | Should -Not -Be $null
            $result | Should -Be $localIpAddress
        }

        It 'should resolve the hostname' {
            $result = & dig +short +search $(hostname)
            $result | Should -Not -Be $null
            $result | Should -Be $localIpAddress
        }
    }
}
