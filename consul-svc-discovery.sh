#!/bin/bash
# consul-svc-discovery.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-discovery
# See how Consul's Service Discovery feature works by connecting multiple services.
# TODO: See https://github.com/hashicorp/consul-guides
# TODO: In prod, instead of "counting" service, replace with real name.

echo "WARNING: There are several TODOs to keep this from working now."
exit

####### Challenge 1 - Register the Counting service
# Register a the Counting service using a service registration file
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-discovery/challenges/register-service/notes

# As of now, you have a Consul cluster with six nodes, but 
# there are no services currently registered with Consul. 
# To validate this, on Consul 1 - DC1:
consul catalog services 
   # consul
   # Consul returned only the default consul service, but no other services. 
   # So let's register a new service.

# On Consul 1 - DC1:
# create a new service configuration file for the counting service:
echo '
service {
  name = "counting"
  port = 9003
  check {
    id = "counting-check"
    http = "http://localhost:9003/health"
    method = "GET"
    interval = "1s"
    timeout = "1s"
  }
}' >> /etc/consul.d/counting.hcl

# Register the new service:
consul services register /etc/consul.d/counting.hcl
   # Registered service: counting

# Make sure that your service was correctly registered:
consul catalog services
   # consul
   # counting

# Alternatively, you can look at the Consul UI tab and 
# view the services there. 
# Don't worry that the health check is currently failing. 
# We've registered the service but we haven't started it yet.


####### Challenge 2 - Start the Counting service and validate its health
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-discovery/challenges/start-service/notes

# Install the counting-service on your machine and in your PATH.
wget https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/counting-service_linux_amd64.zip
unzip counting-service_linux_amd64.zip
   # Archive:  counting-service_linux_amd64.zip
   # inflating: counting-service_linux_amd64  
mv counting-service_linux_amd64 /usr/local/bin/counting-service
rm counting-service_linux_amd64.zip

# All its configuration is supplied via environment variables, 
# so the only one we need to specify is the PORT, 
# which will be 9003 as configured above.

# On Consul 1 - DC1:
# start the counting service to run in the background.
# configure its port with the following command. 
PORT=9003 nohup counting-service &
   # [1] 8574

# Press ENTER to get the command prompt back.
# The service will continue to run in the background.

# Confirm that the service was started:
curl http://localhost:9003
   # {"count":1,"hostname":"consul-server-1"}

# Alternatively, check the Consul UI to validate that the service is 
# now healthly (shows a green check mark).


####### Challenge 3 - Register and Start the Dashboard Service
# Register the Dashboard service, start it, and validate connectivity
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-discovery/challenges/start-dashboard/notes

# Register the dashboard service.
# The dashboard uses the counting service and
# displays the "count" retrieved from the upstream service (counting).

# On Consul 1 - DC1 - Session A:
# create the service registration file for the dashboard service:
echo '
service {
  name = "dashboard"
  port = 9002
  check {
    id = "dashboard-check"
    http = "http://localhost:9002/health"
    method = "GET"
    interval = "1s"
    timeout = "1s"
  }
}' >> /etc/consul.d/dashboard.hcl

# Register the service:
consul services register /etc/consul.d/dashboard.hcl
   # Registered service: dashboard

# View the newly registered dashboard service in the Consul UI or find it by issuing the following command:
consul catalog services
   # consul
   # counting
   # dashboard

# Start the service after the dashboard-service needs to be installed on your machine and in your PATH.
wget https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/dashboard-service_linux_amd64.zip
   # 2022-06-29 18:47:06 (95.1 MB/s) - ‘dashboard-service_linux_amd64.zip’ saved [4575727/4575727]
unzip dashboard-service_linux_amd64.zip
mv dashboard-service_linux_amd64 /usr/local/bin/dashboard-service
rm dashboard-service_linux_amd64.zip

# It gets all its configuration via environment variables. 
# You will use these to supply the PORT on which to 
# run the dashboard service and the URL of the pre-existing counting service.

# Start the dashboard service with the PORT and counting service URL configured using the following command.
PORT=9002 COUNTING_SERVICE_URL="http://counting.service.consul:9003" \
   nohup dashboard-service &
# In this case, notice we are using Consul's Service Discovery capability 
# so the dashboard service can discover the location of the counting service
# by using the DNS interface.

# Check out the application by clicking the Dashboard UI tab. 
# Notice how it shows it is connected to the counting service and 
# the number continues to increment.

# You may need to start the systemd-resolved service 
# in order for counting.service.consul to resolve correctly via DNS.
systemctl restart systemd-resolved



####### Challenge 4 - Explore Consul DNS
# See how you can query Consul's DNS interface to obtian information about a service
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-discovery/challenges/4-explore-dns/notes

# The dashboard service is using Consul's service discovery to 
# find a healthy instance of the counting service based on the 
# service's record, counting.service.consul, and port number, which 
# you included as environment variables in the dashboard's start command.

# Discover what Consul will find when it looks for the counting service by
# running the DNS query yourself and inspecting the output.
# Here's an example of what it could look like:

# ;; ANSWER SECTION:
# dashboard.service.consul. 0     IN      A       10.132.0.99

# Now ask Consul service discovery to give you the SRV record for the counting service.
dig @127.0.0.1 -p 8600 counting.service.consul SRV
   # Consul will return the SRV record for the counting service, 
   # including an IP address and port.
   # ; <<>> DiG 9.16.1-Ubuntu <<>> @127.0.0.1 -p 8600 counting.service.consul SRV
   # ; (1 server found)
   # ;; global options: +cmd
   # ;; Got answer:
   # ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64440
   # ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 4
   # ;; WARNING: recursion requested but not available
   # 
   # ;; OPT PSEUDOSECTION:
   # ; EDNS: version: 0, flags:; udp: 4096
   # ;; QUESTION SECTION:
   # ;counting.service.consul.       IN      SRV
   # 
   # ;; ANSWER SECTION:
   # counting.service.consul. 0      IN      SRV     1 1 9003 consul-server-1.node.dc1.consul.
   # 
   # ;; ADDITIONAL SECTION:
   # consul-server-1.node.dc1.consul. 0 IN   A       10.132.3.126
   # consul-server-1.node.dc1.consul. 0 IN   TXT     "az=Zone1"
   # consul-server-1.node.dc1.consul. 0 IN   TXT     "consul-network-segment="
   # 
   # ;; Query time: 0 msec
   # ;; SERVER: 127.0.0.1#8600(127.0.0.1)
   # ;; WHEN: Wed Jun 29 18:50:32 UTC 2022
   # ;; MSG SIZE  rcvd: 176


####### Challenge5 - Reconfigure a Service without incurring downtime
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-service-discovery/challenges/reconfigure-service/notes

# Most service changes can be reloaded with the consul reload command.

# On the Consul 1 Config tab:
# open the counting service configuration file /etc/counting.hcl.
   # service {
   #   name = "counting"
   #   port = 9003
   #   check {
   #     id = "counting-check"
   #     http = "http://localhost:9003/health"
   #     method = "GET"
   #     interval = "1s"
   #     timeout = "1s"
   #   }
   # }

# Edit the service configuration by adding an extra tag such as 
# golang or javascript or v2.
# The file should look similar to the following - 
# note the new tags configuration:

service {
name = "counting"
port = 9003
tags = ["counting-v2"]
check {
  id = "counting-check"
  http = "http://localhost:9003/health"
  method = "GET"
  interval = "1s"
  timeout = "1s"
 }
}
# Save your file, and run on Consul 1 - DC1.
consul reload
   # Configuration reload triggered

# Go to the web UI and verify that the tag was added
# at Overview: Services, counting: Tags

# You can also query the service with the newly provided tag.
dig counting-v2.counting.service.consul
# Look in " QUESTION SECTION:"
   # ; <<>> DiG 9.16.1-Ubuntu <<>> counting-v2.counting.service.consul
   # ;; global options: +cmd
   # ;; Got answer:
   # ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 42363
   # ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1

   # ;; OPT PSEUDOSECTION:
   # ; EDNS: version: 0, flags:; udp: 65494
   # ;; QUESTION SECTION:
   # ;counting-v2.counting.service.consul. IN        A
   # 
   # ;; Query time: 40 msec
   # ;; SERVER: 127.0.0.53#53(127.0.0.53)
   # ;; WHEN: Wed Jun 29 18:55:36 UTC 2022
   # ;; MSG SIZE  rcvd: 64
