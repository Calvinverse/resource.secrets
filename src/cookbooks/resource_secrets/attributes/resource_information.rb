# frozen_string_literal: true

#
# RESOURCE INFORMATION
#

default['resource']['version_major'] = '${VersionMajor}'
default['resource']['version_minor'] = '${VersionMinor}'
default['resource']['version_patch'] = '${VersionPatch}'
default['resource']['version_semantic'] = '${VersionSemantic}'

default['resource']['name'] = '${ProductName}'
default['resource']['name_short'] = '${ProductShortName}'

#
# PROVISIONING
#

should_provision_from_cloud_init = '${ProvisioningFromCloudInit}'
if should_provision_from_cloud_init == 'true'
  default['provision']['use_cloud_init'] = 'true'

  # Use the /run directory and not the /tmp directory because the /tmp directoy might get deleted
  # in the early boot process. See: https://cloudinit.readthedocs.io/en/latest/topics/modules.html#write-files
  default['provision']['source_path'] = '/run/cloud-init'
else
  default['provision']['use_dvd'] = 'true'
  default['provision']['source_path'] = '/mnt/dvd'
end