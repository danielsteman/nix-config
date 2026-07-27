{
  description = "My configuration for macOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs Homebrew itself from Nix (nix-darwin's homebrew.* only runs brew bundle).
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-dotenvx = {
      url = "github:dotenvx/homebrew-brew";
      flake = false;
    };
    homebrew-databricks = {
      url = "github:databricks/homebrew-tap";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew, homebrew-core, homebrew-cask, homebrew-dotenvx, homebrew-databricks }:
  let
    lib = nixpkgs.lib;
    username = "danielsteman";

    configuration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        # commitizen's test suite fails to build under python3.14 (argparse error-message
        # format changed); skip its checks rather than waiting on a nixpkgs fix.
        (final: prev: {
          commitizen = prev.commitizen.overridePythonAttrs (_: { doCheck = false; });
        })
        # pipx's test suite fails to collect under python3.14 (pytest parametrize
        # mismatch in tests/test_inject.py); skip its checks rather than waiting on a fix.
        (final: prev: {
          pipx = prev.pipx.overridePythonAttrs (_: { doCheck = false; });
        })
        # poetry 2.4.1 in this nixpkgs pin has 3 failing executor tests
        # (tests/installation/test_executor.py) -- fails on both python3.13 and 3.14, so
        # it's a broken test, not a version issue. poetry's package.nix builds its own
        # internal python set that re-defines `poetry` last, so overlay overrides can't
        # reach it; and withPlugins pulls poetry-plugin-export, which build-depends on the
        # unwrapped poetry *with* checks. So we hand-roll withPlugins here: take poetry's
        # own internal python, disable checks on unwrapped poetry, rebuild the export
        # plugin against that, and re-assemble the application with the plugin baked in.
        # home.nix then uses plain `poetry` (no .withPlugins call).
        (final: prev:
          let
            py = prev.poetry.python;
            poetryNoCheck = py.pkgs.poetry.overridePythonAttrs (_: { doCheck = false; });
            # poetry-plugin-export 1.10.0 ships pyproject version 1.9.0 (upstream forgot
            # to bump), so the wheel METADATA mismatches the derivation version. nixpkgs
            # normally never builds this plugin, so the bug is latent; skip the check.
            exportPlugin = (prev.poetry.plugins.poetry-plugin-export.override {
              poetry = poetryNoCheck;
            }).overridePythonAttrs (_: {
              doCheck = false;
              dontCheckPythonMetadata = true;
            });
          in {
            poetry = py.pkgs.toPythonApplication (poetryNoCheck.overridePythonAttrs (old: {
              dependencies = old.dependencies ++ [ exportPlugin ];
              doCheck = false;
              # Propagating dependencies leaks them through $PYTHONPATH (breaks nix-shell);
              # upstream withPlugins strips this, so we mirror that.
              postFixup = ''
                rm -f $out/nix-support/propagated-build-inputs
              '';
            }));
          })
        # lima fails to compile from source on this machine: its Go build crashes
        # nixpkgs' cctools linker (Trace/BPT trap) on the current toolchain. Use
        # upstream's prebuilt, already-entitlement-signed release binary instead.
        (final: prev: {
          lima = final.stdenvNoCC.mkDerivation {
            pname = "lima";
            version = "2.1.4";
            src = final.fetchzip {
              url = "https://github.com/lima-vm/lima/releases/download/v2.1.4/lima-2.1.4-Darwin-arm64.tar.gz";
              hash = "sha256-VLWiw0cvme0+wDd8f1C67hBe5d1jtwo9t6kWyJckjhI=";
              stripRoot = false;
            };
            dontBuild = true;
            # Any post-link mangling (stripping, install_name_tool rpath edits, etc.) voids the
            # upstream ad-hoc codesign + Virtualization.framework entitlements on the binary.
            dontStrip = true;
            dontFixup = true;
            nativeBuildInputs = [ final.makeWrapper ];
            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp -r bin libexec share $out/
              wrapProgram $out/bin/limactl --prefix PATH : ${final.lib.makeBinPath [ final.qemu ]}
              runHook postInstall
            '';
            meta = prev.lima.meta // { mainProgram = "limactl"; };
          };
          # lima-full normally calls `lima.override {...}`, which our plain derivation above
          # doesn't support. colima only needs limactl on PATH, not the extra guest agents.
          lima-full = final.lima;
        })
      ];

      environment.systemPackages = with pkgs; [ dnsmasq ];

      # Homebrew packages (only for things not in nixpkgs)
      # nix-homebrew handles brew installation itself - no manual install needed
      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = true;
          cleanup = "zap";  # Remove unlisted formulae/casks
        };
        brews = [
          "databricks" # Databricks CLI (tap: databricks/tap)
          "dotenvx" # Not in nixpkgs
        ];
        casks = [
          # macOS apps not in nixpkgs go here
        ];
      };

      # Resolve *.mcphost.localhost → 127.0.0.1 for local full-stack dev.
      environment.etc."dnsmasq-mcphost.conf".text = "address=/.mcphost.localhost/127.0.0.1\n";
      environment.etc."resolver/mcphost.localhost".text = "nameserver 127.0.0.1\n";
      launchd.daemons.dnsmasq = {
        serviceConfig = {
          ProgramArguments = [ "/run/current-system/sw/bin/dnsmasq" "--keep-in-foreground" "--conf-file=/etc/dnsmasq-mcphost.conf" ];
          RunAtLoad = true;
          KeepAlive = true;
        };
      };

      nix.enable = false;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Save the disk
      nix.settings.auto-optimise-store = true;

      # Set primary user
      system.primaryUser = username;

      # Enable alternative shell support in nix-darwin.
      programs.zsh.enable = true;
      environment.shells = [ pkgs.bash pkgs.zsh ];

      # Fonts stuff
      fonts.packages = [
          pkgs.nerd-fonts.jetbrains-mono
          pkgs.nerd-fonts.meslo-lg
      ];

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Unlock sudo commands with our fingerprint.
      security.pam.services.sudo_local.touchIdAuth = true;

      system.defaults = {
        trackpad.Clicking = true;
        dock.autohide = true;
        screencapture.target = "clipboard";

        finder = {
          AppleShowAllExtensions = true;
          ShowPathbar = true;
          FXEnableExtensionChangeWarning = false;
        };
      };

      system.keyboard.enableKeyMapping = true;

      system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";
      system.defaults.NSGlobalDomain._HIHideMenuBar = false;

    };

    # nix-homebrew tap paths use .../homebrew-<name>; brew tap names are shorter (e.g. dotenvx/brew).
    nixHomebrewTapToBrewTap = tapPath:
      if tapPath == "dotenvx/homebrew-brew" then "dotenvx/brew"
      else if tapPath == "databricks/homebrew-tap" then "databricks/tap"
      else tapPath;

    nix-homebrew-module = {
      nix-homebrew = {
        enable = true;
        enableRosetta = false;
        user = username;
        mutableTaps = false;
        taps = {
          "homebrew/homebrew-core" = homebrew-core;
          "homebrew/homebrew-cask" = homebrew-cask;
          "databricks/homebrew-tap" = homebrew-databricks;
          "dotenvx/homebrew-brew" = homebrew-dotenvx;
        };
      };
    };

    homebrew-taps-from-nix-homebrew = { config, ... }: {
      # trusted = true satisfies Homebrew 6.0's HOMEBREW_REQUIRE_TAP_TRUST during
      # activation, avoiding a manual `brew trust <tap>` before every build.
      homebrew.taps = map (tapPath: {
        name = nixHomebrewTapToBrewTap tapPath;
        trusted = true;
      }) (builtins.attrNames config.nix-homebrew.taps);
    };
  in
  {
    darwinConfigurations."${username}" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        nix-homebrew.darwinModules.nix-homebrew
        nix-homebrew-module
        homebrew-taps-from-nix-homebrew
        configuration
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."${username}" = {
            imports = [ ./home.nix ];
            home.homeDirectory = lib.mkForce "/Users/${username}";
          };
        }
      ];
    };

    homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      modules = [ ./home.nix ];
    };
  };
}
