# Instances creation

- [Multipass](#multipass)
  - [Setup](#setup)
  - [Remove all Multipass instances](#remove-all-multipass-instances)
  - [Get info](#get-info)
  - [Modify instances](#modify-instances)
- [Generate instances configuration files](#generate-instances-configuration-files)
- [Manage instances](#manage-instances)
- [Ubuntu ISO](#ubuntu-iso)
- [Development](#development)
  - [Troubleshooting](#troubleshooting)

## Multipass

### Setup

```sh
brew install multipass
multipass get local.driver
multipass set local.driver=qemu
```

> On macOS, enable `Full Disk Access` for `multipassd` in `Provacy & Security`

### Remove all Multipass instances

```sh
# Do NOT run if you have other multipass instances you want to keep
multipass delete --all
multipass purge
multipass list
```

### Get info

```sh
multipass info --format yaml 'linux-desktop'
multipass get --keys
multipass get local.linux-desktop.cpus
multipass get local.linux-desktop.memory
multipass get local.linux-desktop.disk
```

### Modify instances

```sh
multipass stop linux-desktop
multipass set local.linux-desktop.cpus=2
multipass set local.linux-desktop.memory=4.0GiB
multipass set local.linux-desktop.disk=10.0GiB
multipass start linux-desktop
```

## Generate instances configuration files

Generate admin password and ansible ssh keys:

```sh
# Create a directory for the generated password files
_instance_admin_password_path="generated/assets/passwords/admin"
mkdir -p "${_instance_admin_password_path:?}"
# Create password
INSTANCE_ADMIN_PASSWORD=changeme
echo "${INSTANCE_ADMIN_PASSWORD:?}" > "${_instance_admin_password_path:?}/plain"
openssl rand -base64 8 > "${_instance_admin_password_path:?}/salt"
_instance_admin_password_salt=$(cat "${_instance_admin_password_path:?}/salt")
openssl passwd -6 -salt "${_instance_admin_password_path:?}" "${INSTANCE_ADMIN_PASSWORD}" \
  > "${_instance_admin_password_path:?}/hash"
# Generate SSH keys for ansible
mkdir -p generated/assets/.ssh
ssh-keygen -t ed25519 -C "automator@iam-demo.test" -f generated/assets/.ssh/id_ed25519 -q -N ""
```

Generate instances management scripts:

```sh
# Set the project root path
project_root_path="$(cd ../../ && pwd)"
# Set the project generator path
project_generator_path="$(pwd)"
# Set the path for the generated files
generated_project_path="${project_root_path:?}/generated"
# Set the Orchestrator to be used in the Instances Generator script
generator_orchestrator=multipass
# Use 'arm64' for Apple silicon processors or 'amd64' for Intel and AMD 64bit CPUs
host_architecture=$(uname -m)
cp config/config.libsonnet.${generator_orchestrator}.example config/config.libsonnet
jsonnet --string \
  --create-output-dirs \
  --multi "${generated_project_path:?}" \
  --ext-str project_root_path="${project_root_path:?}" \
  --ext-str orchestrator_name="${generator_orchestrator:?}" \
  --ext-str host_architecture="${host_architecture:?}" \
  --jpath "${project_root_path}" \
  --jpath "${project_generator_path:?}" \
  --jpath "${project_generator_path}/config" \
  "${project_generator_path}/project-files-generator.jsonnet"
chmod u+x "${generated_project_path}"/*.sh
```

## Manage instances

Instances management scripts are located in the directory `generated`.

```sh
cd generated
```

Create and provision the instances:

```sh
# Generate project configuration
./project-prepare-config.sh
# Create project network and instances
./project-bootstrap.sh
# Wrap-up basic project setup
./project-wrap-up.sh
# Automated provisioning
./project-provisioning.sh
```

```sh
# Get all instances status
./instances-status.sh
# Get status for a specific instance
./instances-status.sh ansible-controller
# Get info for a specific instance
./instance-info.sh ansible-controller
# Get console for a specific instance
./instance-shell.sh ansible-controller
```

To remove networks, destroy all instances, and delete the generated project folder:

```sh
./project-delete.sh
```

## Ubuntu ISO

[Live Server](https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.1-live-server-arm64.iso)
[Cloud Image](https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img)

## Development

### Troubleshooting

This script uses jsonnet.

Remember to check the correct use of `%` when using with string formatting or
interpolation (e.g. escape `%` using `%%`).

Examples:

```jsonnet
{
  my_float: 5.432,
  my_string: "something",
  string1: "my_float truncated is %(my_float)0.2f, my_string is %(my_string)s, and %% is escaped" % self,
  string2: "Concatenate to " + self.my_string + " without templates, and no need to escape %.",
  string3: |||
    When using templates in text blocks, like for %s or %d, we need to escape %%.
  ||| % ["some text", 5+10],
  string4: |||
    Text block and no templates?
    No need to escape %!
  |||,
}
```

```json
{
  "my_float": 5.432,
  "my_string": "something",
  "string1": "my_float truncated is 5.43, my_string is something, and % is escaped",
  "string2": "Concatenate to something without templates, and no need to escape %.",
  "string3": "When using templates in text blocks, like for some text or 15, we need to escape %.\n",
  "string4": "Text block and no templates?\nNo need to escape %!\n"
}
```

If you see a message like `RUNTIME ERROR: Unrecognised conversion type` and a stack
trace hard to debug, it's likely that you're missing a conversion type specifier
for `%` (see Python documentation for [printf-style String Formatting][python-printf-style]).

To reduce the number of lines to check, we can use `awk` to get all the lines
containing `%` and filter out those that should be correct.

```sh
file_to_check=lib/orchestrators/vbox.libsonnet
awk '/%/ && !/\|\|\| %|%(\([a-zA-Z0-9_]+\)){0,1}(0| |-|\+){0,1}[0-9]*(\.[0-9]+){0,1}(h|l|L){0,1}[diouxXeEfFgGcrs]/ {print NR, $0}' "${file_to_check:?}
```

[python-printf-style]: <https://docs.python.org/3/library/stdtypes.html#printf-style-string-formatting> "printf-style String Formatting"
