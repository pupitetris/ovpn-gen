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
