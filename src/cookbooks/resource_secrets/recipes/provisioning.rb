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
