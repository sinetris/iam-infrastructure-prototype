// Run the following command to generate files:
// project_source_path=$(cd ../../ && pwd)
// project_generator_path=$(pwd)
// generated_project_path="${project_source_path:?}/generated"
// jsonnet --string \
//   --create-output-dirs \
//   --multi "${generated_project_path:?}" \
//   --ext-str project_source_path="${project_source_path:?}" \
//   --ext-str orchestrator_name="${generator_orchestrator:?}" \
//   --ext-str host_architecture="${host_architecture:?}" \
//   --jpath "${project_source_path}" \
//   --jpath "${project_generator_path:?}" \
//   --jpath "${project_generator_path}/config" \
//   "${project_generator_path}/project-files-generator.jsonnet"
local orchestrator = import 'lib/orchestrator.libsonnet';
local project_config_base = import 'lib/project_config_base.libsonnet';
local utils = import 'lib/utils.libsonnet';
local setup = import 'setup.libsonnet';

assert utils.verify_setup(setup);

local cloud_init = import 'lib/cloud_init.libsonnet';

function() {
  local orchestrator_implementation = orchestrator.get(setup.orchestrator_name),
  assert utils.verify_orchestrator(orchestrator_implementation.use),
  'assets/cidata-network-config.yaml': importstr 'assets/cidata-network-config.yaml',
  'assets/project-config-base.json': project_config_base.json(setup),
  'assets/vbox_os_mapping.json': importstr 'assets/vbox_os_mapping.json',
  'lib/jq/filters/add_basic_instance_config.jq': importstr 'assets/jq/filters/add_basic_instance_config.jq',
  'lib/jq/filters/get_vbox_mapping_value.jq': importstr 'assets/jq/filters/get_vbox_mapping_value.jq',
  'lib/jq/filters/project_config.jq': importstr 'assets/jq/filters/project_config.jq',
  'lib/jq/modules/utils.jq': importstr 'assets/jq/modules/utils.jq',
  'lib/yq/filters/network_config.yq': importstr 'assets/yq/filters/network_config.yq',
  'lib/utils.sh': utils.bash.helpers(),
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
