# To Do

[Back to project README](../README.md)

> Table of content

- [Documentation](#documentation)
  - [Project scope](#project-scope)
  - [Add an Infrastructure overview](#add-an-infrastructure-overview)
  - [Add Development instructions](#add-development-instructions)
  - [Add screenshots](#add-screenshots)
  - [Internal DNS server](#internal-dns-server)
- [Setup and configurations](#setup-and-configurations)
  - [Install Applications](#install-applications)
  - [Basic setup](#basic-setup)
  - [Compliance As Code](#compliance-as-code)
  - [Kubernetes resources, labels, and annotations](#kubernetes-resources-labels-and-annotations)
  - [Project and instances management](#project-and-instances-management)
    - [VirtualBox](#virtualbox)
      - [Add Serial Console to VirtualBox instances](#add-serial-console-to-virtualbox-instances)
    - [Track boot process state](#track-boot-process-state)
      - [VirtualBox instance boot state](#virtualbox-instance-boot-state)
- [Future changes and alternatives](#future-changes-and-alternatives)
  - [Move elements to their own repositories](#move-elements-to-their-own-repositories)
  - [Excluded Applications](#excluded-applications)
  - [Change configuration](#change-configuration)
    - [Basic changes](#basic-changes)
    - [Restructure Ansible code](#restructure-ansible-code)
      - [ansible directory layout](#ansible-directory-layout)
    - [Restructure Kubernetes code](#restructure-kubernetes-code)
      - [kubernetes directory layout](#kubernetes-directory-layout)
  - [Optional applications](#optional-applications)
    - [Interesting projects](#interesting-projects)
  - [Alternative to linux-desktop instance](#alternative-to-linux-desktop-instance)
    - [Browser from host machine](#browser-from-host-machine)
      - [Pros](#pros)
      - [Cons](#cons)
      - [Example that could work](#example-that-could-work)

## Documentation

The README should:

- [x] include a warning about the lack of backward compatibility
- [x] include a link to the TODO (this document)
- [x] include a brief description on top
- [x] specify licenses for documentation and code
- [ ] have a better description of the [project scope](#project-scope)
- [ ] include links to the main topics covered in the project documentation
- [ ] be concise
- [ ] include [FOSSA badge on GitHub][fossa-github-badge-pr]

The documentation should:

- [ ] include an introduction to IAM and IGA
- [x] include an introduction to HR-Driven Identity Lifecycle
- [ ] have an [infrastructure overview](#add-an-infrastructure-overview)
- [ ] include [development instructions](#add-development-instructions)
- [ ] include [screenshots](#add-screenshots)

### Project scope

Add an overview and place the tools used in the appropriate sub-set.

Clarify that the tools selected are only used for the sake of semplicity (and
in some cases not the best tools for the job) to cover certain topics.

### Add an Infrastructure overview

### Add Development instructions

- [ ] Hardware Requirements
- [ ] Dependencies
  - [Jsonnet][jsonnet]
  - [Windows App][microsoft-windows-app] (formerly known as [Microsoft Remote Desktop][microsoft-remote-desktop])
  - [Multipass][multipass] or [VirtualBox][virtualbox]
  - [pre-commit][pre-commit]

### Add screenshots

- [ ] Linux Desktop
  - [ ] configure Remote Desktop (e.g. [Windows App][microsoft-windows-app]) on host
  - [x] Terminal execute `~/bin/check-instance-config.sh`
  - [x] Firefox bookmarks
  - [ ] Alertmanager
  - [x] Consul
  - [ ] Grafana
  - [ ] Forgejo
  - [ ] Keycloak
  - [ ] Mailpit
  - [x] midPoint
  - [ ] MinIO
  - [x] Prometheus
  - [x] Terrakube
  - [x] Vault
  - [ ] Traefik Dashboard
  - [x] Kubernetes Dashboard
- [x] Ansible Controller

### Internal DNS server

- [ ] document usage of `.internal` tld
- [ ] when using a real (owned) domains
  - [ ] ensure external DNS servers do not resolve internal domains
        (avoid cache problems)

## Setup and configurations

### Install Applications

- [x] [Forgejo][forgejo]: self-hosted Git service
- [x] [Keycloak][keycloak]: IAM, IdP and SSO
- [x] [Hashicorp Vault][vault]: secrets management
- [x] [Consul][consul]: zero trust networking
- [x] [Trivy][trivy]: vulnerability scanners
- [x] [Grafana][grafana]: dashboards for metrics, logs, tracing
- [x] [Prometheus][prometheus]: monitoring system (metrics)
- [x] [Alertmanager][alertmanager]: alerts handling
- [x] [Grafana Loki][grafana-loki]: multi-tenant log aggregation system
- [x] [Grafana Tempo][grafana-tempo]: distributed tracing backend
- [x] [Terrakube][terrakube]: Open source IaC Automation and Collaboration Software-
- [x] [midPoint][midpoint]: Identity Governance and Administration
- [ ] [Grafana OnCall][grafana-oncall]: on-call management system
- [ ] [Grafana k6][grafana-k6]: load testing tool
- [ ] [Wazuh][wazuh]: unified XDR and SIEM protection for endpoints and cloud workloads
  > **Note:** on hold until all components can run on **arm64**.\
  > See: <https://github.com/wazuh/wazuh/issues/18048>
- [ ] [HashiCorp Boundary][boundary]: simple and secure remote access
- [ ] [Waypoint][waypoint]: lower cognitive load for applications deployment
- [x] [Mailpit][mailpit]: Web and API based SMTP testing
- [ ] [Backstage][backstage]: open platform for building developer portals
- [ ] [Fleet][fleet]: device management (MDM)
- [ ] [ERPNext][erpnext]: Enterprise Resource Planning
- [ ] [Kyverno][kyverno]: Policy-as-Code (PaC) lifecycle for Kubernetes

> **Note:**
>
> - a missing tick means that the application has yet to be added
> - many applications still need to be [configured](#setup-and-configurations)
> - some applications have been moved to [Excluded Applications](#excluded-applications)

### Basic setup

- [x] move Postgres to [base](../kubernetes/base/)
  - [x] use `StatefulSet`
  - [x] use [Postgres base](../kubernetes/base/postgres/) in services
- [x] move Redis to [base](../kubernetes/base/)
  - [x] use `StatefulSet`
  - [x] use [Redis base](../kubernetes/base/redis/) in services
- [ ] Setup **Keycloak**
  - [x] update Keycloak to version `26.1`
  - [x] run Keycloak in production mode
  - [x] use separate domain for the Admin Console
  - [ ] create `employee` realm
  - [ ] create `customer` realm
- [ ] setup **Forgejo**
  - [x] certificate for [git.iam-demo.test](https://git.iam-demo.test)
  - [x] use [base/postgres](../kubernetes/base/postgres)
  - [x] use [base/redis](../kubernetes/base//redis)
  - [x] setup ssh-git loadbalancer
  - [x] initialize database and create admin credentials
  - [ ] ensure the [Container Registry][forgejo-container-registry] is working properly
  - [ ] setup Keycloak as IdP
  - [ ] [Renovate][renovate]: automate dependency update
  - [ ] [Conftest][conftest]: use OPA policies to test configurations
  - [x] ensure all instances of Gitea are replaced by Forgejo (where possible)
- [x] use `.test` tld for external domains
- [x] use a separate DNS server resolver for external domains (Bind9)
- [ ] generate certificates in a proper way
  - [ ] check [Vault PKI documentation][vault-pki]
  - [ ] use [Build Certificate Authority (CA) in Vault with an offline Root][vault-external-ca]
        based on [Build your own certificate authority (CA)][vault-pki-engine]
  - [ ] check [CFSSL][cfssl]
  - [ ] apply instructions for Kubernetes certificates
    - [ ] [Manage TLS Certificates in a Cluster][kubernetes-managing-tls]
    - [ ] [PKI certificates and requirements][kubernetes-pki-best-practices]
  - [ ] ~~use in combination with [mkcert][mkcert] to install the root ca
        certs in client machines trust stores~~
      > not flexible enough for our usecase
  - [x] useful code to generate [CA + intermediate certificate][k3s-custom-ca]
        can be found in k3s
  - [ ] generate [Wazuh](../kubernetes/apps/wazuh/) certs using previously
        generated root CA certs
  - [x] install CA certificates chain in instances
  - [x] test generated CA certificates for installed applications domains from
        the `linux-desktop` instance
- [x] setup [pre-commit][pre-commit] for this project repository
  - [x] add `shellcheck` in `.pre-commit-config.yaml` (only for `project-management`)
    - [ ] include more scripts in `shellcheck`
- [ ] configure [Loki][grafana-loki], [Prometheus][prometheus],
      [Grafana][grafana], [Tempo][grafana-tempo]
  - [x] ~~install [Grafana Agent Flow][grafana-agent-flow]~~ (DEPRECATED)
  - [x] replace [Grafana Agent Flow][grafana-agent-flow] with [Grafana Alloy][grafana-alloy]
  - [ ] use [Promtail][promtail] agent to ships logs to Loki from instances
    - [ ] install and setup [Promtail][promtail] agent in `ansible-controller` instance
    - [ ] install and setup [Promtail][promtail] agent in `iam-control-plane` instance
  - [ ] configure dashboards in Grafana
  - [x] use MinIO credentials and endpoint from Secret in Loki
  - [x] use MinIO credentials and endpoint from Secret in Tempo
- [ ] configure [Wazuh][wazuh] (postponed)
- [ ] configure [Consul][consul]
  - [ ] configure [Consul Service Mesh][consul-service-mesh]
  - [ ] configure [Consul API Gateway][consul-api-gateway]
  - [ ] check [Consul tutorials][consul-tutorials]
  - [ ] configure [Vault as the Secrets Backend for Consul][consul-vault]
- [ ] configure [Trivy][trivy]
  - [x] add Trivy dashboard in Grafana
  - [ ] configure [Trivy Policy Reporter Integration][trivy-policy-reporter] to
        send vulnerability and audit reports to [Loki as target in Policy Report][policy-reporter-loki]
- [ ] separate generation of external (loadbalancer) and internal certificates
- [ ] [setup cert-manager to use Vault][cert-manager-vault]
- [ ] use [age][age] (good and simple encryption tool) for secrets
- [ ] add proper [labels and annotations for Kubernetes resources](#kubernetes-resources-labels-and-annotations)
- [x] use separate [MinIO][minio] deployment
  - [x] move endpoints from to ConfigMap
  - [x] save MinIO credentials in Kubernetes Secret
- [ ] setup [FOSSA][fossa] and [.fossa.yml][fossa-yml] for the project repo
- [ ] setup `linux-desktop`
  - Firefox bookmarks
    - [x] add link to [Loki memberlist](https://loki.iam-demo.test/memberlist)
    - [x] add link to [Mailpit](https://mailpit.iam-demo.test)
    - [x] add link to [midPoint](https://midpoint.iam-demo.test)
    - [x] add link to [Terrakube UI](https://terrakube-ui.iam-demo.test)
    - [x] update link to [Kubernetes Dashboard](https://localhost:8443)
  - Configure shell with ansible
    - [ ] export `KUBECONFIG`
    - [ ] setup `kubectl` completion
    - [ ] setup `kustomize` completion
    - [ ] setup `helm` completion

### Compliance As Code

- [ ] [OpenSCAP][open-scap]: Open-source Security Compliance Solution
  > NIST certified [SCAP][scap] toolkit
- [ ] [OSCAL][oscal]: Open Security Controls Assessment Language
- [ ] [Trestle][trestle]: Manage compliance as code using NIST's OSCAL standard
- [ ] [Open Policy Agent (OPA)][opa]: Declarative Policy
  > Context-aware, Expressive, Fast, Portable
- [ ] [OPAL][opal]: Open Policy Administration Layer

### Kubernetes resources, labels, and annotations

See [Labels and Annotations](development/kubernetes.md#labels-and-annotations)
section in [Kubernetes development tips](development/kubernetes.md).

- [ ] replace labels `app` and `app.kubernetes.io/app` with `app.kubernetes.io/name`
- [ ] remove name suffix `-svc` from `kind: Service`
- [ ] use named ports in `kind: Service`

### Project and instances management

- [x] rename `bunch-up` to `project-management`
- [x] change `&& _exit_code=$? || _exit_code=$?` to `&& _exit_code=0 || _exit_code=$?`
- [ ] change `instances-script-generator`
  - [x] move generated scripts default path to project root
  - [x] rename folder to `project-script-generator`
  - [x] rename `instances.jsonnet` to `project-files-generator.jsonnet`
  - [x] rename `cloud-init-<instance_name>.yaml` to `cidata-<instance_name>-user-data.yaml`
  - [x] use `setup` instead of `config` where appropriate
  - [x] generate `include/utils.sh`
  - [x] change path from `include/utils.sh` to `lib/utils.sh`
  - [x] generate and include project config in scripts (create file `lib/project_config.sh`)
  - [x] add `project_configuration` (create file `project-configuration.sh`)
  - [x] rename `project_configuration` to `project_show_configuration` (create
        file `project-show-configuration.sh`)
    - [ ] `project_show_configuration` shows generated project configuration
  - [ ] change `project_delete` (was `virtualmachines_destroy`)
    - [x] rename `virtualmachines_destroy` to `project_delete`
    - [x] rename `instances-destroy.sh` to `project-delete.sh`
    - [ ] delete (keep config)
      - [ ] remove instances
      - [ ] delete `${project_basefolder:?}/${instance_name:?}/disks`
      - [ ] delete files in `${project_basefolder:?}/${instance_name:?}/tmp`
    - [ ] add `--purge` option (destroy project)
      - [ ] all in `delete` + remove `${project_basefolder:?}`
  - [x] add `project_snapshot_restore` (create file `project-restore-snapshots.sh`)
  - [x] rename `virtualmachines_bootstrap` to `project_bootstrap` (create file `project-bootstrap.sh`)
  - [ ] split `project_bootstrap`
    - [x] `project_prepare_config` (create file `project-prepare-config.sh`)
      - [ ] generate configuration files in `project_basefolder`
    - [ ] `project_bootstrap`
      - [ ] create networks and instances based on config files from `project_basefolder`
  - [x] rename `virtualmachines_setup` to `project_wrap_up` (create file `project-wrap-up.sh`)
  - [x] rename `virtualmachines_provisioning` to `project_provisioning`
  - [x] rename `instances-provisioning.sh` to `project-provisioning.sh`
  - [x] rename `virtualmachines_info` to `instance_info`
  - [ ] change `instance_info` to show static instance info
  - [x] rename `virtualmachines_list` to `instances_status`
  - [x] rename `virtualmachine_shell` to `instance_shell`
  - [ ] use `yq` and remove `envsubst` dependency
    - [ ] use `yq` for `cidata-network-config.yaml`
    - [ ] add ssh public key to user in cloud-init using `yq`

        ```sh
        instance_name=ansible-controller
        instance_username="ubuntu" \
        ssh_authorized_key=$(cat "$HOME/.ssh/id_ed25519.pub") \
        yq -i '(.users[] | select(.name == strenv(instance_username)) | .ssh_authorized_keys) |= . + strenv(ssh_authorized_key)' \
          cidata-${instance_name:?}-user-data.yaml
        ```

  - [ ] copy `jq/modules` and `jq/filters` to `generated/lib` folder
  - [ ] standardize scripts output
  - [ ] modify `provisionings` to accept templating
  - [ ] add optional `description` field to `provisionings`
  - [x] add `NO_COLOR` to generated scripts
    - [x] change `tput` calls to variables

      ```sh
      bold_text=$(tput bold)
      bad_result_text=$(tput setaf 1)
      good_result_text=$(tput setaf 2)
      highlight_text=$(tput setaf 3)
      info_text=$(tput setaf 4)
      reset_text=$(tput sgr0)
      ```

    - [x] use variables for Emoji

      ```sh
      status_success=✅
      status_error=❌
      status_warning=⚠️
      status_info=ℹ️
      status_waiting=💤
      status_action=⚙️
      ```

    - [x] when `NO_COLOR`, set variables as

      ```sh
      bold_text=''
      bad_result_text=''
      good_result_text=''
      highlight_text=''
      info_text=''
      reset_text=''
      status_success='[SUCCESS]'
      status_error='[ERROR]'
      status_warning='[WARNING]'
      status_info='[INFO]'
      status_waiting='[WAITING]'
      status_action='[ACTION]'
      ```

  - [x] change `cloud_config` to `user_data` in `cloud_init.libsonnet`
  - [ ] move `cidata_network_config_template` from `vbox.libsonnet` to `cloud_init.libsonnet`
  - [x] move generic functions to `utils.libsonnet`
  - [ ] Generic changes to `orchestrators`
    - [ ] add `ansible_user` to `instances_catalog_file` for each instance
    - [x] move `ssh_exec` to `utils.libsonnet`
    - [x] move `scp_file` to `utils.libsonnet`
    - [x] move `ssh_check_retry` to `utils.libsonnet`
    - [x] move `NO_COLOR` code to `utils.libsonnet`
    - [x] move `bash_mac_address_functions` to `utils.libsonnet`
    - [ ] move `generic_project_config` code to `utils.libsonnet`
    - [ ] move `project_utils` to `utils.libsonnet`
    - [x] add `check_dependency` to `utils.libsonnet`
    - [x] add `generate_ansible_ssh_keys` to `utils.libsonnet`
    - [x] add `join_array` to `utils.libsonnet`
    - [x] add `element_is_in_array` to `utils.libsonnet`
  - [ ] `base_provisionings` for `ansible-controller` in `setup.jsonnet`
    - [ ] rename `machines_ips` to `instances_config`
    - [ ] add `ansible_controller_user` to `inventory/group_vars/all`
    - [ ] add `ansible_user` to `inventory/instances_config`
    - [ ] change occurrences of `ubuntu` user to `%(admin_username)s` (requires templating)
- [x] disable automated suspend for `linux-desktop`
  - [x] modify `/etc/systemd/sleep.conf`

    ```ini
    [Sleep]
    AllowSuspend=no
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
    ```

    To change in cloud-init:

    ```sh
    sed -i 's/^#\?AllowSuspend=.*/AllowSuspend=no/' /etc/systemd/sleep.conf
    sed -i 's/^#\?AllowHibernation=.*/AllowHibernation=no/' /etc/systemd/sleep.conf
    sed -i 's/^#\?AllowSuspendThenHibernate=.*/AllowSuspendThenHibernate=no/' /etc/systemd/sleep.conf
    sed -i 's/^#\?AllowHybridSleep=.*/AllowHybridSleep=no/' /etc/systemd/sleep.conf
    ```

  - [x] set `sleep-inactive-ac-timeout` to `0`

    ```sh
    sudo -u lightdm /bin/bash <<-'END'
    DISPLAY=:0.0 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus \
    gsettings set \
      com.canonical.unity.settings-daemon.plugins.power \
      sleep-inactive-ac-timeout 0
    END
    sudo -u lightdm /bin/bash <<-'END'
    DISPLAY=:0.0 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus \
    gsettings set \
      org.gnome.settings-daemon.plugins.power \
      sleep-inactive-ac-timeout 0
    END
    # To verify changes
    sudo -u lightdm gsettings get \
      com.canonical.unity.settings-daemon.plugins.power sleep-inactive-ac-timeout
    sudo -u lightdm gsettings get \
      org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
    ```

#### VirtualBox

- [x] generate empty instances catalog json file in project assets folder
- [x] add hostname and IPv4 in instances catalog json file
- [x] add username and MAC address in instances catalog json file
- [x] use `VBoxManage guestproperty wait` instead of `until` in instances creation
- [x] set default `options` as `-q -o ServerAliveInterval=300 -o ServerAliveCountMax=3`
      in `ssh_exec`
- [ ] add all network interfaces in instances catalog json file
- [x] create instances snapshots
- [ ] use previous MAC addressses, if presents
- [ ] use `os_images_path` from config
- [ ] use `os_images_url` from config
- [ ] use `vbox_basefolder` from config
- [ ] use `config.network.name` if exists
- [ ] do not create network if `config.network.skip_creation` exists
- [ ] move `instances_catalog_file` to `${project_basefolder:?}\assets\instances_catalog.json`
- [ ] add tags to instances using `guestproperty`

##### Add Serial Console to VirtualBox instances

On instance creation:

```sh
# Configure COM1 to be used for Serial Console
_uart_file="/tmp/${instance_name:?}-tty.socket"
echo " - Set Serial Port for Serial Console"
VBoxManage modifyvm \
  "${instance_name:?}" \
  --uart1 0x3F8 4 \
  --uart-type2 16550A \
  --uartmode1 server \
  "${_uart_file:?}"
```

In cloud-init:

```sh
# create /etc/default/grub.d/60-serial-console.cfg
GRUB_CMDLINE_LINUX="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,keep"
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"
# Update grub configuration
grub2-mkconfig -o /boot/grub2/grub.cfg
# If necessary, enable serial-getty service for ttyS0
systemctl enable serial-getty@ttyS0.service
```

Connect to instance serial console from the host:

```sh
instance_name=ansible-controller
# Connect using 'minicom'
minicom --baudrate 115200 --device 'unix#'"/tmp/${instance_name:?}-tty.socket" --color=on
# Connect using 'socat' and 'screen'
socat UNIX-CONNECT:/tmp/${instance_name:?}-tty.socket PTY,link=/tmp/${instance_name:?}.pty
screen /tmp/${instance_name:?}.pty
```

#### Track boot process state

Use systemd to track boot state.

##### VirtualBox instance boot state

Set `instance:state` guest property on start, shutdown, reboot, etc

On instance:

```sh
VBoxControl --nologo guestproperty set "instance:state" "STARTING"
```

On host:

```sh
instance_name=ansible-controller
VBoxManage guestproperty get "${instance_name:?}" "instance:state"
```

## Future changes and alternatives

### Move elements to their own repositories

- [ ] Move [Ansible custom roles](../platform/ansible/custom_roles/)
  - [ ] create Ansible collections for custom roles
  - [ ] move the Ansible collections to their own repositories
  - [ ] add collections to ansible [requirements.yml](../platform/ansible/requirements.yml)
- [ ] [Project infrastructure script generator](../platform/project-script-generator/)
  - [ ] make the script more generic
  - [ ] move to new repo `project-infrastructure-script-generator`
- [ ] Split code and documentation
  - [ ] Create new repo `iam-infrastructure-prototype` for the code
  - [ ] further split the documentation and move into new repos
    - [ ] Project specific documentation (e.g. `iam-infrastructure-prototype-documentation`)
    - [ ] Generic IAM documentation (e.g. `iam-infrastructure-overview`)
    - [ ] Generic technical documentation
  - [ ] Add link to new repos in README and archive this repo
- [ ] Move project to its own [GitHub organization](https://docs.github.com/en/organizations)

### Excluded Applications

- ~~[Harbor][harbor]: artifacts registry (for Docker images and OPA policies)~~\
  Harbor require too much work to deploy on ARM64 and we can use the already
  deployed [Forgejo OCI registry][forgejo-container-registry]
- ~~[Notary][notary]: trust over arbitrary collections of data~~
- ~~[Drone][drone]: CI/CD pipelines as code~~\
  Excluded because of the license change and the creation of [Gitness][gitness]
  (to be evalued)
- ~~[Gitea][gitea]: a painless self-hosted Git service~~\
  Excluded because domains and trademark of Gitea were transferred to a for-profit
  company without knowledge or approval of the community.\
  Switching to [Forgejo][forgejo-compare-to-gitea]
- ~~[MailHog][mailhog]: Web and API based SMTP testing~~\
  Not maintained anymore. Switching to [Mailpit][mailpit].

### Change configuration

#### Basic changes

- [ ] configure Vault for production
  - [ ] set `server.dev.enabled` to `false`
  - [ ] Vault `unseal`
  - [ ] Vault PKI
  - [ ] save secrets in [Vault][vault] (see [Kubernetes Secrets in Vault][vault-kubernetes-use-case])
- [ ] enable [Grafana Loki authentication][grafana-loki-auth]
- [ ] [restructure Ansible code](#restructure-ansible-code)
  - [ ] [ansible directory layout](#ansible-directory-layout)
  - [ ] create a dinamic Ansible inventory
  - [ ] follow [Good Practices for Ansible][ansible-good-practices]
- [ ] [restructure Kubernetes code](../kubernetes/)
  - [ ] [kubernetes directory layout](#kubernetes-directory-layout)
  - [ ] create a dinamic Ansible inventory
- [ ] restructure Networking
  - [ ] use [MetalLB][metallb] as load-balancer
  - [ ] evaluate the introduction of [Open vSwitch][open-vswitch]
  - [ ] evaluate the introduction of [Cilium][cilium]
  - [ ] evaluate the introduction of [Envoy][envoy-proxy]
  - [ ] create a `.internal` DNS zone (like in [AWS][aws-internal-tld] or
        [Google Cloud][google-cloud-internal-tld]) for domain accessible only
        from the internal network
  - [ ] add explanation on why `.internal` will not end up like `.dev`
  - [ ] add explanation on why is better to add a "sinkhole" for `.internal` domains
        not managed by us and why is better to use `.example` or `.test` TLDs to
        simulate real-life external domains
  - [ ] add "sinkhole" for any other `.internal` domains in our DNS server
  - [ ] use [ExternalDNS][external-dns] for [Traefik Proxy source][external-dns-traefik]
        to dynamically configure Bind9 using the [RFC 2136 provider][external-dns-rfc2136]
- [ ] add [tfsec][tfsec] (terrafrom security scanners) in CI pipelines
- [ ] change Cluster Domain in [k3s server][k3s-server-doc] from `cluster.local`
      to `iam-demo.local`
- [ ] evaluate [Artifact Hub][artifact-hub] as an artifacts registry

#### Restructure Ansible code

The project use [Ansible][ansible] to manage instances and [bootsrap kubernetes](../kubernetes/).
The [Ansible code](../platform/ansible/) for the custom_roles and playbooks
needs to be restructured (add label, move tasks in the proper place, etc)
and would be better to move the custom roles in Ansible collections and use a
[dinamic Ansible inventory][ansible-dev-dynamic-inventory].

##### ansible directory layout

```yaml
ansible.cfg
custom_roles/               # -- locally created roles --
  common/                   # role common to all hosts (hierarchy valid for all roles)
    tasks/                  # tasks files
      main.yaml             #  'main.yaml' can include other files
    handlers/               # handlers file
      main.yaml             #  'main.yaml' can include other files
    templates/              # files used with the template resource
      my_file.j2            #  (templates end in '.j2')
    files/                  # files to be copied as they are
      static.txt            #  (just an example)
    vars/                   # variables associated with this role
      main.yaml             #
    defaults/               # default lower priority variables for this role
      main.yaml             #
    meta/                   # role dependencies and optional info
      main.yaml             #
    library/                # roles can also include custom modules
    module_utils/           # roles can also include custom module_utils
    lookup_plugins/         # other types of plugins ('lookup' in this case)
  my_namespace.my_role/     # -- same structure as 'common' --
inventories/                # -- inventory files --
  production                # inventory file for production
  staging                   # inventory file for staging
  group_vars/               # groups configurations
    group1.yaml             # common configurations for group1 for all stages
    group2.yaml
    production_group1.yaml  # configurations for group1 for production
    production_group2.yaml
    staging_group1.yaml     # configurations for group1 for staging
    staging_group2.yaml
  host_vars/
    host-prod1.yaml
    host-prod2.yaml
    host-staging1.yaml
    host-staging2.yaml
playbooks/                  # -- playbook files --
  tasks/                    # shared tasks for playbooks
    task1.txt               #  (just an example)
    task2.txt               #  (just an example)
library/                    # -- custom modules (optional) --
module_utils/               # -- custom module_utils to support modules (optional) --
filter_plugins/             # -- filter plugins (optional) --
roles/                      # -- downloaded roles defined in 'requirements.yaml' --
  requirements.yaml
```

#### Restructure Kubernetes code

The project use [Kustomize][kustomize] to customize kubernetes application
configuration.

The code under [kubernetes](../kubernetes/) need to be restructured
(manage helm charts in kustomize, make components more flexible, etc).

Allow [multi-tenancy][kubernetes-multi-tenancy].

##### kubernetes directory layout

Make it easier to compose applications and deploy on multiple clusters and
different platforms.

```tree
├── base-resources
│   ├── postgres
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── redis
│   │   ├── ...
│   │   └── kustomization.yaml
│   └── ...
│       ├── ...
│       └── kustomization.yaml
├── components
│   ├── keycloak
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── git-server
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── tempo
│   │   ├── ...
│   │   └── kustomization.yaml
│   └── ...
│       ├── ...
│       └── kustomization.yaml
├── platform-overrides
│   ├── aws
│   │   ├── ...
│   │   └── kustomization.yaml
│   ├── nginx
│   │   ├── ...
│   │   └── kustomization.yaml
│   └── ...
│       ├── ...
│       └── kustomization.yaml
└── overlays
    ├── dev-minimal
    │   └── single-cluster
    │       └── kustomization.yaml
    └── dev-ha
        ├── tools-cluster
        │   └── kustomization.yaml
        └── biz-cluster
            └── kustomization.yaml
```

### Optional applications

- [ ] [woodpecker-ci]: CI/CD pipelines as code
- [ ] [Falco][falco]: threat detection
- [ ] [plantuml-server][plantuml-server]: diagrams as code
- [ ] [Restic][restic]: operating systems backup solution
- [ ] [Velero][velero]: Kubernetes resources and volumes backup solution
- [ ] [Community][community]: wiki and knowledge-base
- [ ] [Mattermost][mattermost]: Channels, Playbooks, Project & Task Management
- [ ] [Excalidraw][excalidraw]: open source virtual hand-drawn style whiteboard.

#### Interesting projects

- [ ] [PacBot][pacbot]: Policy as Code Bot (by T-Mobile)
- [ ] [MagTape][magtape]: Policy-as-Code for Kubernetes (by T-Mobile)

### Alternative to linux-desktop instance

#### Browser from host machine

We could use a browser installed in the operating system of our laptop
(the host machine) instead of the `linux-desktop` instance.

##### Pros

- Easier to use than a remote desktop
- Less resources used
- Probably faster

##### Cons

- Instances IPs might need to be reachable from the host machine
- We need to use the internal DNS server to resolve the project domains and subdomains
- We need to add the self-signed CA root certificate to the browser
- VPNs could interfere with the configuration
- Some of the steps could require administrative privileges, which are
  usually not allowed (whether enforced or not) on company-owned laptops.
- Configuration steps must be performed on the host machine (the `ansible-controller`
  isn't supposed to make changes to the host machine)
- The steps required to configure users' host machines may vary considerably
  (OS, network configuration, apps installation, etc.)

##### Example that could work

We could use a [SOCKS Protocol Version 5][sock5-rfc1928] proxy server for IPs
and DNS resolution and a browser that support socks5 proxy and custom CA certs
like [Mozilla Firefox][mozilla-firefox].

- [ ] Setup a [socks5 proxy server][sock5-catonmat-example] on an instance
      (e.g. `ansible-controller`)
- [ ] Require Firefox to be present on host
- [ ] Add a [policies.json][mozilla-firefox-policy-templates] file for Firefox
  - [ ] Install root CA certificates using one of the methods from
        ([Certificates | Install][mozilla-firefox-policy-templates-install-certs])
      > You can use the **Firefox certificate store** or a **fully qualified path**
  - [ ] optionally add project bookmarks ([ManagedBookmarks][mozilla-firefox-policy-templates-bookmarks])
- [ ] Create a [new user profile][mozilla-firefox-cli-profile] for Firefox
  - [ ] create [user.js][mozilla-firefox-user-js] file in user profile
    - `network.proxy.type=1`
    - `network.proxy.socks_remote_dns=true`
    - `network.proxy.socks=<instance IP>`
    - `network.proxy.socks_port=<sock5 PORT used>`
    - `security.enterprise_roots.enabled=true`

[age]: <https://github.com/FiloSottile/age> "age"
[alertmanager]: <https://github.com/prometheus/alertmanager> "Alertmanager"
[ansible-dev-dynamic-inventory]: <https://docs.ansible.com/ansible/latest/dev_guide/developing_inventory.html> "Developing dynamic inventory for Ansible"
[ansible-good-practices]: <https://redhat-cop.github.io/automation-good-practices/> "Good Practices for Ansible"
[ansible]: <https://ansible.readthedocs.io/> "Ansible"
[artifact-hub]: <https://github.com/artifacthub/hub> "Artifact Hub"
[aws-internal-tld]: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html> "AWS: DNS attributes for your VPC"
[backstage]: <https://github.com/backstage/backstage> "Backstage"
[boundary]: <https://www.boundaryproject.io/> "HashiCorp Boundary"
[cert-manager-vault]: <https://cert-manager.io/docs/configuration/vault/> "cert-manager Vault"
[cfssl]: <https://github.com/cloudflare/cfssl> "Cloudflare's PKI and TLS toolkit (CFSSL)"
[cilium]: <https://cilium.io/> "cilium"
[community]: <https://github.com/documize/community> "Community"
[conftest]: <https://github.com/open-policy-agent/conftest> "Conftest"
[consul-api-gateway]: <https://www.consul.io/docs/api-gateway> "Consul API Gateway"
[consul-service-mesh]: <https://developer.hashicorp.com/consul/docs/connect> "Consul Service Mesh"
[consul-tutorials]: <https://developer.hashicorp.com/consul/tutorials> "Consul tutorials"
[consul-vault]: <https://developer.hashicorp.com/consul/docs/k8s/deployment-configurations/vault> "Vault as the Secrets Backend for Consul"
[consul]: <https://www.consul.io/> "Consul"
[drone]: <https://www.drone.io/> "Drone"
[envoy-proxy]: <https://www.envoyproxy.io/docs/envoy/latest/intro/what_is_envoy> "Envoy proxy"
[erpnext]: <https://erpnext.com/> "ERPNext"
[excalidraw]: <https://github.com/excalidraw/excalidraw> "Excalidraw"
[external-dns-rfc2136]: <https://github.com/kubernetes-sigs/external-dns/blob/v0.14.0/docs/tutorials/traefik-proxy.md> "ExternalDNS with RFC 2136"
[external-dns-traefik]: <https://github.com/kubernetes-sigs/external-dns/blob/v0.14.0/docs/tutorials/traefik-proxy.md> "ExternalDNS with Traefik"
[external-dns]: <https://github.com/kubernetes-sigs/external-dns> "ExternalDNS"
[falco]: <https://falco.org/> "Falco"
[fleet]: <https://github.com/fleetdm/fleet> "Fleet"
[forgejo-compare-to-gitea]: <https://forgejo.org/compare-to-gitea/> "Forgejo Comparison with Gitea"
[forgejo-container-registry]: <https://forgejo.org/docs/latest/user/packages/container/> "Forgejo Container Registry"
[forgejo]: <https://forgejo.org/> "Forgejo"
[fossa-github-badge-pr]: <https://docs.fossa.com/docs/quick-import#getting-a-badge-pull-request-githubcom-only> "FOSSA on GitHub.com - Getting a Badge Pull Request"
[fossa-yml]: <https://github.com/fossas/fossa-cli/blob/master/docs/references/files/fossa-yml.md> "FOSSA yaml configuration"
[fossa]: <https://fossa.com/> "Free Open Source Software Analysis"
[gitea]: <https://gitea.io/> "Gitea"
[gitness]: <https://gitness.com/> "Gitness"
[google-cloud-internal-tld]: <https://cloud.google.com/compute/docs/internal-dns> "Google Cloud internal tld"
[grafana-agent-flow]: <https://grafana.com/docs/agent/next/flow/> "Grafana Agent Flow"
[grafana-alloy]: <https://grafana.com/docs/alloy> "Grafana Alloy"
[grafana-k6]: <https://github.com/grafana/k6> "Grafana k6"
[grafana-loki-auth]: <https://grafana.com/docs/loki/latest/operations/authentication/?pg=blog&plcmt=body-txt> "Grafana Loki authentication"
[grafana-loki]: <https://grafana.com/oss/loki/> "Grafana Loki"
[grafana-oncall]: <https://grafana.com/oss/oncall/> "Grafana OnCall"
[grafana-tempo]: <https://github.com/grafana/tempo> "Grafana Tempo"
[grafana]: <https://grafana.com/> "Grafana"
[harbor]: <https://goharbor.io/> "Harbor"
[jsonnet]: <https://jsonnet.org> "Jsonnet"
[k3s-custom-ca]: <https://raw.githubusercontent.com/k3s-io/k3s/master/contrib/util/generate-custom-ca-certs.sh> "k3s custom CA certs"
[k3s-server-doc]: <https://docs.k3s.io/cli/server> "k3s server documentation"
[keycloak]: <https://www.keycloak.org/> "Keycloak"
[kubernetes-managing-tls]: <https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/> "Kubernetes Manage TLS Certificates in a Cluster"
[kubernetes-multi-tenancy]: <https://kubernetes.io/docs/concepts/security/multi-tenancy/> "Kubernetes multi-tenancy"
[kubernetes-pki-best-practices]: <https://kubernetes.io/docs/setup/best-practices/certificates/> "kubernetes PKI best practices"
[kustomize]: <https://kustomize.io/> "Kustomize"
[kyverno]: <https://kyverno.io/> "Kyverno"
[magtape]: <https://github.com/tmobile/magtape> "MagTape"
[mailhog]: <https://github.com/mailhog/MailHog> "MailHog"
[mailpit]: <https://github.com/axllent/mailpit> "Mailpit"
[mattermost]: <https://mattermost.com/> "Mattermost"
[metallb]: <https://github.com/metallb/metallb> "MetalLB"
[microsoft-remote-desktop]: <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/remote-desktop-clients> "Microsoft Remote Desktop"
[microsoft-windows-app]: <https://learn.microsoft.com/windows-app> "Windows App"
[midpoint]: <https://evolveum.com/midpoint/> "midPoint"
[minio]: <https://min.io/> "MinIO"
[mkcert]: <https://github.com/FiloSottile/mkcert> "mkcert"
[mozilla-firefox]: <https://www.mozilla.org/en/firefox/new/> "Mozilla Firefox for Desktop"
[mozilla-firefox-cli-profile]: <https://wiki.mozilla.org/Firefox/CommandLineOptions#User_profile> "Mozilla Firefox CLI - User profile"
[mozilla-firefox-policy-templates]: <https://mozilla.github.io/policy-templates/> "Mozilla Firefox policy-templates"
[mozilla-firefox-policy-templates-bookmarks]: <https://mozilla.github.io/policy-templates/#managedbookmarks> "Mozilla Firefox policy-templates - ManagedBookmarks"
[mozilla-firefox-policy-templates-install-certs]: <https://mozilla.github.io/policy-templates/#certificates--install> "Mozilla Firefox policy-templates - Certificates | Install"
[mozilla-firefox-user-js]: <https://kb.mozillazine.org/User.js_file> "Mozilla Firefox - user.js"
[multipass]: <https://multipass.run/> "Canonical Multipass"
[notary]: <https://github.com/notaryproject/notary> "Notary"
[opa]: <https://www.openpolicyagent.org/> "Open Policy Agent (OPA)"
[opal]: <https://github.com/permitio/opal> "Open Policy Administration Layer (OPAL)"
[open-scap]: <https://www.open-scap.org/> "OpenSCAP: NIST Certified SCAP 1.2 toolkit"
[open-vswitch]: https://www.openvswitch.org/ "Open vSwitch"
[oscal]: <https://pages.nist.gov/OSCAL/> "OSCAL"
[pacbot]: <https://github.com/tmobile/pacbot> "PacBot"
[plantuml-server]: <https://github.com/plantuml/plantuml-server> "plantuml-server"
[policy-reporter-loki]: <https://kyverno.github.io/policy-reporter/core/targets/#grafana-loki> "Policy Reporter - Loki"
[pre-commit]: <https://pre-commit.com> "pre-commit hooks"
[prometheus]: <https://grafana.com/oss/prometheus/> "Prometheus"
[promtail]: <https://grafana.com/docs/loki/latest/clients/promtail/> "Promtail"
[renovate]: <https://github.com/renovatebot/renovate> "Renovate"
[restic]: <https://restic.net/> "Restic"
[scap]: <http://scap.nist.gov/> "Security Content Automation Protocol"
[sock5-catonmat-example]: <https://catonmat.net/linux-socks5-proxy> "SOCK5 proxy server on Linux using SSH"
[sock5-rfc1928]: <https://datatracker.ietf.org/doc/html/rfc1928> "SOCKS Protocol Version 5 - RFC 1928"
[terrakube]: <https://github.com/AzBuilder/terrakube> "Terrakube: Open source IaC Automation and Collaboration Software"
[tfsec]: <https://github.com/liamg/tfsec> "tfsec"
[trestle]: <https://github.com/IBM/compliance-trestle> "Trestle"
[trivy-policy-reporter]: <https://aquasecurity.github.io/trivy-operator/latest/tutorials/integrations/policy-reporter/> "Trivy Policy Reporter Integration"
[trivy]: <https://github.com/aquasecurity/trivy> "Trivy"
[vault-external-ca]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine-external-ca> "Vault external CA"
[vault-kubernetes-use-case]: <https://www.vaultproject.io/use-cases/kubernetes> "Kubernetes Secrets in Vault"
[vault-pki-engine]: <https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine> "Vault PKI engine"
[vault-pki]: <https://www.vaultproject.io/docs/secrets/pki> "Vault PKI"
[vault]: <https://www.vaultproject.io/> "HashiCorp Vault"
[velero]: <https://velero.io/> "Velero"
[virtualbox]: <https://www.virtualbox.org/> "VirtualBox"
[waypoint]: <https://www.waypointproject.io/> "Waypoint"
[wazuh]: <https://wazuh.com/> "Wazuh"
[woodpecker-ci]: <https://woodpecker-ci.org/> "Woodpecker CI"
