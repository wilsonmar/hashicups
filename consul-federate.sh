#!/bin/bash
# consul-federate.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-datacenter-federation
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

####### Challenge 1 - Bootstrap the ACL System in the Primary Datacenter
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-datacenter-federation/challenges/1-create-certs/assignment

# On Consul 1 - DC1 :
cd /root
consul acl bootstrap >> bootstrap.txt
   # AccessorID:       06513bc4-dd31-8a78-b963-e1983cbc2d67
   # SecretID:         0fe13045-f796-94ed-1135-559b3e37c363
   # Partition:        default
   # Namespace:        default
   # Description:      Bootstrap Token (Global Management)
   # Local:            false
   # Create Time:      2022-06-29 14:39:36.108495561 +0000 UTC
   # Policies:
   #    00000000-0000-0000-0000-000000000001 - global-management

export CONSUL_HTTP_TOKEN=$(cat bootstrap.txt | grep --color=NEVER  "SecretID:"  | cut -d ' '  -f10)
# Confirm:
echo $CONSUL_HTTP_TOKEN  # 0fe13045-f796-94ed-1135-559b3e37c363
# For subsequent: 
export CONSUL_HTTP_TOKEN="0fe13045-f796-94ed-1135-559b3e37c363"

echo 'node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}' >> node-policy.hcl

consul acl policy create \
  -name node-policy \
  -rules @node-policy.hcl
   # ID:           1027c311-273b-af72-cf25-9c06e988d90d
   # Name:         node-policy
   # Partition:    default
   # Namespace:    default
   # Description:  
   # Datacenters:  
   # Rules:
   # node_prefix "" {
   #   policy = "write"
   # }
   # service_prefix "" {
   #   policy = "read"
   # }

RESPONSE=$( consul acl token create \
  -description "node token" \
  -policy-name node-policy )
  # NOTE: ".hcl" is added to policy-name value for "node-policy.hcl".
   # AccessorID:       dc55b453-941c-8a17-abd7-72c80ecdd445
   # SecretID:         768cef52-dabe-2133-17f2-6180d4af2a67
   # Partition:        default
   # Namespace:        default
   # Description:      node token
   # Local:            false
   # Create Time:      2022-06-29 14:39:39.10575888 +0000 UTC
   # Policies:
   #    1027c311-273b-af72-cf25-9c06e988d90d - node-policy

# WLM added: TODO: replace manual copy with command to extract
#export CONSUL_NODE_TOKEN=$(cat ${RESPONSE} \
#   | grep --color=NEVER  "SecretID:"  | cut -d ' '  -f10)

export CONSUL_NODE_TOKEN="768cef52-dabe-2133-17f2-6180d4af2a67"

consul acl set-agent-token agent $CONSUL_NODE_TOKEN
ssh -o stricthostkeychecking=no consul-server-2 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-3 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-4 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-5 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-6 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN"

   # Warning: Permanently added 'consul-server-2,10.132.3.136' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-3,10.132.3.141' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-4,10.132.3.140' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-5,10.132.3.142' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-6,10.132.3.144' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully

# You now have ACLs enabled and enforced.


####### Challenge 2 - Prep the Primary Datacenter for ACL Replication
# Configure an ACL policy and token used for token replication
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-datacenter-federation/challenges/2-replication-token/notes
# configure Consul to prep for token replication.

# Provide Consul with a valid ACL token to make changes to the ACL system:
# On Consul 1 - DC1 :
echo $CONSUL_HTTP_TOKEN

# Create a new ACL policy and token with privileges to replicate ACLs 
# from the primary datacenter to the secondary. 
# This will be used later on to permit token replication to the 
# secondary datacenter:

cd /root/
echo 'acl = "write"
operator = "write"
service_prefix "" {
  policy = "read"
  intentions = "read"
}' >> replication.hcl

consul acl policy create -name replication -rules @replication.hcl
   # ID:           fd2cf4d7-7627-d5d3-c3ab-efba861680fa
   # Name:         replication
   # Partition:    default
   # Namespace:    default
   # Description:  
   # Datacenters:  
   # Rules:
   # acl = "write"
   # operator = "write"
   # service_prefix "" {
   #   policy = "read"
   #   intentions = "read"
   # }

consul acl token create -description "replication token" -policy-name replication
   # AccessorID:       a56ab916-3225-63cf-0d88-2896ccf1a5ec
   # SecretID:         acb2a0d5-6c91-87ed-03d5-651a4c2117f5
   # Partition:        default
   # Namespace:        default
   # Description:      replication token
   # Local:            false
   # Create Time:      2022-06-29 15:13:43.088370594 +0000 UTC
   # Policies:
   #    fd2cf4d7-7627-d5d3-c3ab-efba861680fa - replication

# Note the value of SecretID of the replication token, 
# which you will need to apply to the secondary datacenter's server later on. 
# Save the token on your local computer (using Notepad or similar app).
# export REPLICATION_TOKEN="acb2a0d5-6c91-87ed-03d5-651a4c2117f5"

consul policy list


####### Challenge 3 - Configure Primary Datacenter for Federation

# Ensure the primary datacenter is configured for federation
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-datacenter-federation/challenges/3-configure-test/notes
# In the third challenge, you'll update the Consul configuration to prep for WAN federation.

# On the Consul server in the primary datacenter (Consul 1 - DC1):
# Add the primary_datacenter option at the bottom of the configuration file 
# located at /etc/consul.d/config.hcl:
# TODO: First Check if it's not already in there.
# echo 'primary_datacenter =  "dc1"' >> /etc/consul.d/config.hcl
# Add this option to all other servers in dc1:
ssh -o stricthostkeychecking=no consul-server-1 'echo primary_datacenter =  \"dc1\" >> /etc/consul.d/config.hcl' && \
ssh -o stricthostkeychecking=no consul-server-2 'echo primary_datacenter =  \"dc1\" >> /etc/consul.d/config.hcl' && \
ssh -o stricthostkeychecking=no consul-server-3 'echo primary_datacenter =  \"dc1\" >> /etc/consul.d/config.hcl' && \
ssh -o stricthostkeychecking=no consul-server-4 'echo primary_datacenter =  \"dc1\" >> /etc/consul.d/config.hcl' && \
ssh -o stricthostkeychecking=no consul-server-5 'echo primary_datacenter =  \"dc1\" >> /etc/consul.d/config.hcl' && \
ssh -o stricthostkeychecking=no consul-server-6 'echo primary_datacenter =  \"dc1\" >> /etc/consul.d/config.hcl'
   # Warning: Permanently added 'consul-server-1,10.132.3.151' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-2,10.132.3.136' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-3,10.132.3.141' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-4' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-5,10.132.3.142' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-6,10.132.3.144' (ECDSA) to the list of known hosts.

# Login to each server and validate the /etc/consul.d/config.hcl 
# contains the primary_datacenter parameter:
cat /etc/consul.d/config.hcl

# Restart the Consul service on each server node 
# to ensure the new changes are reflected:
systemctl restart consul


####### Challenge 4 - Configure the Secondary Datacenter and ACL Replication
# Prepare the Secondary Datacenter for Federation and ACL Replication
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-datacenter-federation/challenges/4-configure-secondary/notes

# On the secondary datacenter server (Consul 7 Config):
# View /etc/consul.d/config.hcl to validate whether it 
# includes the proper datacenter configuration:
# TODO: Automate?
# datacenter = "dc2"

# Add to text the replication token from above 
# Modify to ensure the ACL stanza matches the configuration below 
# and add the two new configurations below it:
acl {
  enabled        = true
  default_policy = "deny"
  down_policy    = "extend-cache"
  enable_token_replication = true
  enable_token_persistence = true
  tokens {
      replication = "acb2a0d5-6c91-87ed-03d5-651a4c2117f5"
  }
}
primary_datacenter = "dc1"
retry_join_wan = ["consul-server-1"]

# The settings above instruct Consul to replicate ACLs from the primary datacenter, and then token gives dc2 the access to do so. The two additional configurations tell Consul who is the primary for ACLs and what server(s) to automatically join for WAN federation.

# export REPLICATION_TOKEN="acb2a0d5-6c91-87ed-03d5-651a4c2117f5"

# Repeat the above step for all other servers in DC2:
Consul 8
Consul 9
Consul 10
Consul 11
Consul 12

# Save each configuration on each node and 
# restart the Consul service on the secondary DC nodes 
# to pick up the new configurations:

# On Consul 7 - DC2:
systemctl restart consul && \
ssh -o stricthostkeychecking=no consul-server-8 systemctl restart consul && \
ssh -o stricthostkeychecking=no consul-server-9 systemctl restart consul && \
ssh -o stricthostkeychecking=no consul-server-10 systemctl restart consul && \
ssh -o stricthostkeychecking=no consul-server-11 systemctl restart consul && \
ssh -o stricthostkeychecking=no consul-server-12 systemctl restart consul
   # Warning: Permanently added 'consul-server-8,10.132.3.137' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-9,10.132.3.143' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-10,10.132.3.138' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-11,10.132.3.139' (ECDSA) to the list of known hosts.
   # Warning: Permanently added 'consul-server-12,10.132.2.126' (ECDSA) to the list of known hosts.

# It takes a few minutes to restart the consul service on each DC2 node.



####### Challenge 5 - Confirm Replication is working
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-datacenter-federation/challenges/5-confirm-replication/notes

# In the CLI of a Consul server in the secondary datacenter(Consul 7 - DC2):
# set the following environment variables:

# export CONSUL_HTTP_TOKEN=<primary-datacenter-bootstrap-token-here>
# export CONSUL_HTTP_TOKEN="0fe13045-f796-94ed-1135-559b3e37c363"

# Note: If you forgot to save your bootstrap token, you can pull it via cat bootstrap.txt on Consul 1 - DC1. The token is available in the SecretID parameter.
# Confirm the datacenters are WAN joined using the Consul CLI. The output should include (6) servers in dc1 and (6) in dc2.

consul members -wan
   # Node                  Address            Status  Type    Build       Protocol  DC   Partition  Segment
   # consul-server-1.dc1   10.132.3.151:8302  alive   server  1.11.4+ent  2         dc1  default    <all>
   # consul-server-10.dc2  10.132.3.138:8302  alive   server  1.11.4+ent  2         dc2  default    <all>
   # consul-server-11.dc2  10.132.3.139:8302  alive   server  1.11.4+ent  2         dc2  default    <all>
   # consul-server-12.dc2  10.132.2.126:8302  alive   server  1.11.4+ent  2         dc2  default    <all>
   # consul-server-2.dc1   10.132.3.136:8302  alive   server  1.11.4+ent  2         dc1  default    <all>
   # consul-server-3.dc1   10.132.3.141:8302  alive   server  1.11.4+ent  2         dc1  default    <all>
   # consul-server-4.dc1   10.132.3.140:8302  alive   server  1.11.4+ent  2         dc1  default    <all>
   # consul-server-5.dc1   10.132.3.142:8302  alive   server  1.11.4+ent  2         dc1  default    <all>
   # consul-server-6.dc1   10.132.3.144:8302  alive   server  1.11.4+ent  2         dc1  default    <all>
   # consul-server-7.dc2   10.132.0.157:8302  alive   server  1.11.4+ent  2         dc2  default    <all>
   # consul-server-8.dc2   10.132.3.137:8302  alive   server  1.11.4+ent  2         dc2  default    <all>
   # consul-server-9.dc2   10.132.3.143:8302  alive   server  1.11.4+ent  2         dc2  default    <all>

# You've now federated two Consul datacenters and 
# enabled ACL replication.
# ACL replication is working since we just used the 
# bootstrap token of the primary datacenter (dc1) to 
# authenticate to the secondary datacenter (dc2)

# At the Consul UI tab, Log in using 
#  CONSUL_HTTP_TOKEN="0fe13045-f796-94ed-1135-559b3e37c363"
# see both datacenters by clicking the dc1 at the top left. 
# Selecting dc2 would allow you to see 
# Consul members, services, and intentions in dc2.

# END