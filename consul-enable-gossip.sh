# consul-enable-gossip.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-secure-deployment/challenges/enable-gossip/assignment
# TODO: See https://github.com/hashicorp/consul-guides

# Make sure...
consul members

# Generate key:
journalctl -xe -u consul | grep "Encrypt"

KEY=$( consul keygen )
# such as ADtZEkgK9uujE5rBwGsvAGTKOKle/rJ2JGvnqa46VPk=

systemctl stop consul

# For each consul node:

   # cat /etc/consul.d/config.hcl

   # TODO: sed ?
   # from encrypt = "output of consul keygen"
   # to   encrypt = "ADtZEkgK9uujE5rBwGsvAGTKOKle/rJ2JGvnqa46VPk="
# echo 'encrypt = "ADtZEkgK9uujE5rBwGsvAGTKOKle/rJ2JGvnqa46VPk="' >> /etc/consul.d/config.hcl
# echo 'encrypt = "${KEY}"' >> /etc/consul.d/config.hcl

consul validate /etc/consul.d/config.hcl
   # bootstrap_expect > 0: expecting 3 servers
   # Configuration is valid!

systemctl start consul
   # If you see this error:
   # Job for consul.service failed because a timeout was exceeded.
   # See "systemctl status consul.service" and "journalctl -xe" for details.

# Check raft peers to validate that all six server nodes join the cluster 
# and that three are voting members:
consul operator raft list-peers
   # Error getting peers: Failed to retrieve raft configuration: Unexpected response code: 500 (No cluster leader)
   # Node             ID                                    Address            State     Voter  RaftProtocol
   # consul-server-6  e7ab58f2-5448-9e3b-c472-b7fda68403db  10.132.2.106:8300  leader    true   3
   # consul-server-5  69157c20-7cd6-1836-6c32-8ee956d4e818  10.132.2.52:8300   follower  true   3
   # consul-server-3  e2abbeb2-4f25-9204-5780-2b7b9f7d4265  10.132.2.193:8300  follower  false  3
   # consul-server-1  faf0f509-c9e8-59ce-9000-f19c59a54792  10.132.0.89:8300   follower  false  3
   # consul-server-2  e932ebc3-f1ef-630b-a481-6700950a541f  10.132.2.65:8300   follower  false  3
   # consul-server-4  abf85736-8e5d-55f4-d710-71f3e9393ad8  10.132.0.167:8300  follower  true   3

# Check journal logs to see that gossip encryption now shows as 'true':
journalctl -xe -u consul | grep "Encrypt"
   # Jun 28 19:25:00 consul-server-6 consul[3008]:
   #   Encrypt: Gossip: false, TLS-Outgoing: false, TLS-Incoming: false, Auto-Encrypt-TLS: false
   # Jun 28 20:09:52 consul-server-6 consul[3930]:            
   #   Encrypt: Gossip: true, TLS-Outgoing: false, TLS-Incoming: false, Auto-Encrypt-TLS: false

# The latest entry in the log should read Encrypt: Gossip: true. There most likely will be older entries that show it as false.
# Verify that gossip encryption is enabled:
consul info
# looking for 'encrypted = true' for serf wan and lan:
#serf_lan:
#    coordinate_resets = 0
#    encrypted = true
#...
#serf_wan:
#    coordinate_resets = 0
#    encrypted = true


### Challenge 2 - Rotate Gossip Encryption Key
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-secure-deployment/challenges/rotate-key/assignment

consul keyring -list
   # ==> Gathering installed encryption keys...
   # WAN:
   #   ADtZEkgK9uujE5rBwGsvAGTKOKle/rJ2JGvnqa46VPk= [6/6]
   # dc1 (LAN):
   #   ADtZEkgK9uujE5rBwGsvAGTKOKle/rJ2JGvnqa46VPk= [6/6]
# OLDKEY="ADtZEkgK9uujE5rBwGsvAGTKOKle/rJ2JGvnqa46VPk="

NEWKEY=$( consul keygen )
# such as KEY="yxQ7i0hUeXkb/tTbVdbC6xcEAr6lP6fPokIYBriSzTA="

# Add your newly generated key to the keyring:
# From: consul keyring -install "output of consul keygen"
consul keyring -install "${NEWKEY}"
   # ==> Installing new gossip encryption key...

# Verify that the key has been distributed throughout the cluster:
consul keyring -list
   # Two keys appear.

# Promote the new key to be the primary encryption key:
consul keyring -use "${NEWKEY}"
   # ==> Changing primary gossip encryption key...

# Remove the old primary from the keyring (it's best practice to only have one key during normal operations):
consul keyring -remove "${OLDKEY}"
   # ==> Removing gossip encryption key...

#Verify that the keyring contains only one key:
consul keyring -list


# https://play.instruqt.com/HashiCorp-EA/tracks/consul-secure-deployment/challenges/enable-tls/notes
# Challenge 3 - Enable TLS

Consul can use TLS to verify the authenticity of servers and 
# clients and encrypt data in transit. 
# Consul requires that all agents have certificates signed by a single 
# Certificate Authority (CA). 
# Using Consul's built-in CA to issue our certificates for the server nodes:
# Create the local CA and generate the self-signed root certificates:
consul tls ca create
   # ==> Saved consul-agent-ca.pem
   # ==> Saved consul-agent-ca-key.pem

# Create server certificates for our primary datacenter:
# The -dc flag denotes the name of the Consul datacenter name. 
# This is required for server certificates and defaults to dc1
consul tls cert create -server -dc dc1
   # ==> WARNING: Server Certificates grants authority to become a
   #     server and access all state in the cluster including root keys
   #     and all ACL tokens. Do not distribute them to production hosts
   #     that are not server nodes. Store them as securely as CA keys.
   # ==> Using consul-agent-ca.pem and consul-agent-ca-key.pem
   # ==> Saved dc1-server-consul-0.pem
   # ==> Saved dc1-server-consul-0-key.pem

# Inspect the CA and generated server certificates.
openssl x509 -text -noout -in consul-agent-ca.pem
openssl x509 -text -noout -in dc1-server-consul-0.pem

# Notice the CN and Subject Alternative Name of the server certificate 
# that will be utilized to validate the identity of the server nodes.

# Each of the server nodes in our datacenter require the CA cert and 
# server cert/key. Copy the certificates to your other nodes:
scp -S ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null ./*.pem  consul-server-2:/etc/consul.d/
scp -S ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null ./*.pem  consul-server-3:/etc/consul.d/
scp -S ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null ./*.pem  consul-server-4:/etc/consul.d/
scp -S ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null ./*.pem  consul-server-5:/etc/consul.d/
scp -S ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null ./*.pem  consul-server-6:/etc/consul.d/
mv ./*.pem /etc/consul.d/

# Validate that the pem files exist on each node under the /etc/consul.d directory.
ls /etc/consul.d
   # config.hcl               consul-agent-ca.pem  consul.hcl    dc1-server-consul-0-key.pem
   # consul-agent-ca-key.pem  consul.env           consul.hclic  dc1-server-consul-0.pem

# Update the config on each node to use the new certificates. 
# Add the following lines to each server configuration (config.hcl):
# TODO: echo '
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
ca_file   = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/dc1-server-consul-0.pem"
key_file  = "/etc/consul.d/dc1-server-consul-0-key.pem"
# ' >> config.hcl

# Note: Be sure to save your configuration by selecting the little save icon on the configuration screen.
# Det each of the files inside the /etc/consul.d directory 
# to have the correct file ownership on all your nodes, and then 
# restart consul on each node:
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-2 chown consul:consul /etc/consul.d/*
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-2 sudo systemctl restart consul
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-3 chown consul:consul /etc/consul.d/*
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-3 sudo systemctl restart consul
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-4 chown consul:consul /etc/consul.d/*
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-4 sudo systemctl restart consul
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-5 chown consul:consul /etc/consul.d/*
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-5 sudo systemctl restart consul
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-6 chown consul:consul /etc/consul.d/*
ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null consul-server-6 sudo systemctl restart consul
chown consul:consul /etc/consul.d/*

sudo systemctl restart consul

# Check out the journal logs and validate that 
# TLS outgoing/incoming encryption is now true on the latest log entry.
journalctl -xe -u consul | grep "Encrypt"


# https://play.instruqt.com/HashiCorp-EA/tracks/consul-secure-deployment/challenges/enable-https/notes
### Challenge 5 - enable HTTPS

# If your datacenter is configured to only communicate via HTTPS, 
# you will need to create an additional certificate to continue to access the API, including using any of the CLI commands.
# To update your config to use HTTPS for the UI, 
# add the following to your configuration on Consul 1 Config to the end of the config.hcl:
   # ports {
   #   http = -1
   #   https = 8501
   # }

# While you're in the config on node 1, set verify_incoming = false, 
# and add the following lines: 
# TODO: create echo command
verify_incoming       = false
verify_incoming_rpc   = true
verify_incoming_https = false

# verify_incoming_rpc - When set to true, Consul requires that 
# all incoming RPC connections use TLS and that the 
# client provides a certificate signed by a Certificate Authority from 
# the ca_file or ca_path.

# At a minimimum it is recommended to enforce mTLS for RPC connections 
# (server<->server and agent<->server) vs. needing to 
# enforce mTLS for the API ports as well. 
# In the configuration above we are enforcing mTLS strictly for
#  RPC level communications. 
# In general it's a much simpler operations workflow for 
# interacting with the API by not enforcing mTLS holistically, 
# while still providing the security where it is more important -
# on the RPC side.

# API access is still authorized with bearer tokens from the ACL system, 
# and the channel is encrypted with one-way TLS. 
# Enabling mutual TLS using verify_incoming or verify_incoming_https 
# adds extra authentication that the request is coming from a
# known/trusted client.

# Once the configuration file is modified, save the configuration and reload the Consul service on Consul Terminal:
sudo systemctl restart consul

# Notice that after you make this change the Consul UI tab will break. 
# You may have to click the refresh button in the top-right of the page for this to happen.

# If you are trying to get members of your datacenter, 
# the CLI will now return an error because we are enforcing HTTPS and 
# we haven't provided a CLI certificate:
consul members

# Now we need to generate a new certificate for the CLI :
cd /etc/consul.d/
consul tls cert create -cli
chown consul:consul *.pem

# But it will work again if you provide the certificates you provided:
consul members \
    -http-addr="https://localhost:8501" \
    -ca-file="consul-agent-ca.pem" \
    -client-cert="dc1-cli-consul-0.pem" \
    -client-key="dc1-cli-consul-0-key.pem"

# This process can be cumbersome to type each time, so the Consul CLI also searches environment variables for default values. 
# Set the following environment variables in your shell:
export CONSUL_HTTP_ADDR="https://localhost:8501"
export CONSUL_CACERT="/etc/consul.d/consul-agent-ca.pem"
export CONSUL_CLIENT_CERT="/etc/consul.d/dc1-cli-consul-0.pem"
export CONSUL_CLIENT_KEY="/etc/consul.d/dc1-cli-consul-0-key.pem"

consul members

# Now, let's fix the UI. 
# To create a cert for the client accessing the Consul UI, run:
consul tls cert create -client

chown consul:consul *.pem

# Now we can use this cert to curl the UI over https:
curl https://server.dc1.consul:8501/ui/ \
  --resolve 'server.dc1.consul:8501:127.0.0.1' \
  --cacert consul-agent-ca.pem -I

# Note we got back a 200, which indicates everything worked as expected.

# END