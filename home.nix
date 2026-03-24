{ config, pkgs, ... }:

{
  imports = [
#    ./modules/neovim.nix
  ];
  home.username = "mg";
  home.homeDirectory = "/home/mg";

  # --------------------------------------------------
  # Git (unchanged)
  # --------------------------------------------------
  programs.git = {
    enable = true;
    userName = "Dmitriy L";
    userEmail = "xhaustlesss@gmail.com";
    aliases = {
      s = "status -sb";
      co = "checkout";
      c = "commit";
      br = "branch";
    };
    ignores = [
      "*.swp"
      ".DS_Store"
    ];
    extraConfig = {
      pull.rebase = "false";
      init.defaultBranch = "main";
    };
  };

  # --------------------------------------------------
  # SSH (unchanged)
  # --------------------------------------------------
  services.ssh-agent.enable = true;
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github" = {
        user = "mg";
        identityFile = "~/.ssh/id_ed25519_github";
        identitiesOnly = true;
      };
    };
    extraConfig = ''
      Host *
        ForwardAgent yes
    '';
  };

  # --------------------------------------------------
  # Zoxide + FZF
  # --------------------------------------------------
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultOptions = [
      "--height=100%"
      "--border"
    ];
  };

  # --------------------------------------------------
  # Systemd user services for Wayland components
  # --------------------------------------------------
  systemd.user.services = {
    waybar = {
      Unit = {
        Description = "Waybar status bar";
        PartOf = "graphical-session.target";
        After = "graphical-session.target";
      };
      Service = {
        ExecStart = "${pkgs.waybar}/bin/waybar";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
    
    mako = {
      Unit = {
        Description = "Mako notification daemon";
        PartOf = "graphical-session.target";
        After = "graphical-session.target";
      };
      Service = {
        ExecStart = "${pkgs.mako}/bin/mako";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
    
    swaybg = {
      Unit = {
        Description = "Sway background";
        PartOf = "graphical-session.target";
        After = "graphical-session.target";
      };
      Service = {
        ExecStart = "${pkgs.swaybg}/bin/swaybg -i /path/to/your/wallpaper.png";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
  
  # Start these services when the graphical session starts
  systemd.user.targets.graphical-session = {
    Unit = {
      Description = "Graphical session";
      Wants = [ "waybar.service" "mako.service" ];
    };
  };

  # --------------------------------------------------
  # Zsh configuration
  # --------------------------------------------------
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };

    plugins = [
      {
        name = "fzf-zsh-plugin";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    initExtraBeforeCompInit = ''
      # Powerlevel10k theme
      if [ -f "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme" ]; then
        source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
      fi
    '';

    initExtra = ''
      # If you generated ~/.p10k.zsh once, you can have HM manage it as a dotfile.
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # zoxide keybindings
      eval "$(zoxide init zsh)"
      
      # Wayland environment variables
      export XDG_CURRENT_DESKTOP=wlroots
      export XDG_SESSION_TYPE=wayland
      export QT_QPA_PLATFORM=wayland
      export SDL_VIDEODRIVER=wayland
      export CLUTTER_BACKEND=wayland
      export _JAVA_AWT_WM_NONREPARENTING=1
      
      # Automatically start dwl on tty1 if not already in a session
      if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        systemctl --user start graphical-session.target
        exec dwl
      fi
    '';
  };

  # --------------------------------------------------
  # Create dwl autostart script
  # --------------------------------------------------
  home.file.".config/dwl/autostart.sh" = {
    executable = true;
    text = ''
      #!/bin/bash
      
      # Kill already running duplicate processes
      _ps="waybar mako swaybg foot"
      for _prs in $_ps; do
          if pidof "$_prs" >/dev/null 2>&1; then
              killall -9 "$_prs" 2>/dev/null || true
          fi
      done
      
      # Wait a moment for processes to be killed
      sleep 0.5
      
      # Start notification daemon
      ${pkgs.mako}/bin/mako &
      
      # Start status bar (config will be loaded from ~/.config/waybar)
      ${pkgs.waybar}/bin/waybar &
      
      # Start terminal server (foot)
      ${pkgs.foot}/bin/foot --server &
      
      # Update environment for systemd and Wayland
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
    '';
  };

  # --------------------------------------------------
  # Waybar Configuration from GitHub repo
  # --------------------------------------------------
  # Create a directory for waybar config
  home.file.".config/waybar" = {
    source = pkgs.fetchFromGitHub {
      owner = "misssglory";  # Replace with your GitHub username
      repo = "waybar-config";   # Replace with your repo name
      rev = "b7b524f9ed6d17cae88bcf82c1cfb3806443157b";             # Replace with the branch or commit hash
      sha256 = "sha256-Byj7KBeVKKcalgJM7YHXSJm9M1+pzm5vafbOBJo1GLo=";  # Replace with actual hash after first build
    };
    recursive = true;
  };

  # Alternatively, if you want to manage it as a symlink to a local repo:
  # home.file.".config/waybar" = {
  #   source = config.lib.file.mkOutOfStoreSymlink "/path/to/your/local/waybar-config";
  #   recursive = true;
  # };

  # --------------------------------------------------
  # Foot Terminal Configuration from GitHub repo
  # --------------------------------------------------
  #home.file.".config/foot" = {
  #  source = pkgs.fetchFromGitHub {
  #    owner = "yourusername";  # Replace with your GitHub username
  #    repo = "foot-config";     # Replace with your repo name
  #    rev = "main";
  #    sha256 = lib.fakeSha256;
  #  };
  #  recursive = true;
  #};

  # --------------------------------------------------
  # Mako Configuration from GitHub repo
  # --------------------------------------------------
  #home.file.".config/mako" = {
  #  source = pkgs.fetchFromGitHub {
  #    owner = "yourusername";
  #    repo = "mako-config";
  #    rev = "main";
  #    sha256 = lib.fakeSha256;
  #  };
  #  recursive = true;
  #};

  # --------------------------------------------------
  # Alacritty configuration (if you still want to keep it)
  # --------------------------------------------------
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = 0.7;
        decorations = "full";
        dynamic_title = true;
      };

      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        size = 13.0;
      };

      colors = {
        primary = {
          background = "0x000000";
          foreground = "0xcdd6f4";
        };
        normal = {
          black   = "0x45475a";
          red     = "0xf38ba8";
          green   = "0xa6e3a1";
          yellow  = "0xf9e2af";
          blue    = "0x89b4fa";
          magenta = "0xf5c2e7";
          cyan    = "0x94e2d5";
          white   = "0xbac2de";
        };
        bright = {
          black   = "0x585b70";
          red     = "0xf38ba8";
          green   = "0xa6e3a1";
          yellow  = "0xf9e2af";
          blue    = "0x89b4fa";
          magenta = "0xf5c2e7";
          cyan    = "0x94e2d5";
          white   = "0xa6adc8";
        };
      };

      cursor = {
        style = "Beam";
      };

      terminal.shell = {
        program = "${pkgs.zsh}/bin/zsh";
      };
    };
  };

  # --------------------------------------------------
  # User packages for Wayland environment
  # --------------------------------------------------
  home.packages = with pkgs; [
    # Wayland utilities
    wl-clipboard
    grim
    slurp
    wmenu
    wlsunset
    
    # System utilities
    pavucontrol
    networkmanagerapplet
    libnotify
    mako
    waybar
    foot
    
    # Screenshot editor
    swappy
    
    # Clipboard history
    cliphist
  ];

  # --------------------------------------------------
  # Shells
  # --------------------------------------------------
  programs.bash = {
    enable = true;
  };
  
  # --------------------------------------------------
  # Neovim configuration symlink
  # --------------------------------------------------
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "/home/tony/nixos-dotfiles/config/nvim";
    recursive = true;
  };

  home.stateVersion = "25.11";
}
