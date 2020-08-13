# frozen_string_literal: true

#
# Cookbook Name:: resource_secrets
# Recipe:: provisioning
#
# Copyright 2017, P. van der Velde
#

service 'provision.service' do
  action [:enable]
end

#
# CUSTOM CONFIG FILES FOR VAULT
#

provisioning_source_path = node['provision']['source_path']

file '/etc/provision.d/provision_image.sh' do
  action :create
  content <<~BASH
    #!/bin/bash

    function f_provisionImage {
      # Stop the vault service and kill the data directory. It will have the consul node-id in it which must go!
      sudo systemctl stop vault.service

      # Copy the vault server files if they exist
      if [ -f #{provisioning_source_path}/vault/server/vault_auto_unseal.json ]; then
        cp -a #{provisioning_source_path}/vault/server/vault_auto_unseal.json /etc/vault/conf.d/auto_unseal.json
        dos2unix /etc/vault/conf.d/auto_unseal.json
      fi
    }
  BASH
  mode '755'
end
