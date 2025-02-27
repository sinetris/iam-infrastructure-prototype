local utils = import 'lib/utils.libsonnet';

// start: bash-utils
local bash_mac_address_functions() =
  |||
    ### Generate MAC Address - Locally Administered Address (LAA) ###
    # Description:
    #   - IEEE 802c standard
    #   - six octects (one octect is represented by two hexadecimal digits)
    #   - YANG type: mac-address from RFC-699 (lowercase and separated by colon `:`)
    #   - unicast Administratively Assigned Identifier (AAI) local identifier type
    #     from Structured Local Address Plan (SLAP)
    #     Essentially: second hexadecimal digit is `2`
    # Input:
    #   - first parameter
    #     description: MAC address prefix
    #     format: "X2:XX"
    #     default: "42:12"
    # Output: "X2:XX:XX:XX:XX:XX"
    # Note for Input and Output: `X` is a lowercase hexadecimal digit
    # Return:
    #   0 on success
    #   1 on invalid MAC address prefix
    #   2 on invalid generated MAC address
    function generate_mac_address {
      _mac_address_prefix=${1:-"42:12"}
      if ! [[ "${_mac_address_prefix}" =~ ^[0-9a-f]2:[0-9a-f]{2}$ ]]; then
        echo "${status_error} Invalid MAC address prefix: '${_mac_address_prefix}'" >&2
        return 1
      fi
      local _generated_mac_address=$(dd bs=1 count=4 if=/dev/random 2>/dev/null \
        | hexdump -v \
          -n 4 \
          -e '/2 "'"${_mac_address_prefix}"'" 4/1 ":%02x"')
      if [[ "${_generated_mac_address}" =~ ^[0-9a-f]2(:[0-9a-f]{2}){5}$ ]]; then
        echo "${_generated_mac_address}"
      else
        echo "${status_error} Generated invalid MAC address: '${_generated_mac_address}'" >&2
        return 2
      fi
      return 0
    }

    ### Convert MAC Address in VirtualBox format ###
    # Input:
    #   - first parameter
    #     description: MAC address
    #     format: "X2:XX:XX:XX:XX:XX"
    #     note: `X` is an hexadecimal digit (case insensitive)
    # Output:
    #   format: "X2XXXXXXXXXX"
    #   note: `X` is an uppercase hexadecimal digit
    # Return:
    #   0 on success
    #   1 on invalid MAC address input
    function convert_mac_address_to_vbox {
      _mac_address=${1:?}
      if ! [[ "${_mac_address}" =~ ^[0-9a-fA-F]2(:[0-9a-fA-F]{2}){5}$ ]]; then
        echo "${status_error} Invalid MAC address: '${_mac_address}'" >&2
        return 1
      fi
      awk -v mac_address="${_mac_address}" 'BEGIN { gsub(/:/, "", mac_address); print toupper(mac_address) }'
      return 0
    }

    ### Convert MAC Address from VirtualBox format ###
    # Input:
    #   - first parameter
    #     description: MAC address
    #     format: "X2:XX:XX:XX:XX:XX"
    #     note: `X` is an hexadecimal digit (case insensitive)
    # Output:
    #   format: "X2XXXXXXXXXX"
    #   note: `X` is an uppercase hexadecimal digit
    # Return:
    #   0 on success
    #   1 on invalid MAC address input
    function convert_mac_address_from_vbox {
      _mac_address=${1:?}
      if ! [[ "${_mac_address}" =~ ^[0-9a-fA-F]{12}$ ]]; then
        echo "${status_error} Invalid MAC address: '${_mac_address}'" >&2
        return 1
      fi
      echo "${_mac_address}" | xxd -r -p | hexdump -v -n6 -e '/1 "%02x" 5/1 ":%02x"'
      return 0
    }
  |||;

local generic_project_config(setup) =
  assert std.isObject(setup);
  assert std.objectHas(setup, 'project_name');
  assert std.objectHas(setup, 'project_domain');
  assert std.objectHas(setup, 'projects_folder');
  assert std.objectHas(setup, 'project_basefolder');
  assert std.objectHas(setup, 'project_root_path');
  assert std.objectHas(setup, 'project_generator_path');
  assert std.objectHas(setup, 'os_release_codename');
  assert std.objectHas(setup, 'host_architecture');
  |||
    # -- start: generic-project-config
    project_name=%(project_name)s
    project_domain="${project_name:?}.test"
    projects_folder=%(projects_folder)s
    project_basefolder="%(project_basefolder)s"
    project_root_path="%(project_root_path)s"
    project_generator_path="%(project_generator_path)s"
    os_release_codename=%(os_release_codename)s
    host_architecture=%(host_architecture)s
    host_public_key_file=~/.ssh/id_ed25519.pub
    cidata_network_config_template_file="${generated_files_path:?}/assets/cidata-network-config.yaml.tpl"
    instances_catalog_file="${generated_files_path:?}/assets/machines_config.json"
    # -- end: generic-project-config
  ||| % {
    project_name: setup.project_name,
    project_domain: setup.project_domain,
    projects_folder: setup.projects_folder,
    project_basefolder: setup.project_basefolder,
    project_root_path: setup.project_root_path,
    project_generator_path: setup.project_generator_path,
    os_release_codename: setup.os_release_codename,
    host_architecture: setup.host_architecture,
  };
// end: bash-utils

local cidata_network_config_template(setup) =
  assert std.isObject(setup);
  local dns_servers = std.get(setup, 'dns_servers', []);
  assert std.isArray(dns_servers);
  |||
    tee "${cidata_network_config_template_file:?}" > /dev/null <<-'EOT'
    network:
      version: 2
      ethernets:
        ethnat:
          dhcp4: true
          dhcp6: false
          dhcp-identifier: mac
          match:
            macaddress: ${_mac_address_nat}
          set-name: ethnat
          nameservers:
            addresses: [%(dns_servers)s]
        ethlab:
          dhcp4: true
          dhcp4-overrides:
            use-dns: false
            use-domains: false
            route-metric: 100
          dhcp6: false
          dhcp-identifier: mac
          match:
            macaddress: ${_mac_address_lab}
          set-name: ethlab
          nameservers:
            search:
              - '${_domain}'
            addresses: [127.0.0.53]
    EOT
  ||| % {
    dns_servers: std.join(',', dns_servers),
  };

// start: vbox-bash-variables
local vbox_bash_architecture_configs() =
  |||
    case "${host_architecture:?}" in
      arm64|aarch64)
        vbox_architecture=arm
        guest_architecture=arm64
        vbox_additions_installer_file=VBoxLinuxAdditions-arm64.run
        ;;
      amd64|x86_64)
        vbox_architecture=x86
        guest_architecture=amd64
        vbox_additions_installer_file=VBoxLinuxAdditions.run
        ;;
      *)
        echo "${status_error} Unsupported 'host_architecture' value: '${host_architecture:?}'!" >&2
        exit 1
        ;;
    esac
  |||;

local vbox_project_config(setup) =
  assert std.isObject(setup);
  assert std.objectHas(setup, 'network');
  local network = std.get(setup, 'network');
  assert std.objectHas(network, 'name');
  assert std.objectHas(network, 'netmask');
  assert std.objectHas(network, 'lower_ip');
  assert std.objectHas(network, 'upper_ip');
  |||
    # -- start: vbox-project-config
    project_network_netmask=%(network_netmask)s
    project_network_lower_ip=%(network_lower_ip)s
    project_network_upper_ip=%(network_upper_ip)s
    project_network_name=%(network_name)s
    os_images_path="$HOME/.cache/os-images"
    os_images_url=https://cloud-images.ubuntu.com
    # Serial Port mode:
    #   file = log boot sequence to file
    vbox_instance_uart_mode=file
    vbox_basefolder=~/"VirtualBox VMs"
    # Start type: gui | headless | sdl | separate
    vbox_instance_start_type=headless
    %(set_architecture_configs)s
    # -- end: vbox-project-config
  ||| % {
    network_name: setup.network.name,
    network_netmask: setup.network.netmask,
    network_lower_ip: setup.network.lower_ip,
    network_upper_ip: setup.network.upper_ip,
    set_architecture_configs: vbox_bash_architecture_configs(),
  };
// end: vbox-bash-variables

local instance_shutdown(instance_name, timeout=90, sleep=5) =
  |||
    echo "Stopping '%(instance_name)s'..."
    VBoxManage controlvm "%(instance_name)s" shutdown || echo "Ignoring"
    echo "Waiting for '%(instance_name)s' shutdown..."
    _start_time=$SECONDS
    _command_success=false
    _check_timeout_seconds=%(timeout)s
    _seconds_to_timeout=${_check_timeout_seconds}
    _sleep_time_seconds=%(sleep)s
    until $_command_success; do
      if (( _seconds_to_timeout <= 0 )); then
        echo "${status_error} Instance '%(instance_name)s' check timeout!" >&2
        exit 1
      fi
      _cmd_status=$(VBoxManage showvminfo "%(instance_name)s" --machinereadable 2>&1) \
        && _exit_code=$? || _exit_code=$?
      if [[ $_exit_code -ne 0 ]]; then
        echo "${status_error} Error checking '%(instance_name)s'" >&2
        exit 2
      elif [[ "$_cmd_status" =~ 'VMState="poweroff"' ]]; then
        echo "${status_info} Instance '%(instance_name)s' shutdown!"
        _command_success=true
      else
        echo "${status_waiting} Not ready yet! - Retry in ${_sleep_time_seconds} seconds - Timeout in ${_seconds_to_timeout} seconds"
        sleep ${_sleep_time_seconds}
      fi
      (( _seconds_to_timeout = _check_timeout_seconds - (SECONDS - _start_time)))
    done
  ||| % {
    instance_name: instance_name,
    timeout: timeout,
    sleep: sleep,
  };

local instance_wait_started(instance_name, script='whoami', timeout=90, sleep=5) =
  |||
    _instance_name_to_wait=%(instance_name)s
    echo "Starting '${_instance_name_to_wait:?}'..."
    VBoxManage startvm "${_instance_name_to_wait:?}" --type headless
    echo "Waiting for '${_instance_name_to_wait:?}' to be ready..."
    _start_time=$SECONDS
    _command_success=false
    _check_timeout_seconds=%(timeout)s
    _seconds_to_timeout=${_check_timeout_seconds}
    _sleep_time_seconds=%(sleep)s
    until $_command_success; do
      if (( _seconds_to_timeout <= 0 )); then
        echo "${status_error} Instance '${_instance_name_to_wait:?}' check timeout!" >&2
        exit 1
      fi
      _cmd_status=$(VBoxManage showvminfo "${_instance_name_to_wait:?}" --machinereadable 2>&1) \
        && _exit_code=$? || _exit_code=$?
      if [[ $_exit_code -ne 0 ]]; then
        echo "${status_error} Error checking '${_instance_name_to_wait:?}'" >&2
        exit 2
      elif [[ "$_cmd_status" =~ 'VMState="running"' ]]; then
        echo "${status_info} Instance '${_instance_name_to_wait:?}' running!"
        _command_success=true
      else
        echo "${status_waiting} Not ready yet! - Retry in ${_sleep_time_seconds} seconds - Timeout in ${_seconds_to_timeout} seconds"
        sleep ${_sleep_time_seconds}
      fi
      (( _seconds_to_timeout = _check_timeout_seconds - (SECONDS - _start_time)))
    done
    %(ssh_check_retry)s
  ||| % {
    instance_name: instance_name,
    timeout: timeout,
    sleep: sleep,
    ssh_check_retry: utils.ssh.check_retry(
      '${_instance_name_to_wait:?}',
      script,
    ),
  };

local project_config(setup) =
  |||
    # - start: config
    %(generic_project_config)s
    %(vbox_project_config)s
    echo "${status_info} ${info_text}${bold_text}Checking project '${project_name:?}'...${reset_text}"
    mkdir -pv "${os_images_path:?}"
    mkdir -pv "${project_basefolder:?}"
    # - end: config
  ||| % {
    generic_project_config: generic_project_config(setup),
    vbox_project_config: vbox_project_config(setup),
  };

local bash_utils(setup) =
  |||
    # - start: utils
    %(mac_address_functions)s
    # - end: utils
  ||| % {
    mac_address_functions: bash_mac_address_functions(),
  };


local check_instance_exist_do(setup, instance, action_code) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  |||
    instance_name=%(hostname)s
    echo " ${status_info} ${info_text}Checking '${instance_name:?}'...${reset_text}"
    _instance_status=$(VBoxManage showvminfo "${instance_name:?}" --machinereadable 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]] && ( \
      [[ $_instance_status =~ 'VMState="started"' ]] \
      || [[ $_instance_status =~ 'VMState="running"' ]] \
    ); then
      echo " ${status_ok} Instance '${instance_name:?}' found!"
    elif [[ $_exit_code -eq 0 ]] && [[ $_instance_status =~ 'VMState="poweroff"' ]]; then
      echo "${status_warning} Skipping instance '${instance_name:?}' - Already exist but in state 'poweroff'!"
    elif [[ $_exit_code -eq 0 ]]; then
      echo "${status_error} Instance '${instance_name:?}' already exist but in UNMANAGED state!" >&2
      echo ${_instance_status} >&2
      exit 1
    elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
      %(action_code)s
    else
      echo "${status_error} Instance '${instance_name:?}' - exit code '${_exit_code}'"
      echo ${_instance_status}
      exit 2
    fi
  ||| % {
    hostname: instance.hostname,
    action_code: action_code,
  };

local create_network(setup) =
  |||
    echo " ${status_info} Checking Network '${project_network_name}'..."
    _project_network_status=$(VBoxManage hostonlynet modify \
      --name ${project_network_name} --enable 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo " ${status_ok} Project Network '${project_network_name}' already exist!"
    elif [[ $_exit_code -eq 1 ]] && [[ $_project_network_status =~ 'does not exist' ]]; then
      echo " ${status_action} Creating Project Network '${project_network_name}'..."
      VBoxManage hostonlynet add \
        --name ${project_network_name} \
        --netmask ${project_network_netmask:?} \
        --lower-ip ${project_network_lower_ip:?} \
        --upper-ip ${project_network_upper_ip:?} \
        --enable
      echo " ${status_success} Project Network '${project_network_name}' created."
    else
      echo " ${status_error} Project Network '${project_network_name}' - exit code '${_exit_code}'"
      echo ${_project_network_status}
      exit 2
    fi
  |||;

local remove_network(setup) =
  |||
    _network_status=$(VBoxManage hostonlynet modify \
      --name ${project_network_name} --disable 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo "${status_action} Project Network '${project_network_name}' will be removed!"
      VBoxManage hostonlynet remove \
        --name ${project_network_name}
    elif [[ $_exit_code -eq 1 ]] && [[ $_network_status =~ 'does not exist' ]]; then
      echo "${status_ok} Project Network '${project_network_name}' does not exist!"
    else
      echo "${status_error} Project Network '${project_network_name}' - exit code '${_exit_code}'"
      echo ${_network_status}
      exit 2
    fi
  |||;

local instance_config(setup, instance) =
  assert std.isObject(setup);
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  assert std.objectHas(instance, 'basefolder');
  local instance_cpus = std.get(instance, 'cpus', '1');
  local instance_storage_space = std.get(instance, 'storage_space', '5000');
  local instence_memory = std.get(instance, 'memory', '1024');
  local instance_vram = std.get(instance, 'vram', '64');
  local instance_username = std.get(instance, 'admin_username', 'admin');
  local instance_timeout = std.get(instance, 'timeout', '300');
  local instance_check_ssh_retries = std.get(instance, 'check_ssh_retries', '30');
  local instance_check_sleep_time_seconds = std.get(instance, 'check_sleep_time_seconds', '5');
  |||
    # - Instance settings -
    instance_name=%(instance_hostname)s
    instance_username=%(instance_username)s
    # Disk size in MB
    instance_storage_space=%(instance_storage_space)s
    instance_cpus=%(instance_cpus)s
    instance_memory=%(instance_memory)s
    instance_vram=%(instance_vram)s

    instance_check_timeout_seconds=%(instance_timeout)s
    instance_check_sleep_time_seconds=%(instance_check_sleep_time_seconds)s
    instance_check_ssh_retries=%(instance_check_ssh_retries)s

    instance_basefolder="%(instance_basefolder)s"
    instance_cidata_files_path=${instance_basefolder:?}/cidata
    instance_cidata_iso_file="${instance_basefolder:?}/disks/${instance_name:?}-cidata.iso"
    vbox_instance_disk_file="${instance_basefolder:?}/disks/${instance_name:?}-boot-disk.vdi"
    instance_config=${instance_basefolder:?}/assets/instance_config.json
  ||| % {
    instance_hostname: instance.hostname,
    instance_username: instance_username,
    instance_basefolder: instance.basefolder,
    instance_cpus: instance_cpus,
    instance_storage_space: instance_storage_space,
    instance_timeout: instance_timeout,
    instance_check_sleep_time_seconds: instance_check_sleep_time_seconds,
    instance_check_ssh_retries: instance_check_ssh_retries,
    instance_memory: instence_memory,
    instance_vram: instance_vram,
  };

local create_instance(setup, instance) =
  assert std.isObject(setup);
  assert std.isObject(instance);
  local mount_opt(host_path, guest_path) =
    |||
      echo "   - name: '${instance_name:?}-%(mount_name)s'"
      echo "     host_path: '%(host_path)s'"
      echo "     guest_path: '%(guest_path)s'"
      VBoxManage sharedfolder add \
        "${instance_name:?}" \
        --name "${instance_name:?}-%(mount_name)s" \
        --hostpath "%(host_path)s" \
        --auto-mount-point="%(guest_path)s" \
        --automount
    ||| % {
      mount_name: std.strReplace(guest_path, '/', '-'),
      host_path: host_path,
      guest_path: guest_path,
    };
  local mounts =
    if std.objectHas(instance, 'mounts') then
      assert std.isArray(instance.mounts);
      [
        assert std.isObject(mount);
        assert std.objectHas(mount, 'host_path');
        assert std.objectHas(mount, 'guest_path');
        mount_opt(mount.host_path, mount.guest_path)
        for mount in instance.mounts
      ]
    else [];
  |||
    echo "${status_start_first} -------------- begin creating '${instance_name:?}' -------------- ${status_start_last}"
    echo " ${status_action} Creating Instance '${instance_name:?}' ..."
    %(instance_config)s
    vbox_os_mapping_file="${project_generator_path:?}/assets/vbox_os_mapping.json"
    vbox_instance_ostype=$(jq -L "${project_generator_path:?}/lib/jq/modules" \
      --arg architecture "${vbox_architecture:?}" \
      --arg os_release "${os_release_codename:?}" \
      --arg select_field "os_type" \
      --raw-output \
      --from-file "${project_generator_path:?}/lib/jq/filrters/get_vbox_mapping_value.jq" \
      "${vbox_os_mapping_file:?}" 2>&1) && _exit_code=$? || _exit_code=$?

    if [[ $_exit_code -ne 0 ]]; then
      echo " ${status_error} Could not get 'os_type'"
      echo "${vbox_instance_ostype}"
      exit 2
    fi

    os_release_file=$(jq -L "${project_generator_path:?}/lib/jq/modules" \
      --arg architecture "${vbox_architecture:?}" \
      --arg os_release "${os_release_codename:?}" \
      --arg select_field "os_release_file" \
      --raw-output \
      --from-file "${project_generator_path:?}/lib/jq/filrters/get_vbox_mapping_value.jq" \
      "${vbox_os_mapping_file:?}" 2>&1) && _exit_code=$? || _exit_code=$?

    if [[ $_exit_code -ne 0 ]]; then
      echo " ${status_error} Could not get 'os_release_file'"
      echo "${os_release_file}"
      exit 2
    fi

    os_image_url="${os_images_url:?}/${os_release_codename:?}/current/${os_release_file:?}"

    os_image_path="${os_images_path}/${os_release_file:?}"
    echo " ${status_info} Create Project data folder and subfolders: '${project_basefolder:?}'"
    mkdir -p "${instance_basefolder:?}"/{cidata,disks,shared,tmp,assets}
    if [ -f "${os_image_path:?}" ]; then
      echo " ${status_info} Using existing '${os_release_file:?}' from '${os_image_path:?}'!"
    else
      echo " ${status_action} Downloading '${os_release_file:?}' from '${os_image_url:?}'..."
      mkdir -pv "${os_images_path:?}"
      curl --output "${os_image_path:?}" "${os_image_url:?}"
    fi
    _instance_public_key=$(cat "${host_public_key_file:?}")
    echo " ${status_info} Create cloud-init configuration"
    # MAC Addresses in cloud-init network config (six octects, lowercase, separated by colon)
    _instance_mac_address_nat_cloud_init=$(generate_mac_address)
    _instance_mac_address_lab_cloud_init=$(generate_mac_address)
    # MAC Addresses in VirtualBox configuration (six octects, uppercase, no separators)
    _instance_mac_address_nat_vbox=$(convert_mac_address_to_vbox "${_instance_mac_address_nat_cloud_init}")
    _instance_mac_address_lab_vbox=$(convert_mac_address_to_vbox "${_instance_mac_address_lab_cloud_init}")
    echo "   - Create cloud-init 'network-config'"
    _domain="${project_domain}" \
    _mac_address_nat="${_instance_mac_address_nat_cloud_init}" \
    _mac_address_lab="${_instance_mac_address_lab_cloud_init}" \
    envsubst '$_domain,$_mac_address_nat,$_mac_address_lab' \
      <"${cidata_network_config_template_file:?}" | tee "${instance_cidata_files_path:?}/network-config" >/dev/null
    echo "   - Create cloud-init 'meta-data'"
    tee "${instance_cidata_files_path:?}/meta-data" > /dev/null <<-EOT
    instance-id: i-${instance_name:?}
    local-hostname: ${instance_name:?}
    EOT
    echo "   - Create cloud-init 'user-data'"
    # _domain="${project_domain}" \
    # _hostname="${instance_name}" \
    # _username=${instance_username} \
    # _password_hash=${_instance_password_hash} \
    # _public_key=${_instance_public_key} \
    # _additions_file=${vbox_additions_installer_file} \
    # envsubst '$_domain,$_hostname,$_username,$_password_hash,$_public_key,$_additions_file' \
    #   <"cidata-user-data.yaml.tpl" | tee "${instance_cidata_files_path:?}/user-data" >/dev/null
    cat "assets/cidata-${instance_name:?}-user-data.yaml" > "${instance_cidata_files_path:?}/user-data"
    echo " - Create VirtualMachine"
    VBoxManage createvm \
      --name "${instance_name:?}" \
      --platform-architecture ${vbox_architecture:?} \
      --basefolder "${vbox_basefolder:?}" \
      --ostype ${vbox_instance_ostype:?} \
      --register
    echo " - Set Screen scale to 200%%"
    VBoxManage setextradata \
      "${instance_name:?}" \
      'GUI/ScaleFactor' 2
    echo " - Configure network for instance"
    VBoxManage modifyvm \
      "${instance_name:?}" \
      --groups "/${project_name:?}" \
      --nic1 nat \
      --mac-address1=${_instance_mac_address_nat_vbox} \
      --nic-type1 82540EM \
      --cable-connected1 on \
      --nic2 hostonlynet \
      --host-only-net2 ${project_network_name} \
      --mac-address2=${_instance_mac_address_lab_vbox} \
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
    echo ' - Create cloud-init iso (set label as CIDATA)'
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
      echo " ${status_memo} Set Serial Port to log boot sequence"
      touch "${_uart_file:?}"
      echo "   - To see log file:"
      echo "    tail -f -n +1 '${_uart_file:?}' | cat -v"
      echo
      VBoxManage modifyvm \
      "${instance_name:?}" \
        --uart1 0x3F8 4 \
        --uartmode1 "${vbox_instance_uart_mode}" \
        "${_uart_file:?}"
    else
      echo " - Ignore Serial Port settings"
    fi
    echo " ${status_memo} Add shared folders"
    %(mounts)s
    echo " - Starting instance '${instance_name:?}' in mode '${vbox_instance_start_type:?}'"
    VBoxManage startvm "${instance_name:?}" --type "${vbox_instance_start_type:?}"

    _ipv4_regex='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
    # Note: GuestInfo Net properies start from 0 while 'modifyvm --nicN' start from 1.
    #       So '--nic2' is 'Net/1'.
    _vbox_lab_nic_id=1
    _vbox_lab_nic_ipv4_property="/VirtualBox/GuestInfo/Net/${_vbox_lab_nic_id:?}/V4/IP"

    echo "Wait for instance IPv4 or error on timeout after ${instance_check_timeout_seconds} seconds..."

    _start_time=$SECONDS
    _instance_ipv4=""
    _command_success=false
    _seconds_to_timeout=$instance_check_timeout_seconds
    until $_command_success; do
      if (( _seconds_to_timeout <= 0 )); then
        echo "${status_warning} VirtualBox instance '${instance_name:?}' check timeout!" >&2
        exit 1
      fi
      _cmd_status=$(VBoxManage guestproperty get "${instance_name:?}" "${_vbox_lab_nic_ipv4_property:?}" 2>&1) \
        && _exit_code=$? || _exit_code=$?

      if [[ $_exit_code -ne 0 ]]; then
        echo "${status_warning} Error in VBoxManage for 'guestproperty get ${instance_name:?} ${_vbox_lab_nic_ipv4_property:?}'" >&2
        exit 2
      elif [[ "$_cmd_status" =~ 'No value set!' ]]; then
        echo "${status_waiting} Not ready yet! Retry in: ${instance_check_sleep_time_seconds}s - Timeout in: ${_seconds_to_timeout}s"
        sleep ${instance_check_sleep_time_seconds}
      else
        echo "${status_success} Instance '${instance_name:?}' network ready!"
        _command_success=true
        _instance_ipv4=$(echo "$_cmd_status" | awk '{print $2}')
      fi
      (( _seconds_to_timeout = instance_check_timeout_seconds - (SECONDS - _start_time)))
    done

    echo "Instance IPv4: ${_instance_ipv4:?}"
    instance_config=${instance_basefolder:?}/assets/instance_config.json

    _vbox_lab_nic_name_property="/VirtualBox/GuestInfo/Net/${_vbox_lab_nic_id:?}/Name"
    _instance_nic_name=$(VBoxManage guestproperty get "${instance_name:?}" "${_vbox_lab_nic_name_property:?}" | awk '{print $2}' 2>&1)

    echo "Configuring instance catalog for '${instance_name:?}'..."
    PROJECT_TMP_FILE="$(mktemp)"
    jq --indent 2 \
      --arg host "${instance_name:?}" \
      --arg ip "${_instance_ipv4:?}" \
      --arg nic "${_instance_nic_name:?}" \
      --arg macaddr "${_instance_mac_address_lab_cloud_init:?}" \
      --arg admin_username "${instance_username:?}" \
      '.list += {($host): {ipv4: $ip, mac_address: $macaddr, network_interface_name: $nic, network_interface_netplan_name: $nic, admin_username: $admin_username}}' \
      "${instances_catalog_file:?}" \
      > "$PROJECT_TMP_FILE"
    mv "$PROJECT_TMP_FILE" "${instances_catalog_file:?}"
    echo "Wait for cloud-init to complete..."

    _instance_command='sudo cloud-init status --wait --long'
    %(ssh_check_retry)s
    echo "${status_end_first} --------------  end creating '${instance_name:?}'  -------------- ${status_end_last}"
  ||| % {
    instance_config: instance_config(setup, instance),
    mounts: utils.shell_lines(mounts),
    ssh_check_retry: utils.ssh.check_retry(
      '${instance_name:?}',
      '${_instance_command:?}',
      '${instance_check_ssh_retries:?}',
      '${instance_check_sleep_time_seconds:?}',
    ),
  };

local destroy_instance(setup, instance) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  |||
    %(instance_config)s
    _instance_status=$(VBoxManage showvminfo "${instance_name:?}" --machinereadable 2>&1) \
      && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 0 ]]; then
      echo "${status_action} Destroying instance '${instance_name:?}'!"
      # Try to stop instance and ignore errors
      VBoxManage controlvm "${instance_name:?}" poweroff >/dev/null 2>&1 || true
      VBoxManage unregistervm "${instance_name:?}" --delete-all
    elif [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'Could not find a registered machine' ]]; then
      echo "${status_ok} Instance '${instance_name:?}' not found!"
    else
      echo "${status_error} Skipping instance '${instance_name:?}' - exit code '${_exit_code}'"
      echo ${_instance_status}
    fi
    VBoxManage closemedium dvd "${instance_cidata_iso_file:?}" --delete 2>/dev/null \
      || echo "${status_info} Disk '${instance_cidata_iso_file}' does not exist!"
  ||| % {
    instance_config: instance_config(setup, instance),
    hostname: instance.hostname,
  };

local snapshot_instance(setup, instance) =
  assert std.isObject(instance);
  assert std.objectHas(instance, 'hostname');
  |||
    %(instance_config)s
    _instance_snaphot_name=base-snapshot
    echo "Check '${instance_name}' snapshot"
    _instance_status=$(VBoxManage snapshot ${instance_name} showvminfo ${_instance_snaphot_name} 2>&1) && _exit_code=$? || _exit_code=$?
    if [[ $_exit_code -eq 1 ]] && [[ $_instance_status =~ 'This machine does not have any snapshots' ]]; then
      echo "No snapshots found!"
      %(instance_shutdown)s
      echo "Create snapshot for '${instance_name}'..."
      VBoxManage snapshot "${instance_name:?}" take ${_instance_snaphot_name} --description "First snapshot for '${instance_name}'"
      echo "Restarting '${instance_name}' ..."
      %(instance_wait_started)s
    elif [[ $_exit_code -ne 0 ]]; then
      echo " ${status_error} Error checking snapshots for '${instance_name}' - exit code '${_exit_code}'" >&2
      echo ${_instance_status} >&2
      exit 2
    else
      echo "${status_success} Snapshot for '${instance_name}' already present!"
    fi
  ||| % {
    hostname: instance.hostname,
    instance_config: instance_config(setup, instance),
    instance_shutdown: utils.indent(
      instance_shutdown(
        '${instance_name:?}',
        '${instance_check_timeout_seconds:?}',
        '${instance_check_sleep_time_seconds:?}',
      ),
      '\t',
      ''
    ),
    instance_wait_started: utils.indent(
      instance_wait_started(
        '${instance_name:?}',
        'whoami',
        '${instance_check_timeout_seconds:?}',
        '${instance_check_sleep_time_seconds:?}',
      ),
      '\t',
      ''
    ),
  };

local file_provisioning(opts) =
  assert std.objectHas(opts, 'destination') : 'destination file is missing';
  assert std.objectHas(opts, 'source') : 'source file is missing';
  local is_remote_source = std.objectHas(opts, 'source_host') && opts.source_host != 'localhost';
  local is_remote_destination = std.objectHas(opts, 'destination_host') && opts.destination_host != 'localhost';
  local create_parents_destination_folder =
    if std.objectHas(opts, 'create_parents_dir') && opts.create_parents_dir then
      local script = 'mkdir -pv $(dirname "%s")' % opts.destination;
      |||
        echo " ${status_action} Create destination folder for '%(destination_file)s'"
        %(create_parents_destination_folder)s
      ||| % {
        destination_file: opts.destination,
        create_parents_destination_folder:
          if is_remote_destination then
            utils.ssh.exec(
              opts.destination_host,
              std.escapeStringBash(if std.objectHas(opts, 'destination_owner') then
                "sudo -i -u %(owner)s /bin/bash -c '%(script)s'" % { owner: std.escapeStringBash(opts.destination_owner), script: script }
              else "sudo su -c '%s'" % script),
            )
          else script,
      }
    else '';
  local variables =
    (
      if is_remote_source then
        |||
          source_hostname=%(host)s
          source_instance_username=$(jq -r --arg host "${source_hostname:?}" '.list.[$host].admin_username' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
          if [[ $_exit_code -ne 0 ]]; then
            echo " ${status_error} Could not get 'admin_username' for instance '${source_hostname:?}'" >&2
            exit 2
          fi
          source_instance_host=$(jq -r --arg host "${source_hostname:?}" '.list.[$host].ipv4' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
          if [[ $_exit_code -ne 0 ]]; then
            echo " ${status_error} Could not get 'ipv4' for instance '${source_hostname:?}'" >&2
            exit 2
          fi
        ||| % { host: opts.source_host }
      else ''
    ) + (
      if is_remote_destination then
        |||
          destination_hostname=%(host)s
          destination_instance_username=$(jq -r --arg host "${destination_hostname:?}" '.list.[$host].admin_username' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
          if [[ $_exit_code -ne 0 ]]; then
            echo " ${status_error} Could not get 'admin_username' for instance '${destination_hostname:?}'" >&2
            exit 2
          fi
          destination_instance_host=$(jq -r --arg host "${destination_hostname:?}" '.list.[$host].ipv4' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
          if [[ $_exit_code -ne 0 ]]; then
            echo " ${status_error} Could not get 'ipv4' for instance '${destination_hostname:?}'" >&2
            exit 2
          fi
        ||| % { host: opts.destination_host }
      else ''
    );
  local copy_file =
    (if is_remote_source || is_remote_destination then
       |||
         %(destination_file)s
         %(scp_file)s
         %(remote_mv)s
       ||| % {
         destination_file:
           if std.objectHas(opts, 'destination_host') then
             |||
               # Use a temporary destination_file
               destination_file=$(%s)
             ||| % utils.ssh.exec(opts.destination_host, 'mktemp')
           else 'destination_file="%s"' % opts.destination,
         scp_file: utils.ssh.copy_file(
           if is_remote_source then
             '"${source_instance_username:?}"@"${source_instance_host:?}":"%s"' % opts.source
           else opts.source,
           if is_remote_destination then
             '"${destination_instance_username:?}"@"${destination_instance_host:?}":"${destination_file:?}"'
           else '${destination_file:?}'
         ),
         remote_mv:
           if is_remote_destination && std.objectHas(opts, 'destination_owner') then
             utils.ssh.exec(
               opts.destination_host,
               |||
                 bash <<-EOF
                 sudo chown '%(destination_owner)s':'%(destination_owner)s' "${destination_file:?}"
                 sudo --user='%(destination_owner)s' --login --non-interactive mv "${destination_file:?}" '%(destination_file)s'
                 EOF
               ||| % { destination_owner: opts.destination_owner, destination_file: opts.destination }
             )
           else '',
       }
     else 'cp "%(source_file)s" "%(destination_file)s"' % { source_file: opts.source, destination_file: opts.destination });
  |||
    # - Start file provisioning -
    %(variables)s
    %(create_parents_destination_folder)s
    %(copy_file)s
    # - End file provisioning -
  ||| % {
    variables: variables,
    create_parents_destination_folder: create_parents_destination_folder,
    copy_file: copy_file,
  };

local inline_shell_provisioning(opts) =
  assert std.objectHas(opts, 'destination_host');
  assert std.objectHas(opts, 'script');

  local variables =
    |||
      destination_hostname=%(host)s
      destination_instance_username=$(jq -r --arg host "${destination_hostname:?}" '.list.[$host].admin_username' "${instances_catalog_file:?}")
      destination_instance_host=$(jq -r --arg host "${destination_hostname:?}" '.list.[$host].ipv4' "${instances_catalog_file:?}")
    ||| % { host: opts.destination_host };
  local script =
    "bash <<-'EOF'\n" +
    (if std.objectHas(opts, 'working_directory') then
       |||
         cd '%(working_directory)s'
       ||| % { working_directory: opts.working_directory }
     else '') + opts.script + 'EOF';
  local pre_command =
    if std.objectHas(opts, 'reboot_on_error') then
      'set +e'
    else '';
  local post_command =
    local wait_script =
      if std.objectHas(opts, 'restart_wait_mount') then
        "awk '$2==\"%s\" {n+=1} BEGIN{n=0} END{exit n>0 ? 0 : 1}' /proc/mounts" % opts.restart_wait_mount
      else
        'whoami';
    if std.objectHas(opts, 'reboot_on_error') then
      |||
        _exit_code=$? || _exit_code=$?
        set -e
        _instance_name=%(destination_host)s
        if [[ $_exit_code -eq 0 ]]; then
          echo "No need to reboot '${_instance_name:?}'"
        else
          echo "${status_action} Reboot '${_instance_name:?}'..."
          _instance_check_success=false
          _instance_check_sleep_seconds=2
          _instance_check_etries=10
          for _retry_counter in $(seq ${_instance_check_etries:?} 1); do
            _instance_status=$(VBoxManage showvminfo "${_instance_name:?}" --machinereadable 2>&1) && _exit_code=$? || _exit_code=$?
            if [[ $_exit_code -eq 0 ]] && [[ $_instance_status =~ 'VMState="running"' ]]; then
              echo " ${status_info} We can reboot '${_instance_name:?}'!"
              _instance_check_success=true
              break
            else
              echo "${status_waiting} Will retry command in ${_instance_check_sleep_seconds} seconds. Retry left: ${_retry_counter}"
              sleep ${_instance_check_sleep_seconds}
            fi
          done
          if ${_instance_check_success:?}; then
            %(instance_shutdown)s
            %(instance_wait_started)s
          else
            echo " ${status_warning} Instance '${_instance_name:?}' not ready after reboot!"
          fi
        fi
      ||| % {
        destination_host: opts.destination_host,
        instance_shutdown: instance_shutdown(
          '${_instance_name:?}',
        ),
        instance_wait_started: instance_wait_started(
          '${_instance_name:?}',
          wait_script,
        ),
      }
    else '';
  |||
    # - Start inline provisioning -
    %(variables)s
    %(pre_command)s
    %(remote_script)s
    %(post_command)s
    # - End inline provisioning -
  ||| % {
    variables: std.stripChars(variables, '\n'),
    pre_command: std.stripChars(pre_command, '\n'),
    remote_script: utils.ssh.exec(
      opts.destination_host,
      script,
      { options: { ServerAliveInterval: 5 } }
    ),
    post_command: std.stripChars(post_command, '\n'),
  };

local generate_provisioning(provisioning) =
  assert std.objectHas(provisioning, 'type');
  if provisioning.type == 'file' then
    file_provisioning(provisioning)
  else if provisioning.type == 'inline-shell' then
    inline_shell_provisioning(provisioning)
  else error 'Invalid provisioning: %s' % provisioning.type;

local provision_instance(instance) =
  assert std.isObject(instance);
  if std.objectHas(instance, 'base_provisionings') then
    assert std.objectHas(instance, 'hostname');
    assert std.isArray(instance.base_provisionings) : 'base_provisionings MUST be an array';
    local provisionings = [
      provisioning { destination_host: instance.hostname }
      for provisioning in instance.base_provisionings
    ];
    utils.shell_lines(std.map(
      func=generate_provisioning,
      arr=provisionings
    ))
  else '';

local provision_instances(setup) =
  if std.objectHas(setup, 'provisionings') then
    assert std.isArray(setup.provisionings) : 'provisionings MUST be an array';
    utils.shell_lines(std.map(
      func=generate_provisioning,
      arr=setup.provisionings
    ))
  else '';

// Exported functions
{
  project_utils(setup):
    |||
      #!/usr/bin/env bash
      #
      # Common Helpers Functions
      set -Eeuo pipefail

      : ${NO_COLOR:=0}
      if [[ -z ${NO_COLOR+notset} ]] || [ "${NO_COLOR}" == "0" ]; then
        bold_text=$(tput bold)
        bad_result_text=$(tput setaf 1)
        good_result_text=$(tput setaf 2)
        highlight_text=$(tput setaf 3)
        info_text=$(tput setaf 4)
        reset_text=$(tput sgr0)
        status_success=✅
        status_error=❌
        status_warning=⚠️
        status_info=ℹ️
        status_ok=🆗
        status_memo=📝
        status_start_first=˹
        status_start_last=˺
        status_end_first=˻
        status_end_last=˼
        status_waiting=💤
        status_action=⚙️
      else
        bold_text=''
        bad_result_text=''
        good_result_text=''
        highlight_text=''
        info_text=''
        reset_text=''
        status_success='[SUCCESS]'
        status_error='[ERROR]'
        status_warning='[WARNING]'
        status_info='[INFO]'
        status_ok='[OK]'
        status_memo='[MEMO]'
        status_start_first='['
        status_start_last=']'
        status_end_first='['
        status_end_last=']'
        status_waiting='[WAITING]'
        status_action='[ACTION]'
      fi

      %(bash_utils)s
    ||| % {
      bash_utils: bash_utils(setup),
    },
  project_bootstrap(setup):
    assert std.objectHas(setup, 'virtual_machines');
    assert std.isArray(setup.virtual_machines);
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail
      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      . "${_this_file_path}/include/utils.sh"
      generated_files_path="${_this_file_path}"

      %(project_config)s
      %(cidata_network_config_template)s

      echo "${status_info} ${info_text}${bold_text}Bootstrap Network${reset_text}"
      %(network_creation)s

      echo "${status_info} ${info_text}${bold_text}Bootstrap instances${reset_text}"
      jq --null-input --indent 2 '{list: {}}' > "${instances_catalog_file:?}"
      %(instances_creation)s
      echo "${status_info} ${info_text}Project instances created!${reset_text}"
    ||| % {
      project_config: project_config(setup),
      cidata_network_config_template: std.stripChars(cidata_network_config_template(setup), '\n'),
      network_creation: create_network(setup),
      instances_creation: utils.shell_lines([
        check_instance_exist_do(setup, instance, utils.indent(create_instance(setup, instance), '\t'))
        for instance in setup.virtual_machines
      ]),
    },
  project_configuration(setup):
    '',
  project_wrap_up(setup):
    local instances = [instance.hostname for instance in setup.virtual_machines];
    local provisionings =
      if std.objectHas(setup, 'base_provisionings') then
        setup.base_provisionings
      else [];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      . "${_this_file_path}/include/utils.sh"
      generated_files_path="${_this_file_path}"

      %(project_config)s

      echo "${status_info} ${info_text}Generating machines_config.json for ansible${reset_text}"
      cat "${instances_catalog_file:?}" > "${project_root_path}/%(ansible_inventory_path)s/machines_config.json"
      echo "${status_info} ${info_text}Instances basic provisioning${reset_text}"
      %(instances_provision)s
      echo "Check snapshots for instances"
      %(instances_snapshot)s
    ||| % {
      ansible_inventory_path: setup.ansible_inventory_path,
      project_config: project_config(setup),
      instances_provision: utils.shell_lines([
        provision_instance(instance)
        for instance in setup.virtual_machines
      ]),
      instances_snapshot: utils.shell_lines([
        snapshot_instance(setup, instance)
        for instance in setup.virtual_machines
      ]),
    },
  project_provisioning(setup):
    assert std.isObject(setup);
    local provisionings =
      if std.objectHas(setup, 'app_provisionings') then
        assert std.isArray(setup.app_provisionings);
        setup.app_provisionings
      else [];
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      . "${_this_file_path}/include/utils.sh"
      generated_files_path="${_this_file_path}"
      %(project_config)s

      echo "${status_info} ${info_text}Provisioning instances${reset_text}"
      %(instances_provision)s
    ||| % {
      instances_provision: provision_instances(setup),
      project_config: project_config(setup),
    },
  project_delete(setup):
    assert std.isObject(setup);
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      . "${_this_file_path}/include/utils.sh"
      generated_files_path="${_this_file_path}"

      echo "${status_info} ${info_text}Check instances${reset_text}"
      %(project_config)s
      %(instances_destroy)s
      echo "${status_info} ${info_text}Deleting '${project_basefolder:?}'${reset_text}"
      rm -rfv "${project_basefolder:?}"
      %(remove_network)s
      echo "${status_success} ${good_result_text}Deleting project '${project_name:?}' completed!${reset_text}"
    ||| % {
      project_config: project_config(setup),
      instances_destroy: utils.shell_lines([
        destroy_instance(setup, instance)
        for instance in setup.virtual_machines
      ]),
      remove_network: remove_network(setup),
    },
  project_snapshot_restore(setup):
    assert std.isObject(setup);
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      . "${_this_file_path}/include/utils.sh"
      generated_files_path="${_this_file_path}"
      %(project_config)s

      echo "${status_info} ${info_text}Restore instances snapshot...${reset_text}"
      %(restore_instances_snapshot)s
      echo "${status_success} ${good_result_text}Restoring instances snapshot completed!${reset_text}"
    ||| % {
      project_config: project_config(setup),
      restore_instances_snapshot: utils.shell_lines([
        |||
          %(instance_config)s
          _instance_snaphot_name=base-snapshot
          echo "Restoring '${instance_name:?}' snapshot '${_instance_snaphot_name:?}'"
          %(instance_shutdown)s
          VBoxManage snapshot ${instance_name:?} restore ${_instance_snaphot_name:?}
          %(instance_wait_started)s
        ||| % {
          instance_config: instance_config(setup, instance),
          instance_shutdown: instance_shutdown(
            '${instance_name:?}',
            '${instance_check_timeout_seconds:?}',
            '${instance_check_sleep_time_seconds:?}',
          ),
          instance_wait_started: instance_wait_started(
            '${instance_name:?}',
            'whoami',
            '${instance_check_timeout_seconds:?}',
            '${instance_check_sleep_time_seconds:?}',
          ),
        }
        for instance in setup.virtual_machines
      ]),
    },
  instances_status(setup):
    assert std.isObject(setup);
    assert std.objectHas(setup, 'virtual_machines');
    assert std.isArray(setup.virtual_machines);

    local instances = [instance.hostname for instance in setup.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        instances=( %(instances)s )
        for instance in %(instances)s; do
          VBoxManage showvminfo "${instance:?}" --machinereadable
        done
      else
        VBoxManage showvminfo "${1:?}" --machinereadable
      fi
    ||| % {
      instances: std.join(' ', instances),
    },
  instance_shell(setup):
    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo "${info_text}Usage:${reset_text} ${bold_text}$0 VIRTUAL_MACHINE_IP${reset_text}" >&2
        exit 1
      fi

      _this_file_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
      . "${_this_file_path}/include/utils.sh"
      generated_files_path="${_this_file_path}"
      %(project_config)s

      instance_hostname=${1:?}
      instance_username=$(jq --exit-status -r --arg host "${instance_hostname:?}" '.list.[$host].admin_username' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
      if [[ $_exit_code -ne 0 ]]; then
        echo " ${status_error} Could not get 'username' for instance '${instance_hostname:?}'" >&2
        exit 1
      fi
      instance_host=$(jq --exit-status -r --arg host "${instance_hostname:?}" '.list.[$host].ipv4' "${instances_catalog_file:?}")

      echo "Connecting to '${instance_username:?}@${instance_host:?}'..."

      ssh \
        -o UserKnownHostsFile=/dev/null \
        -o StrictHostKeyChecking=no \
        -o IdentitiesOnly=yes \
        -i "${generated_files_path}/assets/.ssh/id_ed25519" \
        ${instance_username:?}@${instance_host:?}
    ||| % {
      project_config: project_config(setup),
    },
  instance_info(setup):
    assert std.isObject(setup);
    assert std.objectHas(setup, 'virtual_machines');
    assert std.isArray(setup.virtual_machines);

    local instances = [instance.hostname for instance in setup.virtual_machines];

    |||
      #!/usr/bin/env bash
      set -Eeuo pipefail

      if [ $# -lt 1 ]; then
        echo "${info_text}Usage:${reset_text} ${bold_text}$0 VIRTUAL_MACHINE_IP${reset_text}"
        exit 0
      fi

      instance_ip_output=$(VBoxManage guestproperty enumerate "$1" --no-flags --no-timestamp '/VirtualBox/GuestInfo/Net/0/V4/IP' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    ||| % {
      instances: std.join(' ', instances),
    },
}
