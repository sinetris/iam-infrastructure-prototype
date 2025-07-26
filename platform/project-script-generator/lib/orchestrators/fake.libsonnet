{
  local fake_script(setup, action) =
    |||
      #!/usr/bin/env bash

      echo "- Instances %(action)s -"
      %(instances)s
    ||| % {
      action: action,
      instances: std.join('\n', [
        'echo ' + std.escapeStringBash(instance.hostname)
        for instance in setup.virtual_machines
      ]),
    },
  project_bootstrap(setup):
    fake_script(setup, 'bootstrap'),
  project_show_configuration(setup):
    fake_script(setup, 'show configuration'),
  project_config(setup):
    fake_script(setup, 'base config file'),
  project_wrap_up(setup):
    fake_script(setup, 'wrap-up'),
  project_prepare_config(setup):
    fake_script(setup, 'prepare-config'),
  project_provisioning(setup):
    fake_script(setup, 'provisioning'),
  project_delete(setup):
    fake_script(setup, 'destroy'),
  project_snapshot_restore(setup):
    fake_script(setup, 'snapshot restore'),
  instances_status(setup):
    fake_script(setup, 'list'),
  instance_shell(setup):
    fake_script(setup, 'shell'),
  instance_info(setup):
    fake_script(setup, 'info'),
}
