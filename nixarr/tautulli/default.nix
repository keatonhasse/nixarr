{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.nixarr.tautulli;
  nixarr = config.nixarr;
in {
  options.nixarr.tautulli = {
    enable = mkEnableOption "Tautulli";
    package = mkPackageOption pkgs "tautulli" {};

    # user = mkOption {
    #   type = types.str;
    #   default = "tautulli";
    #   description = "";
    # };

    # group = mkOption {
    #   type = types.str;
    #   default = "tautulli";
    #   description = "";
    # };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    users = {
      groups.tautilli = {};
      users.tautilli = {
        isSystemUser = true;
        group = "tautilli";
      };
    };

    services.tautulli = {
      enable = true;
      package = cfg.package;
      user = "tautilli";
      group = "tautilli";
    };
  };
}
