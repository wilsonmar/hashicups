# consul-autopilot.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-autopilot
#  and https://play.instruqt.com/hashicorp/tracks/consul-autopilot
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

######## 0 - Setup environment

# There is a Consul cluster with three servers, including
   # consul-server-1
   # consul-server-2
   # consul-server-3
# These servers are running old ** Consul v1.10.0. 

# You've been tasked with updating the Consul cluster to a newer version.
# Therefore you deploy consul-server-4, consul-server-5, and consul-server-6. 
# These three new Consul servers are running a newer version of Consul,
# but are not yet joined to the cluster.


######## 1 - Add servers - demonstrate the Autopilot Automated Upgrades feature.

# consul --version
   # onsul v1.10.0+ent
   # Revision 464895bd1
   # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)

# Identify the version of each node:

ssh -o stricthostkeychecking=no consul-server-1 consul --version
ssh -o stricthostkeychecking=no consul-server-2 consul --version
ssh -o stricthostkeychecking=no consul-server-3 consul --version
ssh -o stricthostkeychecking=no consul-server-4 consul --version
ssh -o stricthostkeychecking=no consul-server-5 consul --version
ssh -o stricthostkeychecking=no consul-server-6 consul --version

# Use the automated upgrades feature of Autopilot,
# which is enabled by default in Consul Enterprise.
# Verify the configuration for your datacenter by
# using the consul operator autopilot command.

# On Consul 1:
consul operator autopilot get-config
   # CleanupDeadServers = true
   # LastContactThreshold = 200ms
   # MaxTrailingLogs = 250
   # MinQuorum = 0
   # ServerStabilizationTime = 10s
   # RedundancyZoneTag = ""
   # DisableUpgradeMigration = false
   # UpgradeVersionTag = ""

# Once you have verified that DisableUpgradeMigration is set to false,
# start the Consul service on the new servers and
# ensure they join the existing Consul datacenter. 
# Run consul members on Consul 1 to 
# ensure the new servers have joined the cluster.

# On consul-server-4 and consul-server-5 ONLY, start the Consul service.
ssh -o stricthostkeychecking=no consul-server-4 systemctl start consul
ssh -o stricthostkeychecking=no consul-server-5 systemctl start consul

# After the new servers have joined the cluster, verify the status:
consul operator raft list-peers
   # Node             ID                                    Address              State     Voter  RaftProtocol
   # consul-server-1  5dbd5919-c144-93b2-9693-dccfff8a1c53  10.132.255.118:8300  leader    true   3
   # consul-server-2  098c8594-e105-ef93-071b-c2e24916ad78  10.132.255.119:8300  follower  true   3
   # consul-server-3  93a611a0-d8ee-0937-d1f0-af3377d90a19  10.132.255.120:8300  follower  true   3

# Note that although the new servers are members of the cluster,
# they are listed as non-voting members.
# Now, start consul on consul-server-6.
ssh -o stricthostkeychecking=no consul-server-6 systemctl start consul

ssh -o stricthostkeychecking=no consul-server-5 consul --version


# Once the third new server is started,
# autopilot detects an equal number of old nodes vs. 
# new nodes and promotes the new servers as voters,
# triggers a new leader election, and 
# demotes the old nodes as non-voting members.

# validate the changes. Note: this may take 1-2 minutes to occur.
consul operator raft list-peers
# You may need to run the command multiple times to
# see the changes take place in real-time.

# Once a new leader has been elected,
# it is safe to remove servers 1, 2, and 3 from the cluster:
# TODO: Issue commands to specific servers:
ssh -o stricthostkeychecking=no consul-server-1 consul leave
ssh -o stricthostkeychecking=no consul-server-2 consul leave
ssh -o stricthostkeychecking=no consul-server-3 consul leave

# Verify that only 4, 5, 6 remain:
consul operator raft list-peers

# END