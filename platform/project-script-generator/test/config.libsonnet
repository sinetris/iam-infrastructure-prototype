{
  project_name: std.extVar('project_name'),
  project_basefolder: std.extVar('project_basefolder'),
  project_source_path: std.extVar('project_source_path'),
  orchestrator_name: std.extVar('orchestrator_name'),
  host_architecture: std.extVar('host_architecture'),
  project_domain: self.project_name + '.test',
  ansible_ssh_authorized_keys: [],
  ansible_files_path: 'the ansible folder',
  ansible_inventory_path: self.ansible_files_path + '/inventory',
  kubernetes_files_path: 'the kubernetes folder',
  admin_username: 'admin',
  admin_passwd_hash: 'admin password hash',
  admin_passwd_plain: 'admin password',
  admin_ssh_authorized_keys: [],
  admin_ssh_import_id: [],
  network: {
    name: '%s-HON' % $.project_name,
    netmask: '255.255.255.0',
    lower_ip: '192.168.10.50',
    upper_ip: '192.168.10.100',
    interfaces: [
      {
        type: 'nat',
        name: 'ethnat',
      },
      {
        type: 'bridge',
        name: 'ethlab',
      },
    ],
  },
  dns_servers: [
    '1.1.1.1',
  ],
}
