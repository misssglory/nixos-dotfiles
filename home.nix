{ config, pkgs, ... }:


let
  wccSrc = pkgs.fetchFromGitHub {
    owner = "misssglory";
    repo = "wcc";
    rev = "68234a9b72a90196e4df6924cbdf9b121ce945ea";
    sha256 = "sha256-3Ls2y+AAnETTC2r8BOV8OSgjJavriOECw9jTaKyjUBY=";
  };

  wccPkg = pkgs.rustPlatform.buildRustPackage {
    pname = "wcc";
    version = "0.1.0";
    src = wccSrc;

    cargoLock = {
      lockFile = "${wccSrc}/Cargo.lock";
    };
  };

  cliphistFuzzelRich = pkgs.rustPlatform.buildRustPackage {
    pname = "cliphist-fuzzel-rich";
    version = "0.1.0";
    src = ./cliphist-fuzzel-rich-rs;
    cargoLock.lockFile = ./cliphist-fuzzel-rich-rs/Cargo.lock;
  };
in
{
  imports = [
    ./modules/neovim.nix
  ];
  home.username = "mg";
  home.homeDirectory = "/home/mg";

  programs.git = {
    enable = true;
    userName = "Dmitriy L";
    userEmail = "xhaustlesss@gmail.com";
    ignores = [
      "*.swp"
      ".DS_Store"
    ];
    extraConfig = {
      pull.rebase = "false";
      init.defaultBranch = "main";
    };
  };

  services.ssh-agent.enable = true;

  home.shellAliases = {
    proxy-on = ''
      export http_proxy="http://localhost:8080"
      export https_proxy="http://localhost:8080"
      export HTTP_PROXY="http://localhost:8080"
      export HTTPS_PROXY="http://localhost:8080"
      export all_proxy="socks5://localhost:1080"
      export ALL_PROXY="socks5://localhost:1080"
      echo "Proxy enabled"
    '';
    proxy-off = ''
      unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
      echo "Proxy disabled"
    '';
    proxy-status = ''
      echo "HTTP_PROXY: $HTTP_PROXY"
      echo "HTTPS_PROXY: $HTTPS_PROXY"
      echo "ALL_PROXY: $ALL_PROXY"
    '';
    ga  = "git add -v";
    gb  = "git branch";
    gc  = "git commit -m";
    gca = "git commit --amend --no-edit";
    gcam = "git commit --amend -m";
    gch = "git checkout";
    gd  = "git diff -w";
    gds = "git diff -w --staged";
    gl  = "git log";
    gp  = "git push origin";
    gpf = "git push origin --force";
    gra = "git rebase --abort";
    grb = "git rebase";
    grc = "git rebase --continue";
    grh = "git reset --hard";
    gri = "git rebase -i";
    grs = "git reset";
    gst = "git stash";
    gsp = "git stash pop";
    gs  = "git status";
    gdc = "git diff -w -G'(^[^\\*# /])|(^#\\w)|(^\\s+[^\\*#/])'";
    ls = "lsd";
    cb = "wcc build";
    cr = "wcc run";
  };
  
  # Add proxy toggle function
  home.file.".local/bin/proxy-toggle" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      if systemctl is-active --quiet xray-client; then
        echo "Stopping Xray proxy..."
        systemctl stop xray-client
      else
        echo "Starting Xray proxy..."
        systemctl start xray-client
      fi
    '';
  };

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

    cliphist-watcher = {
      Unit = {
        Description = "Cliphist clipboard watcher";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
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
      Wants = [ "waybar.service" "mako.service" "cliphist-watcher.service" "ssh-add-keys" ];
    };
  };

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
      if ! ssh-add -l 2>/dev/null | grep -q 25519; then
        echo "Loading SSH keys..."
        for key in ~/.ssh/*25519*; do
          if [[ -f "$key" && "$key" != *.pub ]]; then
            ssh-add "$key"
          fi
        done
      fi

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

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

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

  home.file.".config/waybar" = {
    source = pkgs.fetchFromGitHub {
      owner = "misssglory";  # Replace with your GitHub username
      repo = "waybar-config";   # Replace with your repo name
      rev = "b39c27b33ba8e87425dc4b4ac3d31c5c485134ea";             # Replace with the branch or commit hash
      sha256 = "sha256-aRPLEZp0nQDoTD73JXgbFf72asdToAl+wtHitQ1k8xI=";  # Replace with actual hash after first build
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
    cliphist
    xray
    mpv
    wccPkg
    cliphistFuzzelRich

    (pkgs.writeShellScriptBin "chromium-proxychains" ''
      exec ${pkgs.proxychains}/bin/proxychains4 \
        ${pkgs.ungoogled-chromium}/bin/chromium \
        --user-data-dir="$HOME/.config/chromium-proxychains" \
        "$@"
    '')
  ];

  home.file.".local/bin/xray-proxy" = {
    executable = true;
    text = ''
      #!/bin/bash
      # Quick proxy toggle script
      if systemctl is-active --quiet xray-client; then
        echo "Stopping Xray client..."
        systemctl stop xray-client
      else
        echo "Starting Xray client..."
        systemctl start xray-client
      fi
    '';
  };

  programs.bash = {
    enable = true;
  };
  
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "/home/mg/nixos-dotfiles/config/nvim";
    recursive = true;
  };

  xdg.configFile."fuzzel" = {
    source = config.lib.file.mkOutOfStoreSymlink "/home/mg/nixos-dotfiles/config/fuzzel";
    recursive = true;
  };

  xdg.desktopEntries = {
    ungoogled-chromium-proxychains = {
      name = "Chromium (Proxy)";
      genericName = "Web Browser via Proxychains";
      exec = "chromium-proxychains %U";
      icon = "chromium";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" "application/xhtml+xml" ];
    };
  };

  home.stateVersion = "25.11";
}
