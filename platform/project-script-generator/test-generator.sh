#!/usr/bin/env bash
set -Eeuo pipefail

echo "Testing script generator..."

project_name=demo
project_source_path="$(cd ../../ && pwd)"
project_generator_path="$(pwd)"
host_architecture=$(uname -m)
generator_orchestrator=multipass

project_basefolder=$(mktemp -q -d -p "${TMPDIR:-/tmp}" "${project_name:?}.XXXXXX") && _exit_code=0 || _exit_code=$?
if [ $_exit_code -ne 0 ]; then
  echo "Can't create temp directory for '${project_name:?}', exiting..." >&2
  exit 1
fi
trap 'echo "Removing generated files..." && rm -rf -- "${project_basefolder:?}"' EXIT

echo "Generating scripts in '${project_basefolder?}'..."

project_generator_config_path="${project_generator_path:?}/test"
generated_project_path="${project_basefolder:?}/generated-scripts"
projects_folder="${project_basefolder:?}/instances-config"

jsonnet --string \
  --max-trace 1 \
  --create-output-dirs \
  --multi "${generated_project_path:?}" \
  --ext-str project_name="${project_name}" \
  --ext-str project_basefolder="${project_basefolder}" \
  --ext-str project_source_path="${project_source_path}" \
  --ext-str orchestrator_name="${generator_orchestrator}" \
  --ext-str host_architecture="${host_architecture}" \
  --jpath "${project_generator_path}" \
  --jpath "${project_generator_config_path}" \
  "${project_generator_path}/project-files-generator.jsonnet"
