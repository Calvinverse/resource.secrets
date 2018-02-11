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
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

vault_config_path = '/etc/vault/conf.d'
directory vault_config_path do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
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
  HCL
end

vault_metrics_file = node['hashicorp-vault']['metrics_file']
file "#{vault_config_path}/#{vault_metrics_file}" do
  action :create
  content <<~CONF
    telemetry {
        disable_hostname = true
        statsd_address = "localhost:8125"
    }
  CONF
  mode '755'
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
systemd_service 'vault' do
  action :create
  after %w[network-online.target]
  description 'Vault'
  documentation 'https://vaultproject.io'
  install do
    wanted_by %w[multi-user.target]
  end
  requires %w[network-online.target]
  service do
    exec_start '/usr/local/bin/vault server -config=/etc/vault/server.hcl -config=/etc/vault/conf.d'
    restart 'on-failure'
  end
  user vault_user
end

service 'vault' do
  action :enable
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
  mode '755'
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
      command = "systemctl restart vault"

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
      perms = 0755

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
  mode '755'
end
