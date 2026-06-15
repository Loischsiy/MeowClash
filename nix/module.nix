{ packageFor }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.meowclash;
  system = pkgs.stdenv.hostPlatform.system;
  defaultPackage = packageFor system;
in
{
  options.programs.meowclash = {
    enable = lib.mkEnableOption "MeowClash";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "inputs.meowclash.packages.${pkgs.system}.default";
      description = "MeowClash package to install.";
    };

    corePackage = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage.core;
      defaultText = lib.literalExpression "config.programs.meowclash.package.core";
      description = "MeowClash core package used for the NixOS capability wrapper.";
    };

    tunMode.enable = lib.mkEnableOption "CAP_NET_ADMIN wrapper for MeowClash TUN mode";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers = lib.mkIf cfg.tunMode.enable {
      MeowClashCore = {
        owner = "root";
        group = "root";
        capabilities = "cap_net_admin+ep";
        source = "${cfg.corePackage}/bin/MeowClashCore";
      };
    };
  };
}
