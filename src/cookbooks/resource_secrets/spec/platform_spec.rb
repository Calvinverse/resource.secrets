# frozen_string_literal: true

require 'spec_helper'

describe 'resource_secrets::default' do
  before do
    stub_command('getcap $(readlink -f $(which vault))|grep cap_ipc_lock+ep').and_return(false)
  end

  context 'configures the operating system' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'has the correct platform_version' do
      expect(chef_run.node['platform_version']).to eq('16.04')
    end
  end
end
