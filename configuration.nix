{
  config,
  lib,
  pkgs,
  ...
}:

{
  system.stateVersion = "26.05";
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays = [
    {
      name = "disable-bt-and-enable-serial";

      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2711";

          fragment@0 {
            target-path = "/soc";
            __overlay__ {
                serial@7e201000 {
                  pinctrl-0 = <&uart0_gpio14>;
                  bluetooth {
                    status = "disabled";
                  };
                };

                serial@7e215040 {
                  status = "disabled";
                };
            };
          };
        };
      '';
    }
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "pi";
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;
  systemd.network.networks."90-end0" = {
    matchConfig.Name = "end0";
    address = [
      "192.168.1.100/24"
      "2001:470:5816:0:b045:e6d3:3f8:9999/64"
    ];
    networkConfig = {
      DHCP = "yes";
    };
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
    ];
  };
  time.timeZone = "Europe/Prague";

  environment.systemPackages = with pkgs; [
    vim
    wget
    htop
    ncdu
    ripgrep
    minicom
    dtc
  ];

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  services.openssh.settings.PasswordAuthentication = false;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDacshL0MKcPH/C0S7/ybYcd7+643Lo6X9VjAkwdgOCw3FKYWr20qKCHd0hPFXcYixt86aNuF2McNRae5h+dlPwPWIuJTt987gnp25IQlsWBeIiS1tDZI1lZcVu+Yj7BQMmp8uXkyP4KqjX9zaa3FmXv4MeWz/41rRYj72A1ZlsF1H/SxZ7uQX27XuhV5nOvsH2yAbXKexDwcvcR/lrxQcYH9el3QDt6x229lqn9piuSSl/LYAN81jxd/4a2Pwrnqeqca+HC9xY6LF6NW64E2RkZMMTbsaFo8E4FFLnTzcYgP1+EKypPiphMhvCJQLOo3crcxMpv9eOGvgGh8iMdak3"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDHPnrZgImCAprHnZQaIyn6Wvvl+YDEjHmm0B8F/TVz57G6E7fHD/Cc8VJ571j1sQ/OeJhSWGm94itmEBBJNx8uoKcVtXvd+7Uow+Ui45KpEGCuMAB+3PdZd6+yzr6yTXr121+//XYAn0bYhAmyijVSMxBZ5gwohmrSg+P2uArhvmuEmn2r5kJ5KCb1tyj2713bhVm/4bFs+q+fHcKRG/0/CyfOPFn8wGfKpjvmmAc1knbzn6zzLOn2tjhA4Y2KEnJuU13ZLvqJLBHXp50LwA0kRDD2irX+6ZJD5KY/JpbzVX5vdgSXUbwAEGeecnU5o7KgXWb61YetRJhi8vu6Q0bxSoG7l1q2XFo8n9mV3TBofFgn4F+nudS9iQ7Cl6To7hi3/0zHnE4M4PVt7idC4BcLyEwGp3rwPApjiuYO7Io3oFTYYv6OORDq788s+FHPDKoHnw2JY/qcEZYQNx9+iIeJhMpBvm2+g7Ysn2NyPoFsB6qg/ZF1TnXdu07t6pngp1E="
  ];

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };
  services.home-assistant = {
    enable = true;
  };
  services.thelounge.enable = true;
  services.octoprint.enable = true;
  services.redis.enable = true;
  services.nextbike-rides-viewer.enable = true;
  services.traefik = {
    enable = true;
    staticConfigOptions = {
      log.level = "DEBUG";
      entryPoints = {
        web = {
          address = ":80";
        };
      };
      #api.dashboard = true;
      #api.insecure = true;
      providers = {
        docker = {
          endpoint = "unix:///run/podman/podman.sock";
          exposedByDefault = false;
        };
      };
    };
    dynamicConfigOptions = {
      http = {
        routers = {
          trnila-root = {
            rule = "Host(`trnila.eu`)";
            entryPoints = [ "web" ];
            middlewares = [ "to-github" ];
            service = "noop@internal";
          };
          printer = {
            rule = "Host(`3dprinter.trnila.eu`)";
            entryPoints = [ "web" ];
            service = "octoprint";
          };
          hass = {
            rule = "Host(`hass.trnila.eu`)";
            entryPoints = [ "web" ];
            service = "hass";
          };
          thelounge = {
            rule = "Host(`trnila.eu`) && PathPrefix(`/irc`)";
            entryPoints = [ "web" ];
            middlewares = [ "strip-irc" ];
            service = "thelounge";
          };
          nextbike = {
            rule = "Host(`trnila.eu`) && PathPrefix(`/nextbike`)";
            entryPoints = [ "web" ];
            middlewares = [ "strip-nextbike" ];
            service = "nextbike";
          };
        };

        services = {
          octoprint = {
            loadBalancer = {
              servers = [
                { url = "http://localhost:5000"; }
              ];
            };
          };

          hass = {
            loadBalancer = {
              servers = [
                { url = "http://localhost:8123"; }
              ];
            };
          };

          thelounge = {
            loadBalancer = {
              servers = [
                { url = "http://localhost:9000"; }
              ];
            };
          };
          nextbike = {
            loadBalancer = {
              servers = [
                { url = "http://localhost:8080"; }
              ];
            };
          };
        };

        middlewares = {
          to-github = {
            redirectRegex = {
              regex = "^http://trnila\\.eu/?$";
              replacement = "https://github.com/trnila";
              permanent = false;
            };
          };

          strip-irc = {
            stripprefix = {
              prefixes = [ "/irc" ];
            };
          };

          strip-nextbike = {
            stripprefix = {
              prefixes = [ "/nextbike" ];
            };
          };
        };
      };
    };
  };

  users.users.traefik = {
    extraGroups = [ "podman" ];
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.lunch = {
      image = "ghcr.io/trnila/assistant:latest";
      extraOptions = [
        "--network=host"
      ];
      cmd = [
        "--port"
        "5001"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.services.lunch-backend.loadbalancer.server.port" = "5001";

        "traefik.http.routers.lunch-frontend.rule" = "Host(`trnila.eu`) && Path(`/lunch`)";
        "traefik.http.routers.lunch-frontend.service" = "lunch-backend";
        "traefik.http.routers.lunch-frontend.middlewares" = "lunch-strip";
        "traefik.http.middlewares.lunch-strip.stripprefix.prefixes" = "/lunch";

        "traefik.http.routers.lunch-backend.rule" = "Host(`trnila.eu`) && Path(`/lunch.json`)";
        "traefik.http.routers.lunch-backend.service" = "lunch-backend";

        "traefik.http.routers.assistant.rule" = "Host(`trnila.eu`) && PathPrefix(`/assistant/`)";
        "traefik.http.routers.assistant.middlewares" = "assistant-strip";
        "traefik.http.middlewares.assistant-strip.stripprefix.prefixes" = "/assistant";
        "traefik.http.routers.assistant.service" = "lunch-backend";
      };
      #user = "nobody";
    };
  };
}
