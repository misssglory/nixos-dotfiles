{ config, pkgs, unstable, ocr-text, ... }:

let
  system =
    pkgs.stdenv.hostPlatform.system;

  ocrTextScreenshot =
    ocr-text.packages.${system}.screenshot-ocr;

  wccSrc = pkgs.fetchFromGitHub {
    owner = "misssglory";

    repo = "wcc";

    rev =
      "2ae68fb2b4b1dbfdcaf1dc89157086182bc16fb3";

    sha256 =
      "sha256-fR2IcUFofHZJ5IkyZDn5J9XHReH/ExtbHGSLsWfE0mY=";
  };

  wccPkg =
    pkgs.rustPlatform.buildRustPackage {
      pname = "wcc";

      version = "0.1.0";

      src = wccSrc;

      cargoLock.lockFile =
        "${wccSrc}/Cargo.lock";
    };

  # erc20RiskGateSrc = pkgs.fetchFromGitHub {
  #   owner = "misssglory";
  #   repo = "erc20-risk-gate";
  #   rev = "b6cc51c5dcaf1a47951b55077df86477bf25981c";
  #   sha256 = "sha256-/00lecZ19a3kJWtsSfyMrIMCsIihQTS0z2pTlU0Qp+U=";
  # };

  # erc20RiskGate = pkgs.rustPlatform.buildRustPackage {
  #   pname = "erc20-risk-gate";
  #   version = "0.1.0";
  #   src = erc20RiskGateSrc;
  #   cargoLock.lockFile = "${erc20RiskGateSrc}/Cargo.lock";
  # };

  cliphistFuzzelRichSrc =
    pkgs.fetchFromGitHub {
      owner = "misssglory";

      repo =
        "cliphist-fuzzel-rich-rs";

      rev =
        "a1919ace41064d7f45b3f7faeaab1061dccef4d0";

      sha256 =
        "sha256-Abi2CnWUTZwpOIwcM2kfR5FTbqlVrooBYSv4EjKb2js=";
    };

  cliphistFuzzelRich =
    pkgs.rustPlatform.buildRustPackage {
      pname =
        "cliphist-fuzzel-rich";

      version =
        "0.1.0";

      src =
        cliphistFuzzelRichSrc;

      cargoLock.lockFile =
        "${cliphistFuzzelRichSrc}/Cargo.lock";
    };

in
{
  imports = [
    ./modules/neovim.nix
  ];

  home.username =
    "mg";

  home.homeDirectory =
    "/home/mg";

  programs.git = {
    enable =
      true;

    userName =
      "Dmitriy L";

    userEmail =
      "xhaustlesss@gmail.com";

    ignores = [
      "*.swp"
      ".DS_Store"
    ];

    aliases = {
      co =
        "checkout";
    };

    extraConfig = {
      pull.rebase =
        "false";

      init.defaultBranch =
        "main";
    };
  };

  services.ssh-agent.enable =
    true;


  xdg.configFile."hypr/hyprland.conf" = {
    source = ./config/hypr/hyprland.conf;
    force = true;
  };

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

    ga =
      "git add -v";

    gb =
      "git branch";

    gc =
      "git commit -m";

    gca =
      "git commit --amend --no-edit";

    gcam =
      "git commit --amend -m";

    gch =
      "git checkout";

    gd =
      "git diff -w";

    gds =
      "git diff -w --staged";

    gl =
      "git log";

    gp =
      "git push origin";

    gpf =
      "git push origin --force";

    gra =
      "git rebase --abort";

    grb =
      "git rebase";

    grc =
      "git rebase --continue";

    grh =
      "git reset --hard";

    gri =
      "git rebase -i";

    grs =
      "git reset";

    gst =
      "git stash";

    gsp =
      "git stash pop";

    gs =
      "git status";

    gdc =
      "git diff -w -G'(^[^\\\\*# /])|(^#\\\\w)|(^\\\\s+[^\\\\*#/])'";

    ls =
      "lsd";

    cb =
      "wcc build";

    cr =
      "wcc run";

    crr =
      "cargo run -r";

    crd =
      "cargo run";

    cbd =
      "cargo build";

    cbb =
      "cargo build -r";

    pc4 =
      "proxychains4";

    cp =
      "cp -v";

    mv =
      "mv -v";

    rm =
      "rm -v";
  };

  home.file.".local/bin/proxy-toggle" = {
    executable =
      true;

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
    enable =
      true;

    enableZshIntegration =
      true;

    enableBashIntegration =
      true;
  };

  programs.fzf = {
    enable =
      true;

    enableZshIntegration =
      true;

    enableBashIntegration =
      true;

    defaultOptions = [
      "--height=100%"
      "--border"
    ];
  };

  systemd.user.services = {
    waybar = {
      Unit = {
        Description =
          "Waybar status bar";

        PartOf =
          "graphical-session.target";

        After =
          "graphical-session.target";
      };

      Service = {
        ExecStart =
          "${pkgs.waybar}/bin/waybar";

        Restart =
          "on-failure";

        RestartSec =
          1;
      };

      Install = {
        WantedBy = [
          "graphical-session.target"
        ];
      };
    };

    mako = {
      Unit = {
        Description =
          "Mako notification daemon";

        PartOf =
          "graphical-session.target";

        After =
          "graphical-session.target";
      };

      Service = {
        ExecStart =
          "${pkgs.mako}/bin/mako";

        Restart =
          "on-failure";

        RestartSec =
          1;
      };

      Install = {
        WantedBy = [
          "graphical-session.target"
        ];
      };
    };

    cliphist-watcher = {
      Unit = {
        Description =
          "Cliphist clipboard watcher";

        After = [
          "graphical-session.target"
        ];

        PartOf = [
          "graphical-session.target"
        ];
      };

      Service = {
        Type =
          "exec";

        ExecStart =
          "${pkgs.bash}/bin/bash -lc '${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store'";

        Restart =
          "on-failure";
      };

      Install = {
        WantedBy = [
          "graphical-session.target"
        ];
      };
    };
  };

  systemd.user.targets.graphical-session = {
    Unit = {
      Description =
        "Graphical session";

      Wants = [
        "waybar.service"
        "mako.service"
        "cliphist-watcher.service"
      ];
    };
  };

  # programs.vscode = {
  #   enable = true;
  #
  #   extensions = with pkgs.vscode-extensions; [
  #     dracula-theme.theme-dracula
  #     vscodevim.vim
  #     yzhang.markdown-all-in-one
  #   ];
  # };

  programs.zsh = {
    enable =
      true;

    enableCompletion =
      true;

    autosuggestion.enable =
      true;

    syntaxHighlighting.enable =
      true;

    oh-my-zsh = {
      enable =
        true;

      plugins = [
        "git"
      ];

      theme =
        "robbyrussell";
    };

    plugins = [
      {
        name =
          "fzf-zsh-plugin";

        src =
          pkgs.zsh-fzf-tab;

        file =
          "share/fzf-tab/fzf-tab.plugin.zsh";
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

      if [ -f "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme" ]; then
        source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
      fi
    '';

    initExtra = ''
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      eval "$(zoxide init zsh)"

      export XDG_CURRENT_DESKTOP=wlroots
      export XDG_SESSION_TYPE=wayland
      export QT_QPA_PLATFORM=wayland
      export SDL_VIDEODRIVER=wayland
      export CLUTTER_BACKEND=wayland
      export _JAVA_AWT_WM_NONREPARENTING=1

      if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        systemctl --user start graphical-session.target

        # exec dwl
      fi
    '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # home.file.".config/dwl/autostart.sh" = {
  #   executable = true;
  #
  #   text = ''
  #     #!/bin/bash
  #
  #     ${pkgs.dbus}/bin/dbus-update-activation-environment \
  #       --systemd \
  #       WAYLAND_DISPLAY \
  #       XDG_CURRENT_DESKTOP=wlroots
  #   '';
  # };

  home.file.".config/waybar" = {
    source =
      pkgs.fetchFromGitHub {
        owner =
          "misssglory";

        repo =
          "waybar-config";

        rev =
          "b39c27b33ba8e87425dc4b4ac3d31c5c485134ea";

        sha256 =
          "sha256-aRPLEZp0nQDoTD73JXgbFf72asdToAl+wtHitQ1k8xI=";
      };

    recursive =
      true;
  };

  programs.alacritty = {
    enable =
      true;

    settings = {
      window = {
        opacity =
          0.5;

        decorations =
          "full";

        dynamic_title =
          true;
      };

      font = {
        normal = {
          family =
            "JetBrainsMono Nerd Font";

          style =
            "Regular";
        };

        size =
          13.0;
      };

      colors = {
        primary = {
          background =
            "0x000000";

          foreground =
            "0xcdd6f4";
        };

        normal = {
          black =
            "0x45475a";

          red =
            "0xf38ba8";

          green =
            "0xa6e3a1";

          yellow =
            "0xf9e2af";

          blue =
            "0x89b4fa";

          magenta =
            "0xf5c2e7";

          cyan =
            "0x94e2d5";

          white =
            "0xbac2de";
        };

        bright = {
          black =
            "0x585b70";

          red =
            "0xf38ba8";

          green =
            "0xa6e3a1";

          yellow =
            "0xf9e2af";

          blue =
            "0x89b4fa";

          magenta =
            "0xf5c2e7";

          cyan =
            "0x94e2d5";

          white =
            "0xa6adc8";
        };
      };

      cursor = {
        style =
          "Beam";
      };

      terminal.shell = {
        program =
          "${pkgs.zsh}/bin/zsh";
      };
    };
  };

  home.packages =
    with pkgs;
    [
      #
      # OCR screenshot command from GitHub.
      #
      ocrTextScreenshot

      wl-clipboard

      grim

      slurp

      wmenu

      wlsunset

      pavucontrol

      networkmanagerapplet

      libnotify

      mako

      waybar

      foot

      swappy

      cliphist

      mpv

      wccPkg

      # erc20RiskGate

      cliphistFuzzelRich

      (
        pkgs.writeShellScriptBin
          "chromium-proxy"
          ''
            exec ${pkgs.ungoogled-chromium}/bin/chromium \
              --proxy-server="socks5://localhost:1080" \
              --user-data-dir="$HOME/.config/chromium-proxy" \
              --no-default-browser-check \
              "$@"
          ''
      )

      (
        pkgs.writeShellScriptBin
          "chromium-regular"
          ''
            exec ${pkgs.ungoogled-chromium}/bin/chromium \
              --user-data-dir="$HOME/.config/chromium" \
              --no-default-browser-check \
              "$@"
          ''
      )
    ];

  programs.zed-editor = {
    enable =
      true;

    package =
      unstable.zed-editor;

    # settings = { ... };
  };

  home.file.".local/bin/xray-proxy" = {
    executable =
      true;

    text = ''
      #!/bin/bash

      if systemctl is-active --quiet xray-client; then
        echo "Stopping Xray client..."

        systemctl stop xray-client
      else
        echo "Starting Xray client..."

        systemctl start xray-client
      fi
    '';
  };

  programs.bash.enable =
    true;

  xdg.configFile."fuzzel/fuzzel.ini" = {
    source =
      "${cliphistFuzzelRichSrc}/fuzzel.ini";
  };

  xdg.configFile."cliphist/config" = {
    source = ./config/cliphist/config;
    force = true;
  };


  xdg.desktopEntries = {
    ungoogled-chromium-proxy = {
      name =
        "Chromium Proxy";

      genericName =
        "Web Browser with SOCKS5 Proxy";

      exec =
        "chromium-proxy %U";

      icon =
        "chromium";

      terminal =
        false;

      categories = [
        "Network"
        "WebBrowser"
      ];

      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];

      startupNotify =
        true;
    };

    ungoogled-chromium-direct = {
      name =
        "Chromium Direct";

      genericName =
        "Web Browser without Proxy";

      exec =
        "chromium-regular %U";

      icon =
        "chromium";

      terminal =
        false;

      categories = [
        "Network"
        "WebBrowser"
      ];

      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];

      startupNotify =
        true;
    };
  };

  home.stateVersion =
    "26.05";
}
