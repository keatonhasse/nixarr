{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.jellyfin;
  defaultPort = 8096;
  nixarr = config.nixarr;
  dnsServers = config.lib.vpn.dnsServers;
in {
  options.nixarr.jellyfin = {
    enable = mkEnableOption "the Jellyfin service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/nixarr/jellyfin";
      description = "The state directory for Jellyfin.";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](/options.html#nixarr.vpn.enable)

        Route Jellyfin traffic through the VPN.
      '';
    };

    expose = {
      vpn = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            **Required options:** 
        
            - [`nixarr.jellyfin.vpn.enable`](/options.html#nixarr.jellyfin.vpn.enable)
            - [`nixarr.jellyfin.expose.vpn.port`](/options.html#nixarr.jellyfin.expose.vpn.port)
            - [`nixarr.jellyfin.expose.vpn.accessibleFrom`](/options.html#nixarr.jellyfin.expose.vpn.accessibleFrom)

            Expose the Jellyfin web service to the internet, allowing anyone to
            access it.

            **Important:** Do _not_ enable this without setting up Jellyfin
            authentication through localhost first!
          '';
        };

        port = mkOption {
          type = with types; nullOr port;
          default = null;
          description = ''
            The port to access jellyfin on. Get this port from your VPN
            provider.
          '';
        };

        accessibleFrom = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "jellyfin.airvpn.org";
          description = ''
            The IP or domain that Jellyfin should be able to be accessed from.
          '';
        };
      };

      https = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            **Required options:** 
        
            - [`nixarr.jellyfin.expose.https.acmeMail`](/options.html#nixarr.jellyfin.expose.https.acmeMail)
            - [`nixarr.jellyfin.expose.https.domainName`](/options.html#nixarr.jellyfin.expose.https.domainName)

            **Conflicting options:** [`nixarr.jellyfin.vpn.enable`](/options.html#nixarr.jellyfin.vpn.enable)

            Expose the Jellyfin web service to the internet with https support,
            allowing anyone to access it.

            **Important:** Do _not_ enable this without setting up Jellyfin
            authentication through localhost first!
          '';
        };

        upnp.enable = mkEnableOption "UPNP to try to open ports 80 and 443 on your router.";

        domainName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The domain name to host Jellyfin on.";
        };

        acmeMail = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The ACME mail required for the letsencrypt bot.";
        };
      };
    };
  };

  config =
    # TODO: this doesn't work. I don't know why :(
    #assert (!(cfg.vpn.enable && cfg.expose.enable)) || abort "vpn.enable not compatible with expose.enable.";
    #assert (cfg.expose.enable -> (cfg.expose.domainName != null && cfg.expose.acmeMail != null)) || abort "Both expose.domain and expose.acmeMail needs to be set if expose.enable is set.";
    mkIf cfg.enable
    {
      systemd.tmpfiles.rules = [
        "d '${cfg.stateDir}' 0700 streamer root - -"
      ];

      services.jellyfin = {
        enable = cfg.enable;
        user = "streamer";
        group = "streamer";
        logDir = "${cfg.stateDir}/log";
        cacheDir = "${cfg.stateDir}/cache";
        dataDir = "${cfg.stateDir}/data";
        configDir = "${cfg.stateDir}/config";
      };

      networking.firewall = mkIf cfg.expose.https.enable {
        allowedTCPPorts = [80 443];
      };

      util-nixarr.upnp = mkIf cfg.expose.https.upnp.enable {
        enable = true;
        openTcpPorts = [80 443];
      };

      services.nginx = mkMerge [
        (mkIf (cfg.expose.https.enable || cfg.vpn.enable) {
          enable = true;

          recommendedTlsSettings = true;
          recommendedOptimisation = true;
          recommendedGzipSettings = true;
        })
        (mkIf cfg.expose.https.enable {
          virtualHosts."${builtins.replaceStrings ["\n"] [""] cfg.expose.https.domainName}" = {
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              recommendedProxySettings = true;
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:${builtins.toString defaultPort}";
            };
          };
        })
        (mkIf cfg.vpn.enable {
          virtualHosts."127.0.0.1:${builtins.toString defaultPort}" = mkIf cfg.vpn.enable {
            listen = [
              {
                addr = "0.0.0.0";
                port = defaultPort;
              }
            ];
            locations."/" = {
              recommendedProxySettings = true;
              proxyWebsockets = true;
              proxyPass = "http://192.168.15.1:${builtins.toString defaultPort}";
            };
          };
        })
        (mkIf cfg.expose.vpn.enable {
          virtualHosts."${cfg.expose.vpn.accessibleFrom}:${builtins.toString cfg.expose.vpn.port}" = {
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              recommendedProxySettings = true;
              proxyWebsockets = true;
              proxyPass = "http://192.168.15.1:${builtins.toString defaultPort}";
            };
          };
        })
      ];

      security.acme = mkIf cfg.expose.https.enable {
        acceptTerms = true;
        defaults.email = cfg.expose.https.acmeMail;
      };

      util-nixarr.vpnnamespace.portMappings = [
        (
          mkIf cfg.vpn.enable {
            From = defaultPort;
            To = defaultPort;
          }
        )
      ];

      systemd.services."container@jellyfin" = mkIf cfg.vpn.enable {
        requires = ["wg.service"];
      };

      containers.jellyfin = mkIf cfg.vpn.enable {
        autoStart = true;
        ephemeral = true;
        extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

        bindMounts = {
          "${nixarr.mediaDir}/library".isReadOnly = false;
          "${cfg.stateDir}".isReadOnly = false;
        };

        config = {
          users.groups.streamer = {
            gid = config.users.groups.streamer.gid;
          };
          users.users.streamer = {
            uid = lib.mkForce config.users.users.streamer.uid;
            isSystemUser = true;
            group = "streamer";
          };

          # Use systemd-resolved inside the container
          # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
          networking.useHostResolvConf = lib.mkForce false;
          services.resolved.enable = true;
          networking.nameservers = dnsServers;

          services.jellyfin = {
            enable = true;
            user = "streamer";
            group = "streamer";
            logDir = "${cfg.stateDir}/log";
            cacheDir = "${cfg.stateDir}/cache";
            dataDir = "${cfg.stateDir}/data";
            configDir = "${cfg.stateDir}/config";
          };

          system.stateVersion = "23.11";
        };
      };
    };
}
