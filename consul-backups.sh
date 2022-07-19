# consul-backups.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-backups
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

# Take snapshots of Consul, configure the Snapshot Agent, and 
# restore your cluster using a snapshot.


######## Challenge 1 - Create First Consul Snapshot manual backup 
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-backups/challenges/1-backup/notes

# View the current state of the consul cluster:
consul members
   # Node             Address           Status  Type    Build       Protocol  DC   Partition  Segment
   # consul-server-1  10.132.0.90:8301  alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-2  10.132.0.42:8301  alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-3  10.132.0.37:8301  alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-4  10.132.1.11:8301  alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-5  10.132.0.35:8301  alive   server  1.12.2+ent  2         dc1  default    <all>
   # consul-server-6  10.132.0.41:8301  alive   server  1.12.2+ent  2         dc1  default    <all>

# The snapshot save save command for backing up the datacenter state 
# has many configuration options. 
# In a production environment, you will want to configure ACL tokens and
# client certificates for security.
# The configuration options also allow you to specify the 
# datacenter and server to collect the backup data from.

# To manually create a snapshot with the default settings:
consul snapshot save backup.snap
   # Saved and verified snapshot to index 94

# The backup is saved locally in the working directory.
ls *.snap

# You can view metadata about the backup with the inspect subcommand.
consul snapshot inspect backup.snap
   # ID           2-102-1656553202409
   #  Size         15235
   #  Index        102
   #  Term         2
   #  Version      1
   # 
   #  Type                       Count      Size
   #  ----                       ----       ----
   #  Register                   18         12.7KB
   #  CoordinateBatchUpdate      6          1.1KB
   #  Index                      17         689B
   #  Autopilot                  1          201B
   #  FederationState            1          139B
   #  Namespace                  1          56B
   #  Partition                  1          44B
   #  ChunkingState              1          12B
   #  ----                       ----       ----
   #  Total                                 14.9KB


######## Challenge 2 - Configure and Use the Consul Snapshot Agent
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-backups/challenges/2-agent/notes

# The Consul snapshot service runs as a separate service, although 
# it uses the same Consul binary to run. 
# The snapshot agent requires a configuration file along with 
# a service configuration file so it can be managed by the 
# local service manager.

# View the agent config file:
cat /etc/consul-snapshot.d/consul-snapshot.json
   #  {
   "snapshot_agent": {
      "http_addr": "127.0.0.1:8500",
      "datacenter": "dc1",
      "license_path": "/etc/consul.d/consul.hclic",
      "snapshot": {
         "interval": "1m",
         "retain": 336,
         "deregister_after": "8h",
         "service": "consul-snapshot"
      },
      "local_storage": {
          "path": "/opt/consul/snapshot/"
      }
   }
 }

# In this case, the snapshot agent is configured to
# save snapshots every 1m to local disk.
# It can also be configured to write to S3, Azure, or GCP.

# ** https://www.consul.io/commands/snapshot/agent

# Take a look at the systemd service file, which is used to 
# start and manage the Consul snapshot agent service:
cat /etc/systemd/system/consul-snapshot.service
  # [Unit]
  # Description="HashiCorp Consul Snapshot Agent"
  # Documentation=https://www.consul.io/
  # Requires=network-online.target
  # After=consul.service
  # ConditionFileNotEmpty=/etc/consul-snapshot.d/consul-snapshot.json
  # 
  # [Service]
  # User=consul
  # Group=consul
  # ExecStart=consul snapshot agent -config-dir=/etc/consul-snapshot.d/
  # KillMode=process
  # Restart=on-failure
  # LimitNOFILE=65536
  # 
  # [Install]
  # WantedBy=multi-user.target

# Notice that the service will run consul snapshot agent command 
# while pointing to our configuration file.

# Start the snapshot agent:
systemctl start consul-snapshot

# See which snapshots were created. One snapshot should be taken immediately but you may have to wait:
ls /opt/consul/snapshot/
   # consul-1656553693297658228.snap
SNAPSHOT_NAME="consul-1656553693297658228.snap"

# Inspect a created snapshot:
# consul snapshot inspect /opt/consul/snapshot/<snapshot-name>
consul snapshot inspect "/opt/consul/snapshot/${SNAPSHOT_NAME}"

# Note that in a production environment, the Consul snapshot agent would 
# run on every Consul node in the cluster, but 
# only a single snapshot would be taken during each interval.



######## Challenge 3 - Restore Your Consul Cluster from Backup
# https://play.instruqt.com/HashiCorp-EA/tracks/consul-backups/challenges/3-restore/notes

# Running the restore process should be straightforward. 
# However, there are a couple of actions you can take to 
# ensure the process goes smoothly. 
# First, make sure the datacenter you are restoring is stable and has a leader:
consul operator raft list-peers
   # Node             ID                                    Address           State     Voter  RaftProtocol
   # consul-server-1  92734833-7ac8-1b8c-192f-5adb97f9bf1a  10.132.0.90:8300  leader    true   3
   # consul-server-2  3c37991c-9a6f-8db1-326e-c31910da6583  10.132.0.42:8300  follower  true   3
   # consul-server-3  caa08822-6961-5c6d-4fb2-0dbf2c465767  10.132.0.37:8300  follower  true   3
   # consul-server-4  3c51785f-00b8-e27c-6f68-2bbc278f7280  10.132.1.11:8300  follower  false  3
   # consul-server-5  d128095d-fd5f-0e14-6e1d-be49d030f32c  10.132.0.35:8300  follower  false  3
   # consul-server-6  5bc501ed-f1e1-b05b-1270-d4db9e6002f4  10.132.0.41:8300  follower  false  3

# and checking server logs and telemetry for signs of leader elections or 
# network issues.

# You will only need to run the process once, on the leader.
# The Raft consensus protocol ensures that all servers restore 
# the same state.

# On Consul UI, open the key/value store and create a new key/value pair.
# Optionally, write some arbitrary data to the Consul KV:
consul kv put kv/labs consul=awesome

# To restore a snapshot:
consul snapshot restore /opt/consul/snapshot/<snapshot-name>

# Make sure to grab one of the first snapshots created. 
# to view the snapshots in a list:
ls -l /opt/consul/snapshot

# Reload the Consul UI and navigate to the key/value section.


# Verify that the key you created is no longer there.


# END