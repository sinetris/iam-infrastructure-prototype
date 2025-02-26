{
  arrayIf(condition, array, elseArray=[])::
    assert std.isArray(array);
    assert std.isArray(elseArray);
    (if condition then array else elseArray),
  objectIf(condition, object, elseObject={})::
    assert std.isObject(object);
    assert std.isObject(elseObject);
    (if condition then object else elseObject),
  indent(string, pre='\t', beginning=pre)::
    beginning + std.join('\n' + pre, std.split(std.rstripChars(string, '\n'), '\n')),
  shell_lines(lines)::
    std.stripChars(std.join('', lines), '\n'),
  file_name(name, opts={})::
    assert std.isObject(opts);
    (if std.objectHas(opts, 'prefix') then opts.prefix + '-' else '') +
    name +
    (if std.objectHas(opts, 'postfix') then '-' + opts.postfix else '') +
    (if std.objectHas(opts, 'extension') then '.' + opts.extension else ''),
  cloudinit_user_data_filename(hostname)::
    self.file_name(hostname, {
      prefix: 'cidata',
      postfix: 'user-data',
      extension: 'yaml',
    }),
  verify_setup(setup)::
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
  verify_orchestrator(orchestrator)::
    assert std.isObject(orchestrator);
    assert std.isFunction(orchestrator.project_utils);
    assert std.isFunction(orchestrator.project_bootstrap);
    assert std.isFunction(orchestrator.project_wrap_up);
    assert std.isFunction(orchestrator.project_provisioning);
    assert std.isFunction(orchestrator.project_delete);
    assert std.isFunction(orchestrator.project_snapshot_restore);
    assert std.isFunction(orchestrator.instances_status);
    assert std.isFunction(orchestrator.instance_shell);
    assert std.isFunction(orchestrator.instance_info);
    true,
}
