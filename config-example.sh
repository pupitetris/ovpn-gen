# Rename this file to config.sh

# Path to file containing basic ovpn profile options
# Relative to script's location. Use an absolute path for other locations.
PROFILE_TPL=${PROFILE_TPL:-./profile_template}

# Directory where certificates, keys, requests and profiles reside.
# Relative to script's location. Use an absolute path for other locations.
PROFILE_DIR=${PROFILE_DIR:-./profiles}

# If set, root cert has no password
CA_NOPASS=${CA_NOPASS:-}

# If set, activate debugging (set -x)
DEBUG=${DEBUG:-}

# Program locations
EASYRSA=${EASYRSA:-/usr/share/easy-rsa/easyrsa}
OPENVPN=${OPENVPN:-/usr/sbin/openvpn}
OPENSSL=${OPENSSL:-/usr/bin/openssl}
PWGEN=${PWGEN:-/usr/bin/pwgen}

# Name of the user's organization, used as an @ suffix to identify the user
ORG=${ORG:-myorg}
