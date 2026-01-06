{
  dot,
  config,
  lib,
  perSystem,
  ...
}: {
  options.dotship.crds = dot.options.attrs.submodule "k8s CRD" ({
    config,
    name,
    ...
  }: {
    options = {
      enable = dot.options.enable "install CRDs" {};

      src = dot.options.package "package to pull CRDs from" {};
      name = dot.options.str "name of CRD installation" {default = name;};
      namePrefix = dot.options.str "prefix to apply to CRD modules" {default = "";};
      attrNameOverrides = dot.options.attrs.str "override CRD names" {};
      crds = dot.options.list.str "all CRD files" {internal = true;};

      targetApp = dot.options.str "target application to install CRDs into" {default = name;};

      prefix = dot.options.str "location in src with CRDs" {default = "";};
      pattern = dot.options.str "regex match of CRD files" {default = ".+";};
    };

    config.crds = let
      inherit (config) pattern prefix;

      isYAML = fileName: lib.hasSuffix ".yaml" fileName;

      isMatch = fileName:
        lib.pipe fileName [
          (builtins.match pattern)
          (! dot.trivial.isNull)
        ];
    in
      dot.filesets.everything
      (name: _: isYAML name && isMatch name)
      (config.src + "/" + prefix);
  });

  config.applications = lib.pipe config.dotship.crds [
    (lib.filterAttrs (_: crd: crd.enable))
    (lib.mapAttrsToList (_: crd: {${crd.application}.settings = map builtins.readFile crd.crds;}))
    lib.mkMerge
  ];

  config.nixidy.applicationImports = lib.flip lib.mapAttrsToList config.dotship.crds (_: crd:
    toString (perSystem.inputs'.nixidy.packages.generators.fromCRD {
      inherit (crd) name src namePrefix crds attrNameOverrides;
    }));
}
