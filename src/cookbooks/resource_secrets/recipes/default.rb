# frozen_string_literal: true

#
# Cookbook Name:: resource_secrets
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_secrets::firewall'

include_recipe 'resource_secrets::meta'
include_recipe 'resource_secrets::provisioning'
include_recipe 'resource_secrets::vault'
