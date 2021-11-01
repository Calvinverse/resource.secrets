BeforeAll {
    $serviceConfigurationPath = '/etc/systemd/system/vault.service'
    $localIpAddress = & ip a show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
}

Describe 'The vault application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/vault' | Should -Exist
        }

        It 'with default configuration in /etc/vault/server.hcl' {
            '/etc/vault/server.hcl' | Should -Exist
        }

        It 'with environment configuration in /etc/vault/conf.d' {
            '/etc/vault/conf.d/metrics.hcl' | Should -Exist
            '/etc/vault/conf.d/region.hcl' | Should -Exist
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
ExecStart = /usr/local/bin/vault server -config=/etc/vault/server.hcl -config=/etc/vault/conf.d
Restart = on-failure
User = vault

[Unit]
Description = Vault
Documentation = https://vaultproject.io
Requires = network-online.target
After = network-online.target

[Install]
WantedBy = multi-user.target

'@
            $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
            $serviceFileContent | Should -Be ($expectedContent -replace "`r", "")

            $systemctlOutput = & systemctl status vault
            $systemctlOutput | Should -Not -Be $null
            $systemctlOutput.GetType().FullName | Should -Be 'System.Object[]'
            $systemctlOutput.Length | Should -BeGreaterThan 3
            $systemctlOutput[0] | Should -Match 'vault.service - Vault'
        }

        It 'that is enabled' {
            $systemctlOutput = & systemctl status vault
            $systemctlOutput[1] | Should -Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput = & systemctl status vault
            $systemctlOutput[2] | Should -Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        It 'responds to HTTP calls' {
            try
            {
                $response = Invoke-WebRequest -Uri "http://$($localIpAddress):8200/v1/sys/health" -UseBasicParsing
            }
            catch
            {
                # Because powershell sucks it throws if the response code isn't a 200 one ...
                $response = $_.Exception.Response
            }

            $response.StatusCode | Should -Be 501
        }
    }
}
