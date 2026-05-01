{ lib
, rustPlatform
, fetchCrate
, pkg-config
, systemd
, openssl
, perl
, llvmPackages
, protobuf
}:

let
  libclang = llvmPackages.libclang;
in
rustPlatform.buildRustPackage rec {
  pname = "spl-token-cli";
  version = "5.5.0";

  src = fetchCrate {
    inherit pname version;
    sha256 = "sha256-XRcDStuNijexsdinMFhYvNcnpyvD0zyZIOm6OpgwjuA=";
  };

  cargoHash = "sha256-DlX7fW9qZlBTU9boXZ5++E45I/+GdqX6dnogmYjTrsk=";

  nativeBuildInputs = [
    pkg-config
    perl
    llvmPackages.libclang
    protobuf
  ];

  buildInputs = [
    systemd
    openssl
  ];

  LIBCLANG_PATH    = "${lib.getLib llvmPackages.libclang}/lib";
  LLVM_CONFIG_PATH = "${lib.getBin llvmPackages.libclang}/bin/llvm-config";
  PROTOC           = "${protobuf}/bin/protoc";

  cargoDepsName = pname;

  # Important: don't run the CLI's tests inside the Nix build
  doCheck = false;
}