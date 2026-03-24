{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "danielsteman";
  home.homeDirectory = "/Users/danielsteman";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  # When using home-manager as a nix-darwin module, programs.home-manager.enable
  # is not needed - it's automatically enabled

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Daniel Steman";
        email = "daniel-steman@live.nl";
      };
      core.editor = "vim";
      core.excludesFile = "~/.gitignore_global";

      push.autoSetupRemote = true;
      pull.rebase = false;
      fetch.prune = true;

      diff.algorithm = "histogram";
      diff.colorMoved = "default";

      merge.conflictstyle = "zdiff3";

      branch.sort = "-committerdate";
      tag.sort = "-creatordate";

      alias.um = "!git fetch origin main && git merge origin/main -m \"🔀 Merge origin/main into $(git rev-parse --abbrev-ref HEAD)\"";
    };
  };

  # User-specific packages organized by category
  home.packages = with pkgs; let
    # Cloud & Infrastructure tools
    cloud = [
      auth0-cli
      awscli2
      azure-cli
      databricks-cli
      fluxcd
      kubernetes-helm
      kubectl
      kubectx
      kind
      packer
      trivy
    ];

    # Development languages & runtimes
    languages = [
      bun
      deno
      go
      lua
      nodejs_24
      postgresql_16
      sqlite
      typescript
      unison
      zig
    ];

    # Nix stuff
    nix = [
      cachix
    ]; 

    # Haskell
    haskell = [
      ghc
      cabal-install
      haskell-language-server
      stack
    ];

    # Python development tools
    python = [
      mypy
      pdm
      pipenv
      (poetry.withPlugins (p: [ p.poetry-plugin-export ]))
      pre-commit
      pyenv
      pyright
      tenv
      uv
      yamllint
    ];

    # Development tools & editors
    devTools = [
      bfg-repo-cleaner
      chromedriver
      claude-code
      code-cursor
      commitizen
      direnv
      esphome
      fzf
      gh
      gh-dash
      gitmoji-cli
      neovim
      prettierd
      vim
      vscode
    ];

    # Git & version control
    gitTools = [
      act
      jira-cli-go
    ];

    # Container & orchestration
    containers = [
      colima
      docker
      process-compose
    ];

    # Security & encryption
    security = [
      age
      gnupg
      mkcert
      sops
    ];

    # System utilities
    systemUtils = [
      ansible
      cue
      htop
      jq
      nmap
      tree
      wget
      websocat
      xz
      yq
      zstd
    ];

    # GUI applications
    guiApps = [
      aerospace
      firefox
      kitty
      monitorcontrol
      raycast
    ];

    # Other tools
    misc = [
      cmatrix
      cook-cli
      goose-cli
      ngrok
      ollama
      temporal-cli
      wimlib
      yarn
    ];
  in
    cloud
    ++ languages
    ++ haskell
    ++ python
    ++ devTools
    ++ gitTools
    ++ containers
    ++ security
    ++ systemUtils
    ++ guiApps
    ++ misc;
}
