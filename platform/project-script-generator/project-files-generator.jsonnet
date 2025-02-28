// Run the following command to generate files:
// project_root_path=$(cd ../../ && pwd)
// project_generator_path="${project_root_path:?}/platform/project-script-generator"
// jsonnet --create-output-dirs \
//   --multi "${project_root_path:?}/generated" \
//   --ext-str project_root_path="${project_root_path:?}" \
//   --ext-str orchestrator_name="multipass" \
//   --ext-str host_architecture="amd64" \
//   --jpath "${project_root_path:?}" \
//   --jpath "${project_generator_path}" \
//   --string "${project_generator_path}/project-files-generator.jsonnet"
local orchestrator = import 'lib/orchestrator.libsonnet';
local utils = import 'lib/utils.libsonnet';
local setup = import 'setup.libsonnet';

assert utils.verify_setup(setup);

local cloud_init = import 'lib/cloud_init.libsonnet';

function() {
  local orchestrator_implementation = orchestrator.get(setup.orchestrator_name),
  assert utils.verify_orchestrator(orchestrator_implementation.use),
  'lib/utils.sh': orchestrator_implementation.use.project_utils(setup),
  'lib/project_config.sh': orchestrator_implementation.use.project_config(setup),
  'instances-status.sh': orchestrator_implementation.use.instances_status(setup),
  'project-bootstrap.sh': orchestrator_implementation.use.project_bootstrap(setup),
  'project-wrap-up.sh': orchestrator_implementation.use.project_wrap_up(setup),
  'project-provisioning.sh': orchestrator_implementation.use.project_provisioning(setup),
  'project-restore-snapshots.sh': orchestrator_implementation.use.project_snapshot_restore(setup),
  'instance-shell.sh': orchestrator_implementation.use.instance_shell(setup),
  'project-delete.sh': orchestrator_implementation.use.project_delete(setup),
  'project-show-configuration.sh': orchestrator_implementation.use.project_show_configuration(setup),
  'project-prepare-config.sh': orchestrator_implementation.use.project_prepare_config(setup),
  'instance-info.sh': orchestrator_implementation.use.instance_info(setup),
} + {
  ['assets/' + utils.cloudinit_user_data_filename(instance.hostname)]: cloud_init.user_data(setup, instance)
  for instance in setup.virtual_machines
}
