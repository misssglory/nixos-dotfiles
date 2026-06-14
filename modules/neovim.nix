{ config, pkgs, lib, ... }:

let
  # Neovim configuration repo (NOT a folder in this flake).
  # Repo layout should be exactly what you want under ~/.config/nvim
  # (init.lua, lua/, etc at the top level).
  nvimConfigSrc = pkgs.fetchFromGitHub {
    owner = "misssglory";
    repo  = "nvim";
    rev   = "b05cf85ac9967d32b67cef1fd74ce263ec488467";
    sha256 = "sha256-DZPS9YDgX1+sGRMJ8vstNrGbwvp0WfD0Qx/gIDMO+eY=";
  };
in
{
  # Install Neovim and dependencies
  home.packages = with pkgs; [
    # Tools required for Telescope / pickers
    ripgrep
    fd
    fzf

    # Extra tooling that helps fff.nvim (but *not* cargo/rustc here;
    # they already come from environment.systemPackages)
    git

    # Language Servers
    lua-language-server
    nil # nix language server
    nixpkgs-fmt # nix formatter

    # Needed for your Neovim plugin ecosystem (node-based stuff)
    nodejs
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;

    # You still let your custom manager manage plugins in the repo.
    # If you ever switch to Nix-managed plugins, you can use `plugins = ...` here.
  };

  # Put Neovim repo into ~/.config/nvim
  xdg.configFile."nvim" = {
    source = nvimConfigSrc;
    recursive = true;
  };
}
