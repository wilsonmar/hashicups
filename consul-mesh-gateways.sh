#!/bin/bash
# consul-mesh-gateways.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-gateways-deployment
# Deploy the Mesh Gateway and Federate Two Consul Datacenters.
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

####### Challenge 1 - Deploy a Mesh Gateway for DC1
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-gateways-deployment/challenges/configure-dc1-gateway/notes

# On Consul Server 1:
# Validate that dc1 has three server nodes and one client. 
consul members
   # Node             Address           Status  Type    Build       Protocol  DC   Segment
   # consul-server-1  10.132.1.36:8301  alive   server  1.10.4+ent  2         dc1  <all>
   # consul-server-2  10.132.1.23:8301  alive   server  1.10.4+ent  2         dc1  <all>
   # consul-server-3  10.132.1.31:8301  alive   server  1.10.4+ent  2         dc1  <all>
   # consul-mgw-dc1   10.132.1.32:8301  alive   client  1.10.4+ent  2         dc1  <default>

# The client is a separate virtual machine running 
# the Consul agent in client mode. 
# This client also has the Envoy proxy installed.

# View the configuration of consul-server-1:
cat /etc/consul.d/config.hcl

# Note that auto_encrypt is enabled: # auto_encrypt { allow_tls = true
# That allows clients to request a TLS certificate when joining the cluster. 
# Also see that connect is enabled with enable_mesh_gateway_wan_federation = true
# and the enable_mesh_gateway_wan_federation parameter is set to true.

# On the node Mesh-Gateway - DC1 (our mesh gateway for dc1):
# validate that Envoy has been installed by checking the version: 
# https://www.consul.io/docs/connect/proxies/envoy
cd /tmp
wget --quiet https://archive.tetratelabs.io/envoy/download/v1.22.2/envoy-v1.22.2-linux-amd64.tar.xz -O envoy.tar.xz
tar -xf envoy.tar.xz
mv envoy-*/bin/envoy /usr/bin/envoy
chmod +x /usr/bin/envoy

envoy --version
   # envoy  version: c919bdec19d79e97f4f56e4095706f8e6a383f1c/1.22.2/Clean/RELEASE/BoringSSL

# View the Consul configuration of this node:
cat /etc/consul.d/config.hcl
# Notice that we are only setting the root CA file ca_file parameter 
   # ca_file = "/etc/consul.d/consul-agent-ca.pem"
# since the Consul agent will retrieve the cert and 
# private key from the Consul server nodes. 
# You can also see the configuration for auto_encrypt and the 
# gRPC port configuration as well.
   #   ports = { grpc = 8502 }

# Check the Consul service catalog to view there is only a single service, 
# the default Consul service:
consul catalog services
   # consul

# Start the mesh gateway service:
consul connect envoy -expose-servers -gateway=mesh \
   -register -service "dc1-mesh-gateway" \
   -address "${local_ipv4}:443" \
   -wan-address "${public_ipv4}:443" -- -l debug
   # Registered service: dc1-mesh-gateway
   # [2022-06-29 17:18:32.077][30639][info][main] [source/server/server.cc:390] initializing epoch 0 (base id=0, hot restart version=disabled)
   # [2022-06-29 17:18:32.086][30639][info][main] [source/server/server.cc:392] statically linked extensions:
   # [2022-06-29 17:18:32.086][30639][info][main] [source/server/server.cc:394]   envoy.matching.network.custom_matchers: envoy.matching.custom_matchers.trie_matcher

# In the Consul-Server-1 CLI:
# run the command below 
# TODO: Automate checking that the new mesh gateway has been registered:
consul catalog services
   # consul
   # dc1-mesh-gateway

# Click the Consul UI tab and see that the dc1 mesh gateway is 
# registered and healthy. 
# Note the "Mesh Gateway" tag showing that 
# Consul knows the service is a mesh gateway.

# In the upper left, click dc1 and note there is only a 
# single Consul datacenter currently available.


####### Challenge 2 - Deploy a Mesh Gateway for DC2
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-gateways-deployment/challenges/configure-dc2-gateway/notes

# On Consul Server 4:
# validate that dc2 has three server nodes, similar to dc1. 
# You won't see the mesh gateway (Consul client) connected yet 
# because we need to establish federation between the two datacenters so
# Consul can issue a TLS cert to the client through auto_config.
consul members
   # Node             Address           Status  Type    Build       Protocol  DC   Segment
   # consul-server-4  10.132.1.52:8301  alive   server  1.10.4+ent  2         dc2  <all>
   # consul-server-5  10.132.1.56:8301  alive   server  1.10.4+ent  2         dc2  <all>
   # consul-server-6  10.132.1.64:8301  alive   server  1.10.4+ent  2         dc2  <all>

# See that only the local server nodes are participating in the 
# WAN gossip pool right now:
consul members -wan
   # Node                 Address             Status  Type    Build       Protocol  DC   Partition  Segment
   # consul-server-4.dc2  10.132.255.99:8302  alive   server  1.12.2+ent  2         dc2  default    <all>
   # consul-server-5.dc2  10.132.255.90:8302  alive   server  1.12.2+ent  2         dc2  default    <all>
   # consul-server-6.dc2  10.132.255.96:8302  alive   server  1.12.2+ent  2         dc2  default    <all>

# Moving over to the Consul UI tab, validate that you have only a 
# single service for consul and that dc2 is dsiplayed in the top left.
# The equivalent CLI command:
consul catalog services -datacenter=dc2

# In the Consul 4 Config:
# view the Consul configuration file in the code editor. 
# The file name is config.hcl. 
# Add the following configuration at the bottom on the file:
# primary_gateways = ["consul-mgw-dc1:443"]

# Don't forget to click the Save icon on the tab 
# when you've finished editing the file

# Repeat the above step for Consul 5 Config and Consul 6 Config

# Back on Consul 4 Server:
# run the following commands to restart the Consul service 
# on all three server nodes and the client node:
systemctl restart consul
ssh -o stricthostkeychecking=no consul-server-5 systemctl restart consul
ssh -o stricthostkeychecking=no consul-server-6 systemctl restart consul
ssh -o stricthostkeychecking=no consul-mgw-dc2 systemctl restart consul
   # Warning: Permanently added 'consul-server-5,10.132.1.9' (ECDSA) to the list of known hosts.

# Make sure each of the above commands runs successfully. 
# You might need to copy each command individually and run it.

# Validate that the local cluster is back up:
consul members
   # Node             Address              Status  Type    Build       Protocol  DC   Partition  Segment
   # consul-server-4  10.132.255.111:8301  alive   server  1.12.2+ent  2         dc2  default    <all>
   # consul-server-5  10.132.1.9:8301      alive   server  1.12.2+ent  2         dc2  default    <all>
   # consul-server-6  10.132.0.239:8301    alive   server  1.12.2+ent  2         dc2  default    <all>

# and includes all three server nodes PLUS our mesh gateway client node.

# Since the Mesh Gateway is running in dc1 and 
# we've now configured dc2 to communicate with that gateway, 
# you should now see that the datacenters can communicate. 
consul members -wan
# to display all the servers. You should see the three servers in dc1 and the three in dc2.
   # Node                 Address              Status  Type    Build       Protocol  DC   Partition  Segment
   # consul-server-1.dc1  10.132.255.108:8302  alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-2.dc1  10.132.2.26:8302     alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-3.dc1  10.132.1.185:8302    alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-4.dc2  10.132.255.111:8302  alive   server  1.12.2+ent  2         dc2  default    <all>
   # consul-server-5.dc2  10.132.1.9:8302      alive   server  1.12.2+ent  2         dc2  default    <all>
   # consul-server-6.dc2  10.132.0.239:8302    alive   server  1.12.2+ent  2         dc2  default    <all>

# At this point, dc2 can replicate from dc1, but 
# dc1 can’t initiate/route traffic back into dc2 because 
# we haven't started and registered the local mesh gateway. 
# So let's do that.

# On the Mesh Gateway - DC2 CLI:
# validate that Envoy has been installed by checking the version:
envoy --version
   # envoy  version: c919bdec19d79e97f4f56e4095706f8e6a383f1c/1.22.2/Clean/RELEASE/BoringSSL

echo $public_ipv4  # local machine env. variable from operating system:
   # 104.155.22.102

# Start the mesh gateway service:
consul connect envoy -expose-servers -gateway=mesh \
  -register -service "dc2-mesh-gateway" \
  -address "${local_ipv4}:443" \
  -wan-address "${public_ipv4}:443" -- -l debug

# In the Consul UI tab, you can see the new Mesh Gateway registered 
# and eventually report as healthy. 
# Click on dc2 in the top left and notice you can see 
# both dc1 and dc2 in the UI now since the dataceters are now 
# federated using the new mesh gateways.

# You now have connected two Consul datacenters using 
# Consul Connect service mesh using Mesh Gateways.

# 
journalctl -u consul 
