#!/bin/bash
# consul-install.sh From https://gist.github.com/mdaffin/17a22fab2722e506705e#file-consul-install-sh
set -euo pipefail
IFS=$'\n\t'

function required() {
  hash "${1}" 2>/dev/null || { echo >&2 "${1} is required but is not installed.  Aborting."; exit 1; }
}

required wget
required unzip
required mktemp
required id
required useradd

CONSUL_CONFIG=${1:-}

VERSION="${VERSION:-0.5.2}"
ARCH="$(uname -m)"

case "${ARCH}" in
"x86_64")
  ARCH="amd64"
  ;;
*)
  echo >&2 "Unsupported architecture: ${ARCH}"
  exit 1
  ;;
esac

ZIP_NAME="${VERSION}_linux_${ARCH}.zip"
URL="https://dl.bintray.com/mitchellh/consul/${ZIP_NAME}"

DLDIR=$(mktemp --directory -t tmp.XXXXXXXXXX)
function finish {
  rm -rf "${DLDIR}"
}
trap finish EXIT
ZIP="${DLDIR}/${ZIP_NAME}"

wget --quiet -O "${ZIP}" "${URL}"
unzip -q "${ZIP}" -d "${DLDIR}"

id consul > /dev/null 2>&1 || useradd --no-create-home --system --shell "/bin/nologin" --user-group consul

install -D --mode 0755 "${DLDIR}/consul" "/usr/local/bin/consul"
install --directory --mode 0755 --owner consul --group consul "/var/lib/consul"
install --directory --mode 0755 "/etc/consul.d"

if [[ -z "${CONSUL_CONFIG}" ]]; then
  [[ -f "/etc/consul.conf" ]] || cat <<-EOF > "/etc/consul.conf"
{
  "server": true,
  "data_dir": "/var/lib/consul",
}
EOF
else
  install -D --mode 0644 "${CONSUL_CONFIG}" "/etc/consul.conf"
fi

# TODO install service file
if hash systemctl 2>/dev/null; then
cat <<-EOF > /etc/systemd/system/consul.service
[Unit]
Description=Consul Agent
Wants=basic.target
After=basic.target network.target

[Service]
User=consul
Group=consul
Environment="GOMAXPROCS=2"
ExecStart=/usr/local/bin/consul agent -config-file=/etc/consul.conf -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF
else
  echo "Unknown init system, service not installed" 1>&2
fi

echo "Finished installing consul."
