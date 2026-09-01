# ovpn-gen

Shell script for OpenVPN client profile management


## Setup

After cloning, copy `config-example.sh` to `config.sh`, copy
`profile_template-example` to `profile_template` and copy
`vars.example` to `vars`, then edit these files to suit your needs.

Required software (Debian packages, for other distros the names will vary):

```bash
apt install openssl easy-rsa pwgen openvpn ncurses-bin
```


## Running

### Usage

```bash
ovpn-gen [-rm] login

example: ovpn-gen johndoe@myorg
```

Arguments:

* `-rm`: removes the profile identified by `login`. Otherwise, the
  profile is created.
* `login`: required, specifies the username. If `@org` suffix is not
  present, the one sepcified by the configured `ORG` environment
  variable will be used.

On the first run, if the server and root CAs are not present, they
will be created.

### Environment variables

* `DEBUG`: set it to any value to activate logging of the commands run.
* `CONFIG_FILE`: path to the configuration file to set the environment.
* `PASS`: set the password for the generated client profile instead of generating a random one.

Other environment variables that are used can be found with
explanations in `[config-example.sh](config-example.sh)`. Environment
variables set on invocation should override values set on the config
file.

## Profile management

### Create a profile

After the initial setup, you can start creating OpenVPN client
profiles. Switch to the directory where `ovpn-gen` resides and then:

```bash
./ovpn-gen test.joe
```

If this is the first profile you are creating, a `server` directory
will be created with the files needed to run the openvpn server. These
files would have to be installed in your `/etc/openvpn/server` with a
its configuration and so on.

### ovpn file

A `client-*` directory will be created inside the `profiles`
directory. In case of our example, it would be
`profiles/client-test.joe`. Inside this directory, you will find the
`*.ovpn` file that is to be shared with the user that will connect its
client to your server. In case of our example, it would be
`profiles/client-test.joe/myorg-test.joe.ovpn` (assuming you left the
organization unchanged as `myorg`).

Give this file to the user and provide instructions on how to import
the `ovpn` profile.

### Password

The password is stored as plain text in the client directory inside a
file named `pass`. In case of our example, it would be
`profiles/client-test.joe/pass`. It is also reported on the run output
when creating the profile. Provide this password to the user, which
will be needed to be entered every time the user connects, unless the
client software is told to remember the password.

Passwords are randomly generated but you can set it to your discretion
using the `PASS` environment variable:

```bash
 PASS=hell0World ./ovpn-gen test.joe
```

### Client fingerprint

Every client profile has a cryptographic signature that is used to
help protecting the server from authentication retry abuse. The
signature is reported on the run output besides the password, and
stored inside the `ovpn` file as a commented line prefixed with `#
cert peer-fingerprint:`. This fingerprint has to be added to your
openvpn server configuration in a line of its own alongside the others
in the `<peer-fingerprint>` section (recommended to put a comment
before it with the user name):

```
<peer-fingerprint>

...

# test.joe
AA:BB:CC:DD:...:A6:F0:87

...

</peer-fingerprint>
```

Note that any change in a client's configuration, including its
password, will result in a new fingerprint that will have to be
included in the `<peer-fingerprint>`, replacing the old one.


### Client reconfiguration

There is no functionality for client profile editing. If you want to
reconfigure a client, first remove the profile using the `-rm`
argument, and then recreate it with the new options:

```bash
./ovpn-gen -rm test.joe
...
PASS=newPassword ./ovpn-gen test.joe
```

New options can be set by, for example, specifying a different profile
template by altering the `PROFILE_TPL` variable.

### Restart openvpn server (Debian)

If you have for example a file named
`/etc/openvpn/server/intranet.conf`, then you can restart the server
so that new fingerprints are recognized, using:

```bash
sudo systemctl restart openvpn-server@intranet
```

You can see who is connected by consulting `*-status.log` files
located in `/var/log/openvpn`:

```bash
cat /var/log/openvpn/intranet-status.log
```
