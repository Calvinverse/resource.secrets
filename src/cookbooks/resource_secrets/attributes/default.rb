# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# VAULT
#

default['hashicorp-vault']['version'] = '0.9.1'

default['hashicorp-vault']['config']['habackend_type'] = 'consul'
default['hashicorp-vault']['config']['habackend_options']['address'] = '127.0.0.1:8500'
default['hashicorp-vault']['config']['habackend_options']['check_timeout'] = '10s'
default['hashicorp-vault']['config']['habackend_options']['disable_registration'] = false
default['hashicorp-vault']['config']['habackend_options']['path'] = 'vault/'
default['hashicorp-vault']['config']['habackend_options']['scheme'] = 'http'

default['hashicorp-vault']['config']['tls_disable'] = true

default['hashicorp-vault']['consul_template_metrics_file'] = 'vault_metrics.ctmpl'
default['hashicorp-vault']['consul_template_region_file'] = 'vault_region.ctmpl'

default['hashicorp-vault']['metrics_file'] = 'metrics.hcl'
default['hashicorp-vault']['region_file'] = 'region.hcl'
