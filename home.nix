{ config, pkgs, ... }:
{
  home.username = "mg";
  home.homeDirectory = "/home/mg";
  programs.git = {
    enable = true;
    userName = "Dmitriy L";
    userEmail = "xhaustlesss@gmail.com";
    # You can add aliases, ignores, and other settings here
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
    # Use extraConfig for arbitrary git config key-value pairs
    extraConfig = {
      pull.rebase = "false";
      init.defaultBranch = "main";
    };
  };

  services.ssh-agent.enable = true;
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github" = {
        user = "mg";
	identityFile = "~/.ssh/id_ed25519_github"; # Specify the key file
        identitiesOnly = true; # Only use the keys specified here
      };
      #"work-server" = {
      #  hostName = "192.168.1.10";
      #  user = "myuser";
      #  identityFile = "~/.ssh/id_rsa_work";
      #};
    };
    # You can also add arbitrary configuration lines
    extraConfig = ''
      Host *
        ForwardAgent yes
    '';
  };

  home.stateVersion = "25.11";
  programs.bash = {
    enable = true;
  };
}

