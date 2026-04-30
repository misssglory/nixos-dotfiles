# modules/neovim.nix
{ config, pkgs, lib, ... }:

let
  # Neovim configuration repo (NOT a folder in this flake).
  # Repo layout should be exactly what you want under ~/.config/nvim
  # (init.lua, lua/, etc at the top level).
  nvimConfigSrc = pkgs.fetchFromGitHub {
    owner = "misssglory";
    repo  = "nvim";          # <- your Neovim repo name
    rev   = "127c723a048f5c49fced4ff9d6b9e4cca711c214";           # <- pin a commit hash
    sha256 = "sha256-K/10kaOH/lymXgeTxK2Zvy3Lkb3upMftJAPAERK6nQ8=";
  };
in
{
  # Install Neovim and dependencies
  home.packages = with pkgs; [
    # Tools required for Telescope
    ripgrep
    fd
    fzf

    # Language Servers
    lua-language-server
    nil # nix language server
    nixpkgs-fmt # nix formatter

    # Needed for lazy.nvim
    nodejs
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;

    # You still let lazy.nvim manage plugins in the repo.
    # If you ever switch to Nix-managed plugins, you can use `plugins = ...` here.
  };

  # Put Neovim repo into ~/.config/nvim
  xdg.configFile."nvim" = {
    source = nvimConfigSrc;
    recursive = true;
  };
}
