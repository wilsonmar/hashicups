# consul-namespaces.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/configure-consul-namespaces
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

# Namespaces provide separation for teams within a single organization
# enabling them to share access to one or more Consul datacenters
# without conflict.
# and create more granular access to the datacenter with namespaced ACLs.
# Additionally, namespaces with ACLs allows you to 
# delegate access control to specific resources within the datacenter
# including services, Connect service mesh proxies, key/value pairs,
# and sessions.

######## Challenge 1 - Create a Consul Namespace
# https://play.instruqt.com/HashiCorp-EA/tracks/configure-consul-namespaces/challenges/configure-consul-namespaces/notes

consul acl bootstrap >> bootstrap.txt
cat bootstrap.txt
   # AccessorID:       d2fc11cb-bc71-a842-3ef0-cb83c9616edb
   # SecretID:         0b640f9b-e3dc-9f2d-db0b-b532d127b778
   # Partition:        default
   # Namespace:        default
   # Description:      Bootstrap Token (Global Management)
   # Local:            false
   # Create Time:      2022-06-30 20:16:28.143264061 +0000 UTC
   # Policies:
   #    00000000-0000-0000-0000-000000000001 - global-management
# TODO: extract command:
# export CONSUL_HTTP_TOKEN=<ACL managment Token>
# export CONSUL_HTTP_TOKEN="0b640f9b-e3dc-9f2d-db0b-b532d127b778"

cat <<-EOF > app-team.hcl
name = "app-team",
description = "Namespace for app-team managing the production dashboard application"
EOF
cat <<-EOF > db-team.hcl
name = "db-team",
description = "Namespace for db-team managing the production counting application"
EOF

consul namespace write app-team.hcl
   # Name: app-team
   # Description:
   #    Namespace for app-team managing the production dashboard application
   # Partition:   default

consul namespace write db-team.hcl
   # Name: db-team
   # Description:
   #    Namespace for db-team managing the production counting application
   # Partition:   default

consul namespace list
   # app-team:
   #    Description:
   #       Namespace for app-team managing the production dashboard application
   #    Partition:   default
   # db-team:
   #    Description:
   #       Namespace for db-team managing the production counting application
   #    Partition:   default
   # default:
   #    Description:
   #       Builtin Default Namespace


# ** Click the Consul UI tab:



######## Challenge 2 - Create namespace management tokens
# export CONSUL_HTTP_TOKEN=<ACL managment Token>
# export CONSUL_HTTP_TOKEN="0b640f9b-e3dc-9f2d-db0b-b532d127b778"

consul acl token create \
      -namespace app-team \
      -description "App Team Administrator" \
      -policy-name "namespace-management"
   # AccessorID:       4a38e82c-366b-358d-9cc0-8f2bb1e03101
   # SecretID:         d379064c-ac50-15c3-4848-dd3c5aff85d0
   # Partition:        default
   # Namespace:        app-team
   # Description:      App Team Administrator
   # Local:            false
   # Create Time:      2022-06-30 20:28:05.131064376 +0000 UTC
   # Policies:
   #    6fb88c20-2456-89b9-88c6-d2a9cc7e12ab - namespace-management

consul acl token create \
      -namespace db-team \
      -description "DB Team Administrator" \
      -policy-name "namespace-management"
   # AccessorID:       17bd259c-6c57-f1a8-d452-2b6b031f9a08
   # SecretID:         205d8a72-7ea5-3836-431d-0d83d0c2604a
   # Partition:        default
   # Namespace:        db-team
   # Description:      DB Team Administrator
   # Local:            false
   # Create Time:      2022-06-30 20:36:12.541418472 +0000 UTC
   # Policies:
   #    596ca4b5-d4e6-f04d-e5ba-e1230f7aea24 - namespace-management

# To view tokens within a namespace, use the -namespace command-line flag.
consul acl token list -namespace app-team
   # AccessorID:       4a38e82c-366b-358d-9cc0-8f2bb1e03101
   # SecretID:         d379064c-ac50-15c3-4848-dd3c5aff85d0
   # Partition:        default
   # Namespace:        app-team
   # Description:      App Team Administrator
   # Local:            false
   # Create Time:      2022-06-30 20:28:05.131064376 +0000 UTC
   # Legacy:           false
   # Policies:
   #    6fb88c20-2456-89b9-88c6-d2a9cc7e12ab - namespace-management

# Now that you have a management token for each namespace, you can
# create tokens that restrict privileges for end-users,
# only providing the minimum necessary privileges for their role.
# In this example you will give the developers on the db-team the ability to register their own services and allow or deny communication between services in their team’s namespace with intentions.

# Create a developer token
# CONSUL_HTTP_TOKEN=<db-team operator token here>
# export CONSUL_HTTP_TOKEN=<db-team operator token here>
# export CONSUL_HTTP_TOKEN="205d8a72-7ea5-3836-431d-0d83d0c2604a"

# Create an app team developer policy

cat <<-EOF > db-developer-policy.hcl
service_prefix "" {
  policy = "write"
  intention = "write"
}
EOF

consul acl policy create \
  -name developer-policy \
  -description "Write services and intentions" \
  -namespace db-team \
  -rules @db-developer-policy.hcl
   # ID:           26bbd4fa-ce8f-572f-4c86-cb4c4507d84f
   # Name:         developer-policy
   # Partition:    default
   # Namespace:    db-team
   # Description:  Write services and intentions
   # Datacenters:  
   # Rules:
   # service_prefix "" {
   #   policy = "write"
   #   intention = "write"
   # }

consul acl token create \
  -description "DB developer token" \
  -namespace db-team \
  -policy-name developer-policy
   # AccessorID:       95c24fd7-4b03-efa4-184f-9504da2b6e57
   # SecretID:         139c97dd-ed0f-2802-022a-8c6aa488c81d
   # Partition:        default
   # Namespace:        db-team
   # Description:      DB developer token
   # Local:            false
   # Create Time:      2022-06-30 20:40:27.110292896 +0000 UTC
   # Policies:
   #    26bbd4fa-ce8f-572f-4c86-cb4c4507d84f - developer-policy

# Login to the Consul UI with the different ACL tokens
# (management and developer) to see what Consul namespaces
# are scoped and available to the respective tokens.

# In this lab we created namespaces and 
# secured the resources within a namespace.
# We created management tokens for two namespaces and then
# a developer token for the db-team.

# Note, the super-operator can also create policies that can be
# shared by all namespaces.
# Shared policies are universal and should be created in
# the default namespace.



######## Challenge 3 - Register services in namespaces
# You register services in a namespace by 
# adding namespace information to the registration.
# This should not disrupt your existing workflow.
# The namespace information can be added to the registration
# using one of the following methods.

# ** FYI: Challenge 3 - Register services in namespaces:
# missiing export before CONSUL_HTTP_TOKEN=<db-team developer token here>

wget https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/counting-service_linux_amd64.zip
unzip counting-service_linux_amd64.zip
mv counting-service_linux_amd64 /usr/local/bin/counting-service
rm counting-service_linux_amd64.zip

# counting.hcl

cat <<-EOF > counting.hcl
service {
  name = "counting"
  port = 9003
  namespace = "db-team"
}
EOF

# ** Utilzed the db-team developer token

CONSUL_HTTP_TOKEN=<db-team developer token here>
# export CONSUL_HTTP_TOKEN="139c97dd-ed0f-2802-022a-8c6aa488c81d"
consul services register counting.hcl
   # Registered service: counting

PORT=9003 nohup counting-service &
   # [1] 9742
   # root@consul-server-1:~# nohup: ignoring input and appending output to 'nohup.out'

consul catalog services
   # counting

consul catalog services -namespace db-team
   # counting


# END