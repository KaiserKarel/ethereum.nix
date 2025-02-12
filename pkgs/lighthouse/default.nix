{
  clang,
  cmake,
  fetchFromGitHub,
  fetchurl,
  lib,
  llvmPackages,
  openssl,
  sqlite,
  rust-jemalloc-sys,
  protobuf,
  rustPlatform,
  postgresql,
  foundry,
}: let
  slasherContractVersion = "0.12.1";
  slasherContractSrc = fetchurl {
    url = "https://raw.githubusercontent.com/ethereum/eth2.0-specs/v${slasherContractVersion}/deposit_contract/contracts/validator_registration.json";
    sha256 = "sha256-ZslAe1wkmkg8Tua/AmmEfBmjqMVcGIiYHwi+WssEwa8=";
  };

  slasherContractTestVersion = "0.9.2.1";
  slasherContractTestnetSrc = fetchurl {
    url = "https://raw.githubusercontent.com/sigp/unsafe-eth2-deposit-contract/v${slasherContractTestVersion}/unsafe_validator_registration.json";
    sha256 = "sha256-aeTeHRT3QtxBRSNMCITIWmx89vGtox2OzSff8vZ+RYY=";
  };
in
  rustPlatform.buildRustPackage rec {
    pname = "lighthouse";
    version = "4.6.0";

    src = fetchFromGitHub {
      owner = "sigp";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-uMrVnVvYXcY2Axn3ycsf+Pwur3HYGoOYjjUkGS5c3l4=";
    };

    patches = [
      ./use-c-kzg-from-crates-io.patch
      ./use-system-sqlite.patch
    ];

    postPatch = ''
      cp ${./Cargo.lock} Cargo.lock
    '';

    cargoLock = {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "amcl-0.3.0" = "sha256-kc8k/ls4W0TwFBsRcyyotyz8ZBEjsZXHeJnJtsnW/LM=";
        "discv5-0.4.0" = "sha256-GKAk9Du6fy0ldeBEwPueDbVPhyNxdKNROKpMJvR/OTc=";
        "futures-bounded-0.2.3" = "sha256-/LbD+je9P1lPnXMJVDqRQHJziQPXPvSDmQadTfsQ5I8=";
        "libmdbx-0.1.4" = "sha256-NMsR/Wl1JIj+YFPyeMMkrJFfoS07iEAKEQawO89a+/Q=";
        "lmdb-rkv-0.14.0" = "sha256-sxmguwqqcyOlfXOZogVz1OLxfJPo+Q0+UjkROkbbOCk=";
        "warp-0.3.6" = "sha256-knDt2aw/PJ0iabhKg+okwwnEzCY+vQVhE7HKCTM6QbE=";
      };
    };

    enableParallelBuilding = true;

    cargoBuildFlags = ["--package lighthouse"];

    nativeBuildInputs = [cmake clang];
    buildInputs = [openssl protobuf sqlite rust-jemalloc-sys];

    buildNoDefaultFeatures = true;
    buildFeatures = ["modern" "slasher-lmdb"];

    # Needed to get openssl-sys to use pkg-config.
    OPENSSL_NO_VENDOR = 1;
    OPENSSL_LIB_DIR = "${lib.getLib openssl}/lib";
    OPENSSL_DIR = "${lib.getDev openssl}";

    # Needed to get prost-build to use protobuf
    PROTOC = "${protobuf}/bin/protoc";

    # Needed by libmdx
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

    # common crate tries to fetch the compiled version from an URL
    # see: https://github.com/sigp/lighthouse/blob/stable/common/deposit_contract/build.rs#L30
    LIGHTHOUSE_DEPOSIT_CONTRACT_SPEC_URL = "file:${slasherContractSrc}";

    # common crate tries to fetch the compiled version from an URL
    # see: https://github.com/sigp/lighthouse/blob/stable/common/deposit_contract/build.rs#L33
    LIGHTHOUSE_DEPOSIT_CONTRACT_TESTNET_URL = "file:${slasherContractTestnetSrc}";

    # This is needed by the unit tests.
    FORK_NAME = "capella";

    cargoTestFlags = [
      "--workspace"
      "--exclude beacon_chain"
      "--exclude beacon_node"
      "--exclude http_api"
      "--exclude lighthouse"
      "--exclude lighthouse_network"
      "--exclude network"
      "--exclude slashing_protection"
      "--exclude watch"
      "--exclude web3signer_tests"
    ];

    nativeCheckInputs = [
      postgresql
      foundry
    ];

    checkFeatures = [];

    # All of these tests require network access
    checkFlags = [
      "--skip service::tests::tests::test_dht_persistence"
      "--skip time::test::test_reinsertion_updates_timeout"
    ];

    meta = {
      description = "Ethereum consensus client in Rust";
      homepage = "https://github.com/sigp/lighthouse";
      mainProgram = "lighthouse";
      platforms = ["x86_64-linux"];
    };
  }
