# application-aware-intentions-in-consul-service-mesh-with-envoy.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/application-aware-intentions-in-consul-service-mesh-with-envoy
# by Karl Cardenas
# TODO: See https://github.com/hashicorp/consul-guides
# Configure and deploy application aware intentions to a pre-existing Consul datacenter.

echo "WARNING: There are several TODOs to keep this from working now."
exit

######## Verify the environment
# Familiarize yourself with the Consul datacenter and the services

# In Web Service tab:
# Verify all 3 Consul Servers, the two services (web and api), 
# and the ingress gateway containers are up and running and
# part of the Consul cluster.
consul members

 Node           Address            Status  Type    Build  Protocol  DC   Segment
 ConsulServer0  10.96.25.60:8301   alive   server  1.9.8  2         dc1  <all>
 ConsulServer1  10.96.42.24:8301   alive   server  1.9.8  2         dc1  <all>
 ConsulServer2  10.96.22.210:8301  alive   server  1.9.8  2         dc1  <all>
 api            10.96.20.29:8301   alive   client  1.9.6  2         dc1  <default>
 igw            10.96.30.133:8301  alive   client  1.9.5  2         dc1  <default>
 web            10.96.62.41:8301   alive   client  1.9.6  2         dc1  <default>

# Consul UI
# The Consul service mesh in this lab is configured to have a 
# pre-configured policy that denies all services communication.

# You can check the initial intentions configuration on 
# the Consul UI intentions tab. You should see a deny policy to all services.

# Application
# Go to the App tab,
# you should see a message "no healthy upstream" or RBAC: access denied. 
# This is due to our deny policy blocking all communication within the service mesh. If you were to issue the command below, you would see that the request returns an error.
curl --silent web.service.consul:9002 | jq

# NOTE: You may have to issue the command twice.


######## Create intentions
# Create an intention that allows the web service to communicate with the api service
# Consul 1.9 introduces the ability to create service intentions as
# configuration entries that can be applied globally to 
# many instances of a service or services.
# To make the api service accessible from the web service, you will need to 
# define an intention that permits communication between service web and service api.

# To make the web service work properly you will need to define an intention that permits communication between service web and service api. Create a file named config-intentions-web.hcl with the following content:

cat <<-EOF > config-intentions-web.hcl
Kind = "service-intentions"
Name = "api"
Sources = [
  {
    Name   = "web"
    Action = "allow"
  },
  # NOTE: a default catch-all based on the default ACL policy will apply to
  # unmatched connections and requests. Typically this will be DENY.
]
EOF

# This configuration entry defines an intention for
# service api allowing communication started from service web.
# Once you reviewed the file, apply the configuration:
consul config write config-intentions-web.hcl
   # Config entry written: service-intentions/api

# Verify intentions
# Go to the Consul UI and verify you see the new intention that 
# allows the service web to communicate with the api service. 

# You can also verify the intention is allowing communication by 
# issuing the command
curl --silent web.service.consul:9002 | jq

# NOTE: You may have to issue the command twice.


######## Access the Web UI
# Enable external access to the web UI

# To enable external access to the web service, you will need to
# setup an extra intention that will permit connections between the
# ingress gateway service and the web service.

# You will setup a more fine grained configuration where you will 
# only allow connections from the ingress gateway on the /ui path and
# deny connections on the /health path.

# Create L7 intention

# Once you verified connectivity between web and api,
# *the* next step is to expose your web interface 
# outside the mesh using the ingress gateway.

# You do not want to expose the root (/health) path outside the mesh because, being used to monitor the health of the service, it reveals details about the infrastructure state externally.

# Consul 1.9.0, with the service-intention config entry introduction also implemented a more powerful implementation of intentions for http services.

# Some intentions may additionally enforce access based on L7 request
# attributes in addition to connection identity.
# These may only be defined for services with a protocol that is HTTP-based.
cat <<-EOF > config-intentions-ingress-web.hcl
Kind = "service-intentions"
Name = "web"
Sources = [
  {
    Name = "ingress-service"
    Permissions = [
      {
        Action = "allow"
        HTTP {
          PathExact = "/"
          Methods   = ["GET"]
        }
      },
      {
        Action = "deny"
        HTTP {
          PathExact = "/health"
          Methods   = ["GET"]
        }
      }
    ]
  }
]
EOF

# The configuration entry above defines an intention for
# service web allowing GET http requests on /ui path and 
# denying those on /health started from service ingress-service,
# that is the service we configured as the ingress service representing
# web outside the mesh.

# Create the new intention.
consul config write config-intentions-ingress-web.hcl

# Verify service connectivity
# Go to the App tab and check out the ui. You may have to click on the refresh symbol in the upper right hand corner. You can now access the UI from an external service through the ingress gatewat.

# And you can verify the /health endpoint is actually denied. The command below should return a message stating the action is denied.
curl --silent web.ingress.consul:8080/health


# END