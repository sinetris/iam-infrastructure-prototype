{
  local utils = self,
  arrayIf(condition, array, elseArray=[]):
    assert std.isArray(array);
    assert std.isArray(elseArray);
    (if condition then array else elseArray),
  objectIf(condition, object, elseObject={}):
    assert std.isObject(object);
    assert std.isObject(elseObject);
    (if condition then object else elseObject),
  indent(string, pre='\t', beginning=pre):
    beginning + std.join('\n' + pre, std.split(std.rstripChars(string, '\n'), '\n')),
  shell_lines(lines):
    std.stripChars(std.join('', lines), '\n'),
  file_name(name, opts={}):
    assert std.isObject(opts);
    (if std.objectHas(opts, 'prefix') then opts.prefix + '-' else '') +
    name +
    (if std.objectHas(opts, 'postfix') then '-' + opts.postfix else '') +
    (if std.objectHas(opts, 'extension') then '.' + opts.extension else ''),
  cloudinit_user_data_filename(hostname):
    utils.file_name(hostname, {
      prefix: 'cidata',
      postfix: 'user-data',
      extension: 'yaml',
    }),
  verify_setup(setup):
    assert std.isObject(setup);
    assert std.objectHas(setup, 'ansible_inventory_path');
    assert std.objectHas(setup, 'base_domain');
    assert std.objectHas(setup, 'dns_servers');
    assert std.objectHas(setup, 'host_architecture');
    assert std.objectHas(setup, 'network');
    assert std.objectHas(setup, 'orchestrator_name');
    assert std.objectHas(setup, 'os_release_codename');
    assert std.objectHas(setup, 'project_basefolder');
    assert std.objectHas(setup, 'project_domain');
    assert std.objectHas(setup, 'project_generator_path');
    assert std.objectHas(setup, 'project_name');
    assert std.objectHas(setup, 'project_root_path');
    assert std.objectHas(setup, 'projects_folder');
    assert std.objectHas(setup, 'provisionings');
    assert std.objectHas(setup, 'virtual_machines');
    assert std.isArray(setup.provisionings);
    assert std.isArray(setup.virtual_machines);
    true,
  verify_orchestrator(orchestrator):
    assert std.isObject(orchestrator);
    assert std.isFunction(orchestrator.instance_info);
    assert std.isFunction(orchestrator.instance_shell);
    assert std.isFunction(orchestrator.instances_status);
    assert std.isFunction(orchestrator.project_bootstrap);
    assert std.isFunction(orchestrator.project_configuration);
    assert std.isFunction(orchestrator.project_delete);
    assert std.isFunction(orchestrator.project_provisioning);
    assert std.isFunction(orchestrator.project_snapshot_restore);
    assert std.isFunction(orchestrator.project_utils);
    assert std.isFunction(orchestrator.project_wrap_up);
    true,
  bash: {
    check_dependency():
      |||
        check_dependency() {
          if ! [ -x "$(command -v "$1")" ]; then
            echo -e "${bad_result_text}Error: ${bold_text}$1${reset_text}${bad_result_text} is not installed.${reset_text}" >&2
            exit 1
          fi
        }
      |||,
    mac_address_functions():
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
      |||,
    no_color():
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
      |||,
  },
  ssh: {
    local ssh_default_args = {
      quiet: true,
      options: {
        IdentitiesOnly: 'yes',
        ServerAliveCountMax: 3,
        ServerAliveInterval: 120,
        StrictHostKeyChecking: 'no',
        UserKnownHostsFile: '/dev/null',
      },
      identity_files: [
        '"${generated_files_path}/assets/.ssh/id_ed25519"',
      ],
    },
    local ssh_options_to_array(args) =
      if std.isString(args) then
        [args]
      else if std.isObject(args) then
        (if std.objectHas(args, 'quiet') then ['-q'] else [])
        + utils.arrayIf(
          std.objectHas(args, 'options'),
          ['-o %(key)s=%(value)s' % option for option in std.objectKeysValues(args.options)]
        ) + utils.arrayIf(
          std.objectHas(args, 'identity_files'),
          ['-i %s' % identity_file for identity_file in args.identity_files]
        )
      else if std.isArray(args) then
        args
      else
        [],
    exec(instance_name, script, override_args='', default_args=ssh_default_args):
      local args_string =
        std.join(
          ' \\\n\t',
          (if std.isObject(override_args) && std.isObject(default_args) then
             ssh_options_to_array(std.mergePatch(default_args, override_args))
           else
             ssh_options_to_array(override_args) + ssh_options_to_array(default_args))
        );
      |||
        _instance_username=$(jq -r --arg host "%(instance_name)s" '.list.[$host].admin_username' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
        if [[ $_exit_code -ne 0 ]]; then
          echo " ${status_error} Could not get 'admin_username' for instance '%(instance_name)s'" >&2
          exit 2
        fi
        _instance_host=$(jq -r --arg host "%(instance_name)s" '.list.[$host].ipv4' "${instances_catalog_file:?}") && _exit_code=$? || _exit_code=$?
        if [[ $_exit_code -ne 0 ]]; then
          echo " ${status_error} Could not get 'ipv4' for instance '%(instance_name)s'" >&2
          exit 2
        fi
        ssh %(args_string)s \
          "${_instance_username:?}"@"${_instance_host:?}" \
        %(script)s
      ||| % {
        instance_name: instance_name,
        script: script,
        args_string: args_string,
      },
    check_retry(instance_name, script='whoami', retries=20, sleep=5):
      |||
        _instance_name_to_check=%(instance_name)s
        _check_retries=%(retries)s
        _check_sleep=%(sleep)s
        _instance_check_ssh_success=false
        echo "${status_info} Wait for SSH and run command"
        for retry_counter in $(seq $_check_retries 1); do
          %(ssh_exec)s && _exit_code=$? || _exit_code=$?
          if [[ $_exit_code -eq 0 ]]; then
            echo "${status_success} SSH command ran successfully!"
            _instance_check_ssh_success=true
            break
          else
            echo "${status_waiting} Will retry command in ${_check_sleep} seconds. Retry left: ${retry_counter}"
            sleep ${_check_sleep}
          fi
        done
        if ${_instance_check_ssh_success}; then
          echo "${status_success} Instance '${_instance_name_to_check:?}' is ready!"
        else
          echo "${status_warning} Instance '${_instance_name_to_check:?}' not ready!"
        fi
      ||| % {
        instance_name: instance_name,
        retries: retries,
        sleep: sleep,
        ssh_exec: utils.indent(
          std.stripChars(
            utils.ssh.exec(
              '${_instance_name_to_check:?}',
              script,
            ), '\n'
          ),
          '\t',
          ''
        ),
      },
    copy_file(source, destination, override_args='', default_args=ssh_default_args):
      local args_string =
        std.join(
          ' \\\n\t',
          ssh_options_to_array(override_args) + ssh_options_to_array(default_args)
        );
      |||
        scp %(args_string)s \
          %(source)s \
          %(destination)s
      ||| % {
        source: source,
        destination: destination,
        args_string: args_string,
      },
  },
}
