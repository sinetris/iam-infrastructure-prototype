.instances += {
  ($host): {
    admin_username: $admin_username,
    cpus: $cpus,
    storage_space: $storage_space,
    memory: $memory,
    vram: $vram,
    timeout: $timeout,
    check_ssh_retries: $check_ssh_retries,
    check_sleep_time_seconds: $check_sleep_time_seconds,
    mac_address: $macaddr,
    network_interface_name: $nic,
    network_interface_netplan_name: $nic,
  }
}
