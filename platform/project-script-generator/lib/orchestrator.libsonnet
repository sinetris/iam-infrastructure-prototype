{
  get(orchestrator):
    // jsonnet doesn't allow dynamic import paths
    local orchestrator_implementation =
      if orchestrator == 'fake' then
        import 'orchestrators/fake.libsonnet'
      else if orchestrator == 'multipass' then
        import 'orchestrators/multipass.libsonnet'
      else if orchestrator == 'vbox' then
        import 'orchestrators/vbox.libsonnet'
      else
        '';
    assert orchestrator_implementation != '' : 'Invalid orchestrator';
    {
      use: orchestrator_implementation,
    },
}
