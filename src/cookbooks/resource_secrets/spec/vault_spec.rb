# frozen_string_literal: true

require 'spec_helper'

describe 'resource_secrets::vault' do
  context 'creates the vault configuration files' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    vault_client_config_content = <<~HCL
      backend "consul" {
        address = "127.0.0.1:8500"
        path = "vault/"
        scheme = "http"
      }

      ha_backend "consul" {
        disable_clustering = "false"
      }
    HCL
    it 'creates server.hcl in the vault configuration directory' do
      expect(chef_run).to create_file('/etc/vault/server.hcl')
        .with_content(vault_client_config_content)
    end
  end

  context 'configures vault' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the vault service' do
      expect(chef_run).to create_systemd_service('vault').with(
        action: [:create],
        after: %w[network-online.target],
        description: 'Vault',
        documentation: 'https://vaultproject.io',
        requires: %w[network-online.target]
      )
    end

    it 'enable the vault service' do
      expect(chef_run).to enable_service('vault')
    end
  end

  context 'configures the firewall for consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Vault HTTP port' do
      expect(chef_run).to create_firewall_rule('vault-http').with(
        command: :allow,
        dest_port: 8200,
        direction: :in
      )
    end

    it 'opens the Vault cluster HTTP port' do
      expect(chef_run).to create_firewall_rule('vault-cluster-http').with(
        command: :allow,
        dest_port: 8201,
        direction: :in
      )
    end
  end

  context 'adds the consul-template files for vault' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    vault_metrics_template_content = <<~CONF
      telemetry {
          statsd_address = "{{ keyOrDefault "config/services/metrics/protocols/statsd/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}:{{ keyOrDefault "config/services/metrics/protocols/statsd/port" "80" }}"
      }
    CONF
    it 'creates vault metrics template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/vault_metrics.ctmpl')
        .with_content(vault_metrics_template_content)
    end

    consul_template_vault_metrics_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/vault_metrics.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/vault/conf.d/metrics.hcl"

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
    CONF
    it 'creates vault_metrics.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/vault_metrics.hcl')
        .with_content(consul_template_vault_metrics_content)
    end

    vault_region_template_content = <<~CONF
      cluster_name = "{{ keyOrDefault "config/services/consul/datacenter" "unknown" }}"
    CONF
    it 'creates vault region template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/vault_region.ctmpl')
        .with_content(vault_region_template_content)
    end

    consul_template_vault_region_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/vault_region.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/vault/conf.d/region.hcl"

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
    CONF
    it 'creates vault_region.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/vault_region.hcl')
        .with_content(consul_template_vault_region_content)
    end
  end
end
