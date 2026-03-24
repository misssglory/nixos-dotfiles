# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos-btw"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # X11 and Wayland setup
  # Enable X11 server for XWayland compatibility only
  services.xserver = {
    enable = true;  # Required for XWayland
    # Disable X11 window managers since we're using Wayland
    # autoRepeatDelay = 200;
    # autoRepeatInterval = 35;
    # windowManager.i3.enable = true; # Disable i3 when using dwl
  };
  
  # Enable display manager (ly supports both X11 and Wayland)
  services.displayManager.ly.enable = true;
  
  # Optional: Enable other display managers if needed
  # services.displayManager.sddm.enable = true;
  # services.displayManager.sddm.wayland.enable = true;

  # Enable seat management for Wayland
  services.seatd.enable = true;
  
  # Configure XWayland
  # No need to set services.xserver.enable again - it's already set above
  # services.xserver.displayManager.gdm.wayland = false; # Remove this unless using GDM

# Enable Podman in configuration.nix
virtualisation.podman = {
  enable = true;
  # Create the default bridge network for podman
  defaultNetwork.settings.dns_enabled = true;
};

# Optionally, create a Docker compatibility alias
#programs.zsh.shellAliases = {
#  docker = "podman";
#};
  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound with PipeWire (Wayland-friendly)
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    # Enable JACK if needed
    jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;
  # Enable libinput for touchpad support in Wayland
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "seat" ]; # Add needed groups for Wayland
    packages = with pkgs; [
      tree
    ];
  };

  # programs.firefox.enable = true;
  hardware.graphics.enable = true; # Required for GPU access
  hardware.amdgpu.opencl.enable = true;
  hardware.opengl.enable = true;
  # hardware.opengl.extraPackages = [ pkgs.rocm-opencl-icd ];

  programs.nix-ld.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    aria2
    git
    alacritty
    ripgrep
    fd
    zellij
    fzf
    telegram-desktop
    brightnessctl    
    ungoogled-chromium
    lazygit
    rocmPackages.clr
    rocmPackages.hipblas
    btop
    stdenv.cc.cc.lib
    glibc
    nix-index
    # xclip - Replace with Wayland clipboard tools
    wl-clipboard  # Wayland clipboard utility
    # Additional Wayland utilities
    grim          # Screenshot utility for Wayland
    slurp         # Region selection for Wayland
    swaybg        # Wallpaper utility for Wayland
    waybar        # Status bar for Wayland
    mako          # Notification daemon for Wayland
    wmenu         # Application launcher for Wayland (dmenu replacement)
    foot          # Terminal emulator for Wayland
    # redshift - Use wlsunset for Wayland instead
    wlsunset      # Day/night gamma adjustments for Wayland
  ];

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  networking.wg-quick.interfaces.lithuania = {
    configFile = "/etc/nixos/files/wireguard/lithuania.conf";
    autostart = false;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  services.openssh.enable = true;
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true#;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment3?
}