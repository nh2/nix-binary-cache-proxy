let
  domain = "nixos-cachecache.example.com";
in
{
  network.enableRollback = true;

  machine1 = { pkgs, ... }: {
    deployment.targetEnv = "ec2";
    deployment.ec2.accessKeyId = "example-nixops"; # symbolic name looked up in ~/.ec2-keys or a ~/.aws/credentials profile name
    deployment.ec2.region = "eu-central-1";
    deployment.ec2.instanceType = "t2.medium";
    deployment.ec2.keyPair = "yourkeypairname";
    deployment.ec2.ebsBoot = true;
    deployment.ec2.ebsInitialRootDiskSize = 100;

    deployment.route53.accessKeyId = "example-nixops";
    deployment.route53.hostName = domain;
    deployment.route53.ttl = 1;

    # Firewall all connections (except SSH which is open by default).
    networking.firewall.enable = true;
    # Reject instead of drop.
    networking.firewall.rejectPackets = true;
    networking.firewall.allowedTCPPorts = [
      80 # nginx
      443 # nginx
    ];

    boot.kernelModules = [ "tcp_bbr" ];

    # Enable BBR congestion control
    boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr";
    boot.kernel.sysctl."net.core.default_qdisc" = "fq"; # see https://news.ycombinator.com/item?id=14814530

    environment.systemPackages = [
      pkgs.htop
      pkgs.ncdu
      pkgs.nload
      pkgs.vim
    ];

    nix.binaryCaches = [ "http://nixos-cache.example.com/" "http://cache.nixos.org/" ];
    
    services.nginx = {
      enable = true;
      appendHttpConfig = ''
        proxy_cache_path /tmp/cache/ levels=1:2 keys_zone=cachecache:100m max_size=10g inactive=365d use_temp_path=off;

        # Cache only success status codes; in particular we don't want to cache 404s.
        # See https://serverfault.com/a/690258/128321
        map $status $cache_header {
          200     "public";
          302     "public";
          default "no-cache";
        }

        access_log logs/access.log;
      '';
      virtualHosts."${domain}" = {
        # enableACME = true;

        locations."/" = {
          root = "/var/public-nix-cache";
          extraConfig = ''
            expires max;
            add_header Cache-Control $cache_header always;

            # Ask the upstream server if a file isn't available locally
            error_page 404 = @fallback;
          '';
        };
        extraConfig = ''
          # Using a variable for the upstream endpoint to ensure that it is
          # resolved at runtime as opposed to once when the config file is loaded
          # and then cached forever (we don't want that):
          # see https://tenzer.dk/nginx-with-dynamic-upstreams/
          # This fixes errors like
          #   nginx: [emerg] host not found in upstream "upstream.example.com"
          # when the upstream host is not reachable for a short time when
          # nginx is started.
          resolver 8.8.8.8;
          set $upstream_endpoint http://cache.nixos.org;
        '';
        locations."@fallback" = {
          proxyPass = "$upstream_endpoint";
          extraConfig = ''
            proxy_cache cachecache;
            proxy_cache_valid  200 302  60m;

            expires max;
            add_header Cache-Control $cache_header always;
          '';
        };
        # We always want to copy cache.nixos.org's nix-cache-info file,
        # and ignore our own, because `nix-push` by default generates one
        # without `Priority` field, and thus that file by default has priority
        # 50 (compared to cache.nixos.org's `Priority: 40`), which will make
        # download clients prefer `cache.nixos.org` over our binary cache.
        locations."= /nix-cache-info" = {
          # Note: This is duplicated with the `@fallback` above,
          # would be nicer if we could redirect to the @fallback instead.
          proxyPass = "$upstream_endpoint";
          extraConfig = ''
            proxy_cache cachecache;
            proxy_cache_valid  200 302  60m;

            expires max;
            add_header Cache-Control $cache_header always;
          '';
        };
      };
    };

  };
}
