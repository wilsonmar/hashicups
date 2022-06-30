# vault-as-consul-connect-certificate-authority.sh
# from https://play.instruqt.com/HashiCorp-EA/tracks/vault-as-consul-connect-certificate-authority
# by Gabe Maentz
# TODO: See https://github.com/hashicorp/consul-guides
# Consul Enterprise Academy: Vault as Consul Connect service mesh Certification Authority
# Use Vault's PKI Secrets Engine to generate and renew certificates for Consul Connect service mesh.

echo "WARNING: There are several TODOs to keep this from working now."
exit

######## 1 - Review Consul configuration and verify Connect CA
# https://play.instruqt.com/HashiCorp-EA/tracks/vault-as-consul-connect-certificate-authority/challenges/verify-configuration/notes?auto_start=true

# The environment is setup to expose all environment variables necessary for the communication with Consul and Vault.

# You can verify the environment variables that have been set by inspecting the profile file imported.
cat /etc/profile.d/variables.sh
   # export CONSUL_HTTP_ADDR=https://consul-server-0.mieixj5litj6.svc.cluster.local
   # export CONSUL_HTTP_TOKEN=0a8a11fe-928b-200b-20f4-68b8c7671d6d
   # export CONSUL_HTTP_SSL=true
   # export CONSUL_CACERT=/home/app/assets/consul-agent-ca.pem
   # export CONSUL_TLS_SERVER_NAME=server.dc1.consul
   # export CONSUL_FQDN_ADDR=consul-server-0.mieixj5litj6.svc.cluster.local
   # export VAULT_ADDR=http://vault.mieixj5litj6.svc.cluster.local:8200
   # export VAULT_TOKEN=password

# With the environment variables setup for your terminal you can
# verify the Consul configuration by checking the datacenter nodes and services.
consul members

consul catalog services
   # api
   # api-sidecar-proxy
   # consul
   # web
   # web-sidecar-proxy

# You also can use the  Consul UI tab to inspect the datacenter nodes and services.

# Check the Consul Connect CA configuration using the Consul CLI.
consul connect ca get-config
   # {
   #     "Provider": "consul",
   #     "Config": {
   #             "IntermediateCertTTL": "8760h",
   #             "LeafCertTTL": "72h",
   #             "rotation_period": "2160h"
   #     },
   #     "State": null,
   #     "ForceWithoutCrossSigning": false,
   #     "CreateIndex": 7,
   #     "ModifyIndex": 7
   # }

# Also you can retrieve the root certificate for the CA using curl.
curl --silent \
    --cacert /home/app/assets/consul-agent-ca.pem \
    --connect-to server.dc1.consul:443:${CONSUL_FQDN_ADDR}:443 \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    https://server.dc1.consul/v1/agent/connect/ca/roots | jq
   # {
   #   "ActiveRootID": "1c:c7:ce:6d:38:bd:65:e4:07:09:6f:6c:da:8f:fd:f6:e9:ba:77:d2",
   #   "TrustDomain": "4aa3e76c-2c6d-bc4c-ffeb-24ee25e9c900.consul",
   #   "Roots": [
   #     {
   #       "ID": "1c:c7:ce:6d:38:bd:65:e4:07:09:6f:6c:da:8f:fd:f6:e9:ba:77:d2",
   #       "Name": "Consul CA Root Cert",
   #       "SerialNumber": 9,
   #       "SigningKeyID": "a5:6b:11:f7:00:7c:81:b9:14:61:0d:5e:02:bd:f9:36:9a:62:1f:c0:3b:88:58:be:8d:9e:90:77:e4:96:9f:69",
   #       "ExternalTrustDomain": "4aa3e76c-2c6d-bc4c-ffeb-24ee25e9c900",
   #       "NotBefore": "2022-06-30T13:55:29Z",
   #       "NotAfter": "2032-06-30T13:55:29Z",
   #       "RootCert": "-----BEGIN CERTIFICATE-----\nMIICDDCCAbOgAwIBAgIBCTAKBggqhkjOPQQDAjAwMS4wLAYDVQQDEyVwcmktdXRu\ndzZ4ZC5jb25zdWwuY2EuNGFhM2U3NmMuY29uc3VsMB4XDTIyMDYzMDEzNTUyOVoX\nDTMyMDYzMDEzNTUyOVowMDEuMCwGA1UEAxMlcHJpLXV0bnc2eGQuY29uc3VsLmNh\nLjRhYTNlNzZjLmNvbnN1bDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABIKdevRc\n/2g+BNrEKrv+uemAX0osXqBDBEj0xZnlfTQZn+im847Z2n69BgeoKSvaRK0kLZG8\nVVh/YU5HVDH7vDWjgb0wgbowDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMB\nAf8wKQYDVR0OBCIEIKVrEfcAfIG5FGENXgK9+TaaYh/AO4hYvo2ekHfklp9pMCsG\nA1UdIwQkMCKAIKVrEfcAfIG5FGENXgK9+TaaYh/AO4hYvo2ekHfklp9pMD8GA1Ud\nEQQ4MDaGNHNwaWZmZTovLzRhYTNlNzZjLTJjNmQtYmM0Yy1mZmViLTI0ZWUyNWU5\nYzkwMC5jb25zdWwwCgYIKoZIzj0EAwIDRwAwRAIgKQ6p2NQan0a0eGL4EPlkqSt3\nrxF0GzmddGDVjXUOmpsCIFH3TFMmOr+Kb/pgFkVfkSOjc9kWeVrTVZgUZ4cqmCHF\n-----END CERTIFICATE-----\n",
   #       "IntermediateCerts": null,
   #       "Active": true,
   #       "PrivateKeyType": "ec",
   #       "PrivateKeyBits": 256,
   #       "CreateIndex": 11,
   #       "ModifyIndex": 11
   #     }
   #   ]
   # }

# To examine the content of the root certificate use the openssl tool.
curl --silent \
    --cacert /home/app/assets/consul-agent-ca.pem \
    --connect-to server.dc1.consul:443:${CONSUL_FQDN_ADDR}:443 \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    https://server.dc1.consul/v1/agent/connect/ca/roots | \
    jq -r .Roots[0].RootCert | openssl x509 -text -noout
   # RESPONSE:
   # Certificate:
   #     Data:
   #         Version: 3 (0x2)
   #         Serial Number: 9 (0x9)
   #         Signature Algorithm: ecdsa-with-SHA256
   #         Issuer: CN = pri-utnw6xd.consul.ca.4aa3e76c.consul
   #         Validity
   #             Not Before: Jun 30 13:55:29 2022 GMT
   #             Not After : Jun 30 13:55:29 2032 GMT
   #         Subject: CN = pri-utnw6xd.consul.ca.4aa3e76c.consul
   #         Subject Public Key Info:
   #             Public Key Algorithm: id-ecPublicKey
   #                 Public-Key: (256 bit)
   #                 pub:
   #                     04:82:9d:7a:f4:5c:ff:68:3e:04:da:c4:2a:bb:fe:
   #                     b9:e9:80:5f:4a:2c:5e:a0:43:04:48:f4:c5:99:e5:
   #                     7d:34:19:9f:e8:a6:f3:8e:d9:da:7e:bd:06:07:a8:
   #                     29:2b:da:44:ad:24:2d:91:bc:55:58:7f:61:4e:47:
   #                     54:31:fb:bc:35
   #                 ASN1 OID: prime256v1
   #         X509v3 extensions:
   #             X509v3 Key Usage: critical
   #                 Digital Signature, Certificate Sign, CRL Sign
   #             X509v3 Basic Constraints: critical
   #                 CA:TRUE
   #             X509v3 Subject Key Identifier: 
   #                 A5:6B:11:F7:00:7C:81:B9:14:61:0D:5E:02:BD:F9:36:9A:62:1F:C0:3B:88:58:BE:8D:9E:90:77:E4:96:9F:69
   #             X509v3 Authority Key Identifier: 
   #                 keyid:A5:6B:11:F7:00:7C:81:B9:14:61:0D:5E:02:BD:F9:36:9A:62:1F:C0:3B:88:58:BE:8D:9E:90:77:E4:96:9F:69
   # 
   #             X509v3 Subject Alternative Name: 
   #                 URI:spiffe://4aa3e76c-2c6d-bc4c-ffeb-24ee25e9c900.consul
   #     Signature Algorithm: ecdsa-with-SHA256
   #          30:44:02:20:29:0e:a9:d8:d4:1a:9f:46:b4:78:62:f8:10:f9:
   #          64:a9:2b:77:af:11:74:1b:39:9d:74:60:d5:8d:75:0e:9a:9b:
   #          02:20:51:f7:4c:53:26:3a:bf:8a:6f:fa:60:16:45:5f:91:23:
   #          a3:73:d9:16:79:5a:d3:55:98:14:67:87:2a:98:21:c5

Subject: CN = pri-oukfw0d.vault.ca.4aa3e76c.consul

######## 2 - Create Vault token
# https://play.instruqt.com/HashiCorp-EA/tracks/vault-as-consul-connect-certificate-authority/challenges/create-vault-token/notes
# To allow Consul to automatically generate certificates from Vault you need a token with appropriate permissions.

# To interact with the PKI Secrets Engine endpoints, you have to
# generate a Vault token, giving the appropriate permissions to Consul to
# generate the certificates.
# The scenario provides a policy definition file, vault-policy-connect-ca.hcl,
# with the right permissions for the PKI secrets engines that will be used to generate certificates for Consul Connect service mesh.
cat ./assets/vault-policy-connect-ca.hcl
# Consul Managed PKI Mounts

# Read existing secret engines
path "/sys/mounts" {
  capabilities = [ "read" ]
}

# Full permissions over PKI secret engine for root CA
path "/sys/mounts/connect_root" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Full permissions over PKI secret engine for intermediate CA
path "/sys/mounts/connect_inter" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Full permissions over PKI secret engine for root CA path
path "/connect_root/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Full permissions over PKI secret engine for intermediate CA path
path "/connect_inter/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# If you prefer you can use the  Code Editor tab to visualize the file
# in a code editor.

# The policy defines permissions for the connect_root and
# connect_inter paths, you can change these paths but,
# if you do, the same names will have to be reflected in
# the Consul configuration you will create in the next step.

# Once reviewed the file, move to the Shell tab and
# create the policy into Vault.
vault policy write connect-ca ./assets/vault-policy-connect-ca.hcl
   # Success! Uploaded policy: connect-ca

# Generate a new token using the connect-ca policy.
vault token create -policy=connect-ca \
  --format=json | tee ./assets/vault-token-connect-ca.json

{
  "request_id": "8255815f-fd09-05b9-4868-96d290ff09fe",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": null,
  "warnings": null,
  "auth": {
    "client_token": "s.SyAuHSLLGV3wikkPQcat4mws",
    "accessor": "zELCQ04w9PnWI6qvMJgE3xgs",
    "policies": [
      "connect-ca",
      "default"
    ],
    "token_policies": [
      "connect-ca",
      "default"
    ],
    "identity_policies": null,
    "metadata": null,
    "orphan": false,
    "entity_id": "",
    "lease_duration": 2764800,
    "renewable": true
  }
}

# ** The "tee" saves the output to a file, vault-token-connect-ca.json.
# This is done so that you can use it in the next steps.
# In your production scenario you want to store it in a
# secure place or retrieve it directly from Vault.

######## 3 - Configure Consul Connect service mesh CA
# Change the configuration of your Consul Connect CA using the Consul CLI.

# To change the configuration for your Consul Connect CA
# create a configuration file with the new configuration parameters.

# The scenario provides you a template file for the configuration,
# config-connect-ca-provider-vault.json,
# that you can use as a base for the configuration tuning.

{
    "Provider": "vault",
    "Config": {
        "Address": "http://vault.mieixj5litj6.svc.cluster.local:8200",
        "Token": "<Insert Vault token here>",
        "RootPKIPath": "<Path for the root CA>",
        "IntermediatePKIPath": "<Path for the intermediate CA>",
        "LeafCertTTL": "72h",
        "RotationPeriod": "2160h",
        "IntermediateCertTTL": "8760h",
        "PrivateKeyType": "rsa",
        "PrivateKeyBits": 2048
    },
    "ForceWithoutCrossSigning": false
}

# Use the Code Editor tab to visualize the file in a code editor.

# The data needed to complete the configuration are:
   # Address: This is your Vault cluster address.
   # In the template is already populated with the Vault address.

   # Token: The Vault token that will be used by Consul to
   # generate the certificates.
   
# You can retrieve the token from the vault-token-connect-ca.json file
# generated in the previous step, under the auth.client_token parameter.
{
  "request_id": "8255815f-fd09-05b9-4868-96d290ff09fe",
  "lease_id": "",
  "lease_duration": 0,
  "renewable": false,
  "data": null,
  "warnings": null,
  "auth": {
    "client_token": "s.SyAuHSLLGV3wikkPQcat4mws",
    "accessor": "zELCQ04w9PnWI6qvMJgE3xgs",
    "policies": [
      "connect-ca",
      "default"
    ],
    "token_policies": [
      "connect-ca",
      "default"
    ],
    "identity_policies": null,
    "metadata": null,
    "orphan": false,
    "entity_id": "",
    "lease_duration": 2764800,
    "renewable": true
  }
}

# You can also retrieve it from the command line using jq.
# This is useful in case you want to automate this step.
cat /root/assets/vault-token-connect-ca.json | jq -r ".auth.client_token"
   # s.SyAuHSLLGV3wikkPQcat4mws

# "Token": "<Insert Vault token here>",
# "Token": "s.SyAuHSLLGV3wikkPQcat4mws",

   # "RootPKIPath": "<Path for the root CA>",
   # RootPKIPath: The path to a PKI secrets engine for the root certificate.
   # If you did not change the value in the Vault policy in
   # the previous challenge this should be connect_root

   # "IntermediatePKIPath": "<Path for the intermediate CA>",
   # IntermediatePKIPath: The path to a PKI secrets engine
   # for the generated intermediate certificate.
   # If you did not change the value in the Vault policy in the
   # previous challenge this should be connect_inter

# Once complete editing the configuration file, save it, using the
# Save Button
{
    "Provider": "vault",
    "Config": {
        "Address": "http://vault.mieixj5litj6.svc.cluster.local:8200",
        "Token": "s.SyAuHSLLGV3wikkPQcat4mws",
        "RootPKIPath": "connect_root",
        "IntermediatePKIPath": "connect_inter",
        "LeafCertTTL": "72h",
        "RotationPeriod": "2160h",
        "IntermediateCertTTL": "8760h",
        "PrivateKeyType": "rsa",
        "PrivateKeyBits": 2048
    },
    "ForceWithoutCrossSigning": false
}

# Move to the ** Shell tab.
# Change the Consul Connect CA configuration.
consul connect ca set-config \
   -config-file ./assets/config-connect-ca-provider-vault.json
   # Configuration updated!

# Verify the configuration changed.
consul connect ca get-config

# The output should now reflect the new configuration.


######## 4 - Verify configuration
# Verify the configuration for Consul Connect service mesh CA got updated.
# Learn how to use Consul API endpoints to verify configuration change and service leaf certificates.

# Verify the root certificate for the CA have been updated to
# reflect the new configuration.
curl --silent \
    --cacert /home/app/assets/consul-agent-ca.pem \
    --connect-to server.dc1.consul:443:${CONSUL_FQDN_ADDR}:443 \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    https://server.dc1.consul/v1/agent/connect/ca/roots | jq

# Notice "Name": "Consul CA Root Cert",
# "Name": "Vault CA Root Cert",

# Also, you can now verify the service certificates are now
# generated using Vault.
curl --silent \
    --cacert /home/app/assets/consul-agent-ca.pem \
    --connect-to server.dc1.consul:443:${CONSUL_FQDN_ADDR}:443 \
    --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
    https://server.dc1.consul/v1/agent/connect/ca/leaf/web | jq

# TODO: Run openssl
curl --silent     --cacert /home/app/assets/consul-agent-ca.pem     --connect-to server.dc1.consul:443:${CONSUL_FQDN_ADDR}:443     --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}"     https://server.dc1.consul/v1/agent/connect/ca/leaf/web | jq -r .PrivateKeyPEM  | openssl x509 -text -noout
unable to load certificate
140703830469960:error:0909006C:PEM routines:get_name:no start line:crypto/pem/pem_lib.c:745:Expecting: TRUSTED CERTIFICATE

# Congratulations, you now have configured your Consul datacenter to
# use Vault as the service mesh CA.


# END