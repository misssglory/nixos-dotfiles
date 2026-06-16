{ lib
, stdenv
, pkg-config
, wayland
, wayland-protocols
, wlroots
, libinput
, xwayland
, libX11
, wayland-scanner
, scdoc
, xorg
, libxkbcommon
, pixman
, src
, enableXWayland ? true
}:

stdenv.mkDerivation {
  pname = "dwl";
  version = "0.7-unstable-2026-05-06";  # Update version to reflect newer commit
  
  inherit src;
  
  nativeBuildInputs = [
    pkg-config
    wayland-scanner
    scdoc
  ];
  
  buildInputs = [
    wayland
    wayland-protocols
    wlroots  # Now uses wlroots 0.19+ from nixpkgs
    libinput
    libxkbcommon
    pixman
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilwm
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilcursor
  ] ++ lib.optionals enableXWayland [
    libX11
    xwayland
  ];
  
  preConfigure = ''
    # Copy config.h if needed
    if [ ! -f config.h ] && [ -f config.def.h ]; then
      cp config.def.h config.h
    fi
    
    # For wlroots 0.19+, the pkg-config name is just "wlroots"
    # No need for wlroots-0.18.pc symlink anymore
    
    # Set PKG_CONFIG_PATH
    export PKG_CONFIG_PATH="${wlroots}/lib/pkgconfig:${xorg.libxcb}/lib/pkgconfig:${libxkbcommon}/lib/pkgconfig:${pixman}/lib/pkgconfig:$PKG_CONFIG_PATH"
    
    echo "=== Testing dependencies ==="
    pkg-config --modversion wlroots 2>/dev/null || echo "wlroots not found"
    pkg-config --modversion pixman-1 2>/dev/null || echo "pixman-1 not found"
  '';
  
  makeFlags = [
    "PREFIX=${placeholder "out"}"
  ] ++ lib.optionals enableXWayland [
    "XWAYLAND=-DXWAYLAND"
  ];
  
  NIX_CFLAGS_COMPILE = [
    "-I${wlroots}/include"
    "-I${libinput}/include/libinput"
    "-I${xorg.libxcb}/include"
    "-I${libxkbcommon}/include"
    "-I${pixman}/include/pixman-1"
  ];
  
  meta = with lib; {
    description = "dwl with custom patches (updated for wlroots 0.19+)";
    homepage = "https://github.com/djpohly/dwl";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    # Add maintainer if needed
  };
}