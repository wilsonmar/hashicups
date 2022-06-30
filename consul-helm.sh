#!/bin/bash
# consul-helm.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/consul-kubernetes/challenges/install-consul/notes
# TODO: See https://github.com/hashicorp/consul-guides

echo "WARNING: There are several TODOs to keep this from working now."
exit

####### Challenge 1 - Install Consul on Kubernetes

# To use Helm is to add the Helm repository so Helm charts can be used. 
# Add the official HashiCorp repository:
helm repo add hashicorp https://helm.releases.hashicorp.com
   # "hashicorp" has been added to your repositories

# Verify that you have access to the Consul Helm chart:
helm search repo hashicorp/consul
   # NAME                    CHART VERSION   APP VERSION     DESCRIPTION                    
   # hashicorp/consul        0.45.0          1.12.2          Official HashiCorp Consul Chart
   # Above you should see Helm chart version and Consul version.

# Prior to installing Consul via Helm, ensure that the 
# consul Kubernetes namespace does not exist, 
# as installing on a dedicated namespace is recommended.
kubectl get namespace
   # NAME                   STATUS   AGE
   # default                Active   119s
   # kube-system            Active   119s
   # kube-public            Active   119s
   # kube-node-lease        Active   119s
   # kubernetes-dashboard   Active   115s

# https://play.instruqt.com/HashiCorp-EA/tracks/consul-kubernetes/challenges/customize-consul/notes


###### Challenge 2 - Customize your installation
# The Consul Helm chart includes many default settings that 
# you'll often want to change in order to customize the installation 
# for your environment. If you want to customize your installation, 
# create a config.yaml file to override the default settings. 
# You can learn what settings are available by running helm inspect values 
# hashicorp/consul or by reading the Helm Chart Reference at 
# https://www.consul.io/docs/k8s/helm

# Create config.yaml file to enforce the security model by 
# using Gossip Encryption and setting up TLS:
# Instead of openning the Editor tab and addding the file,
cat <<EOT >> config.yaml
global:
  name: consul
  enabled: true
  datacenter: k8s
  gossipEncryption:
    autoGenerate: true # Automatically generate a gossip encryption key
  tls:
    enabled: true # Enforce ingoing/outgoing TLS, and automatically create/rotate CA and agent certificates
    httpsOnly: true # Disable the non-TLS HTTP listener
    verify: true
  acls:
    manageSystemACLs: true # Automatically bootstrap ACL system and manage tokens and policies
server:
  affinity: null # Allow running multiple Consul servers per Kubernetes node (for lab environment)
  securityContext:
    runAsNonRoot: false
    runAsUser: 0
ui:
  enabled: true # Enable and configure the Consul UI.
connectInject:
  enabled: true # Deploy an operator to automatically add Consul Connect proxy sidecars to k8s services
controller:
  enabled: true # Enable Kubernetes CRDs
EOT

# Switch to the Terminal tab and install the Helm chart while 
# overriding the defaults using our new custom configuration:
helm install consul hashicorp/consul \
   --create-namespace -n consul -f /root/config.yaml

# NOTE: Be patient, as the install might take a minute or two.

# View the installation on the Terminal 2 :
watch kubectl get pods -n consul
   # NAME                                           READY   STATUS     RESTARTS   AGE
   # consul-client-24kmj                            0/1     Init:0/2   0          37s
   # consul-webhook-cert-manager-847cf7cbf8-vfrv9   1/1     Running    0          37s
   # consul-server-acl-init-g4qxk                   1/1     Running    0          37s
   # consul-server-acl-init-cleanup-7ntgg           1/1     Running    0          36s
   # consul-connect-injector-547885c49f-jpjrk       0/1     Init:0/1   0          37s
   # consul-controller-67d6bdddb9-gttkx             0/1     Init:0/1   0          37s
   # consul-connect-injector-547885c49f-6zd79       0/1     Init:0/1   0          37s
   # consul-server-2                                0/1     Running    0          35s
   # consul-server-1                                0/1     Running    0          35s
   # consul-server-0                                0/1     Running    0          36s

#After install check the helm status and list all of the pods in the 
# Consul namespace on Terminal 1
helm status consul -n consul
   #        NAME: consul
   #        LAST DEPLOYED: Tue Jun 28 21:14:14 2022
   #        NAMESPACE: consul
   #        STATUS: deployed
   #        REVISION: 1
   #        NOTES:
   #        Thank you for installing HashiCorp Consul!
   #        Your release is named consul.
   #
   #        To learn more about the release, run:
   #
   #        $ helm status consul --namespace consul
   #        $ helm get all consul --namespace consul
   #
   #        Consul on Kubernetes Documentation:
   #        https://www.consul.io/docs/platform/k8s
   #
   #        Consul on Kubernetes CLI Reference:
   #        https://www.consul.io/docs/k8s/k8s-cli

kubectl get pods -n consul
   # NAME                                           READY   STATUS    RESTARTS   AGE
   # consul-webhook-cert-manager-847cf7cbf8-vfrv9   1/1     Running   0          3m35s
   # consul-server-1                                1/1     Running   0          3m33s
   # consul-server-0                                1/1     Running   0          3m34s
   # consul-server-2                                1/1     Running   0          3m33s
   # consul-controller-67d6bdddb9-gttkx             1/1     Running   0          3m35s
   # consul-client-24kmj                            1/1     Running   0          3m35s
   # consul-connect-injector-547885c49f-jpjrk       1/1     Running   0          3m35s
   # consul-connect-injector-547885c49f-6zd79       1/1     Running   0          3m35s

# Look at the services within the namespace.
kubectl get svc -n consul
  # NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                   AGE
  # consul-server               ClusterIP   None            <none>        8501/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   4m30s
  # consul-dns                  ClusterIP   10.43.206.42    <none>        53/TCP,53/UDP                                                             4m29s
  # consul-controller-webhook   ClusterIP   10.43.76.200    <none>        443/TCP                                                                   4m29s
  # consul-connect-injector     ClusterIP   10.43.177.45    <none>        443/TCP                                                                   4m29s
  # consul-ui                   ClusterIP   10.43.189.190   <none>        443/TCP                                                                   4m29s

# Use kubectl exec to get direct access to any container, 
# including the Consul server. 
# Check for a list of Consul's servers and clients and 
# check that the Consul cluster is running:

# Open a window into the server:
kubectl exec -it --namespace=consul consul-server-0 -i -t -- sh
   # TODO: Docs on paramters?
consul members
exit

# Using the Helm chart, we've already enabled ACLs and TLS has been enabled,
# which saves significant time. 
# The Consul UI has also been enabled with TLS listening on port 8501. 
# To access the Consul UI, forward the consul-server service to the 
# Instruqt host, so that you can access the Consul UI in a browser. 
# Perform this command on Terminal 2
kubectl port-forward service/consul-server \
   --address 0.0.0.0 --namespace consul 8443:8501

# View the Consul UI on the Consul UI tab.

# The ACL system is bootstrapped as part of the helm install, using the acls stanza, and the token is saved as a kubernetes secret.

# To list secrets in the consul namespace:
kubectl get secrets -n consul

# To get your management/bootstrap token, run:
kubectl get secrets/consul-bootstrap-acl-token \
   --template={{.data.token}} --namespace consul | base64 -d

# And that's it. You've successfully installed Consul using the official Helm chart!



# https://play.instruqt.com/HashiCorp-EA/tracks/consul-kubernetes/challenges/verify-secure-deployment/notes
######## Challenge 3 - Verify Gossip encryption, TLS and ACLs

# Verify that gossip encryption and TLS are enabled, 
# and that ACLs are being enforced.

# Gossip Encryption:
# View network traffic by attaching to a consul server on Terminal 1
kubectl exec -it --namespace=consul consul-server-0 -i -t -- sh
# / # means that you're
# Install tcpdump:  TODO: Inside 
apk update && apk add tcpdump
   # fetch https://dl-cdn.alpinelinux.org/alpine/v3.15/main/x86_64/APKINDEX.tar.gz
   # fetch https://dl-cdn.alpinelinux.org/alpine/v3.15/community/x86_64/APKINDEX.tar.gz
   # v3.15.4-208-g3b158a1c74 [https://dl-cdn.alpinelinux.org/alpine/v3.15/main]
   # v3.15.4-208-g3b158a1c74 [https://dl-cdn.alpinelinux.org/alpine/v3.15/community]
   # OK: 15860 distinct packages available
   # (1/2) Installing libpcap (1.10.1-r0)
   # (2/2) Installing tcpdump (4.99.1-r3)
   # Executing busybox-1.34.1-r5.trigger
   # OK: 31 MiB in 63 packages

# Verify Gossip Encryption by running a tcpdump on port 8301
tcpdump -an portrange 8301 -A

# Inspect the output and observe that the traffic is encrypted. Note the UDP operations, these entries are the gossip protocol at work. This proves that gossip encryption is enabled. Type CTRL-C to stop the tcpdump session
# TLS
# The Consul UI has also been enabled with TLS listening on port 8501. To access the Consul UI, forward the consul-server service to the Instruqt host, so that you can access the Consul UI in a browser. 
# Perform this command on Terminal 2
kubectl port-forward service/consul-server \
   --address 0.0.0.0 --namespace consul 8443:8501 &

# Export the CA file from Kubernetes so that you can pass it to the CLI on Terminal 3
kubectl get secret consul-ca-cert -n consul -o jsonpath="{.data['tls\.crt']}" | base64 --decode > /root/ca.pem

# You can view the certificate inside the Editor tab.
# Connect back inside the interactive termial of consul-server-0 on Terminal 1 and 
# save the contents of the certificate inside the container.
touch ca.pem
vi ca.pem

# Copy the contents of your ca.pem file into the ca.pem file in the container.
consul members -ca-file ca.pem

# This proves that TLS is enabled.

# ACLs - Now, try launching a debug session on Terminal 1
consul debug -ca-file ca.pem

# You will get a permission denied when attempting to run a debug because an ACL was not provided.
   # ==> Capture validation failed: error querying target agent: Unexpected response code: 403 (Permission denied). verify connectivity and agent address

# The ACL system is bootstrapped as part of the helm install, 
# using the acls stanza, and the token is saved as a kubernetes secret. 
# List secrets in the consul namespace run the following command on Terminal 3
kubectl get secrets -n consul

# Get your management/bootstrap token:
kubectl get secrets/consul-bootstrap-acl-token \
   --template={{.data.token}} --namespace consul | base64 -d

#Set the CONSUL_HTTP_TOKEN inside the consul server container on Terminal 1
export CONSUL_HTTP_TOKEN=<boot strap token>

# Now with the ACL set, rerun the debug command
consul debug -ca-file ca.pem

# This proves that ACLs are enabled.

