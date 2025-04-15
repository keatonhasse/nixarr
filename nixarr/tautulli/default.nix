{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.tautulli;
  nixarr = config.nixarr;
in {
  options.nixarr.tautulli = {
    enable = mkEnableOption "Tautulli";
    package = mkPackageOption pkgs "tautulli" { };

    users = {
      groups.tautilli = { };
      users.tautilli = {
        isSystemUser = true;
        group = "tautilli";
      };
    };

    user = mkOption {
      type = types.str;
      default = tautulli;
      description = "";
    };

    group = mkOption {
      type = types.str;
      default = "tautulli";
      description = "";
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    services.tautulli = {
      enable = cfg.enable;
      package = cfg.package;
      user = cfg.user;
      group = cfg.roup;
    };
  };
}
