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
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    lib = nixpkgs.lib;
    username = "danielsteman";
    configuration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;

      # System-level packages (keep minimal - only what's needed system-wide)
      # Most packages have been moved to home-manager (see home.nix)
      environment.systemPackages = with pkgs; [
        # Keep system packages minimal - most are now in home-manager
      ];

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

    };
  in
  {
    darwinConfigurations."${username}" = nix-darwin.lib.darwinSystem {
      modules = [
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
