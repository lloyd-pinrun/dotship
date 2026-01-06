{
  nixidy.applicationImports = [
    (_: {
      syncPolicy.syncOptions = {
        applyOutOfSyncOnly = true;
        pruneLast = true;
        serverSideApply = true;
        failOnSharedResource = true;
      };
    })
  ];

  nixidy.defaults.syncPolicy.autoSync = {
    default = true;
    prune = true;
    selfHeal = true;
  };
}
