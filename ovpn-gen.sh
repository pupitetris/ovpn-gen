#!/bin/bash

# Required installed software (Debian):
# openssl, easy-rsa, pwgen, openvpn, ncurses-bin

# Stop if a command fails:
set -e

# DEBUG=1
[ -n "$DEBUG" ] && set -x

scriptdir=$(dirname "$0")
cd "$scriptdir"

CONFIG_FILE=${CONFIG_FILE:-config.sh}
[ -e "$CONFIG_FILE" ] && source $CONFIG_FILE

[ -n "$DEBUG" ] && set -x

ORG=${ORG:-myorg}
SERVER=${SERVER:-vpn.myorg.com}
PROTO=${PROTO:-udp4}
PORT=${PORT:-1194}

if [ -n "$CA_NOPASS" ]; then
    CA_NOPASS=nopass
    CA_PASSIN=
else
    CA_NOPASS=
    CA_PASSIN=--passin=file:pass
fi

easyrsa="${EASYRSA:-/usr/share/easy-rsa/easyrsa} --batch"
if [ -n "$DEBUG" ]; then
    export EASYRSA_DEBUG=1
else
    easyrsa="$easyrsa --silent"
fi

openvpn=${OPENVPN:-/usr/sbin/openvpn}
openssl=${OPENSSL:-/usr/bin/openssl}
pwgen=${PWGEN:-/usr/bin/pwgen}

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
server_dir=./intranet

ca_crt=$ca_dir/pki/ca.crt
client_req=$client_dir/pki/reqs/$entity.req
client_crt=$client_dir/$entity.crt
server_crt=$server_dir/OpenVPNServer.crt
client_key=$client_dir/pki/private/$entity.key
tls_client_key=$client_dir/intranet-tls-crypt-v2-client-$client.key

if [ -n "$REMOVE_CLIENT" ]; then
    rm -rf "$client_dir" "$ca_dir/pki/reqs/$entity.req" "$ca_dir/pki/issued/$entity.crt"
    exit 0
fi

mkdir -p "$client_dir"

if [ ! -e "$client_req" ]; then
    pushd "$client_dir"
    [ -f pki ] || $easyrsa init-pki
    [ -e pki/vars ] || cp "../$server_dir/pki/vars" pki
    if [ -n "$PASS" ]; then
	echo -n "$PASS" > pass
	chmod 600 pass
    fi
    if [ ! -e pass ]; then
	echo -n $(pass_gen) > pass
	chmod 600 pass
    fi
    message Generating private key and request pems.
    $easyrsa --passout=file:pass --req-cn="$client_email" gen-req $entity text
    popd
fi

if [ ! -e "$client_crt" ]; then
    pushd "$ca_dir"
    $easyrsa import-req "../$client_req" $entity
    message CA: Signing request pem...
    $easyrsa $CA_PASSIN sign-req client $entity $CA_NOPASS
    cp -f pki/issued/$entity.crt "../$client_crt"
    popd
fi

server_crt_fp=$(fingerprint < "$server_crt")
client_crt_fp=$(fingerprint < "$client_crt")

[ -e "$tls_client_key" ] ||
    $openvpn --tls-crypt-v2 "$server_dir/intranet-tls-crypt-v2-server.key" \
	     --genkey tls-crypt-v2-client "$tls_client_key"

ovpn_file="$client_dir/$ORG-$client.ovpn"

{
    cat <<EOF
client
tls-client
verb 4
dev tun
tun-mtu 1400
remote $SERVER
proto $PROTO
port $PORT
nobind
resolv-retry infinite
persist-key
persist-tun
remote-cert-tls server
peer-fingerprint $server_crt_fp
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
