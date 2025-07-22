local utils = import 'lib/utils.libsonnet';

local interface_config(instance, interface) =
  assert std.isObject(interface);
  assert std.objectHas(interface, 'type');
  local name =
    if std.objectHas(interface, 'name') then
      interface.name
    else if interface.type == 'nat' then
      'ethnat'
    else if interface.type == 'bridge' then
      'ethlab'
    else
      error "Invalid network interface type '%s' for instance '%s'" % [interface.type, instance.name];
  {
    name: name,
    type: interface.type,
  };

local instance_config(setup, instance) = {
  admin_username: std.get(instance, 'admin_username', 'admin'),
  architecture: std.get(instance, 'architecture', 'amd64'),
  check_sleep_time_seconds: std.get(instance, 'check_sleep_time_seconds', 5),
  check_ssh_retries: std.get(instance, 'check_ssh_retries', 30),
  cpus: std.get(instance, 'cpus', 1),
  memory: std.get(instance, 'memory', 1024),
  storage_space: std.get(instance, 'storage_space', 5000),
  timeout: std.get(instance, 'timeout', 300),
  vram: std.get(instance, 'vram', 64),
  [if std.objectHas(instance, 'network') then 'network']: {
    cidata: true,
    [if std.objectHas(instance.network, 'interfaces') then 'interfaces']:
      assert std.isArray(instance.network.interfaces);
      {
        [interface_config(instance, interface).name]: interface_config(instance, interface)
        for interface in instance.network.interfaces
      },
  },
  [if std.objectHas(instance, 'mounts') then 'mounts']:
    assert std.isArray(instance.mounts);
    instance.mounts,
};

local project_config(setup) = {
  project_name: setup.project_name,
  project_domain: setup.project_domain,
  host: {
    architecture: setup.host_architecture,
  },
  instances:
    {
      [instance.hostname]: instance_config(setup, instance)
      for instance in setup.virtual_machines
    },
};

{
  json(setup):
    std.manifestJsonEx(project_config(setup), '  '),
}
