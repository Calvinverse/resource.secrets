Describe 'On the system' {
    Context 'system metrics' {
        It 'with binaries in /usr/local/bin' {
            '/usr/bin/telegraf' | Should Exist
        }

        It 'with default configuration in /etc/telegraf/telegraf.conf' {
            '/etc/telegraf/telegraf.conf' | Should Exist
        }

        $expectedContent = @'
# Telegraf Configuration

# Global tags can be specified here in key="value" format.
[global_tags]
  environment = "test-integration"
  os = "linux"
  consul = "client"

# Configuration for telegraf agent
[agent]
  ## Default data collection interval for all inputs
  interval = "10s"

  ## Rounds collection interval to 'interval'
  ## ie, if interval="10s" then always collect on :00, :10, :20, etc.
  round_interval = true

  ## Telegraf will send metrics to outputs in batches of at most
  ## metric_batch_size metrics.
  ## This controls the size of writes that Telegraf sends to output plugins.
  metric_batch_size = 1000

  ## For failed writes, telegraf will cache metric_buffer_limit metrics for each
  ## output, and will flush this buffer on a successful write. Oldest metrics
  ## are dropped first when this buffer fills.
  ## This buffer only fills when writes fail to output plugin(s).
  metric_buffer_limit = 10000

  ## Collection jitter is used to jitter the collection by a random amount.
  ## Each plugin will sleep for a random time within jitter before collecting.
  ## This can be used to avoid many plugins querying things like sysfs at the
  ## same time, which can have a measurable effect on the system.
  collection_jitter = "0s"

  ## Default flushing interval for all outputs. You shouldn't set this below
  ## interval. Maximum flush_interval will be flush_interval + flush_jitter
  flush_interval = "10s"
  ## Jitter the flush interval by a random amount. This is primarily to avoid
  ## large write spikes for users running a large number of telegraf instances.
  ## ie, a jitter of 5s and interval 10s means flushes will happen every 10-15s
  flush_jitter = "0s"

  ## By default or when set to "0s", precision will be set to the same
  ## timestamp order as the collection interval, with the maximum being 1s.
  ##   ie, when interval = "10s", precision will be "1s"
  ##       when interval = "250ms", precision will be "1ms"
  ## Precision will NOT be used for service inputs. It is up to each individual
  ## service input to set the timestamp at the appropriate precision.
  ## Valid time units are "ns", "us" (or "µs"), "ms", "s".
  precision = ""

  ## Logging configuration:
  ## Run telegraf with debug log messages.
  debug = false
  ## Run telegraf in quiet mode (error log messages only).
  quiet = false
  ## Specify the log file name. The empty string means to log to stderr.
  logfile = "/var/log/syslog"

  ## Override default hostname, if empty use os.Hostname()
  hostname = ""
  ## If set to true, do no set the "host" tag in the telegraf agent.
  omit_hostname = false

'@
        $scollectorConfigContent = Get-Content '/etc/telegraf/telegraf.conf' | Out-String
        It 'with the expected content in the configuration file' {
            $scollectorConfigContent | Should Be ($expectedContent -replace "`r", "")
        }
    }

    Context 'has been daemonized' {
        It 'with default configuration in /etc/telegraf/telegraf.d/system' {
            '/etc/telegraf/telegraf.d/inputs_statsd.conf' | Should Exist
            '/etc/telegraf/telegraf.d/inputs_system.conf' | Should Exist

            '/etc/telegraf/telegraf.d/outputs_statsd.conf' | Should Exist
            '/etc/telegraf/telegraf.d/outputs_system.conf' | Should Exist
        }

        $serviceConfigurationPath = '/lib/systemd/system/telegraf.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
                $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=The plugin-driven server agent for reporting metrics into InfluxDB
Documentation=https://github.com/influxdata/telegraf
After=network.target

[Service]
EnvironmentFile=-/etc/default/telegraf
User=telegraf
ExecStart=/usr/bin/telegraf -config /etc/telegraf/telegraf.conf -config-directory /etc/telegraf/telegraf.d $TELEGRAF_OPTS
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartForceExitStatus=SIGPIPE
KillMode=control-group

[Install]
WantedBy=multi-user.target

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status telegraf
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'telegraf.service - The plugin-driven server agent for reporting metrics into InfluxDB'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }
}
