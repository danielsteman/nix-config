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
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew, homebrew-core, homebrew-cask, homebrew-dotenvx }:
  let
    lib = nixpkgs.lib;
    username = "danielsteman";

    configuration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [];

      # Homebrew packages (only for things not in nixpkgs)
      # nix-homebrew handles brew installation itself - no manual install needed
      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = true;
          cleanup = "zap";  # Remove unlisted formulae/casks
        };
        brews = [
          "dotenvx"  # Not in nixpkgs
        ];
        casks = [
          # macOS apps not in nixpkgs go here
        ];
      };

      nix.enable = false;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

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
      system.defaults.NSGlobalDomain._HIHideMenuBar = true;

    };

    # nix-homebrew tap paths use .../homebrew-<name>; brew tap names are shorter (e.g. dotenvx/brew).
    nixHomebrewTapToBrewTap = tapPath:
      if tapPath == "dotenvx/homebrew-brew" then "dotenvx/brew" else tapPath;

    nix-homebrew-module = {
      nix-homebrew = {
        enable = true;
        enableRosetta = false;
        user = username;
        mutableTaps = false;
        taps = {
          "homebrew/homebrew-core" = homebrew-core;
          "homebrew/homebrew-cask" = homebrew-cask;
          "dotenvx/homebrew-brew" = homebrew-dotenvx;
        };
      };
    };

    homebrew-taps-from-nix-homebrew = { config, ... }: {
      homebrew.taps = map nixHomebrewTapToBrewTap (builtins.attrNames config.nix-homebrew.taps);
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
