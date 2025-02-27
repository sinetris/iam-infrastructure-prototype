#!/usr/bin/env bash
set -Eeuo pipefail

this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. "${this_file_path}/configuration.sh"

_ipv4_regex='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
# Note: GuestInfo Net properies start from 0 while 'modifyvm --nicN' start from 1.
#       So '--nic2' is 'Net/1'.
_vbox_lan_nic=1
_vbox_lan_ipv4_property="/VirtualBox/GuestInfo/Net/${_vbox_lan_nic:?}/V4/IP"

echo "Wait for instance IPv4 or error on timeout..."
_start_time=$SECONDS
_instance_ipv4=""
_command_success=false
instance_check_debug=true
until $_command_success; do
	$instance_check_debug && echo "timeout_seconds=${instance_check_timeout_seconds}"
	$instance_check_debug && echo "seconds=$SECONDS"
	if (( SECONDS > _start_time + instance_check_timeout_seconds )); then
		echo "VirtualBox instance network check timeout!"  >&2
		exit 1
	fi
	_cmd_status=$(VBoxManage guestproperty get "${instance_name:?}" "${_vbox_lan_ipv4_property:?}" 2>&1) && _exit_code=0 || _exit_code=$?
	if [[ $_exit_code -ne 0 ]]; then
		echo "Error in VBoxManage for 'guestproperty get'!"  >&2
		exit 2
	fi
	_cmd_status=$(echo "${_cmd_status}" | grep --extended-regexp "${_ipv4_regex}" --only-matching --color=never 2>&1) && _exit_code=0 || _exit_code=$?
	if [[ $_exit_code -eq 0 ]]; then
		_command_success=true
		_instance_ipv4="${_cmd_status}"
	else
		sleep ${instance_check_sleep_time_seconds}
	fi
done

echo "Instance IPv4: ${_instance_ipv4:?}"
echo "VirtualBoz guest additions should be installed now."

_instance_command=whoami
echo "Run '${_instance_command}' command on instance..."
_instance_status=$(VBoxManage guestcontrol \
	${instance_name:?} run \
	--username ${instance_username:?} \
	--passwordfile ${instance_password_file:?} \
	--exe "/bin/bash" \
	--wait-stdout --wait-stderr \
	-- -c "${_instance_command}" 2>&1) && _exit_code=0 || _exit_code=$?

if [[ $_exit_code -eq 0 ]]; then
	echo " ✅ Command '${_instance_command}' run on instance '${instance_name}' shows: '${_instance_status}'!"
elif [[ $_exit_code -eq 1 ]] && [[ "${_instance_status}" =~ 'Guest Additions are not installed' ]]; then
	echo " ⚠️ Guest Additions are not installed or not ready (yet)."
	echo "  Try in few minutes!"
	exit 2
else
	echo " ❌ Error with exit code '${_exit_code}'"
	echo ${_instance_status}
	exit 1
fi

_instance_command='sudo cloud-init status --wait --long'
ssh \
	-o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	-o IdentitiesOnly=yes \
	-t ${instance_username:?}@${_instance_ipv4:?} \
	"${_instance_command:?}"
