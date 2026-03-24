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
  # Zsh with Powerlevel10k and plugins
  # --------------------------------------------------
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;      # zsh-autosuggestions
    syntaxHighlighting.enable = true;  # zsh-syntax-highlighting

    # Oh My Zsh for plugins like git and fzf-zsh-plugin
    oh-my-zsh = {
      enable = true;
      # Basic plugins list; fzf-zsh-plugin is provided separately below
      plugins = [ "git" ];
      # You can set another theme here, but Powerlevel10k will override prompt
      theme = "robbyrussell";
    };

    # Additional, non-oh-my-zsh plugins such as fzf-zsh-plugin
    plugins = [
      {
        name = "fzf-zsh-plugin";
        src = pkgs.zsh-fzf-tab; # or another fzf-related plugin you prefer
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    # Make zsh your login shell when using Home Manager
    # (applies to new shells; you may still want `chsh` once manually)
    #loginShellInit = ''
    #  export SHELL=${pkgs.zsh}/bin/zsh
    #'';

    # Load Powerlevel10k theme
    initExtraBeforeCompInit = ''
      # Powerlevel10k theme
      if [ -f "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme" ]; then
        source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
      fi
    '';

    # Put your p10k config here, or source a separate file
    initExtra = ''
      # If you generated ~/.p10k.zsh once, you can have HM manage it as a dotfile.
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # zoxide keybindings (example)
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
      
      # Start our applications
      # Uncomment to set wallpaper (replace with your wallpaper path)
      # ${pkgs.swaybg}/bin/swaybg --output '*' --mode center --image /path-to-your-favorite-wallpaper &
      
      # Start notification daemon
      ${pkgs.mako}/bin/mako &
      
      # Start status bar
      ${pkgs.waybar}/bin/waybar &
      
      # Start terminal server (foot)
      ${pkgs.foot}/bin/foot --server &
      
      # Update environment for systemd and Wayland
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
    '';
  };

  # --------------------------------------------------
  # Create a desktop entry for dwl
  # --------------------------------------------------
  home.file.".local/share/wayland-sessions/dwl.desktop" = {
    text = ''
      [Desktop Entry]
      Name=dwl
      Comment=Dynamic Wayland Compositor
      Exec=${pkgs.dwl}/bin/dwl
      Type=Application
      DesktopNames=dwl
    '';
  };

  # --------------------------------------------------
  # Waybar Configuration
  # --------------------------------------------------
  programs.waybar = {
    enable = true;
    systemd.enable = false;
    
    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        
        modules-left = [ "wlr/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "battery" "pulseaudio" "network" "tray" ];
        
        "wlr/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "󰈹";
            "2" = "󰈹";
            "3" = "󰈹";
            "4" = "󰈹";
            "5" = "󰈹";
            "urgent" = "";
            "focused" = "";
            "default" = "󰈹";
          };
        };
        
        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%Y-%m-%d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        
        battery = {
          format = "{capacity}% {icon}";
          format-icons = ["" "" "" "" ""];
        };
        
        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "";
          format-icons = ["" "" ""];
        };
        
        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "";
          tooltip-format = "{ifname} via {gwaddr}";
        };
        
        tray = {
          icon-size = 21;
          spacing = 10;
        };
      }
    ];
    
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }
      
      window#waybar {
        background: rgba(26, 27, 38, 0.9);
        color: #c0caf5;
      }
      
      #workspaces button {
        padding: 0 5px;
        background: transparent;
        color: #c0caf5;
        border-bottom: 2px solid transparent;
      }
      
      #workspaces button.focused {
        border-bottom: 2px solid #7aa2f7;
        color: #7aa2f7;
      }
      
      #workspaces button.urgent {
        border-bottom: 2px solid #f7768e;
      }
      
      #clock, #battery, #pulseaudio, #network, #tray {
        padding: 0 10px;
        margin: 0 2px;
      }
      
      #battery.charging {
        color: #9ece6a;
      }
      
      #battery.warning:not(.charging) {
        color: #e0af68;
      }
      
      #battery.critical:not(.charging) {
        color: #f7768e;
      }
    '';
  };

  # --------------------------------------------------
  # Foot Terminal Configuration
  # --------------------------------------------------
  xdg.configFile."foot/foot.ini" = {
    text = ''
      [main]
      font=JetBrainsMono Nerd Font:size=13
      term=foot
      pad=10x10
      shell=${pkgs.zsh}/bin/zsh
      
      [colors]
      background=1a1b26
      foreground=c0caf5
      
      regular0=1a1b26
      regular1=f7768e
      regular2=9ece6a
      regular3=e0af68
      regular4=7aa2f7
      regular5=bb9af7
      regular6=7dcfff
      regular7=a9b1d6
      
      bright0=414868
      bright1=f7768e
      bright2=9ece6a
      bright3=e0af68
      bright4=7aa2f7
      bright5=bb9af7
      bright6=7dcfff
      bright7=c0caf5
      
      [cursor]
      style=beam
      color=c0caf5
    '';
  };

  # --------------------------------------------------
  # Mako Configuration
  # --------------------------------------------------
  xdg.configFile."mako/config" = {
    text = ''
      # Mako notification daemon configuration
      default-timeout=5000
      width=300
      height=100
      margin=10
      padding=10
      border-size=1
      border-color=#a9b1d6
      background-color=#1a1b26
      text-color=#c0caf5
      progress-color=overlay
      font=JetBrainsMono Nerd Font 10
      max-visible=5
      layer=overlay
      anchor=top-right
      
      [urgency=low]
      default-timeout=3000
      
      [urgency=normal]
      default-timeout=5000
      
      [urgency=high]
      default-timeout=0
      background-color=#f7768e
      text-color=#1a1b26
    '';
  };

  # --------------------------------------------------
  # Alacritty configuration
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
    wl-clipboard     # Clipboard utilities
    grim             # Screenshot utility
    slurp            # Region selection for screenshots
    wmenu            # Application launcher (dmenu replacement)
    wlsunset         # Day/night color temperature (redshift replacement)
    
    # System utilities
    pavucontrol      # Audio control
    networkmanagerapplet  # Network manager applet
    
    # Optional utilities
    libnotify        # For sending notifications
    mako             # Notification daemon
    waybar           # Status bar
    foot             # Terminal emulator
    
    # For screenshots with grim
    swappy           # Screenshot editor
    
    # Clipboard history
    cliphist         # Clipboard history manager
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
