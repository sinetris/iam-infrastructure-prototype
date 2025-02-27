#!/usr/bin/env bash
set -Eeuo pipefail

_this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

. "${_this_file_path}/configuration.sh"

# == Generate MAC Address - Locally Administered Address (LAA) ==
# Format:
#   - IEEE 802c standard
#   - six octects (one octect is represented by two hexadecimal digits)
#   - YANG type: mac-address from RFC-699 (lowercase and separated by colon `:`)
#   - unicast Administratively Assigned Identifier (AAI) local identifier type
#     from Structured Local Address Plan (SLAP) (second hex digit is `2`)
# Input: "X2:XX" in variable `mac_address_prefix` (default "02:12")
# Output: "X2:XX:XX:XX:XX:XX"
# Return: 0 on success - 1 on invalid mac_address_prefix - 2 on invalid generated MAC address
# Note for Input and Output: `X` is a lowercase hexadecimal digit
function generate_mac_address {
	: ${mac_address_prefix:="02:12"}
	if ! [[ "${mac_address_prefix}" =~ ^[0-9a-f]2:[0-9a-f]{2}$ ]]; then
		echo "Invalid MAC address prefix: '${mac_address_prefix}'" >&2
		return 1
	fi
	local _generated_mac_address=$(dd bs=1 count=4 if=/dev/random 2>/dev/null \
		| hexdump -v \
			-n 4 \
			-e '/2 "'"${mac_address_prefix}"'" 4/1 ":%02X"' \
		| awk '{print tolower($0)}')
	if [[ "${_generated_mac_address}" =~ ^[0-9a-f]2(:[0-9a-f]{2}){5}$ ]]; then
		echo "${_generated_mac_address}"
	else
		echo "Generated invalid MAC address: '${_generated_mac_address}'" >&2
		return 2
	fi
	return 0
}

echo "Checking Network '${project_network_name}'..."
_project_network_status=$(VBoxManage hostonlynet modify \
	--name ${project_network_name} --enable 2>&1) && _exit_code=0 || _exit_code=$?
if [[ $_exit_code -eq 0 ]]; then
	echo " ✅ Project Network '${project_network_name}' already exist!"
elif [[ $_exit_code -eq 1 ]] && [[ $_project_network_status =~ 'does not exist' ]]; then
	echo " ⚙️ Creating Project Network '${project_network_name}'..."
	VBoxManage hostonlynet add \
		--name ${project_network_name} \
		--netmask ${project_network_netmask:?} \
		--lower-ip ${project_network_lower_ip:?} \
		--upper-ip ${project_network_upper_ip:?} \
		--enable
else
	echo " ❌ Project Network '${project_network_name}' - exit code '${_exit_code}'" >&2
	echo ${_project_network_status} >&2
	exit 2
fi

echo "Creating instances"
echo "Checking '${instance_name:?}'..."
_instance_status=$(VBoxManage showvminfo "${instance_name:?}" --machinereadable 2>&1) && _exit_code=0 || _exit_code=$?
if [[ $_exit_code -eq 0 ]] && ( \
	[[ $_instance_status =~ 'VMState="started"' ]] \
	|| [[ $_instance_status =~ 'VMState="running"' ]] \
); then
	echo "✅ Instance '${instance_name:?}' found!"
elif [[ $_exit_code -eq 0 ]] && [[ $_instance_status =~ 'VMState="poweroff"' ]]; then
	echo "⚠️ Skipping instance '${instance_name:?}' - Already exist but in state 'poweroff'!"
elif [[ $_exit_code -eq 0 ]]; then
	echo "❌ Instance '${instance_name:?}' already exist but in UNMANAGED state!" >&2
	echo ${_instance_status} >&2
	exit 1
elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
	echo "⚙️ Creating Instance '${instance_name:?}' ..."
	vbox_os_mapping_file="${_this_file_path}/../assets/vbox_os_mapping.json"
	vbox_instance_ostype=$(jq -L "${_this_file_path}/../lib/jq/modules" \
		--arg architecture "${vbox_architecture:?}" \
		--arg os_release "${os_release_codename:?}" \
		--arg select_field "os_type" \
		--raw-output \
		--from-file "${_this_file_path}/../lib/jq/filrters/get_vbox_mapping_value.jq" \
		"${vbox_os_mapping_file:?}" 2>&1) && _exit_code=0 || _exit_code=$?

	if [[ $_exit_code -ne 0 ]]; then
		echo " ❌ Could not get 'os_type'"
		echo "${vbox_instance_ostype}"
		exit 2
	fi

	os_release_file=$(jq -L "${_this_file_path}/../lib/jq/modules" \
		--arg architecture "${vbox_architecture:?}" \
		--arg os_release "${os_release_codename:?}" \
		--arg select_field "os_release_file" \
		--raw-output \
		--from-file "${_this_file_path}/../lib/jq/filrters/get_vbox_mapping_value.jq" \
		"${vbox_os_mapping_file:?}" 2>&1) && _exit_code=0 || _exit_code=$?

	if [[ $_exit_code -ne 0 ]]; then
		echo " ❌ Could not get 'os_release_file'"
		echo "${os_release_file}"
		exit 2
	fi

	os_image_url="${os_images_url:?}/${os_release_codename:?}/current/${os_release_file:?}"

	os_image_path="${os_images_path}/${os_release_file:?}"
	echo " - Create Project data folder (and required subfolders): '${project_basefolder:?}'"
	mkdir -p "${instance_basefolder:?}"/{cidata,disks,shared,tmp,assets}
	if [ -f "${os_image_path:?}" ]; then
		echo "✅ Using existing '${os_release_file:?}' from '${os_image_path:?}'!"
	else
		echo " ⚙️ Downloading '${os_release_file:?}' from '${os_image_url:?}'..."
		mkdir -pv "${os_images_path:?}"
		curl --output "${os_image_path:?}" "${os_image_url:?}"
	fi
	echo "${instance_password:?}" > "${instance_password_file:?}"
	openssl passwd -6 -salt $(openssl rand -base64 8) "${instance_password}" > "${instance_password_hash_file:?}"
	_instance_password_hash=$(cat "${instance_password_hash_file:?}")
	_instance_public_key=$(cat "${host_public_key_file:?}")
	echo " - Create cloud-init configuration"
	# MAC Addresses in cloud-init network config (six octects, lowercase, separated by colon)
	_instance_mac_address_nat_cloud_init=$(generate_mac_address)
	_instance_mac_address_lab_cloud_init=$(generate_mac_address)
	# MAC Addresses in VirtualBox configuration (six octects, uppercase, no separators)
	_instance_mac_address_nat=$(awk -v mac_address="${_instance_mac_address_nat_cloud_init}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	_instance_mac_address_lab=$(awk -v mac_address="${_instance_mac_address_lab_cloud_init}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }')
	echo "   - Create cloud-init 'network-config'"
	_domain="${project_domain}" \
	_mac_address_nat_cloud_init="${_instance_mac_address_nat_cloud_init}" \
	_mac_address_lab_cloud_init="${_instance_mac_address_lab_cloud_init}" \
	envsubst '$_domain,$_mac_address_nat_cloud_init,$_mac_address_lab_cloud_init' \
		<"cloud-init-user-network-config.yaml.tpl" | tee "${instance_cidata_files_path:?}/network-config" >/dev/null
	echo "   - Create cloud-init 'meta-data'"
	tee "${instance_cidata_files_path:?}/meta-data" > /dev/null <<-EOT
	instance-id: i-${instance_name:?}
	local-hostname: ${instance_name:?}
	EOT
	echo "   - Create cloud-init 'user-data'"
	_domain="${project_domain}" \
	_hostname="${instance_name}" \
	_username=${instance_username} \
	_password_hash=${_instance_password_hash} \
	_public_key=${_instance_public_key} \
	_additions_file=${vbox_additions_installer_file} \
	envsubst '$_domain,$_hostname,$_username,$_password_hash,$_public_key,$_additions_file' \
		<"cloud-init-user-data.yaml.tpl" | tee "${instance_cidata_files_path:?}/user-data" >/dev/null
	echo " - Create VirtualMachine"
	VBoxManage createvm \
		--name "${instance_name:?}" \
		--platform-architecture ${vbox_architecture:?} \
		--basefolder "${vbox_basefolder:?}" \
		--ostype ${vbox_instance_ostype:?} \
		--register
	echo " - Set Screen scale to 200%"
	VBoxManage setextradata \
		"${instance_name:?}" \
		'GUI/ScaleFactor' 2
	echo " - Configure network for instance"
	VBoxManage modifyvm \
		"${instance_name:?}" \
		--groups "/${project_name:?}" \
		--nic1 nat \
		--mac-address1=${_instance_mac_address_nat} \
		--nic-type1 82540EM \
		--cable-connected1 on \
		--nic2 hostonlynet \
		--host-only-net2 ${project_network_name} \
		--mac-address2=${_instance_mac_address_lab} \
		--nic-type2 82540EM \
		--cable-connected2 on \
		--nic-promisc2 allow-all
	echo " - Create storage controllers"
	_scsi_controller_name="SCSI Controller"
	VBoxManage storagectl \
		"${instance_name:?}" \
		--name "${_scsi_controller_name:?}" \
		--add virtio \
		--controller VirtIO \
		--bootable on
	echo " - Configure the instance"
	VBoxManage modifyvm \
		"${instance_name:?}" \
		--cpus "${instance_cpus:?}" \
		--memory "${instance_memory:?}" \
		--vram "${instance_vram:?}" \
		--graphicscontroller vmsvga \
		--audio-driver none \
		--ioapic on \
		--usbohci on \
		--cpu-profile host
	echo " - Create instance main disk cloning ${os_release_file:?}"
	VBoxManage clonemedium disk \
		"${os_images_path}/${os_release_file:?}" \
		"${vbox_instance_disk_file:?}" \
		--format VDI \
		--variant Standard
	echo " - Resize instance main disk to '${instance_storage_space:?} MB'"
	VBoxManage modifymedium disk \
		"${vbox_instance_disk_file:?}" \
		--resize ${instance_storage_space:?}
	echo " - Attach main disk to instance"
	VBoxManage storageattach \
		"${instance_name:?}" \
		--storagectl "${_scsi_controller_name:?}" \
		--port 0 \
		--device 0 \
		--type hdd \
		--medium "${vbox_instance_disk_file:?}"
	echo " - Create cloud-init iso (set label as CIDATA)"
	hdiutil makehybrid \
		-o "${instance_cidata_iso_file:?}" \
		-default-volume-name CIDATA \
		-hfs \
		-iso \
		-joliet \
		"${instance_cidata_files_path:?}"
	echo " - Attach cloud-init iso to instance"
	VBoxManage storageattach \
		"${instance_name:?}" \
		--storagectl "${_scsi_controller_name:?}" \
		--port 1 \
		--device 0 \
		--type dvddrive \
		--medium "${instance_cidata_iso_file:?}" \
		--comment "cloud-init data for ${instance_name:?}"
	echo " - Attach Guest Addition iso installer to instance"
	# (Note: need to attach 'emptydrive' before 'additions' becuse VBOX is full of bugs)
	VBoxManage storageattach  \
		"${instance_name:?}" \
		--storagectl "${_scsi_controller_name:?}" \
		--port 2 \
		--device 0 \
		--type dvddrive \
		--medium emptydrive
	VBoxManage storageattach  \
		"${instance_name:?}" \
		--storagectl "${_scsi_controller_name:?}" \
		--port 2 \
		--device 0 \
		--type dvddrive \
		--medium additions
	echo " - Configure the VM boot order"
	VBoxManage modifyvm \
		"${instance_name:?}" \
		--boot1 disk \
		--boot2 dvd
	if [ "${vbox_instance_uart_mode}" == "file" ]; then
		_uart_file="${instance_basefolder:?}/tmp/tty0.log"
		echo " - Set Serial Port to log boot sequence"
		touch "${_uart_file:?}"
		echo "   - To see log file:"
		echo "    tail -f -n +1 '${_uart_file:?}'"
		echo
		VBoxManage modifyvm \
		"${instance_name:?}" \
			--uart1 0x3F8 4 \
			--uartmode1 "${vbox_instance_uart_mode}" \
			"${_uart_file:?}"
	else
		echo " - Ignore Serial Port settings"
	fi
	VBoxManage sharedfolder add \
		"${instance_name:?}" \
		--name "${instance_name:?}--var-local-data" \
		--hostpath "${_this_file_path}/shared" \
		--auto-mount-point="/var/local/data" \
		--automount
	echo " - Starting instance '${instance_name:?}' in mode '${vbox_instance_start_type:?}'"
	VBoxManage startvm "${instance_name:?}" --type "${vbox_instance_start_type:?}"

	_ipv4_regex='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
	# Note: GuestInfo Net properies start from 0 while 'modifyvm --nicN' start from 1.
	#       So '--nic2' is 'Net/1'.
	_vbox_lab_nic_id=1
	_vbox_lab_ipv4_property="/VirtualBox/GuestInfo/Net/${_vbox_lab_nic_id:?}/V4/IP"

	echo "Wait for instance IPv4 or error on timeout after ${instance_check_timeout_seconds} seconds..."

	_start_time=$SECONDS
	_instance_ipv4=""
	_command_success=false
	until $_command_success; do
		if (( SECONDS > _start_time + instance_check_timeout_seconds )); then
			echo "⚠️ VirtualBox instance network check timeout!"  >&2
			exit 1
		fi
		_cmd_status=$(VBoxManage guestproperty get "${instance_name:?}" "${_vbox_lab_ipv4_property:?}" 2>&1) && _exit_code=0 || _exit_code=$?
		if [[ $_exit_code -ne 0 ]]; then
			echo "Error in VBoxManage for 'guestproperty get'!"  >&2
			exit 2
		fi
		_cmd_status=$(echo "${_cmd_status}" | grep --extended-regexp "${_ipv4_regex}" --only-matching --color=never 2>&1) && _exit_code=0 || _exit_code=$?
		if [[ $_exit_code -eq 0 ]]; then
			_command_success=true
			_instance_ipv4="${_cmd_status}"
		else
			(( seconds_to_timeout = instance_check_timeout_seconds - SECONDS))
			echo "💤 Not ready yet!"
			echo " - retry in: ${instance_check_sleep_time_seconds} seconds"
			echo " - passed time: $SECONDS seconds"
			echo " - will timeout in: ${seconds_to_timeout} seconds"
			sleep ${instance_check_sleep_time_seconds}
		fi
	done

	echo "Instance IPv4: ${_instance_ipv4:?}"

	echo "Wait for cloud-init to complete..."

	_instance_command='sudo cloud-init status --wait --long'
	_instance_check_ssh_success=false
	for retry_counter in $(seq $instance_check_ssh_retries 1); do
		ssh \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-o IdentitiesOnly=yes \
			-t ${instance_username:?}@${_instance_ipv4:?} \
			"${_instance_command:?}" && _exit_code=0 || _exit_code=$?
		if [[ $_exit_code -eq 0 ]]; then
			echo "✅ SSH command ran successfully!"
			_instance_check_ssh_success=true
			break
		else
			echo "💤 Will retry command in ${instance_check_sleep_time_seconds} seconds. Retry left: ${retry_counter}"
			sleep ${instance_check_sleep_time_seconds}
		fi
	done
	if ${_instance_check_ssh_success}; then
		echo "✅ Instance is ready!"
	else
		echo "⚠️ Instance not ready. - Skipping mount!"
	fi
else
	echo "❌ Instance '${instance_name:?}' - exit code '${_exit_code}'"
	echo ${_instance_status}
	exit 2
fi
