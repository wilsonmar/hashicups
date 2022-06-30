# consul-ingress-gateways-deployment.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-ingress-gateways-deployment
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit
# TODO

######## Challenge 1 - Deploy the Counting Service
# set up the counting service and the sidecar proxy using Envoy
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-ingress-gateways-deployment/challenges/1-deploy-counting-service/notes

# On Consul Server 1, 
# Validate that dc1 has three server nodes and two clients:
consul members
# The clients are separate virtual machines running the Consul agent in client mode. Both of these clients have the Envoy proxy installed.
   # Node                  Address            Status  Type    Build       Protocol  DC   Segment
   # consul-server-1       10.132.1.57:8301   alive   server  1.10.4+ent  2         dc1  <all>
   # consul-server-2       10.132.0.225:8301  alive   server  1.10.4+ent  2         dc1  <all>
   # consul-server-3       10.132.1.58:8301   alive   server  1.10.4+ent  2         dc1  <all>
   # app-counting-service  10.132.1.6:8301    alive   client  1.10.4+ent  2         dc1  <default>
   # consul-igw-dc1        10.132.1.19:8301   alive   client  1.10.4+ent  2         dc1  <default>
   # NOTE: IP addresses are different with every deployment.

# On the node App Server - Counting:
# validate that Envoy has been installed
#  by checking the version using the following command:
cd /tmp
wget --quiet https://archive.tetratelabs.io/envoy/download/v1.22.2/envoy-v1.22.2-linux-amd64.tar.xz -O envoy.tar.xz
tar -xf envoy.tar.xz
mv envoy-*/bin/envoy /usr/bin/envoy
chmod +x /usr/bin/envoy
cd ..
envoy --version
   # envoy  version: c919bdec19d79e97f4f56e4095706f8e6a383f1c/1.22.2/Clean/RELEASE/BoringSSL


# Check the Consul service catalog to view there is only a single service,
# the default Consul service:
consul catalog services
   # consul

# On the App Server - Counting tab:
# Start the counting service service:
PORT=9003 nohup /etc/counting.d/counting-service &
   # [1] 8152
   # nohup: ignoring input and appending output to 'nohup.out'
# If you see this, you're on the wrong tab:
   # nohup: failed to run command '/etc/counting.d/counting-service': No such file or directory

# Press Enter to get back to the command line

# View the counting service registration file:
# Note that we are registering the counting service and 
# registering a sidecar for the service:
cat /etc/consul.d/counting.hcl
   # service {
   #   name = "counting"
   #   id = "app-counting-service"
   #   port = 9003
   # 
   #   connect {
   #     sidecar_service {}
   #   }
   # 
   #   check {
   #     id       = "counting-check"
   #     http     = "http://localhost:9003/health"
   #     method   = "GET"
   #     interval = "1s"
   #     timeout  = "1s"
   #   }
   # }

# Now we're going to register the service with Consul using the 
# service configuration file we just viewed. 
# Register the service:
consul services register /etc/consul.d/counting.hcl
   # Registered service: counting

# Click the Consul UI tab and see that the counting service is
# registered but not healthy because the sidecar is not running.

# Back on the App Server - Counting node,
# start the sidecar proxy for the counting service. Since Envoy is already installed on the app server, you can just run the following command:
consul connect envoy -sidecar-for "app-counting-service" &

# ++ Consul UI tab should now show counting service running.

# Modify the default settings of Consul and
# configure a deny-by-default intention in Consul.
# Setting this policy requires that each individual service needs to be
# explicitly permitted using an allow intention.

# Run on Consul Server 1:
consul intention create -deny "*" "*"
   # Created: * => * (deny)


######## Challenge 2 - Deploy the Ingress Gateway
# In this lab, you'll deploy an ingress gateway and
# register the upstream service 

# The first step to get the Ingress Gateway running is to 
# register the configuration with Consul.

# On the Ingress Gateway CLI:
# view the service configuration file for the Ingress Gateway.
cat /etc/consul.d/ingress.hcl
   # Kind = "ingress-gateway"
   # Name = "ingress-gateway-service"
   # 
   # Listeners = [
   #  {
   #    Port = 8080
   #    Protocol = "tcp"
   #    Services = [
   #      {
   #        Name = "counting"
   #      }
   #    ]
   #  }
   # ]
# Note the Kind is ingress-gateway, and we're 
# defining a listener on port 8080 that will direct traffic to the
# counting service.
# This is how external applications/users will access the counting service.

# On the Ingress Gateway CLI, 
# register the Ingress Gateway configuration with Consul:
consul config write /etc/consul.d/ingress.hcl
   # Config entry written: ingress-gateway/ingress-gateway-service

# View the configuration of our gateway:
consul config read -kind=ingress-gateway -name=ingress-gateway-service
   # {
   #     "Kind": "ingress-gateway",
   #     "Name": "ingress-gateway-service",
   #     "Partition": "default",
   #     "Namespace": "default",
   #     "TLS": {
   #         "Enabled": false
   #     },
   #     "Listeners": [
   #         {
   #             "Port": 8080,
   #             "Protocol": "tcp",
   #             "Services": [
   #                 {
   #                     "Name": "counting",
   #                     "Hosts": null,
   #                     "Namespace": "default",
   #                     "Partition": "default"
   #                 }
   #             ]
   #         }
   #     ],
   #     "CreateIndex": 2589,
   #     "ModifyIndex": 2589
   # }

# Now that the ingress gateway is registered, we can
# start the ingress gateway.
# Envoy is already installed and the service can be started:
consul connect envoy -gateway=ingress -register -service ingress-gateway-service -address "${local_ipv4}:8888"
   # [2022-06-30 18:32:43.919][9140][info][upstream]
   # [external/envoy/source/server/lds_api.cc:78]
   # lds: add/update listener 'default/default/counting:0.0.0.0:8080'

   # [2022-06-30 18:32:43.919][9140][info][config] [external/envoy/source/server/listener_manager_impl.cc:888] all dependencies initialized. starting workers

# Click the Consul UI to validate the "ingress-gateway-service" is 
# registered and healthy. 
# Click the ingress-gateway-service service to review the topology map.
# Note the red X indicating that these services cannot communicate
# since we created the default Deny intention.
# Don't worry, we'll fix that soon.
# You can also see the upstreams registered with this ingress gateway
# on the Upstreams tab.

# You should also be able to
# query the counting service using the ingress gateway
# using Consul's DNS service using counting.ingress.dc1.consul.

# On Consul Server 1, 
# validate you can query the service and return the IP address:
dig @127.0.0.1 -p 8600 counting.ingress.dc1.consul. ANY
   # ; <<>> DiG 9.16.1-Ubuntu <<>> @127.0.0.1 -p 8600 counting.ingress.dc1.consul. ANY
   # ; (1 server found)
   # ;; global options: +cmd
   # ;; Got answer:
   # ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 9609
   # ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
   # ;; WARNING: recursion requested but not available
   # 
   # ;; OPT PSEUDOSECTION:
   # ; EDNS: version: 0, flags:; udp: 4096
   # ;; QUESTION SECTION:
   # ;counting.ingress.dc1.consul.   IN      ANY
   # 
   # ;; ANSWER SECTION:
   # counting.ingress.dc1.consul. 0  IN      A       10.132.2.87
   # 
   # ;; Query time: 0 msec
   # ;; SERVER: 127.0.0.1#8600(127.0.0.1)
   # ;; WHEN: Thu Jun 30 18:35:04 UTC 2022
   # ;; MSG SIZE  rcvd: 72

# Notice the IP address we get back (10.132.2.87)
# is the ingress gateway and
# not the host running the counting service.

# Note: To obtain the address of the host running the counting service:
dig @127.0.0.1 -p 8600 counting.service.consul
   # ; <<>> DiG 9.16.1-Ubuntu <<>> @127.0.0.1 -p 8600 counting.service.consul
   # ; (1 server found)
   # ;; global options: +cmd
   # ;; Got answer:
   # ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 25838
   # ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
   # ;; WARNING: recursion requested but not available
   # 
   # ;; OPT PSEUDOSECTION:
   # ; EDNS: version: 0, flags:; udp: 4096
   # ;; QUESTION SECTION:
   # ;counting.service.consul.       IN      A
   # 
   # ;; ANSWER SECTION:
   # counting.service.consul. 0      IN      A       10.132.2.90
   # 
   # ;; Query time: 0 msec
   # ;; SERVER: 127.0.0.1#8600(127.0.0.1)
   # ;; WHEN: Thu Jun 30 18:38:47 UTC 2022
   # ;; MSG SIZE  rcvd: 68

# Using the ingress gateway allows applications to connect via 
# DNS name (counting.ingress.consul) and 
# use the ingress gateway as the entry point into the service mesh. 

# We will use this DNS record to configure the dashboard service in 
# the next lab.


######## Challenge 3 - Deploy the Dashboard Service
# In this lab, you'll deploy the dashboard service
# outside of the service mesh
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-ingress-gateways-deployment/challenges/3-deploy-dashboard-service/notes

# The dashboard service is running on another host that is 
# NOT part of the Consul service mesh. 
# In fact, it doesn't even have the Consul agent or Envoy installed. 
# We're going to start the dashboard service on this host while 
# pointing to the ingress gateway and port we registered in the last lab.

# Now let's start the Dashboard service using the following command. Notice that we are using the DNS name of the service registered with the Ingress Gateway and the port of 8080 which we configured in the last lab.

# On Dashboard App Server:
PORT=9002 COUNTING_SERVICE_URL="http://counting.ingress.consul:8080" \
   /etc/dashboard.d/dashboard-service nohup &
   # [1] 14291
   # root@app-dashboard-service:~# Starting server on http://0.0.0.0:9002
   # (Pass as PORT environment variable)
   # Using counting service at http://counting.ingress.consul:8080
   # (Pass as COUNTING_SERVICE_URL environment variable)
   # Starting websocket server...
   # New client connected
   # Fetched count -1
   # Fetched count -1

# To view the application, click the Dashboard Application tab. 
# ** If the dashboard is not yet showing, click the refresh icon
# (at the top right).

# Notice the connection indicator in the dashboard UI will
# show "Counting Service is Unreachable"
# due to our zero-trust networking approach.
# This means that we need to explicitly enable the connection
# between the two services. That's what we'll do in the next few steps.

# In the Consul UI tab, 
# click the counting service and click on topolgy. 
# Notice how the ingress-gateway-service cannot communicate with
# the counting service due to the current intention configuration.
# Let's fix that.

# In the Consul Server 1 tab, 
# create an intention that permits communication from 
# the ingress gateway to the counting service.
consul intention create -allow ingress-gateway-service counting
   # Created: ingress-gateway-service => counting (allow)

# ++ systemctl restart systemd-resolved

# Back in the Dashboard Application tab, 
# validate that the Dashboard service can now access the counting service 
# and the number is now incrementing. 

# Back in the Consul UI, you can also view the topology to see that 
# the communication is now permitted. 
# You can also view the new intention we created.

# That's it! 
# You've successfully deployed an ingress gateway that 
# enabled communication from a service outside the service mesh (dashboard)
# with a service running inside the service mesh (counting).


# END