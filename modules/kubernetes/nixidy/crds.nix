{
  dotlib,
  config,
  lib,
  perSystem,
  ...
}: {
  options.dotship.crds = dotlib.options.attrs.submodule "k8s CRD" ({
    config,
    name,
    ...
  }: {
    options = {
      enable = dotlib.options.enable "install CRDs" {};

      src = dotlib.options.package "package to pull CRDs from" {};
      name = dotlib.options.str "name of CRD installation" {default = name;};
      namePrefix = dotlib.options.str "prefix to apply to CRD modules" {default = "";};
      attrNameOverrides = dotlib.options.attrs.str "override CRD names" {};
      crds = dotlib.options.list.str "all CRD files" {internal = true;};

      targetApp = dotlib.options.str "target application to install CRDs into" {default = name;};

      prefix = dotlib.options.str "location in src with CRDs" {default = "";};
      pattern = dotlib.options.str "regex match of CRD files" {default = ".+";};
    };

    config.crds = let
      inherit (config) pattern prefix;

      isYAML = fileName: lib.hasSuffix ".yaml" fileName;

      isMatch = fileName:
        lib.pipe fileName [
          (builtins.match pattern)
          (! dotlib.trivial.isNull)
        ];
    in
      dotlib.filesystem.everything
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
