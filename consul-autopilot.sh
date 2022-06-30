# consul-autopilot.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-autopilot
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

######## Challenge 1 - Add servers - demonstrate the Autopilot Automated Upgrades feature.

# TODO: Identify the version of each node:
ssh -o stricthostkeychecking=no consul-server-1 consul --version
ssh -o stricthostkeychecking=no consul-server-2 consul --version
ssh -o stricthostkeychecking=no consul-server-3 consul --version
ssh -o stricthostkeychecking=no consul-server-4 consul --version
ssh -o stricthostkeychecking=no consul-server-5 consul --version
ssh -o stricthostkeychecking=no consul-server-6 consul --version


consul --version
   # onsul v1.10.0+ent
   # Revision 464895bd1
   # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)

# There is a Consul cluster with three servers, including
   # consul-server-1
   # consul-server-2
   # consul-server-3
# These servers are running olde Consul v1.10.0. 

# You've been tasked with updating the Consul cluster to a newer version, 
# therefore you deploy consul-server-4, consul-server-5, and consul-server-6. 
# These three new Consul servers are running a newer version of Consul, but 
# are not yet joined to the cluster.

# Use the automated upgrades feature of Autopilot, which is enabled by default in Consul Enterprise.
# You can verify the configuration for your datacenter by using the consul operator autopilot command.
# Run the following command on Consul 1:
consul operator autopilot get-config
   # CleanupDeadServers = true
   # LastContactThreshold = 200ms
   # MaxTrailingLogs = 250
   # MinQuorum = 0
   # ServerStabilizationTime = 10s
   # RedundancyZoneTag = ""
   # DisableUpgradeMigration = false
   # UpgradeVersionTag = ""

#...
# DisableUpgradeMigration = false
# UpgradeVersionTag = ""

# Once you have verified that DisableUpgradeMigration is set to false, you can begin 
# starting the Consul service on the new servers and ensure they join the existing Consul datacenter. 
# Run consul members on Consul 1 to ensure the new servers have joined the cluster.

# On consul-server-4 and consul-server-5 ONLY, start the Consul service:
# TODO: Issue commands to specific servers:
systemctl start consul

# After the new servers have joined the cluster, verify the status by running the following command.
consul operator raft list-peers

# Note that although the new servers are members of the cluster, they are listed as non-voting members.
# Now, start consul on consul-server-6.
# TODO: Issue commands to specific servers:
systemctl start consul
# While on a specific server:
consul --version

# Once the third new server is started, autopilot detects an equal number of old nodes vs. 
# new nodes and promotes the new servers as voters, triggers a new leader election, and 
# demotes the old nodes as non-voting members.

# Run the following command to validate the changes. Note: this may take 1-2 minutes to occur.
consul operator raft list-peers

# You may run the command multiple times to see the changes take place in real-time.

# Once a new leader has been elected, it is safe to remove servers 1, 2, and 3 from the cluster:
# TODO: Issue commands to specific servers:
consul leave


# END