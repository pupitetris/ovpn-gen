#!/bin/bash

# Required software packages (Debian):
# openssl, easy-rsa, pwgen, openvpn, ncurses-bin

# DEBUG=1
[ -n "$DEBUG" ] && set -x

# Stop if a command fails:
set -e

CONFIG_FILE=${CONFIG_FILE:-config.sh}
if [ -n "$CONFIG_FILE" ]; then
    if [ -e "$CONFIG_FILE" ]; then
	source $CONFIG_FILE
    else
	echo Config file $CONFIG_FILE not found >&2
    fi
fi

scriptdir=$(dirname "$0")
cd "$scriptdir"
scriptdir=$(pwd)

if [ -n "$DEBUG" ]; then
    set -x
else
    set +x
fi

if [ ! -e "$PROFILE_TPL" ]; then
    echo Profile template file $PROFILE_TPL not found >&2
    exit 1
fi

pd=$PROFILE_DIR
if [ ! -e "$pd" -o ! -d "$pd" ]; then
    echo Profile dir $PROFILE_DIR not found or not a directory >&2
    exit 1
fi
cd "$pd"

ORG=${ORG:-myorg}

if [ -n "$CA_NOPASS" ]; then
    CA_NOPASS=nopass
    CA_PASSIN=
else
    CA_NOPASS=
    CA_PASSIN=--passin=file:pass
fi

openvpn=${OPENVPN:-/usr/sbin/openvpn}
openssl=${OPENSSL:-/usr/bin/openssl}
pwgen=${PWGEN:-/usr/bin/pwgen}

function easyrsa {
    if [ -n "$DEBUG" ]; then
	EASYRSA_DEBUG=1 ${EASYRSA:-/usr/share/easy-rsa/easyrsa} --batch --vars="$scriptdir"/vars "$@"
    else
	${EASYRSA:-/usr/share/easy-rsa/easyrsa} --batch --vars="$scriptdir"/vars --silent "$@"
    fi
}

function pass_gen {
    # Secure, with simbols, 10 length, generate 1:
    $pwgen --secure --symbols 10 1
}

function message {
    echo $(tput bold rev setaf 3)">>>  $@ "$(tput sgr0)
}

function fingerprint {
    $openssl x509 -fingerprint -sha256 -noout | cut -f2 -d=
}

# req_file entity crt_file
function sign_req {
    pushd "$ca_dir" > /dev/null
    easyrsa import-req "../$1" $2
    message CA: Signing request pem for $2...
    easyrsa $CA_PASSIN sign-req client $2 $CA_NOPASS
    cp -f pki/issued/$2.crt "../$3"
    popd > /dev/null
}

if [ -z "$1" ]; then
    {
	echo "Usage: $0 [-rm] login"
	echo
	echo "example: $0 some.user@$ORG"
	echo
	echo "-rm removes the client's configuration"
    } >&2
    exit 1
fi

if [ "$1" = -rm ]; then
    REMOVE_CLIENT=1
    shift
fi

client_email=$1
shift

if [ -n "$1" ]; then
    echo "Excess arguments: $@" >&2
    exit 1
fi

client=${client_email%@*}

if [ "$client" = "$client_email" ]; then
    client_email=$client@$ORG
fi

entity=OpenVPNClient-$client

ca_dir=./ca
client_dir=./client-$client
server_dir=./server

ca_crt=$ca_dir/pki/ca.crt
client_req=$client_dir/pki/reqs/$entity.req
client_crt=$client_dir/$entity.crt
server_req=$server_dir/pki/reqs/server.req
server_crt=$server_dir/server.crt
client_key=$client_dir/pki/private/$entity.key
tls_client_key=$client_dir/server-tls-crypt-v2-client-$client.key

if [ ! -d "$ca_dir" ]; then
    message Creating new CA pki...
    mkdir -p "$ca_dir"
    pushd "$ca_dir" > /dev/null
    easyrsa init-pki
    if [ -z "$CA_NOPASS" ]; then
	{ read -rsp 'Enter New CA Key Passphrase: ' i; echo -n "$i"; } > pass
	chmod 600 pass
	pass=$(cat pass)
    fi
    { echo $pass; echo $pass; } | easyrsa build-ca $CA_NOPASS
    popd > /dev/null
fi

if [ ! -d "$server_dir" ]; then
    message Creating new server pki...
    mkdir -p "$server_dir"
    pushd "$server_dir" > /dev/null
    easyrsa init-pki
    easyrsa gen-req server nopass
    popd > /dev/null
fi

if [ ! -e "$server_crt" ]; then
    message Creating new server certificate...
    sign_req "$server_req" server "$server_crt"
    message "Generating new TLS keys. If you already have server keys, put them in $server_dir"
    pushd "$server_dir" > /dev/null
    $openvpn --genkey tls-auth server-tls-auth.key
    $openvpn --genkey tls-crypt-v2-server server-tls-crypt-v2-server.key
    popd > /dev/null
fi

if [ -n "$REMOVE_CLIENT" ]; then
    rm -rf "$client_dir" "$ca_dir/pki/reqs/$entity.req" "$ca_dir/pki/issued/$entity.crt"
    exit 0
fi

mkdir -p "$client_dir"

if [ ! -e "$client_req" ]; then
    pushd "$client_dir" > /dev/null
    [ -f pki ] || easyrsa init-pki
    if [ -n "$PASS" ]; then
	echo -n "$PASS" > pass
	chmod 600 pass
    fi
    if [ ! -e pass ]; then
	echo -n $(pass_gen) > pass
	chmod 600 pass
    fi
    message Generating private key and request pems for $client_email...
    easyrsa --passout=file:pass --req-cn="$client_email" gen-req $entity text
    popd > /dev/null
fi

if [ ! -e "$client_crt" ]; then
    sign_req "$client_req" $entity "$client_crt"
fi

server_crt_fp=$(fingerprint < "$server_crt")
client_crt_fp=$(fingerprint < "$client_crt")

[ -e "$tls_client_key" ] ||
    $openvpn --tls-crypt-v2 "$server_dir/server-tls-crypt-v2-server.key" \
	     --genkey tls-crypt-v2-client "$tls_client_key"

ovpn_file="$client_dir/$ORG-$client.ovpn"

{
    cat "$scriptdir/$PROFILE_TPL"
    cat <<EOF
<peer-fingerprint>
$server_crt_fp
</peer-fingerprint>
<ca>
EOF
    $openssl x509 -in "$ca_crt"
    cat <<EOF
</ca>
# cert peer-fingerprint: $client_crt_fp
<cert>
EOF
    $openssl x509 -in "$client_crt"
    cat <<EOF
</cert>
<key>
EOF
    cat "$client_key"
    cat <<EOF
</key>
<tls-crypt-v2>
EOF
    cat "$tls_client_key"
    cat <<EOF
</tls-crypt-v2>
EOF
} > "$ovpn_file"

message OpenVPN client config saved to $ovpn_file
message password: $(cat "$client_dir/pass")
message $(grep "cert peer-fingerprint" "$ovpn_file" | cut -f2 -d-)
