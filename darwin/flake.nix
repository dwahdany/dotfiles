{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    rayscripts = {
      url = "path:/Users/dariush/git/personal/dotfiles/rayscripts";
      flake = false;
    };
  };

  outputs =
    {
      self,
      darwin,
      nixpkgs,
      home-manager,
      nix-homebrew,
      homebrew-bundle,
      ...
    }@inputs:
    let
      hostConfig = import ./host.nix;
    in
    {
      darwinConfigurations.${hostConfig.hostname} = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit hostConfig; };
        modules = [
          home-manager.darwinModules.home-manager
          ./work.nix
          ./cispa.nix
          (
            { pkgs, lib, ... }:
            {
              # Add system-level allowUnfree
              nixpkgs.config.allowUnfree = true;

              # Add Rosetta 2 installation
              system.activationScripts.extraActivation.text = ''
                softwareupdate --install-rosetta --agree-to-license

                # Configure noTunes to use Qobuz as the replacement app
                defaults write digital.twisted.noTunes replacement /Applications/Qobuz.app

                # Configure LinearMouse to run at login
                osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/LinearMouse.app", hidden:false}'
              '';

              # Finder preferences
              system.defaults.finder = {
                AppleShowAllExtensions = true; # Show all file extensions in Finder
                _FXSortFoldersFirst = true; # Sort folders first in the Finder
                FXPreferredViewStyle = "Nlsv"; # Use list view in Finder
                ShowStatusBar = true; # Show status bar in Finder (e.g. space left)
                _FXShowPosixPathInTitle = false; # Show POSIX path in window title
                QuitMenuItem = true; # Show "Quit" option in Finder
                ShowPathbar = true; # Show path bar in Finder
                FXDefaultSearchScope = "SCcf"; # Search the current folder by default
                ShowMountedServersOnDesktop = true;
                ShowHardDrivesOnDesktop = true;
                ShowRemovableMediaOnDesktop = true;
                ShowExternalHardDrivesOnDesktop = true;
              };

              system.defaults.menuExtraClock = {
                Show24Hour = true;
                ShowDayOfWeek = false;
                ShowSeconds = false;
                ShowDate = 2;
                ShowDayOfMonth = true;
              };

              system.defaults.trackpad = {
                Clicking = true; # tap to click
              };
              system.startup.chime = false;
              # system.defaults.screensaver.askForPasswordDelay = 4;
              # has to be done manually using either
              # sysadminctl -screenLock immediate -password -
              # or
              # sysadminctl -screenLock [seconds] -password -
              # https://github.com/mathiasbynens/dotfiles/issues/922#issuecomment-1322698371

              # List packages installed in system profile. To search by name, run:
              # $ nix-env -qaP | grep wget
              environment.systemPackages = with pkgs; [
                nixfmt-rfc-style
                vim
                uv
                git-lfs
              ];
              system.keyboard = {
                enableKeyMapping = true;
                remapCapsLockToEscape = true;
              };
              security.pam.services.sudo_local.touchIdAuth = true;
              # Necessary for using flakes on this system.
              nix.settings.experimental-features = "nix-command flakes";

              # Enable alternative shell support in nix-darwin.
              # programs.fish.enable = true;

              # Set Git commit hash for darwin-version.
              system.configurationRevision = self.rev or self.dirtyRev or null;

              # Used for backwards compatibility, please read the changelog before changing.
              # $ darwin-rebuild changelog
              system.stateVersion = 5;

              # The platform the configuration will be used on.
              nixpkgs.hostPlatform = "aarch64-darwin";
              system.primaryUser = hostConfig.username;
              # Add home-manager configuration
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${hostConfig.username} =
                {
                  config,
                  pkgs,
                  lib,
                  ...
                }:
                let
                  workConfig = if hostConfig.enableWork or false then { } else { };
                in
                lib.recursiveUpdate {
                  home = {
                    stateVersion = "25.05";
                    username = hostConfig.username;
                    homeDirectory = lib.mkForce hostConfig.homeDirectory;
                    shell.enableShellIntegration = true;
                  };
                  imports = [
                    ./file-associations.nix
                  ];
                  home.packages = with pkgs; [
                    # dev tools
                    iterm2
                    cyberduck
                    mountain-duck
                    starship
                    keka
                    nodePackages.pnpm
                    ollama
                    nodejs_20
                    rclone
                    gh

                    #nix stuff
                    duti
                    nixd
                    nil

                    # python
                    python3
                    uv
                    ruff

                    # general
                    obsidian
                    nerd-fonts.fira-code
                    raycast

                    # comms
                    slack

                    # academic
                    drawio
                    zotero
                    texliveFull
                  ];
                  programs.git = {
                    enable = true;
                    lfs.enable = true;
                    userName = hostConfig.fullName;
                    userEmail = hostConfig.email;
                    signing = {
                      key = "~/.ssh/id_keychain.pub";
                      signByDefault = true;
                      format = "ssh";
                    };
                    extraConfig = {
                      core.editor = "vim";
                    };
                  };
                  home.sessionVariables = {
                    # Set history control to ignore commands starting with space
                    HISTCONTROL = "ignorespace";
                    # Set default editor to vim
                    EDITOR = "vim";
                  };

                  programs.zsh = {
                    enable = true;
                    autosuggestion.enable = true;
                    enableCompletion = true;
                    syntaxHighlighting.enable = true;

                    # Set zsh theme using starship (a cross-shell prompt)
                    initContent = ''
                      # Add SSH key to keychain on startup
                      ssh-add --apple-use-keychain ~/.ssh/id_keychain 2>/dev/null || true

                      eval "$(starship init zsh)"

                      # Configure npm to use a directory in your home folder for global installs
                      mkdir -p ~/.npm-global/bin
                      npm config set prefix ~/.npm-global
                      export PATH=$HOME/.npm-global/bin:$PATH

                      # Add ~/.local/bin to PATH
                      if [ -d "$HOME/.local/bin" ]; then
                          export PATH="$HOME/.local/bin:$PATH"
                      fi

                      # Add ~/.turso to PATH
                      export PATH="$HOME/.turso:$PATH"

                      # Enable forward delete key
                      bindkey "^[[3~" delete-char

                      # Add ~/bin to PATH
                      if [ -d "$HOME/bin" ]; then
                          export PATH="$HOME/bin:$PATH"
                      fi

                      # Helpful alias for creating new Python projects
                      pynew() {
                        mkdir -p "$1" && cd "$1"
                        uv venv
                        source .venv/bin/activate
                        echo "Created new Python project in $1 with uv virtual environment"
                      }

                      # Function to install IPython kernel
                      ki() {
                        if [ -z "$1" ]; then
                          echo "Usage: ki <kernel-name>"
                          return 1
                        fi
                        uv run python -m ipykernel install --user --name "$1"
                        echo "Installed IPython kernel: $1"
                      }

                      # https://github.com/astral-sh/uv/issues/8432#issuecomment-2453494736
                      _uv_run_mod() {
                          if [[ "$words[2]" == "run" && "$words[CURRENT]" != -* ]]; then
                              _arguments '*:filename:_files'
                          else
                              _uv "$@"
                          fi
                      }
                      compdef _uv_run_mod uv
                    '';

                    # Oh-My-Zsh like aliases
                    shellAliases = {
                      ll = "ls -l";
                      la = "ls -la";
                      ".." = "cd ..";
                      "..." = "cd ../..";
                      ga = "git add";
                      gc = "git commit";
                      gco = "git checkout";
                      gst = "git status";
                      hf = "huggingface-cli";
                      ci = "git commit --allow-empty -m 'ci: trigger'; git push";
                    };
                  };
                  # Starship prompt - a customizable cross-shell prompt
                  programs.starship = {
                    enable = true;
                    settings = {
                      add_newline = true;
                      character = {
                        success_symbol = "[➜](bold green)";
                        error_symbol = "[✗](bold red)";
                      };
                      git_branch = {
                        style = "bold purple";
                      };
                      git_status = {
                        disabled = false;
                        format = "([$all_status$ahead_behind]($style) )";
                        style = "bold blue";
                      };
                    };
                  };

                  programs.ssh = {
                    enable = true;
                    extraConfig = ''
                      AddKeysToAgent yes
                      UseKeychain yes
                      IdentityFile ~/.ssh/id_keychain
                      IgnoreUnknown UseKeychain
                      Protocol 2
                      ControlMaster auto
                      ControlPersist 1800
                      Compression yes
                      TCPKeepAlive yes
                      ServerAliveInterval 20
                      ServerAliveCountMax 10
                      ForwardAgent no
                    '';
                    matchBlocks = {
                      "github.com" = {
                        hostname = "github.com";
                        user = "git";
                      };
                      "btrfs" = {
                        hostname = "5.161.43.188";
                        user = "root";
                      };
                      "hf" = {
                        hostname = "hf.co";
                        user = "git";
                      };
                      "cx22" = {
                        hostname = "65.108.88.62";
                        user = "root";
                        identityFile = "~/.ssh/id_ansible";
                      };
                      "ce" = {
                        hostname = "138.201.184.164";
                        user = "root";
                        identityFile = "~/.ssh/id_ansible";
                      };
                      "one" = {
                        hostname = "one.nunc.immo";
                        user = "root";
                        identityFile = "~/.ssh/id_ansible";
                      };
                      "ha" = {
                        hostname = "10.0.10.9";
                        port = 22;
                        user = "root";
                        identityFile = "~/.ssh/ha";
                      };
                      "tower" = {
                        hostname = "10.0.1.2";
                        port = 5858;
                        user = "root";
                      };
                      "ghost" = {
                        hostname = "49.12.15.250";
                        user = "root";
                      };
                    };
                  };

                  home.file = {
                    "Documents/rayscripts/enable-sleep.sh" = {
                      text = builtins.readFile "${inputs.rayscripts}/enable-sleep.sh";
                      executable = true;
                    };

                    "Documents/rayscripts/disable-sleep.sh" = {
                      text = builtins.readFile "${inputs.rayscripts}/disable-sleep.sh";
                      executable = true;
                    };
                  };
                } workConfig;

              homebrew = {
                enable = true;
                onActivation = {
                  autoUpdate = true;
                  cleanup = "zap";
                  upgrade = true;
                };
                global = {
                  brewfile = true;
                  lockfiles = false;
                };
                extraConfig = ''
                  # Add custom Homebrew configuration for better compatibility
                  cask_args appdir: "~/Applications"
                '';
                casks = [
                  "docker"
                  "mx-power-gadget"
                  "github"
                  "google-chrome"
                  "google-drive"
                  "firefox"
                  "linearmouse"
                  "owncloud"
                  "betterdisplay" # to fix wrong TV role for displays
                  "displaylink"
                  "discord"
                  "visual-studio-code"
                  "orion"
                  "tailscale"
                  "obs"
                  "mathpix-snipping-tool"
                  # "bartender"
                  "jordanbaird-ice" # bartender replacement
                  "monodraw"

                  # dev tools
                  "cursor"
                  "zed"

                  # comms
                  "zoom"
                  "signal"
                  "telegram"

                  # private
                  "notunes"
                  "qobuz"
                  "teamviewer"
                  "protonvpn"
                  "portfolioperformance"
                ];
                brews = [
                  "mas"
                  "awscli@2"
                  "minio-mc"
                  "huggingface-cli"
                  # pandoc and stuff
                  "pandoc"
                  "librsvg"
                  "displayplacer"
                  "pv"
                ];
                masApps = {
                  "System Color Picker" = 1545870783;
                  "Numbers" = 409203825;
                  "Pages" = 409201541;
                  "Keynote" = 409183694;
                  "Final Cut Pro" = 424389933;
                  "Bitwarden" = 1352778147;
                  "WireGuard" = 1451685025;
                };
              };

              system.defaults.dock = {
                persistent-apps = [
                  "/System/Applications/Launchpad.app"
                  "${hostConfig.homeDirectory}/Applications/Home Manager Apps/iTerm2.app"
                  "/Applications/Firefox.app"
                  "/Applications/Bitwarden.app"
                  "${hostConfig.homeDirectory}/Applications/Home Manager Apps/Slack.app"
                  "${hostConfig.homeDirectory}/Applications/Home Manager Apps/Obsidian.app"
                  "/Applications/Cursor.app"
                  "${hostConfig.homeDirectory}/Applications/Home Manager Apps/Zotero.app"
                ];
                orientation = "left"; # Dock position on screen
                autohide = false; # Don't automatically hide the dock
                tilesize = 34; # Dock icon size
                magnification = true; # Enable dock magnification
                largesize = 56; # Magnified dock icon size
                wvous-tr-corner = 1; # disable all hot corners
                wvous-tl-corner = 1;
                wvous-bl-corner = 1;
                wvous-br-corner = 1;
              };

              system.defaults.NSGlobalDomain = {
                NSAutomaticCapitalizationEnabled = false;
                NSAutomaticDashSubstitutionEnabled = false;
                NSAutomaticInlinePredictionEnabled = false;
                NSAutomaticPeriodSubstitutionEnabled = false;
                NSAutomaticQuoteSubstitutionEnabled = false;
                NSAutomaticSpellingCorrectionEnabled = false;
              };
            }
          )
          nix-homebrew.darwinModules.nix-homebrew
          (
            { pkgs, lib, ... }:
            {
              nix-homebrew = {
                enable = true;
                user = hostConfig.username;
                mutableTaps = true;
                taps = {
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };
              };
            }
          )
          (
            { pkgs, ... }:
            {
              environment.etc."Keyboard Layouts/EurKEY.keylayout".source = ./../EurKEY-Mac-1.2/EurKEY.keylayout;
              environment.etc."Keyboard Layouts/EurKEY.icns".source = ./../EurKEY-Mac-1.2/EurKEY.icns;
            }
          )
        ];
      };
    };
}
