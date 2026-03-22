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
    '';
  };

  # If you want Home Manager to manage ~/.p10k.zsh itself,
  # you can later add something like:
  # xdg.configFile."p10k/p10k.zsh".source = ./p10k.zsh;

  home.packages = [
   # pkgs.xclip
  ];

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
  # Shells
  # --------------------------------------------------
  programs.bash = {
    enable = true;
  };
  xdg.configFile."nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "/home/tony/nixos-dotfiles/config/nvim";
      recursive = true;
  };

  home.stateVersion = "25.11";
}

