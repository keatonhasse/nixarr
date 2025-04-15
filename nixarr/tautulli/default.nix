{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.tautulli;
  nixarr = config.nixarr;
  #user = "tautulli";
  #group = "tautulli";
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

    services.tautulli = {
      enable = cfg.enable;
      package = cfg.package;
      user = "tautulli";
      group = "tautulli";
    };
  };
}

