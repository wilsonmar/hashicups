# load-balancing-services-in-consul-service-mesh-with-envoy.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/load-balancing-services-in-consul-service-mesh-with-envoy
# by Gabe Maentz
# TODO: See https://github.com/hashicorp/consul-guides
# Load Balancing Services in Consul Service Mesh with Envoy
# In this hands-on lab, you will operate a Consul datacenter and
# configure load balancing policies on service sidecar proxies.

echo "WARNING: There are several TODOs to keep this from working now."
exit

# TODO: Reverse challenges 2 and 3, or give each a different name other than "backend"

# Specifically, you will:

   # Inspect the environment with the Consul CLI
   # Verify default least_request load balancing policy
   # Use centralized configuration to set service defaults
   # Use the maglev policy to configure load balancing with sticky session
   # Verify the new configuration
   # Use least_request load balancing policy
   # Verify the new configuration
   # Use the ingress gateway to access the service

######## 1 - Verify the environment and load balancing policy

# Before updating the load balancing policy, 
# check that the environment has 3 Consul server agents, 
# two backend services, and ingress gateway.

# This can be verified by using consul members on one of the containers
consul members
   # Node           Address            Status  Type    Build  Protocol  DC   Segment
   # ConsulServer0  10.2.12.110:8301  alive   server  1.10.1  2         dc1  <all>
   # ConsulServer1  10.2.27.148:8301  alive   server  1.10.1  2         dc1  <all>
   # ConsulServer2  10.2.7.42:8301    alive   server  1.10.1  2         dc1  <all>
   # backend-clone  10.2.13.247:8301  alive   client  1.9.6   2         dc1  <default>
   # backend-main   10.2.4.56:8301    alive   client  1.9.6   2         dc1  <default>
   # client         10.2.38.239:8301  alive   client  1.9.6   2         dc1  <default>
   # igw            10.2.1.55:8301    alive   client  1.10.0  2         dc1  <default>
# In this configuration you can verify the backend service is accessible from the ingress gateway by visiting the App tab. 
# Alternatively, you may curl the application.
curl localhost:9192 | jq
   # {
   #   "name": "clone",
   #   "uri": "/",
   #   "type": "HTTP",
   #   "ip_addresses": [
   #     "10.2.13.247"
   #   ],
   #   "start_time": "2022-06-30T15:14:50.827871",
   #   "end_time": "2022-06-30T15:14:50.828114",
   #   "duration": "242.424µs",
   #   "body": "Hello World",
   #   "code": 200
   # }

# Default load balancing policy:
# By default Consul balances traffic across instances of the 
# same service using the round_robin policy.

# You can verify the balancing by issuing the curl command multiple times.
# You may also click on the "Go" button in the App Tab multiple times.

  $ curl -s localhost:9192
  {
    "name": "main",
    "uri": "/",
    "type": "HTTP",
    "ip_addresses": [
      "10.96.27.195"
    ],
    "start_time": "2021-08-10T00:21:28.577020",
    "end_time": "2021-08-10T00:21:28.577184",
    "duration": "164.015µs",
    "body": "Hello World",
    "code": 200
  }


######## 2 - Verify the environment and load balancing policy

# A common requirements for many applications is to have the possibility
# to redirect all the requests from a specific client to the same server.
# You can achieve this configuration using the maglev policy.
# To learn more about other supported policies, please visit https://www.consul.io/docs/connect/config-entries/service-resolver#policy.

# Once verified, you can access the backend service and that the
# round_robin policy is applied you can apply new policies for the
# load balancing and verify how these affect the requests' resolution.

# Configure service defaults
# In order to enable service resolution and apply load balancer policies,
# you need to define the service protocol in a
# service-defaults configuration entry.

# The lab provides a default configuration for service-defaults 
# Go ahead and issue the command below to view the service default.
consul config read -kind service-defaults -name backend | jq
   # {
   #   "Kind": "service-defaults",
   #   "Name": "backend",
   #   "Protocol": "http",
   #   "MeshGateway": {},
   #   "Expose": {},
   #   "CreateIndex": 25,
   #   "ModifyIndex": 25
   # }

# Configure service resolution with sticky sessions
# A common *requirements* for many applications is to have the possibility to redirect all the requests from a specific client to the same server.

# You can achieve this configuration using the maglev policy
# provided in the command below. Go ahead and issue the command below.
cat <<-EOF > /etc/consul.d/hash-resolver.hcl
Kind           = "service-resolver"
Name           = "backend"
LoadBalancer = {
    Policy = "maglev"
    HashPolicies = [
      {
        Field = "header"
        FieldValue = "x-user-id"
      }
    ]
}
EOF

# This configuration creates a service-resolver configuration,
# for the service backend that uses the content of the x-user-id header to resolve requests.

# You can apply the policy using the consul config command.
consul config write /etc/consul.d/hash-resolver.hcl
   # Config entry written: service-resolver/backend

# Verify the policy is applied
# Once the policy is in place, you can test it using the
# curl command and applying the x-user-id header to the request,
# using x-user-id which was hard-coded:
curl -s localhost:9192 -H "x-user-id: 12345" | jq
   # {
   #   "name": "main",
   #   "uri": "/",
   #   "type": "HTTP",
   #   "ip_addresses": [
   #     "10.2.4.56"
   #   ],
   #   "start_time": "2022-06-30T15:20:32.649671",
   #   "end_time": "2022-06-30T15:20:32.649876",
   #   "duration": "204.814µs",
   #   "body": "Hello World",
   #   "code": 200
   # }

# Execute the curl command multiple times, you will always be redirected to the same instance of the backend service.

# NOTE: Sticky sessions are consistent given a stable service configuration. If the number of backend hosts changes, a fraction of the sessions will be routed to a new host after the change.

# Check configuration
# Another way to verify the policy applied to services is to use the consul config command to list and
# inspect the configuration entries in your Consul datacenter:
consul config read -kind service-resolver -name backend | jq
# ** You should see a similar following output.
{
    "Kind": "service-resolver",
    "Name": "backend",
    "LoadBalancer": {
        "Policy": "maglev",
        "HashPolicies": [
            {
                "Field": "header",
                "FieldValue": "x-user-id"
            }
        ]
    },
    "CreateIndex": 146,
    "ModifyIndex": 662
}

######## 3 - Configure least_req policy

# The default load balancing policy, round_robin, is usually
# the best approach in scenarios where requests are homogeneous and 
# the system is over-provisioned.

# In scenarios where the different instances might be
# subject to substantial differences in terms of workload there are
# better approaches.

# Using the least_request policy permits Envoy sidecar proxies to
# resolve requests using information on instance load level and
# select the one with the lowest load.

# Generate a file containing the configuration for a least_request policy.
cat <<-EOF > /etc/consul.d/least-req-resolver.hcl
Kind           = "service-resolver"
Name           = "backend"
LoadBalancer = {
  Policy = "least_request"
  LeastRequestConfig = {
    ChoiceCount = "2"
  }
}
EOF

# This configuration creates a service-resolver load balancing policy,
# for every request to the backend service 2 (as expressed by ChoiceCount).
# Random instances of that service are selected and the traffic is
# routed to the one with the least amount of load.
# You can apply the policy using the consul config command.
consul config write /etc/consul.d/least-req-resolver.hcl
   # Config entry written: service-resolver/backend

# Verify the policy is applied
# Once the policy is in place, you can test it using the curl command and applying the x-user-id header to the request:
curl -s localhost:9192 -H "x-user-id: 12345" | jq
   # {
   #   "name": "clone",
   #   "uri": "/",
   #   "type": "HTTP",
   #   "ip_addresses": [
   #     "10.2.13.247"
   #   ],
   #   "start_time": "2022-06-30T15:28:59.289409",
   #   "end_time": "2022-06-30T15:28:59.289612",
   #   "duration": "202.826µs",
   #   "body": "Hello World",
   #   "code": 200
   # }

# Execute the command multiple times to verify that, 
# despite the user id in the header,
# the request gets served by different instances of the service.

# INFO: The least_request configuration with ChoiceCount set to 2 is
# also known as P2C (power of two choices).
# The P2C load balancer has the property that a host with
# the highest number of active requests in the cluster will
# never receive new requests.
# It will be allowed to drain until it is less than or equal to
# all of the other hosts.
# You can read more on this on this paper
# https://www.eecs.harvard.edu/~michaelm/postscripts/handbook2001.pdf


######## Load balancing and ingress gateways

# The load balancing policy for the service sidecar proxies also
# applies to the service resolution performed by ingress gateways.
# Once you configured the policies for the services and
# tested it internally using the client service, you can
# introduce an ingress gateway in your configuration and the
# same policies will be now respected by external requests
# being served by your Consul datacenter.

# In this lab you can access the service from the App tab.

# By refreshing the App tab (Click on the "Go" button)
# you can verify that the request is
# being balanced between both instances of the service.

# To test the load balancing policy on ingress gateways you can
# re-enable the sticky session for service resolution:
consul config write /etc/consul.d/hash-resolver.hcl
   # Config entry written: service-resolver/backend

# Verify the policy is applied
# Once the policy is in place you can test it using the curl command and applying the x-user-id header to the request.
curl -s ingress-service.service.consul:8080 -H "x-user-id: 12345" | jq
   # {
   #   "name": "clone",
   #   "uri": "/",
   #   "type": "HTTP",
   #   "ip_addresses": [
   #     "10.2.1.58"
   #   ],
   #   "start_time": "2022-06-30T15:43:28.871866",
   #   "end_time": "2022-06-30T15:43:28.872023",
   #   "duration": "156.521µs",
   #   "body": "Hello World",
   #   "code": 200
   # }

# Execute the curl command multiple times you, **
# will always be redirected to the same instance of the backend service.





# END