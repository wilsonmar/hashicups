# consul-and-chaos-engineering.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-and-chaos-engineering
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

# Conduct chaos engineering experiments against the application, HashiCups.
# You will also learn about how Consul can greatly improve an application's 
# availability and resiliency through the usage of service mesh.

######## Verify the environment

# Verify all of the services are up and running in 
# both Consul datacenters, DC1 and DC2. 
# Start by verifying through the Consul CLI that all services are up.
docker exec frontend bash -c "consul members"
   # Node             Address        Status  Type    Build   Protocol  DC   Partition  Segment
   # consul_server_0  10.5.0.2:8301  alive   server  1.11.1  2         dc1  default    <all>
   # consul_server_1  10.5.0.3:8301  alive   server  1.11.1  2         dc1  default    <all>
   # consul_server_2  10.5.0.4:8301  alive   server  1.11.1  2         dc1  default    <all>
   # frontend-0       10.5.0.5:8301  alive   client  1.11.1  2         dc1  default    <default>
   # payments0        10.5.0.9:8301  alive   client  1.11.1  2         dc1  default    <default>
   # product-api0     10.5.0.7:8301  alive   client  1.11.1  2         dc1  default    <default>
   # product-db-0     10.5.0.8:8301  alive   client  1.11.1  2         dc1  default    <default>
   # public-api-0     10.5.0.6:8301  alive   client  1.11.1  2         dc1  default    <default>

docker exec frontend-secondary bash -c "consul members"
   # Node                       Address        Status  Type    Build   Protocol  DC   Partition  Segment
   # consul_secondary_server_0  10.5.1.2:8301  alive   server  1.11.1  2         dc2  default    <all>
   # consul_secondary_server_1  10.5.1.3:8301  alive   server  1.11.1  2         dc2  default    <all>
   # consul_secondary_server_2  10.5.1.4:8301  alive   server  1.11.1  2         dc2  default    <all>
   # frontend-secondary0        10.5.1.5:8301  alive   client  1.11.1  2         dc2  default    <default>
   # payments-secondary0        10.5.1.9:8301  alive   client  1.11.1  2         dc2  default    <default>
   # product-api-secondary0     10.5.1.7:8301  alive   client  1.11.1  2         dc2  default    <default>
   # product-db-secondary0      10.5.1.8:8301  alive   client  1.11.1  2         dc2  default    <default>
   # public-api-secondary0      10.5.1.6:8301  alive   client  1.11.1  2         dc2  default    <default>

# Do the same through the Consul UI by visting the Consul tab. 
# You will have to log in with the Consul bootstrap token.

# Get the Consul token value by echoing the CONSUL_HTTP_TOKEN environment variable.
echo $CONSUL_HTTP_TOKEN
   # 20d16fb2-9bd6-d238-bfdc-1fab80177667

# NOTE: After clicking on Services , refresh the Instrqut tab by 
# clicking on the refresh icon on the far right of side of the tab bar. 
# This will render the Consul services if they are not displayed

# Go ahead and visit the HashiCups tab to interact with the application.

# When you are done exploring the application and the Consul UI. 
# Go ahead and click on "Check".


######## Improving resiliency

# A service resolver controls which service instances should 
# satisfy the service mesh upstream discovery requests for 
# a given service name. In simple terms, a service resolver can
# be used to dictate the behavior of what information is shared back to 
# applications. Such as a failover services to target if
# the local instance of a service is unavailable.

# In the current state of the application there is no failover behavior. 
# In addition, there is only a single instance of each 
# service deployed in each Consul datacenter. 
# You can verify this behavior by pausing the public api service container.
docker pause public-api
   # public-api

# Visit the HashiCups UI tab and refresh the tab (far right button at the top).
# This will result in "Error :(" when you refresh the HashiCups landing page.

# OPTIONAL: Check the application logs to verify the failure
docker logs frontend
   # 2022/06/29 20:56:51 [error] 51#51: *27364 recv() failed (104: Connection reset by peer) while reading response header from upstream, client: 10.96.115.6, server: localhost, request: "POST /api HTTP/1.1", upstream: "http://127.0.0.1:8080/api", host: "server-0-80-dt3dttq2oabv.env.play.instruqt.com", referrer: "https://server-0-80-dt3dttq2oabv.env.play.instruqt.com/"
   # 2022/06/29 20:56:51 [warn] 51#51: *27364 upstream server temporarily disabled while reading response header from upstream, client: 10.96.115.6, server: localhost, request: "POST /api HTTP/1.1", upstream: "http://127.0.0.1:8080/api", host: "server-0-80-dt3dttq2oabv.env.play.instruqt.com", referrer: "https://server-0-80-dt3dttq2oabv.env.play.instruqt.com/"
   # 10.96.115.6 - - [29/Jun/2022:20:56:51 +0000] "POST /api HTTP/1.1" 502 497 "https://server-0-80-dt3dttq2oabv.env.play.instruqt.com/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36" "129.222.0.137, 130.211.45.14, 10.64.0.53"

# Unpause the public api container:
docker unpause public-api
   # public-api

# Go back to the HashiCups tab and refresh the page.
# The application will now load up again.

# Implement service resolvers:

# Add a configuration resolver to the public api service:
# QUESTION: what file?
Kind           = "service-resolver"
Name           = "public-api"
ConnectTimeout = "0s"
Failover = {
  "*" = {
    Datacenters = ["dc2", "dc1"]
  }
}

# Issue the command below to enable the configuration resolver for 
# the public api service.
docker cp '/tmp/public-api.hcl' public-api:'/tmp/' && \
   docker exec public-api bash -c "consul config write /tmp/public-api.hcl"
   # Config entry written: service-resolver/public-api


# Verify the configuration resolver:

# To verify the configuration resolver is working and failing over traffic, 
# use a coffee order script that simulates the actions of a user purchasing a cup of coffee.
# Start by kicking off the coffee order script.
docker exec -it frontend  /tmp/chaos.sh

# Take a moment to see how the orders are getting processed as expected.

# Next, go to the Terminal2 tab and pause the public api container.
docker pause public-api
   # public-api

# You will see that the coffee order requests are still processing as normal. 
# type Ctrl + C or Command + C in to stop the script.

# Unpause the public api service:
docker unpause public-api


# Failover:
# For your convenience, we have added a service resolver to the other services. 
# Verify the other services have a service resolver:
docker exec frontend bash -c "consul config list -kind service-resolver"
   # frontend
   # payments
   # product-api
   # product-db

# When you are ready to move on, click on the Check button.

# The service resolver for public-api is not available. 
# Please use the command provided in the instructions to 
# enable the service resolver.


######## Improve application resiliency with service resolvers
# It's time to kick off the chaos experiments. 
# You will try to disprove the following hypothesis: 
# the application is able to handle container failures on the backend.

# To attempt to disprove this hypothesis you will use 
# Pumba, an open source tool used to disrupt containers.

# Start the chaos experiment:
# issue the command below from the Terminal tab. 
# to trigger the coffee order script. 
docker exec -it frontend  /tmp/chaos.sh

# Use this to see how HTTP requests are being handled throughout 
# the experiment.

# At Terminal2 tab, trigger the actual chaos experiment:
docker run --rm --name chaos \
   -v /var/run/docker.sock:/var/run/docker.sock gaiaadm/pumba:0.9.0 \
   --random --label application=backend \
   --label location=primary \
   --log-level info --interval 21s pause \
   --duration 20s
# A single entry:
   # time="2022-06-29T21:09:48Z" level=info msg="pausing container" 
   # dryrun=false id=ed2f31c1bc96fb9da62d06c7b5f6475039332ddbf54ad0df138f614b5536e218 name=/public-api

# Go back to the first terminal and observe that 
# HTTP requests as random backend containers are paused every 21 seconds.

# When you are ready to stop the experiment type Ctrl + C or Command + C in both terminals.

# Target DC2 (frontend-secondary):
# On Tab 1:
docker exec -it frontend-secondary  /tmp/chaos.sh

# On Tab 2:
docker run -it --rm --name chaos \
   -v /var/run/docker.sock:/var/run/docker.sock gaiaadm/pumba:0.9.0 \
   --random --label application=backend \
   --label location=secondary \
   --log-level info --interval 21s pause \
   --duration 20s

# To stop the experiment type Ctrl + C or Command + C 
# in both terminals.

# Review
# In this experiment you can see that the application is able 
# to process coffee orders with minimal disruptions. 
# You might have noticed that occasionaly a single request fails 
# when a cut over occurs for the public-api service.
# This is an important data point and something that should be addressed.
# Due to the nature of the application and processing payment requests, 
# it's ideal all requests are handled correctly. 
# There are various ways to address this problem. 
# The critical thing to keep in mind is that you now have
# an important finding to review and can have a fruitful discussion 
# with others about the next steps.

# The hypothesis that you tried to disprove 
# "the application cannot handle a container failure at the backend"
# is technically not disproven.
# Implementing a service resolver through Consul helped tremendously 
# improve the overall resiliency of the application.
# But there is room for improvement,
# which is the most important lesson to learn from chaos engineering.
# The HashiCups application does not have any retry logic.
# Implementing retry logic, and deploying more than one instance,
# would help address the gaps the Chaos experiment revealed.
# Finding opportunities for improvement is better than
# passing a series of tests that test the application
# in an isolated environment.

# When you are ready to move on, click on the Check button.


######## Chaos experiments - Use Pumba to stop random containers
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-and-chaos-engineering/challenges/chaos-experiments/assignment



######## Playground to Tryout different experiments
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-and-chaos-engineering/challenges/playground/notes

# This next section is optional.
# You can use the container labels to create different experiments
# by having Pumba target these labels for container disruptions.

# END