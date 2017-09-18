# nix-binary-cache-proxy

An NGINX caching proxy to serve the cache.nixos.org binary cache from your local network.

Using this you can download from a fast machine in your data center or basement instead of the cache.nixos.org CDN, which depending on your geographical location or connection speed can be slow to download from.
The nginx caching proxy transparently fetches any package from the upstream cache.nixos.org on first access, and saves it to its local disk so that subsequent accesses don't hit the internet.

It's ready-to-deploy with [nixops](https://nixos.org/nixops) for your convenience.

## Deploy

### How to deploy to AWS

First change [nginx-binary-cache-proxy.nix](nginx-binary-cache-proxy.nix) to set it up for your AWS account and domain name (best use `~/.aws/credentials`).

Then

* `nixops create <nginx-binary-cache-proxy.nix> -d nginx-binary-cache-proxy`
* `nixops deploy -d nginx-binary-cache-proxy`

### How to deploy to a dedicated machine running NixOS

Simply follow the AWS steps, but remove all AWS/Route53 related `deployment.*` entries and use

```nix
{
  deployment.targetEnv = "none";
  deployment.targetHost = "1.2.3.4"; # your server's IP you can SSH into
}
```

## Use

Simply point your NixOS boxes at it with:

```nix
{
  nix.binaryCaches = [
    "http://nixos-cache.example.com/"
    "http://cache.nixos.org/" # include this line if you want it to fallback to upstream if your cache is down
  ];
}
```

For non-NixOS nix users, set the `binary-caches` option in `/etc/nix/nix.conf` as described in the last paragraphs of [this manual section](https://nixos.org/nix/manual/#ssec-binary-cache-substituter).


#### Acknowledgements

Thanks to [@cleverca22](https://github.com/cleverca22/) for lots of help with this!
