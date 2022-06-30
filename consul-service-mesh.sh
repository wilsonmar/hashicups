#!/bin/bash
# consul-service-mesh.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-mesh
# Learn how to register services with a sidecar, start the Envoy sidecar, and enable communication using Intentions.
# TODO: See https://github.com/hashicorp/consul-guides
# TODO: In prod, instead of "counting" service, replace with real name.

echo "WARNING: There are several TODOs to keep this from working now."
exit

# Not in Data Plane 
# offload to a sidecar proxy - Envoy.

####### Challenge 1 - Register Services in the Service Mesh
# Learn how to register services with Consul that will be used in the service mesh.
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-mesh/challenges/add-services/notes

# The goal is to have two services communicating securely through 
# their sidecar proxies using Consul's service mesh.

# On Consul 1 - DC1:
# bootstrap the ACL system and create policies and tokens:
cd /root
consul acl bootstrap >> bootstrap.txt
export CONSUL_HTTP_TOKEN=$(cat bootstrap.txt | grep --color=NEVER  "SecretID:"  | cut -d ' '  -f10)
echo $CONSUL_HTTP_TOKEN
   # export CONSUL_HTTP_TOKEN="7163196f-4e37-006f-cb13-7f65a3df7883"

# You should now be able to login to Consul UI using this bootstrap token.

# Create Node Policy:
echo 'agent_prefix "" {
  policy = "write"
}
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
session_prefix "" {
  policy = "read"
}' >> node-policy.hcl

consul acl policy create \
  -name node-policy \
  -rules @node-policy.hcl
   # ID:           1aac3a70-3393-d3cc-8b37-c52ee4398560
   # Name:         node-policy
   # Partition:    default
   # Namespace:    default
   # Description:  
   # Datacenters:  
   # Rules:
   # agent_prefix "" {
   #   policy = "write"
   # }
   # node_prefix "" {
   #   policy = "write"
   # }
   # service_prefix "" {
   #   policy = "read"
   # }
   # session_prefix "" {
   #   policy = "read"
   # }

# Generate Node Token for Node Policy:
consul acl token create \
  -description "node token" \
  -policy-name node-policy
   # AccessorID:       474e6fa6-5702-ee7f-d84e-c9524f01e75f
   # SecretID:         92eb19c4-8866-b055-0ae9-33d2e9f55b3f
   # Partition:        default
   # Namespace:        default
   # Description:      node token
   # Local:            false
   # Create Time:      2022-06-29 19:05:18.747743688 +0000 UTC
   # Policies:
   #    1aac3a70-3393-d3cc-8b37-c52ee4398560 - node-policy

# Manually save the node token above and bootstrap token to 
# your local machine (using notepad, notes, etc.):
# export CONSUL_NODE_TOKEN="your_node_token_here"
# export CONSUL_NODE_TOKEN="92eb19c4-8866-b055-0ae9-33d2e9f55b3f"
echo $CONSUL_HTTP_TOKEN
echo $CONSUL_NODE_TOKEN

# Apply the node token for all Consul agents in the cluster:
consul acl set-agent-token agent $CONSUL_NODE_TOKEN
ssh -o stricthostkeychecking=no consul-server-2 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-3 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-4 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-5 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN" && \
ssh -o stricthostkeychecking=no consul-server-6 "export CONSUL_HTTP_TOKEN=$CONSUL_HTTP_TOKEN && consul acl set-agent-token agent $CONSUL_NODE_TOKEN"
   # Warning: Permanently added 'consul-server-2,10.132.2.178' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-3,10.132.1.171' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-4,10.132.2.180' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-5,10.132.2.179' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully
   # Warning: Permanently added 'consul-server-6,10.132.2.181' (ECDSA) to the list of known hosts.
   # ACL token "agent" set successfully

# All your lab instances already have two, pre-installed services and 
# related service registration files. 
# You will need to register both services and their 
# proxies in the Consul catalog, start the services, and then
# start their proxies.

# On Consul 1 - DC1, create the counting service definition:
echo 'service {
  name = "counting"
  id = "counting-1"
  port = 9003

  connect {
    sidecar_service {}
  }

  check {
    id       = "counting-check"
    http     = "http://localhost:9003/health"
    method   = "GET"
    interval = "1s"
    timeout  = "1s"
  }
}' >> /root/counting.hcl

# On Consul 2 - DC1, create the dashboard service definition:
echo 'service {
  name = "dashboard"
  id = "dashboard-1"
  port = 9002

  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "counting"
            local_bind_port  = 5000
          }
        ]
      }
    }
  }

  check {
    id       = "dashboard-check"
    http     = "http://localhost:9002/health"
    method   = "GET"
    interval = "1s"
    timeout  = "1s"
  }
}' >> /root/dashboard.hcl

# Submit the service definitions to your Consul agent.
# On Consul 1 - DC1, run:
consul services register counting.hcl
   # Registered service: counting

# On Consul 2 - DC1, run:
# export CONSUL_HTTP_TOKEN="add_your_bootstrap_token_here"
# export CONSUL_HTTP_TOKEN="7163196f-4e37-006f-cb13-7f65a3df7883"
consul services register dashboard.hcl
   # Registered service: dashboard

# Verify that the services were created correctly:
consul catalog services
   # consul
   # counting
   # counting-sidecar-proxy
   # dashboard
   # dashboard-sidecar-proxy


####### Challenge 2 - Configure intentions to permit the services to communicate.
# Validate and permit communication between the two services.
# Add intentions to enable communication between the services.
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-mesh/challenges/set-intentions/notes

# Intentions define authorization policies for services in 
# the service mesh and are used to control which services may 
# establish connections. 
# The default intention behavior is defined by the default ACL policy.

# On Consul 1 - DC-1, export your HTTP token again:
# export CONSUL_HTTP_TOKEN=<your_token_here>
# export CONSUL_HTTP_TOKEN="7163196f-4e37-006f-cb13-7f65a3df7883"

# Log in to the UI using your bootstrap token, and 
# select the dashboard service. 
# Notice how there is an "x" for the two services, 
# indicating that they are not permitted to communicate due to the
# current intentions.
# Let's fix that...create an intention for your services:
# On Consul 1 - DC-1:
consul intention create dashboard counting
   # Created: dashboard => counting (allow)

# Check the UI again. Now there should be no issues with the
# dashboard service and its upstream service (counting), because 
# the Allow intention was created.
# TODO: Still showing red checks.


####### Challenge 3 - Start the applications and related service mesh proxies
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-mesh/challenges/start-services/notes

# On Consul 1 - DC-1, 
# export your HTTP token again and set the required TLS variables:
# export CONSUL_HTTP_TOKEN=<your_token_here>
  export CONSUL_HTTP_TOKEN="7163196f-4e37-006f-cb13-7f65a3df7883"
export CONSUL_HTTP_SSL=true
export CONSUL_HTTP_ADDR=127.0.0.1:8501
export CONSUL_CACERT="/etc/consul.d/consul-agent-ca.pem"
export CONSUL_CLIENT_CERT="/etc/consul.d/dc1-cli-consul-0.pem"
export CONSUL_CLIENT_KEY="/etc/consul.d/dc1-cli-consul-0-key.pem"

# On Consul 1 - DC1, install and start the counting service:
wget https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/counting-service_linux_amd64.zip
   # 2022-06-29 19:25:36 (66.7 MB/s) - ‘counting-service_linux_amd64.zip’ saved [3629949/3629949]
unzip counting-service_linux_amd64.zip
mv counting-service_linux_amd64 /usr/local/bin/counting-service
rm counting-service_linux_amd64.zip
PORT=9003 counting-service &
   # [1] 12454

# Still on Consul 1 - DC1, 
# start the Envoy sidecar proxy for the counting service:
consul connect envoy -sidecar-for counting-1 &

# On Consul 2 - DC1, set the following environment variables:
# export CONSUL_HTTP_TOKEN=<your_token_here>
export CONSUL_HTTP_TOKEN="7163196f-4e37-006f-cb13-7f65a3df7883"
export CONSUL_HTTP_SSL=true
export CONSUL_HTTP_ADDR=127.0.0.1:8501
export CONSUL_CACERT="/etc/consul.d/consul-agent-ca.pem"
export CONSUL_CLIENT_CERT="/etc/consul.d/dc1-cli-consul-0.pem"
export CONSUL_CLIENT_KEY="/etc/consul.d/dc1-cli-consul-0-key.pem"

# On Consul 2 - DC1, install and start the dashboard service pointing to a local port for the counting service url.
wget https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/dashboard-service_linux_amd64.zip
   # 2022-06-29 19:25:36 (66.7 MB/s) - ‘counting-service_linux_amd64.zip’ saved [3629949/3629949]
unzip dashboard-service_linux_amd64.zip
mv dashboard-service_linux_amd64 /usr/local/bin/dashboard-service
rm dashboard-service_linux_amd64.zip
PORT=9002 COUNTING_SERVICE_URL="http://127.0.0.1:5000" dashboard-service &
   # [1] 12155

# Now, start the Envoy sidecar proxy for the dashboard service:
consul connect envoy -sidecar-for dashboard-1 &
   # (Pass as PORT environment variable)
   # Using counting service at http://127.0.0.1:5000
   # (Pass as COUNTING_SERVICE_URL environment variable)
   # Starting websocket server...
   # New client connected
   # Fetched count -1
   # Fetched count -1
   # Fetched count -1

# If you then open the UI tab and login using your HTTP token, 
# you will see that the counting service and the 
# dashboard service are in the service mesh with the proxy enabled.

# You can also view the counting service on the local side car proxy port 
# on Consul 2 - DC1
curl http://127.0.0.1:5000


####### More: split (shape) traffic via Layer 7


# END