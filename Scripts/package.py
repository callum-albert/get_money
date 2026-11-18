"""Minimal IPA bundling using Python stdlib; no third-party build dependencies."""
import sys
import plistlib
import zipfile
from pathlib import Path


def metadata(app, version, deploy):
    app = Path(app)
    for extension in (False, True):
        root = app / "PlugIns/EarningsWidgetExtension.appex" if extension else app
        executable = "EarningsWidgetExtension" if extension else "TodayEarnings"
        info = {
            "CFBundleDevelopmentRegion": "zh_CN",
            "CFBundleDisplayName": "今日进账",
            "CFBundleExecutable": executable,
            "CFBundleIdentifier": "com.callum.TodayEarnings.widget" if extension else "com.callum.TodayEarnings",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": executable,
            "CFBundlePackageType": "XPC!" if extension else "APPL",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "1",
            "MinimumOSVersion": deploy,
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "UIDeviceFamily": [1],
            "LSRequiresIPhoneOS": True,
            "ITSAppUsesNonExemptEncryption": False,
        }
        if extension:
            info["NSExtension"] = {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"}
        else:
            info.update({
                "UILaunchScreen": {},
                "UIRequiredDeviceCapabilities": ["arm64"],
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
                "CFBundleURLTypes": [{"CFBundleURLName": "com.callum.TodayEarnings", "CFBundleURLSchemes": ["todayearnings"]}],
            })
        with (root / "Info.plist").open("wb") as file:
            plistlib.dump(info, file)


def archive(payload, output):
    payload = Path(payload)
    # Stored ZIP maximizes compatibility with sideloading tools.
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as file:
        for path in sorted(payload.rglob("*")):
            if path.is_file():
                file.write(path, path.relative_to(payload.parent))
    with zipfile.ZipFile(output) as file:
        assert file.testzip() is None, "ZIP CRC check failed"
        for bundle, binary in [("Payload/TodayEarnings.app", "TodayEarnings"),
                               ("Payload/TodayEarnings.app/PlugIns/EarningsWidgetExtension.appex", "EarningsWidgetExtension")]:
            info = plistlib.loads(file.read(bundle + "/Info.plist"))
            assert info["CFBundleExecutable"] == binary
            assert len(file.read(bundle + "/" + binary)) > 0
            assert bundle + "/_CodeSignature/CodeResources" in file.namelist()
        print(f"IPA verified: {Path(output).stat().st_size:,} bytes")


if __name__ == "__main__":
    if sys.argv[1] == "metadata":
        metadata(*sys.argv[2:])
    elif sys.argv[1] == "archive":
        archive(*sys.argv[2:])
    else:
        raise SystemExit("Expected metadata or archive")
