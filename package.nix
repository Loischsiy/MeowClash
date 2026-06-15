{ lib
, stdenv
, buildGoModule
, flutter
, makeDesktopItem
, copyDesktopItems
, autoPatchelfHook
, libcap
, which
}:

let
  version = "0.4.0";

  # Core Go binary
  meowclash-core = buildGoModule {
    pname = "meowclash-core";
    inherit version;

    src = ./core;

    vendorHash = "sha256-n6L4R67eBwHqIq+lY0U21t0nU+V/d++jL6x3I42B28c=";

    CGO_ENABLED = 0;

    ldflags = [
      "-s" "-w"
    ];

    meta = with lib; {
      description = "MeowClash core component";
      homepage = "https://github.com/Loischsiy/MeowClash";
      license = licenses.gpl3Only;
      maintainers = [ ];
    };
  };

  # GUI Flutter application
  meowclash-gui = flutter.buildFlutterApplication {
    pname = "meowclash-gui";
    inherit version;

    src = ./.;

    autoPubspecLock = ./pubspec.lock;

    nativeBuildInputs = [
      autoPatchelfHook
      copyDesktopItems
    ];

    buildInputs = [
      libcap
      which
    ];

    desktopItems = [
      (makeDesktopItem {
        name = "meowclash";
        exec = "meowclash";
        icon = "meowclash";
        desktopName = "MeowClash";
        genericName = "Proxy Client";
        categories = [ "Network" "Utility" ];
        keywords = [ "MeowClash" "Clash" "ClashMeta" "Proxy" ];
        startupNotify = true;
      })
    ];

    postInstall = ''
      # Install icons
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp assets/images/icon.png $out/share/icons/hicolor/512x512/apps/meowclash.png

      # Wrapper that includes core in PATH
      mkdir -p $out/bin
      mv $out/app/meowclash $out/app/meowclash-unwrapped

      cat > $out/bin/meowclash <<WEF
      #!/bin/sh
      # If security.wrappers is used, MeowClashCore will be in /run/wrappers/bin
      # We check if it exists there, and if not, fallback to the one from our package
      export PATH="/run/wrappers/bin:${meowclash-core}/bin:\$PATH"
      exec $out/app/meowclash-unwrapped "\$@"
      WEF

      chmod +x $out/bin/meowclash
    '';

    passthru = {
      core = meowclash-core;
    };

    meta = with lib; {
      description = "Fork multi-platform proxy client MeowClash based on ClashMeta, simple and easy to use, open-source and ad-free.";
      homepage = "https://github.com/Loischsiy/MeowClash";
      license = licenses.gpl3Only;
      maintainers = [ ];
    };
  };
in
meowclash-gui
