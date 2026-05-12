#!/usr/bin/env python3
"""
Xcode's generated Info.plist merge drops nested UISceneConfigurations entries from
Application-Info.plist. Inject the CarPlay template scene after the app Info.plist exists.
"""
import os
import plistlib
import sys

def main() -> None:
    built = os.environ.get("BUILT_PRODUCTS_DIR")
    wrapper = os.environ.get("WRAPPER_NAME")
    module = os.environ.get("PRODUCT_MODULE_NAME", "MusicPlayer")
    if not built or not wrapper:
        print("inject_carplay_plist: missing BUILT_PRODUCTS_DIR or WRAPPER_NAME", file=sys.stderr)
        sys.exit(0)
    path = os.path.join(built, wrapper, "Info.plist")
    if not os.path.isfile(path):
        print("inject_carplay_plist: skip (no Info.plist yet)")
        sys.exit(0)

    with open(path, "rb") as f:
        plist = plistlib.load(f)

    manifest = plist.setdefault("UIApplicationSceneManifest", {})
    manifest["UIApplicationSupportsMultipleScenes"] = True
    configs = manifest.setdefault("UISceneConfigurations", {})
    if not isinstance(configs, dict):
        configs = {}
        manifest["UISceneConfigurations"] = configs

    configs["CPTemplateApplicationSceneSessionRoleApplication"] = [
        {
            "UISceneConfigurationName": "CarPlay",
            "UISceneClassName": "CPTemplateApplicationScene",
            "UISceneDelegateClassName": f"{module}.CarPlaySceneDelegate",
        }
    ]

    with open(path, "wb") as f:
        plistlib.dump(plist, f)
    print("inject_carplay_plist: updated", path)


if __name__ == "__main__":
    main()
