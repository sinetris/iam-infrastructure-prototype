local config = import 'config.libsonnet';
assert std.isObject(config);

local admin_user =
  assert std.objectHas(config, 'admin_username') : 'Missing admin_username in config.libsonnet';
  local use_ssh_authorized_keys =
    std.objectHas(config, 'admin_ssh_authorized_keys')
    && std.isArray(config.admin_ssh_authorized_keys)
    && std.length(config.admin_ssh_authorized_keys) > 0;
  local use_ssh_import_id =
    std.objectHas(config, 'admin_ssh_import_id')
    && std.isArray(config.admin_ssh_import_id)
    && std.length(config.admin_ssh_import_id) > 0;
  {
    username: config.admin_username,
    is_admin: true,
    [if std.objectHas(config, 'admin_passwd_hash') then 'hashed_passwd']: config.admin_passwd_hash,
    [if std.objectHas(config, 'admin_passwd_plain') then 'plain_text_passwd']: config.admin_passwd_plain,
    [if use_ssh_authorized_keys then 'ssh_authorized_keys']:
      config.admin_ssh_authorized_keys,
    [if use_ssh_import_id then 'ssh_import_id']:
      config.admin_ssh_import_id,
  };
local ansible_user =
  local use_ssh_authorized_keys =
    std.objectHas(config, 'ansible_ssh_authorized_keys')
    && std.isArray(config.ansible_ssh_authorized_keys)
    && std.length(config.ansible_ssh_authorized_keys) > 0;
  {
    username: 'ansible',
    is_admin: true,
    [if use_ssh_authorized_keys then 'ssh_authorized_keys']:
      config.ansible_ssh_authorized_keys,
  };

local add_default_machine_data(setup, instance) =
  assert std.isObject(setup);
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  {
    basefolder: setup.project_basefolder + '/instances/' + instance.hostname,
    cpus: 1,
    architecture: setup.host_architecture,
    memory: '1024',
    timeout: 15 * 60,
    storage_space: '10240',
    admin_username: config.admin_username,
    [if std.objectHas(config, 'admin_passwd_plain') then 'admin_passwd_plain']: config.admin_passwd_plain,
    users: [admin_user],
    mounts: [
      {
        host_path: $.basefolder + '/shared',
        guest_path: '/var/local/data',
      },
    ],
    provisionings: [
      {
        type: 'inline-shell',
        script:
          |||
            set -Eeuo pipefail
            cloud-init status --wait --long
          |||,
      },
    ],
    network: std.get(config, 'network', {}),
  } + instance;

local get_config_value(config, key) =
  assert std.objectHas(config, key) : 'Missing %s in config.libsonnet' % key;
  local value = std.trim(std.get(config, key));
  if std.isEmpty(value) then
    error 'Empty %s.' % key
  else
    value;

// Exported
{
  local setup = self,
  project_name: get_config_value(config, 'project_name'),
  project_domain: get_config_value(config, 'project_domain'),
  host_architecture: get_config_value(config, 'host_architecture'),
  orchestrator_name: get_config_value(config, 'orchestrator_name'),
  project_source_path: get_config_value(config, 'project_source_path'),
  project_basefolder: get_config_value(config, 'project_basefolder'),
  project_generator_path: self.project_source_path + '/platform/project-script-generator',
  os_distro: 'ubuntu',
  os_release_codename: 'noble',
  ansible_inventory_path: get_config_value(config, 'ansible_inventory_path'),
  virtual_machines: [
    add_default_machine_data(setup, {
      local ansible_files_path = get_config_value(config, 'ansible_files_path'),
      local kubernetes_files_path = get_config_value(config, 'kubernetes_files_path'),
      hostname: 'ansible-controller',
      memory: '2048',
      mounts+: [
        {
          host_path: '${project_source_path:?}/' + ansible_files_path,
          guest_path: '/ansible',
        },
        {
          host_path: '${project_source_path:?}/' + kubernetes_files_path,
          guest_path: '/kubernetes',
        },
      ],
      tags: [
        'ansible-controller',
      ],
      base_provisionings: [
        {
          type: 'file',
          source_host: 'localhost',
          source: './assets/.ssh/id_ed25519.pub',
          destination: '/home/ubuntu/.ssh/id_ed25519.pub',
          destination_owner: 'ubuntu',
          create_parents_dir: true,
        },
        {
          type: 'file',
          source_host: 'localhost',
          source: './assets/.ssh/id_ed25519',
          destination: '/home/ubuntu/.ssh/id_ed25519',
          destination_owner: 'ubuntu',
          create_parents_dir: true,
        },
        {
          type: 'inline-shell',
          script:
            |||
              set -Eeuo pipefail
              sudo chown ubuntu /home/ubuntu/.ssh
              sudo chmod u=rw,go= /home/ubuntu/.ssh/id_ed25519
              sudo chmod u=rw,go= /home/ubuntu/.ssh/id_ed25519.pub
              sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y ansible
            |||,
        },
        {
          type: 'inline-shell',
          working_directory: '/ansible',
          script:
            |||
              set -Eeuo pipefail
              source "${HOME}/.profile"
              echo '# Generated file' > inventory/machines_ips
              cat inventory/machines_config.json \
                | jq '.list | {all: {hosts: with_entries({key: .key, value: .value | with_entries(.key |= if . == "ipv4" then "ansible_host" else . end) })}}' \
                | yq -P >> inventory/machines_ips
              echo '# Generated file' > inventory/group_vars/all/10-hosts
              cat inventory/machines_config.json \
                | jq '.list | {named_hosts: .}' \
                | yq -P >> inventory/group_vars/all/10-hosts
              ansible 'all' -m ping
            |||,
        },
      ],
    }),
    add_default_machine_data(setup, {
      hostname: 'iam-control-plane',
      cpus: 8,
      memory: '16384',
      storage_space: '25600',
      tags: [
        'kubernetes',
        'nested-hw-virtualization',
      ],
      users+: [ansible_user],
    }),
    add_default_machine_data(setup, {
      hostname: 'linux-desktop',
      cpus: 2,
      memory: '4096',
      tags: [
        'rdpserver',
        'desktop',
      ],
      install_recommends: true,
      users+: [ansible_user],
    }),
  ],
  provisionings: [
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      working_directory: '/ansible',
      script:
        |||
          set -Eeuo pipefail
          source "${HOME}/.profile"
          ansible-playbook playbooks/bootstrap-ansible-controller
          ansible-playbook playbooks/bootstrap-bind
          ansible-playbook playbooks/basic-bootstrap
        |||,
    },
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      script:
        |||
          set -Eeuo pipefail
          [ -f /var/run/reboot-required ] && exit 1 || exit 0
        |||,
      reboot_on_error: true,
      restart_wait_mount: '/ansible',
    },
    {
      type: 'inline-shell',
      destination_host: 'ansible-controller',
      working_directory: '/ansible',
      script:
        |||
          set -Eeuo pipefail
          source "${HOME}/.profile"
          ansible-playbook playbooks/all-setup
        |||,
    },
  ],
  network: std.get(config, 'network', {}),
  dns_servers: std.get(config, 'dns_servers', []),
}
