# resource.secrets

This repository contains the source code for the Resource-Secrets image, the image that contains an
instance of the [Vault](https://www.vaultproject.io/) secret management system.

## Image

The image is created by using the [Linux base image](https://github.com/Calvinverse/base.linux)
and amending it using a [Chef](https://www.chef.io/chef/) cookbook which installs Vault.

### Contents

In addition to the default applications installed in the template image the following items are
also installed and configured:

* The Vault application. The version of which is determined by the
  `default['hashicorp-vault']['version']` attribute in the `default.rb` attributes file in the cookbook.

### Configuration

The configuration for the Vault instance comes from a
[Consul-Template](https://github.com/hashicorp/consul-template) template file which replaces some
of the template parameters with values from the Consul Key-Value store.

The cluster name is set once the resource has joined a Consul environment and is set to
the name of the environment.

### Provisioning

No changes to the provisioning are applied other than the default one for the base image.

### Logs

No additional configuration is applied other than the default one for the base image.

### Metrics

Metrics are collected by Vault sending [StatsD](https://www.vaultproject.io/docs/internals/telemetry.html)
metrics to [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).

## Build, test and release

The build process follows the standard procedure for
[building Calvinverse images](https://www.calvinverse.net/documentation/how-to-build).

## Deploy

* Download the new image to one of your Hyper-V hosts.
* Create a directory for the image and copy the image VHDX file there.
* Create a VM that points to the image VHDX file with the following settings
  * Generation: 2
  * RAM: at least 1024 Mb
  * Hard disk: Use existing. Copy the path to the VHDX file
  * Attach the VM to a suitable network
* Update the VM settings:
  * Enable secure boot. Use the Microsoft UEFI Certificate Authority
  * Attach a DVD image that points to an ISO file containing the settings for the environment. These
    are normally found in the output of the [Calvinverse.Infrastructure](https://github.com/Calvinverse/calvinverse.infrastructure)
    repository. Pick the correct ISO for the task, in this case the `Linux Consul Client` image
  * Disable checkpoints
  * Set the VM to always start
  * Set the VM to shut down on stop
* Start the VM, it should automatically connect to the correct environment once it has provisioned
* [Unseal](https://www.vaultproject.io/docs/concepts/seal.html) the new instance.
* SSH into one of the old hosts and give the following commands and then wait for the machine to
  shut down
  * `sudo systemctl stop vault`
  * `consul leave`
  * `sudo shutdown now`
* Once the VM has been shutdown it can be deleted
* Repeat until all old instances have been replaced with new instances
