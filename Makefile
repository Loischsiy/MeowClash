android_arm64:
	dart ./setup.dart android --arch arm64
macos_arm64:
	dart ./setup.dart macos --arch arm64
android_app:
	dart ./setup.dart android
android_arm64_core:
	dart ./setup.dart android --arch arm64 --out core
macos_arm64_core:
	dart ./setup.dart macos --arch arm64  --out core


macLocal:
	rm -rf dist
	rm -rf build
	dart ./setup.dart macos --arch arm64 --env stable

macLocal_amd64:
	rm -rf dist
	rm -rf build
	dart ./setup.dart macos --arch amd64 --env stable


notarizeLocal:
	DMG_FILE=$$(ls dist/MeowClash-*.dmg) && \
	echo "Found DMG: $$DMG_FILE" && \
	xcrun notarytool submit "$$DMG_FILE" --keychain-profile "meowclash-notarization" --wait && \
	xcrun stapler staple "$$DMG_FILE" && \
	xcrun stapler validate "$$DMG_FILE"

cleanLocal:
	rm -rf dist
	rm -rf build


# ---- NixOS verification ----
# nixCheck is fast (evaluation only); nixTest boots real NixOS VMs and needs KVM.
nixCheck:
	nix flake check --no-build --show-trace

nixCore:
	nix build .#core -L

nixBuild:
	nix build .#meowclash -L

nixTest:
	nix build .#checks.x86_64-linux.nixos-vm -L

nixAll: nixCheck nixCore nixBuild nixTest