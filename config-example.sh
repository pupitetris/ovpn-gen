# Rename this file to config.sh

# If set, root cert has no password
CA_NOPASS=${CA_NOPASS:-}

# If set, activate debugging (set -x)
DEBUG=${DEBUG:-}

# Program locations
EASYRSA=${EASYRSA:-/usr/share/easy-rsa/easyrsa}
OPENVPN=${OPENVPN:-/usr/sbin/openvpn}
OPENSSL=${OPENSSL:-/usr/bin/openssl}
PWGEN=${PWGEN:-/usr/bin/pwgen}

ORG=${ORG:-myorg}
SERVER=${ORG:-vpn.myorg.com}
PROTO=${PROTO:-udp4}
PORT=${PORT:-1194}
