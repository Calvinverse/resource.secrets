Describe 'The vault application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/vault' | Should Exist
        }

        It 'with default configuration in /etc/vault/server.hcl' {
            '/etc/vault/server.hcl' | Should Exist
        }

        It 'with environment configuration in /etc/vault/conf.d' {
            '/etc/vault/conf.d/region.hcl' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/vault.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Vault
Requires=network-online.target
After=network-online.target
Documentation=https://vaultproject.io

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/local/bin/vault server -config=/etc/vault/server.hcl -config=/etc/vault/conf.d
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status vault
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'vault.service - Vault'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        $ifConfigResponse = & ifconfig eth0
        $line = $ifConfigResponse[1].Trim()
        # Expecting line to be:
        #     inet addr:192.168.6.46  Bcast:192.168.6.255  Mask:255.255.255.0
        $localIpAddress = $line.SubString(10, ($line.IndexOf(' ', 10) - 10))

        try
        {
            $response = Invoke-WebRequest -Uri "http://$($localIpAddress):8200/v1/sys/health" -UseBasicParsing
        }
        catch
        {
            # Because powershell sucks it throws if the response code isn't a 200 one ...
            $response = $_.Exception.Response
        }

        It 'responds to HTTP calls' {
            $response.StatusCode | Should Be 501
        }
    }
}
