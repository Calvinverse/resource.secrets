# frozen_string_literal: true

#
# Cookbook Name:: resource_secrets
# Recipe:: vault
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which vault will be run
vault_user = node['hashicorp-vault']['service_user']
poise_service_user vault_user do
  group node['hashicorp-vault']['service_group']
end

directory '/etc/vault' do
  action :create
  group 'root'
  mode '0755'
  owner 'root'
end

vault_config_path = '/etc/vault/conf.d'
directory vault_config_path do
  action :create
  group 'root'
  mode '0755'
  owner 'root'
end

file '/etc/vault/server.hcl' do
  action :create
  content <<~HCL
    storage "consul" {
      address = "127.0.0.1:8500"
      path = "data/services/secrets/"
      scheme = "http"
      service = "secrets"
    }

    listener "tcp" {
      address         = "0.0.0.0:8200"
      cluster_address = "0.0.0.0:8201"
      tls_disable = 1
    }

    ui = true
  HCL
  group node['hashicorp-vault']['service_group']
  mode '0550'
  owner vault_user
end

vault_metrics_file = node['hashicorp-vault']['metrics_file']
file "#{vault_config_path}/#{vault_metrics_file}" do
  action :create
  content <<~CONF
    telemetry {
        disable_hostname = true
        statsd_address = "127.0.0.1:8125"
    }
  CONF
  group node['hashicorp-vault']['service_group']
  mode '0550'
  owner vault_user
end

#
# INSTALL VAULT
#

# This installs vault as follows
# - Binaries: /usr/local/bin/vault
# - Configuration: /etc/vault/vault.json
vault_installation node['hashicorp-vault']['version'] do |r|
  node['hashicorp-vault']['installation']&.each_pair { |k, v| r.send(k, v) }
end

# Create the systemd service for vault. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
vault_install_path = '/usr/local/bin/vault'
systemd_service 'vault' do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start "#{vault_install_path} server -config=/etc/vault/server.hcl -config=/etc/vault/conf.d"
    restart 'on-failure'
    user vault_user
  end
  unit do
    after %w[network-online.target]
    description 'Vault'
    documentation 'https://vaultproject.io'
    requires %w[network-online.target]
  end
end

service 'vault' do
  action :enable
end

#
# ALLOW VAULT TO LOCK MEMORY WITH MLOCK
#
# See: https://www.vaultproject.io/guides/operations/production.html

package 'libcap2-bin' do
  action :install
end

execute 'allow vault to lock memory' do
  action :run
  command 'setcap cap_ipc_lock=+ep $(readlink -f $(which vault))'
  not_if 'getcap $(readlink -f $(which vault))|grep cap_ipc_lock+ep'
end

#
# ALLOW VAULT THROUGH THE FIREWALL
#
firewall_rule 'vault-http' do
  command :allow
  description 'Allow Vault HTTP traffic'
  dest_port 8200
  direction :in
end

firewall_rule 'vault-cluster-http' do
  command :allow
  description 'Allow Vault cluster HTTP traffic'
  dest_port 8201
  direction :in
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

# region.hcl
vault_region_template_file = node['hashicorp-vault']['consul_template_region_file']
file "#{consul_template_template_path}/#{vault_region_template_file}" do
  action :create
  content <<~CONF
    cluster_name = "{{ keyOrDefault "config/services/consul/datacenter" "unknown" }}"
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

vault_region_file = node['hashicorp-vault']['region_file']
file "#{consul_template_config_path}/vault_region.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{vault_region_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{vault_config_path}/#{vault_region_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'chown #{vault_user}:#{node['hashicorp-vault']['service_group']} #{vault_config_path}/#{vault_region_file} && systemctl restart vault'"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0550

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end
