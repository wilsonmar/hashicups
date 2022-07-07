#!/usr/bin/env sh
# This is consul-backup.sh from https://github.com/wilsonmar/hashicups/blob/main/consul-download.sh
# Coding of shell scripting is explained in https://wilsonmar.github.io/shell-scripts

# Break on error:
set -e

# See https://tinkerlog.dev/journal/verifying-gpg-signatures-history-terms-and-a-how-to-guide
# Alternately, see https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/terraform-debian.sh
echo "*** Obtain HashiCorp's public asc file (7177 bytes)"
# Automation of steps described at 
                        #  https://github.com/sethvargo/hashicorp-installer/blob/master/hashicorp.asc
# curl -o hashicorp.asc https://raw.githubusercontent.com/sethvargo/hashicorp-installer/master/hashicorp.asc
if [ ! -f "hashicorp.asc" ]; then  # not found:
    curl -o hashicorp.asc https://keybase.io/hashicorp/pgp_keys.asc
    curl -s "https://keybase.io/_/api/1.0/key/fetch.json?pgp_key_ids=34365D9472D7468F" | jq -r '.keys | .[0] | .bundle' > hashicorp.asc
    # From https://circleci.com/developer/orbs/orb/jmingtan/hashicorp-vault
# Note https://keybase.io/hashicorp says 34365D9472D7468F
fi

if command -v gpg ; then
    # This is the public key from above - one-time step.   # applicable to all HashiCorp products
    gpg --import hashicorp.asc  
    # gpg: key 34365D9472D7468F: public key "HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>" imported
    # gpg: Total number processed: 1
    # gpg:               imported: 1
fi  # see https://www.vaultproject.io/docs/concepts/pgp-gpg-keybase

# The response we want is specified in https://www.hashicorp.com/security#pgp-public-keys
# Verify we want key ID 72D7468F and fingerprint C874 011F 0AB4 0511 0D02 1055 3436 5D94 72D7 468F. 
gpg --fingerprint C874011F0AB405110D02105534365D9472D7468F
    # pub   rsa4096 2021-04-19 [SC] [expires: 2026-04-18]
    #       C874 011F 0AB4 0511 0D02  1055 3436 5D94 72D7 468F
    # uid           [ unknown] HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>
    # sub   rsa4096 2021-04-19 [E] [expires: 2026-04-18]
    # sub   rsa4096 2021-04-21 [S] [expires: 2026-04-20]
    # NOTE: It's not expired?

# Enable run specification of this variable within https://releases.hashicorp.com/consul
if [ -n "${CONSUL_VERSION_IN}" ]; then  # specified by parameter
    export CONSUL_VERSION="${CONSUL_VERSION_IN}" 
else
    # blank/unspecified, so use hard-coded last-known good default:
    export CONSUL_VERSION="1.12.2+ent" 
fi

# for each platform:
export PLATFORM1=$(echo $(uname) | awk '{print tolower($0)}')
export PLATFORM=$( echo "${PLATFORM1}"_"$( uname -m )" )
# PLATFORM="darwin_arm64" amd64, freebsd_386/amd64, linux_386/amd64/arm64, solaris_amd64, windows_386/amd64
if [ ! -f "consul_${CONSUL_VERSION}_${PLATFORM}.zip" ]; then  # not found:
    wget "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_${PLATFORM}.zip"
    # consul_1.12.2+ent_d 100%[===================>]  44.59M  4.14MB/s    in 13s     
else
    echo "*** consul_${CONSUL_VERSION}_${PLATFORM}.zip alread downloaded."
fi

if [ ! -f "consul_${CONSUL_VERSION}_SHA256SUMS" ]; then  # not found:
    wget "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS"
        # 1.08K  --.-KB/s    in 0s
fi
if [ ! -f "consul_${CONSUL_VERSION}_SHA256SUMS.72D7468F.sig" ]; then  # not found:
    wget "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.72D7468F.sig"
        # 566  --.-KB/s    in 0s      
fi
if [ ! -f "consul_${CONSUL_VERSION}_SHA256SUMS.sig" ]; then  # not found:
    wget "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig"
        # 566  --.-KB/s    in 0s      
fi

gpg --verify "consul_${CONSUL_VERSION}_SHA256SUMS.sig" \
    "consul_${CONSUL_VERSION}_SHA256SUMS"  
    # gpg: Signature made Fri Jun  3 13:58:17 2022 MDT
    # gpg:                using RSA key 374EC75B485913604A831CC7C820C6D5CD27AB87
    # gpg: Good signature from "HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>" [unknown]
    # gpg: WARNING: This key is not certified with a trusted signature!
    # gpg:          There is no indication that the signature belongs to the owner.
    # Primary key fingerprint: C874 011F 0AB4 0511 0D02  1055 3436 5D94 72D7 468F
    #      Subkey fingerprint: 374E C75B 4859 1360 4A83  1CC7 C820 C6D5 CD27 AB87

# Verify the SHASUM matches the archive.
export EXPECTED_TEXT=$( echo "consul_${CONSUL_VERSION}_${PLATFORM}.zip: OK" )
    # consul_1.12.2+ent_darwin_arm64.zip: OK
RESPONSE=$( shasum -a 256 -c "consul_${CONSUL_VERSION}_SHA256SUMS" 2>/dev/null | grep "${EXPECTED_TEXT}" )
    # shasum: consul_1.12.2+ent_darwin_amd64.zip: No such file or directory
    # consul_1.12.2+ent_darwin_amd64.zip: FAILED open or read
    # consul_1.12.2+ent_darwin_arm64.zip: OK
if [[ "${RESPONSE}" == *"${EXPECTED_TEXT}"* ]]; then  # contains it:
    echo "*** Download verified: ${EXPECTED_TEXT} "
else
    echo "*** ${EXPECTED_TEXT} FAILED verification: ${RESPONSE}"
    exit
fi

# Unzip
if [ -f "consul" ]; then  # found:
   echo "*** removing consul executable binary file before unzip:"
   ls -al consul
      # -rwxr-xr-x@ 1 wilsonmar  staff  127929168 Jun  3 13:46 /usr/local/bin/consul
   rm consul
fi
if [ -f "consul_${CONSUL_VERSION}_${PLATFORM}.zip" ]; then  # not found:
   unzip "consul_${CONSUL_VERSION}_${PLATFORM}.zip"
fi
if [ ! -f "consul" ]; then  # not found:
    echo "*** consul file not found. Aborting."
    exit
fi

# Move consul executable binary to folder in $PATH :
TARGET_FOLDER="/usr/local/bin"
mv consul "${TARGET_FOLDER}"
if [ ! -f "${TARGET_FOLDER}/consul" ]; then  # not found:
   echo "*** ${TARGET_FOLDER}/consul not found after move."
   exit
else
   ls -al "${TARGET_FOLDER}/consul"
      # -rwxr-xr-x@ 1 wilsonmar  staff  127929168 Jun  3 13:46 /usr/local/bin/consul
fi

# Cleanup:
rm "hashicorp.asc"
rm "consul_${CONSUL_VERSION}_SHA256SUMS"
rm "consul_${CONSUL_VERSION}_SHA256SUMS.72D7468F.sig"
rm "consul_${CONSUL_VERSION}_SHA256SUMS.sig"
rm "consul_${CONSUL_VERSION}_${PLATFORM}.zip"
# Now you can do git push.

echo "Done downloading consul_${CONSUL_VERSION}."

# END