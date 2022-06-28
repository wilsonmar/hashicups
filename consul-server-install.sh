#!/bin/bash
# consul.sh in https://github.com/wilsonmar/hashicups
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-ent-basics/challenges/install-consul/assignment
apt-get update
apt-get -y install curl wget software-properties-common jq
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
# Add the official HashiCorp Linux repository
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
# Install Consul Enterprise on the node
apt-get -y install consul-enterprise