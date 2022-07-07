#!/usr/bin/env sh
# This is consul-download.sh from https://github.com/wilsonmar/hashicups/blob/main/consul-download.sh
# Instead of using brew (Homebrew)...
# This downloads and installs "safely" - verifying that what is downloaded has NOT been altered.
#   1. The fingerprint used here matches what the author saved in Keybase.
#   2. The author's hash of the downloaded file matches the hash created by the author.
#   3. Download does not occur if the file already exists in the current folder.
#   4. Files downloaded are removed because the executable is what is used.
# Techniques for shell scripting used here are explained at https://wilsonmar.github.io/shell-scripts

# Break on error:
set -e

# $CONSUL_VERSION_IN and $TARGET_FOLDER_IN specified before invoking this.

# Instead of obtaining manually: https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
LATEST_VERSION=$( curl -sL https://api.github.com/repos/hashicorp/consul/releases/latest | jq -r ".tag_name" | cut -c2- )

# Enable run specification of this variable within https://releases.hashicorp.com/consul
# Thanks to https://fabianlee.org/2021/02/16/bash-determining-latest-github-release-tag-and-version/
if [ -n "${CONSUL_VERSION_IN}" ]; then  # specified by parameter
   export CONSUL_VERSION="${CONSUL_VERSION_IN}"
else
   # TODO: Enable user selection of +ent or FOSS edition?
   CONSUL_VERSION="${LATEST_VERSION}+ent"  # for "1.12.2+ent"
fi

if command -v consul ; then  # executable found:
    RESPONSE=$( consul --version )
    # Consul v1.12.2
    # Revision 19041f20
    # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)
    if [[ "${RESPONSE}" == *"${LATEST_VERSION}"* ]]; then  # contains it:
        echo "${RESPONSE}"
        if [[ "${CONSUL_VERSION}" == *"${LATEST_VERSION}"* ]]; then  # contains it:
            echo "*** consul binary is already at the latest version ${LATEST_VERSION}."
            which consul
            echo "*** Exiting..."
            exit
        else
            echo "*** consul binary being changed to version ${CONSUL_VERSION}."
        fi
    fi

    # NOTE: There are /usr/local/bin/consul and /usr/local/bin/consul-k8s  
    # There is /opt/homebrew/bin//consul-terraform-sync installed by homebrew
    # So /usr/local/bin should be at the front of $PATH in .bash_profile or .zshrc
    echo "*** which consul "
    which consul
else
    echo "*** consul executable not found. Installing ..."
fi

if [ -n "${TARGET_FOLDER_IN}" ]; then  # specified by parameter
   TARGET_FOLDER="${TARGET_FOLDER_IN}"
else
   TARGET_FOLDER="/usr/local/bin"
fi

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

# TODO: Install gpg if needed
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

# TODO: Install wget if needed
if ! command -v wget ; then
   brew install wget
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

echo "*** Downloaded files removed for consul_${CONSUL_VERSION}."
# Now you can do git push.

RESPONSE=$( consul --version )
   # Consul v1.12.2
   # Revision 19041f20
   # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)
if [[ "${CONSUL_VERSION}" == *"${RESPONSE}"* ]]; then  # contains it:
   echo $RESPONSE
   echo "*** Consul is NOT the desired version ${CONSUL_VERSION} - Aborting."
   exit
fi

# END