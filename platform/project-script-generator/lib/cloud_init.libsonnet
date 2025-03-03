local utils = import 'lib/utils.libsonnet';

{
  user_data(setup, instance)::
    assert std.isObject(setup);
    assert std.objectHas(setup, 'project_domain');
    assert std.isObject(instance);
    assert std.objectHas(instance, 'hostname');
    assert std.objectHas(instance, 'architecture');
    local tags = utils.arrayIf(std.objectHas(instance, 'tags'), instance.tags);
    local instance_users = utils.arrayIf(std.objectHas(instance, 'users'), instance.users);
    local instance_users_usernames = std.uniq(std.sort(['ubuntu'] + [user.username for user in instance_users]));
    local is_desktop = std.member(tags, 'desktop');
    local install_recommends = std.get(instance, 'install_recommends', false);
    local is_rdp_server = std.member(tags, 'rdpserver');
    local is_ansible_controller = std.member(tags, 'ansible-controller');
    local is_vbox = setup.orchestrator_name == 'vbox';
    local user_mapping(user) =
      assert std.isObject(user);
      assert std.objectHas(user, 'username');
      assert !(
        std.objectHas(user, 'password')
        && std.objectHas(user, 'plain_text_passwd')
      ) : "Invalid user '%s' in instance '%s' - cannot have both 'password' and 'plain_text_passwd'!" % [
        user.username,
        instance.hostname,
      ];
      local is_admin = std.objectHas(user, 'is_admin') && user.is_admin;
      {
        name: user.username,
        shell: '/bin/bash',
        groups: std.uniq(
          std.sort(
            utils.arrayIf(is_admin, [
              'adm',
              'audio',
              'cdrom',
              'dialout',
              'dip',
              'floppy',
              'lxd',
              'netdev',
              'plugdev',
              'ssl-cert',
              'staff',
              'sudo',
              'users',
              'video',
            ], [
              'staff',
              'users',
            ]) + utils.arrayIf(is_rdp_server, [
              'xrdp',
            ]) + utils.arrayIf(is_vbox, [
              'vboxsf',
            ]),
          )
        ),
        [if is_admin then 'sudo']: 'ALL=(ALL) NOPASSWD:ALL',
        [if std.objectHas(user, 'password') then 'passwd']: user.password,
        [if std.objectHas(user, 'plain_text_passwd') then 'plain_text_passwd']: user.plain_text_passwd,
        lock_passwd: if std.objectHas(user, 'password') ||
                        std.objectHas(user, 'plain_text_passwd') then false else true,
        [if std.objectHas(user, 'ssh_import_id')
            && std.isArray(user.ssh_import_id) then 'ssh_import_id']:
          user.ssh_import_id,
        [if std.objectHas(user, 'ssh_authorized_keys')
            && std.isArray(user.ssh_authorized_keys) then 'ssh_authorized_keys']:
          user.ssh_authorized_keys,
      };
    local runcmd_fix_home_for_user(username) =
      local home_path = '/home/' + username;
      local ownership = username + ':' + username;
      [
        ['mkdir', '-p', home_path + '/bin'],
        ['chown', '-R', ownership, home_path + '/bin'],
        ['mkdir', '-p', home_path + '/.local/bin'],
        ['chown', '-R', ownership, home_path + '/.local'],
      ];
    local write_files() = [
      {
        path: '/var/local/.test',
        content: |||
          File created!
        |||,
        permissions: '0o640',
      },
    ] + utils.arrayIf(is_desktop, [
      {
        path: '/etc/skel/.xsession',
        content: |||
          xfce4-session
        |||,
        permissions: '0o640',
      },
      {
        path: '/usr/share/glib-2.0/schemas/certification.gschema.override',
        content: |||
          [com.canonical.unity.settings-daemon.plugins.power]
          sleep-inactive-ac-timeout=0
          sleep-inactive-battery-timeout=0
          sleep-inactive-battery-type='nothing'
          sleep-inactive-ac-type='nothing'
          idle-dim=false
          [org.gnome.settings-daemon.plugins.power]
          sleep-inactive-ac-timeout=0
          sleep-inactive-battery-timeout=0
          sleep-inactive-battery-type='nothing'
          sleep-inactive-ac-type='nothing'
          idle-dim=false
          [org.gnome.desktop.session]
          idle-delay=0
          [org.gnome.desktop.screensaver]
          ubuntu-lock-on-suspend=false
          lock-enabled=false
          idle-activation-enabled=false
        |||,
      },
    ]);

    local manifest = {
      hostname: instance.hostname,
      fqdn: '%(hostname)s.%(project_domain)s' % {
        hostname: instance.hostname,
        project_domain: setup.project_domain,
      },
      prefer_fqdn_over_hostname: true,
      manage_etc_hosts: true,
      chpasswd: { expire: false },
      growpart: {
        mode: 'auto',
        devices: ['/'],
        ignore_growroot_disabled: false,
      },
      users: [user_mapping(user) for user in instance_users],
      apt: {
        // APT config
        conf: |||
          APT {
            Install-Recommends "%(install_recommends)s";
            Install-Suggests "false";
            Get {
              Fix-Broken "true";
            };
          };
        ||| % { install_recommends: install_recommends },
      },
      package_update: true,
      package_upgrade: true,
      packages: std.uniq(
        std.sort(
          [
            'apt-transport-https',
            'build-essential',
            'ca-certificates',
            'curl',
            'dbus',
            'git',
            'gnupg2',
            'jq',
            'libpam-systemd',
            'openssh-server',
            'python3-pip',
            'python3',
            'snapd',
            'vim',
            'wget',
          ] + utils.arrayIf(is_desktop, [
            'lightdm',
            'xclip',
            'xfce4-clipman-plugin',
            'xfce4-goodies',
            'xfce4',
          ]) + utils.arrayIf(is_rdp_server, [
            'xrdp',
          ]) + utils.arrayIf(is_vbox, [
            'linux-headers-generic',
            'make',
            'perl',
          ]),
        )
      ),
      runcmd: utils.arrayIf(is_vbox, [
        ['mkdir', '-p', '/mnt/additions'],
        ['mount', '-t', 'iso9660', '-o', 'ro', '/dev/sr1', '/mnt/additions'],
        // ['/mnt/additions/${_additions_file}'],
        ['/mnt/additions/VBoxLinuxAdditions-arm64.run'],
      ]) + utils.arrayIf(is_rdp_server, [
        ['systemctl', 'enable', 'xrdp'],
        ['service', 'xrdp', 'restart'],
      ]) + utils.arrayIf(is_desktop, [
        ['sed -i', 's/^#\\?AllowSuspend=.*/AllowSuspend=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowHibernation=.*/AllowHibernation=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowSuspendThenHibernate=.*/AllowSuspendThenHibernate=no/', '/etc/systemd/sleep.conf'],
        ['sed -i', 's/^#\\?AllowHybridSleep=.*/AllowHybridSleep=no/', '/etc/systemd/sleep.conf'],
        ['glib-compile-schemas', '/usr/share/glib-2.0/schemas'],
        ['systemctl', 'disable', 'systemd-networkd.service'],
      ]) + std.flatMap(
        runcmd_fix_home_for_user,
        instance_users_usernames
      ),
      write_files: write_files(),
      final_message: |||
        ## template: jinja
        cloud-init final message
        version: {{version}}
        timestamp: {{timestamp}}
        datasource: {{datasource}}
        uptime: {{uptime}}
      |||,
      snap: {
        commands: [
          ['install', 'yq'],
        ],
      },
    } + utils.objectIf(is_ansible_controller, {
      ansible: {
        package_name: 'ansible-core',
        install_method: 'distro',
        run_user: instance.admin_username,
      },
    }) + utils.objectIf(is_vbox, {
      power_state: {
        mode: 'reboot',
        delay: 'now',
        message: 'Rebooting machine',
        timeout: 120,
        condition: true,
      },
    });

    // Result
    '#cloud-config\n'
    + std.manifestYamlDoc(
      manifest,
      quote_keys=false,
    ) + '\n',
}
