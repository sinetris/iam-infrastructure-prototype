local config = import 'config.libsonnet';
assert std.isObject(config);

local admin_user =
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
    [if std.objectHas(config, 'admin_passwd') then 'passwd']: config.admin_passwd,
    [if std.objectHas(config, 'admin_plain_text_passwd') then 'plain_text_passwd']: config.admin_plain_text_passwd,
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
  } + instance;

// Exported
{
  local setup = self,
  project_name: config.project_name,
  project_domain: config.project_domain,
  host_architecture: std.extVar('host_architecture'),
  orchestrator_name: std.extVar('orchestrator_name'),
  project_root_path: std.extVar('project_root_path'),
  project_generator_path: self.project_root_path + '/platform/project-script-generator',
  projects_folder: '$HOME/.local/projects',
  project_basefolder: self.projects_folder + '/' + self.project_name,
  os_release_codename: 'noble',
  ansible_inventory_path:
    if std.objectHas(config, 'ansible_inventory_path') then
      config.ansible_inventory_path
    else '.',
  virtual_machines: [
    add_default_machine_data(setup, {
      hostname: 'ansible-controller',
      memory: '2048',
      mounts+: [
        {
          host_path: '${project_root_path:?}/' + config.ansible_files_path,
          guest_path: '/ansible',
        },
        {
          host_path: '${project_root_path:?}/' + config.kubernetes_files_path,
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
              source $HOME/.profile
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
          source $HOME/.profile
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
          source $HOME/.profile
          ansible-playbook playbooks/all-setup
        |||,
    },
  ],
  network: config.network,
  dns_servers: config.dns_servers,
}
