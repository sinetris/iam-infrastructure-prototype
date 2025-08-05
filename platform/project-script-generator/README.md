# Instances creation

- [Dependencies](#dependencies)
  - [Multipass](#multipass)
    - [Setup](#setup)
    - [To remove all Multipass instances](#to-remove-all-multipass-instances)
    - [Get info](#get-info)
    - [Modify instances](#modify-instances)
  - [VirtualBox](#virtualbox)
- [Test script generator](#test-script-generator)
- [Generate instances configuration files](#generate-instances-configuration-files)
- [Manage instances](#manage-instances)
- [Development](#development)
  - [Troubleshooting](#troubleshooting)
  - [Ubuntu ISOs](#ubuntu-isos)

## Dependencies

### Multipass

#### Setup

[Install Multipass](https://canonical.com/multipass/install)

> On macOS, enable `Full Disk Access` for `multipassd` in `Provacy & Security`

#### To remove all Multipass instances

```sh
# Do NOT run if you have other multipass instances you want to keep
multipass delete --all
multipass purge
multipass list
```

#### Get info

```sh
multipass info --format yaml 'linux-desktop'
multipass get --keys
multipass get local.linux-desktop.cpus
multipass get local.linux-desktop.memory
multipass get local.linux-desktop.disk
```

#### Modify instances

```sh
multipass stop linux-desktop
multipass set local.linux-desktop.cpus=2
multipass set local.linux-desktop.memory=4.0GiB
multipass set local.linux-desktop.disk=10.0GiB
multipass start linux-desktop
```

### VirtualBox

[Install VirtualBox](https://www.virtualbox.org/wiki/Downloads)

## Test script generator

To test if the script generator is working, run:

```sh
./test-generator.sh
```

The script will generate files in a temporary directory and then remove the
generated files.

## Generate instances configuration files

Generate admin password and ansible ssh keys:

```sh
# Set variables
instance_admin_password_path="generated/assets/passwords/admin"
instance_admin_password_file="${instance_admin_password_path:?}/plain"
instance_admin_password_salt_file="${instance_admin_password_path:?}/salt"
instance_admin_password_hash_file="${instance_admin_password_path:?}/hash"

# Create a directory for the generated password files
mkdir -p "${instance_admin_password_path:?}"

# Create plain password file
INSTANCE_ADMIN_PASSWORD=changeme
echo "${INSTANCE_ADMIN_PASSWORD:?}" > "${instance_admin_password_path:?}"

# Create salt password file
openssl rand -base64 8 > "${instance_admin_password_salt_file:?}"

# Create hash password file
_instance_admin_password=$(cat "${instance_admin_password_file:?}")
_instance_admin_password_salt=$(cat "${instance_admin_password_salt_file:?}")
openssl passwd -6 -salt "${_instance_admin_password_salt:?}" "${_instance_admin_password}" \
  > "${instance_admin_password_hash_file:?}"

# Generate SSH keys for ansible
mkdir -p generated/assets/.ssh
ssh-keygen -t ed25519 -C "automator@iam-demo.test" -f generated/assets/.ssh/id_ed25519 -q -N ""
```

Generate instances management scripts:

```sh
# Set a name for the generated project
project_name=demo
# Set the project source code root path
project_source_path="$(cd ../../ && pwd)"
# Set the path to the project-script-generator folder
project_generator_path="$(pwd)"
# Set the path for the generated files
generated_project_path="${project_source_path:?}/generated"
# Set the Orchestrator to be used to create the instances
generator_orchestrator=multipass
# Set the host architecture (e.g, 'arm64' for Apple silicon, 'amd64' for Intel/AMD 64bit CPUs)
# We can use 'uname -m' for auto-discovering
host_architecture=$(uname -m)
# Set a path for the instances data
project_basefolder="$HOME/.local/projects/${project_name:?}"

# Copy a configuration example
cp config/config.libsonnet.${generator_orchestrator}.example config/config.libsonnet

# Generate the scripts
jsonnet --string \
  --max-trace 1 \
  --create-output-dirs \
  --multi "${generated_project_path:?}" \
  --ext-str project_name="${project_name:?}" \
  --ext-str project_source_path="${project_source_path:?}" \
  --ext-str project_basefolder="${project_basefolder:?}" \
  --ext-str orchestrator_name="${generator_orchestrator:?}" \
  --ext-str host_architecture="${host_architecture:?}" \
  --jpath "${project_generator_path:?}" \
  --jpath "${project_generator_path}/config" \
  "${project_generator_path}/project-files-generator.jsonnet"

# Make generated scripts executables
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
# Wrap-up basic project setup (and make instances snapshots)
./project-wrap-up.sh
# Automated provisioning
./project-provisioning.sh
```

Check the instances:

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

To restore instances snapshots (rollback to the state before provisioning), use:

```sh
./project-restore-snapshots.sh
```

To remove networks, destroy all instances, and delete the generated project folder:

```sh
./project-delete.sh
```

## Development

### Troubleshooting

This script uses jsonnet.

Remember to check the correct use of `%` when using with string formatting or
interpolation (e.g. you might need to escape `%` using `%%`).

For example, this jsonnet code:

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

generate the this JSON:

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
awk '/%/ && !/\|\|\| %|%(\([a-zA-Z0-9_]+\)){0,1}(0| |-|\+){0,1}[0-9]*(\.[0-9]+){0,1}(h|l|L){0,1}[diouxXeEfFgGcrs]/ {print NR, $0}' \
  "${file_to_check:?}
```

### Ubuntu ISOs

- [Live Server](https://cdimage.ubuntu.com/releases/) (`ubuntu-[version]-live-server-[architecture].iso`)
- [Cloud Image](https://cloud-images.ubuntu.com/) (`[version-name]-server-cloudimg-[architecture].img`)

[python-printf-style]: <https://docs.python.org/3/library/stdtypes.html#printf-style-string-formatting> "printf-style String Formatting"
