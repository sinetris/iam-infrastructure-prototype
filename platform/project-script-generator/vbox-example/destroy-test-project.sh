#!/usr/bin/env bash
set -Eeuo pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. "${this_file_path}/configuration.sh"

_instance_status=$(VBoxManage showvminfo "${instance_name:?}" --machinereadable 2>&1) \
  && _exit_code=0 || _exit_code=$?
if [[ $_exit_code -eq 0 ]]; then
  echo "⚙️ Destroying instance '${instance_name:?}'!"
  if [[ $_instance_status =~ 'VMState="started"' ]] || [[ $_instance_status =~ 'VMState="running"' ]]; then
    VBoxManage controlvm "${instance_name:?}" poweroff
  fi
  VBoxManage unregistervm "${instance_name:?}" --delete-all
elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
  echo "✅ Instance '${instance_name:?}' not found!"
else
  echo "❌ Instance '${instance_name:?}' - exit code '${_exit_code}'"
  echo ${_instance_status}
  exit 2
fi

_network_status=$(VBoxManage hostonlynet modify \
  --name ${project_network_name} --disable 2>&1) && _exit_code=0 || _exit_code=$?
if [[ $_exit_code -eq 0 ]]; then
  echo "⚙️ Project Network '${project_network_name}' will be removed!"
  VBoxManage hostonlynet remove \
    --name ${project_network_name}
elif [[ $_exit_code -eq 1 ]] && [[ $_network_status =~ 'does not exist' ]]; then
  echo "✅ Project Network '${project_network_name}' does not exist!"
else
  echo "❌ Project Network '${project_network_name}' - exit code '${_exit_code}'"
  echo ${_network_status}
  exit 2
fi

VBoxManage closemedium dvd "${instance_cidata_iso_file:?}" --delete 2>/dev/null \
  || echo "✅ Disk '${instance_cidata_iso_file}' does not exist!"

if [[ -d "${project_basefolder:?}" ]]; then
  echo "⚙️ Deleting project data folder '${project_basefolder:?}'"
  rm -rfv "${project_basefolder:?}"
else
   echo "✅ Project data folder '${project_basefolder:?}' does not exist."
fi
