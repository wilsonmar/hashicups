#!/usr/bin/env sh
# This is consul-download.sh from https://github.com/wilsonmar/hashicups/blob/main/consul-download.sh
# This automates manual instructions at https://learn.hashicorp.com/tutorials/consul/deployment-guide?in=consul/production-deploy
# and instead of brew (Homebrew)...
# This downloads and installs "safely" - verifying that what is downloaded has NOT been altered.
#   1. The fingerprint used here matches what the author saved in Keybase.
#   2. The author's hash of the downloaded file matches the hash created by the author.
#   3. Download does not occur if the file already exists in the current folder.
#   4. Files downloaded are removed because the executable is what is used.
# Techniques for shell scripting used here are explained at https://wilsonmar.github.io/shell-scripts
# Explainer: https://serverfault.com/questions/896228/how-to-verify-a-file-using-an-asc-signature-file

# This is v1.03 tool: add shellcheck disable
# shellcheck disable=SC3010,SC2155,SC2005,SC2046
   # SC3010 POSIX compatibility per http://mywiki.wooledge.org/BashFAQ/031 where [[ ]] is undefined.
   # SC2155 (warning): Declare and assign separately to avoid masking return values.
   # SC2005 (style): Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.
   # SC2046 (warning): Quote this to prevent word splitting.

# Break on error:
set -e

# Can be specified on Terminal before invoking this:
# export CONSUL_VERSION_IN="1.12.2"
# export CONSUL_VERSION_IN="1.12.2+ent"
# export TARGET_FOLDER_IN="/usr/local/bin" 

if ! command -v jq ; then
    echo "*** Installing jq ..."
    brew install jq
fi
# Instead of obtaining manually: https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
LATEST_VERSION=$( curl -sL "https://api.github.com/repos/hashicorp/consul/releases/latest" | jq -r ".tag_name" | cut -c2- )

# Enable run specification of this variable within https://releases.hashicorp.com/consul
# Thanks to https://fabianlee.org/2021/02/16/bash-determining-latest-github-release-tag-and-version/
if [ -n "${CONSUL_VERSION_IN}" ]; then  # specified by parameter
   export CONSUL_VERSION="${CONSUL_VERSION_IN}"
else
   # TODO: Enable user selection of +ent or FOSS edition in parameter?
   CONSUL_VERSION="${LATEST_VERSION}+ent"  # for "1.12.2+ent"
fi

if ! command -v consul ; then  # executable not found:
    echo "*** consul executable not found. Installing ..."
else
    RESPONSE=$( consul --version )
    # Consul v1.12.2
    # Revision 19041f20
    # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)
    if [[ "${LATEST_VERSION}" == *"${RESPONSE}"* ]]; then  # contains it:
        echo "*** Currently installed:"
        echo "${RESPONSE}"
        if [[ "${CONSUL_VERSION}" == *"${LATEST_VERSION}"* ]]; then  # contains it:
            echo "*** consul binary is already at the latest version ${LATEST_VERSION}."
            which consul
            echo "*** Exiting..."
            exit
        else
            echo "*** consul binary being replaced with version ${CONSUL_VERSION}."
        fi
    fi

    # NOTE: There are /usr/local/bin/consul and /usr/local/bin/consul-k8s  
    # There is /opt/homebrew/bin//consul-terraform-sync installed by homebrew
    # So /usr/local/bin should be at the front of $PATH in .bash_profile or .zshrc
    echo "*** which consul (/usr/local/bin/consul)"
    which consul
fi

if [ -n "${TARGET_FOLDER_IN}" ]; then  # specified by parameter
   TARGET_FOLDER="${TARGET_FOLDER_IN}"
else
   # Default path:
   TARGET_FOLDER="/usr/local/bin"
fi
if [[ ! ":$PATH:" == *":$TARGET_FOLDER:"* ]]; then
   echo "*** TARGET_FOLDER=\"${TARGET_FOLDER_IN}\" not in PATH to be found. Aborting."
   exit
fi

if ! command -v wget ; then
   echo "*** Installing wget ..."
   brew install wget
fi

# See https://tinkerlog.dev/journal/verifying-gpg-signatures-history-terms-and-a-how-to-guide
# Alternately, see https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/terraform-debian.sh
# Automation of steps described at 
                     #  https://github.com/sethvargo/hashicorp-installer/blob/master/hashicorp.asc
# curl -o hashicorp.asc https://raw.githubusercontent.com/sethvargo/hashicorp-installer/master/hashicorp.asc
if [ ! -f "hashicorp.asc" ]; then  # not found:
    echo "*** Downloading HashiCorp's public asc file (7177 bytes)"
    # Get PGP Signature from a commonly trusted 3rd-party (Keybase) - asc file applicable to all HashiCorp products.
    # This does not return a file:
    # wget --no-check-certificate -q hashicorp.asc https://keybase.io/hashicorp/pgp_keys.asc
    # SO ALTERNATELY since https://keybase.io/hashicorp says 34365D9472D7468F
    curl -s "https://keybase.io/_/api/1.0/key/fetch.json?pgp_key_ids=34365D9472D7468F" | jq -r '.keys | .[0] | .bundle' > hashicorp.asc
    # 34365D9472D7468F Created 2021-04-19 (after the Codedev supply chain attack)
       # See https://discuss.hashicorp.com/t/hcsec-2021-12-codecov-security-event-and-hashicorp-gpg-key-exposure/23512
       # And https://www.securityweek.com/twilio-hashicorp-among-codecov-supply-chain-hack-victims
    # See https://circleci.com/developer/orbs/orb/jmingtan/hashicorp-vault
else
    echo "*** Using existing HashiCorp.asc file ..."
fi
if [ ! -f "hashicorp.asc" ]; then  # not found:
   echo "*** Download of hashicorp.asc failed. Aborting."
   exit
else
   ls -alT hashicorp.asc
fi

if ! command -v gpg ; then
    # Install gpg if needed: see https://wilsonmar.github.io/git-signing
    echo "*** brew install gnupg2 (gpg)..."
    brew install gnupg2
    chmod 700 ~/.gnupg
fi
echo "*** gpg import hashicorp.asc ..."
# No Using gpg --list-keys @34365D9472D7468F to check if asc file is already been imported into keychain (a one-time process)
    # gpg --import hashicorp.asc
    # gpg: key 34365D9472D7468F: public key "HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>" imported
    # gpg: Total number processed: 1
    # gpg:               imported: 1
    # see https://www.vaultproject.io/docs/concepts/pgp-gpg-keybase

RESPONSE=$( gpg --show-keys hashicorp.asc )
    # pub   rsa4096 2021-04-19 [SC] [expires: 2026-04-18]
    #       C874 011F 0AB4 0511 0D02  1055 3436 5D94 72D7 468F
    # uid           [ unknown] HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>
    # sub   rsa4096 2021-04-19 [E] [expires: 2026-04-18]
    # sub   rsa4096 2021-04-21 [S] [expires: 2026-04-20]
    # The "C874..." fingerprint is used for verification:

echo "*** Verifying fingerprint ..."
# Extract 2nd line (containing fingerprint):
RESPONSE2=$( echo "$RESPONSE" | sed -n 2p ) 
# Remove spaces:
FINGERPRINT=$( echo "${RESPONSE2}" | xargs )
# Verify we want key ID 72D7468F and fingerprint C874 011F 0AB4 0511 0D02 1055 3436 5D94 72D7 468F. 
gpg --fingerprint "${FINGERPRINT}"
    # pub   rsa4096 2021-04-19 [SC] [expires: 2026-04-18]
    #       C874 011F 0AB4 0511 0D02  1055 3436 5D94 72D7 468F
    # uid           [ unknown] HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>
    # sub   rsa4096 2021-04-19 [E] [expires: 2026-04-18]
    # sub   rsa4096 2021-04-21 [S] [expires: 2026-04-20]
# The response we want is specified in https://www.hashicorp.com/security#pgp-public-keys
echo "*** TODO: The expires: date above must be in the future ..."
# QUESTION: What does "[ unknown]" mean?  trusted with [ultimate]
# TODO: Script automated check if this has expired?

# Install wget if needed
if ! command -v wget ; then
   brew install wget
fi
# for each platform:
export PLATFORM1="$( echo $( uname ) | awk '{print tolower($0)}')"
export PLATFORM="${PLATFORM1}"_"$( uname -m )"
echo "*** PLATFORM=${PLATFORM}"
# For PLATFORM="darwin_arm64" amd64, freebsd_386/amd64, linux_386/amd64/arm64, solaris_amd64, windows_386/amd64
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

echo "*** gpg --verify consul_${CONSUL_VERSION}_SHA256SUMS.sig consul_${CONSUL_VERSION}_SHA256SUMS"
RESPONSE=$( gpg --verify "consul_${CONSUL_VERSION}_SHA256SUMS.sig" \
    "consul_${CONSUL_VERSION}_SHA256SUMS" )
    # gpg: Signature made Fri Jun  3 13:58:17 2022 MDT
    # gpg:                using RSA key 374EC75B485913604A831CC7C820C6D5CD27AB87
    # gpg: Good signature from "HashiCorp Security (hashicorp.com/security) <security@hashicorp.com>" [unknown]
    # gpg: WARNING: This key is not certified with a trusted signature!
    # gpg:          There is no indication that the signature belongs to the owner.
    # Primary key fingerprint: C874 011F 0AB4 0511 0D02  1055 3436 5D94 72D7 468F
    #      Subkey fingerprint: 374E C75B 4859 1360 4A83  1CC7 C820 C6D5 CD27 AB87
EXPECTED_TEXT="Good signature"
if [[ "${EXPECTED_TEXT}" == *"${RESPONSE}"* ]]; then  # contains it:
    echo "*** ${EXPECTED_TEXT} verified."
else
    echo "*** Signature FAILED verification: ${RESPONSE}"
    # If the file was manipulated, you'll see "gpg: BAD signature from ..."
    exit
fi

# Verify the SHASUM matches the archive.
export EXPECTED_TEXT="consul_${CONSUL_VERSION}_${PLATFORM}.zip: OK"
    # consul_1.12.2+ent_darwin_arm64.zip: OK
RESPONSE=$( shasum -a 256 -c "consul_${CONSUL_VERSION}_SHA256SUMS" 2>/dev/null | grep "${EXPECTED_TEXT}" )
    # shasum: consul_1.12.2+ent_darwin_amd64.zip: No such file or directory
    # consul_1.12.2+ent_darwin_amd64.zip: FAILED open or read
    # consul_1.12.2+ent_darwin_arm64.zip: OK
if [[ "${EXPECTED_TEXT}" == *"${RESPONSE}"* ]]; then  # contains it:
    echo "*** Download verified: ${EXPECTED_TEXT} "
else
    echo "*** ${EXPECTED_TEXT} FAILED verification: ${RESPONSE}"
    exit
fi

# Unzip
if [ -f "consul" ]; then  # found:
   echo "*** removing existing consul binary file before unzip of new file:"
   ls -alT "${TARGET_FOLDER}/consul"
      # -rwxr-xr-x@ 1 user  group  127929168 Jun  3 13:46 2022 /usr/local/bin/consul
   # TODO: Change file name with time stamp instead of removing.
   rm "${TARGET_FOLDER}/consul"
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
   echo "*** ${TARGET_FOLDER}/consul not found after move. Aborting."
   exit
else
   echo "*** consul_${CONSUL_VERSION} date/time stamp and bytes:"
   ls -alT "${TARGET_FOLDER}/consul"
      # -rwxr-xr-x  1 user  group  117722304 Jun  3 13:44:36 2022 /usr/local/bin/consul # for consul_1.12.2 (open source)
      # -rwxr-xr-x@ 1 user  group  127929168 Jun  3 13:46 2022 /usr/local/bin/consul  # for consul_1.12.2+ent
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
   # Consul v1.12.2+ent
   # Revision 0a4743c5
   # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)
#OR:
   # Consul v1.12.2
   # Revision 19041f20
   # Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)
if [[ "${CONSUL_VERSION}" == *"${RESPONSE}"* ]]; then  # contains it:
   echo "${RESPONSE}"
   echo "*** Consul is NOT the desired version ${CONSUL_VERSION} - Aborting."
   exit
fi

echo "*** What we're using: consul_${CONSUL_VERSION}."
consul version

# END