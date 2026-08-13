#!/usr/bin/env python3
"""Static checks that can run without Apple SDKs.

This intentionally does not claim to compile Swift. It validates the XcodeGen spec,
plists, asset catalogs, icon dimensions, and safety-critical cleanup hooks.
"""

from __future__ import annotations

import json
import plistlib
import re
import struct
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyYAML is required: python3 -m pip install pyyaml") from exc


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "EmojiOverdrive"
ASSETS = APP / "Assets.xcassets"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    require(header[:8] == b"\x89PNG\r\n\x1a\n", f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def png_color_type(path: Path) -> int:
    with path.open("rb") as handle:
        header = handle.read(26)
    require(header[:8] == b"\x89PNG\r\n\x1a\n", f"Not a PNG: {path}")
    return header[25]


def validate_spec() -> None:
    spec = yaml.safe_load((ROOT / "project.yml").read_text(encoding="utf-8"))
    require(spec["name"] == "EmojiOverdrive", "Unexpected project name")
    app_target = spec["targets"]["EmojiOverdrive"]
    require(app_target["platform"] == "iOS", "Target must be iOS")
    require(float(app_target["deploymentTarget"]) >= 17, "iOS 17+ is required")
    require(spec["options"].get("projectFormat") == "xcode15_3", "Pin the Xcode project format")
    require(spec["settings"]["base"].get("SWIFT_VERSION") == "5.0", "Use Swift language mode 5")
    require(
        app_target["info"]["properties"].get("NSCameraUsageDescription"),
        "Missing truthful camera/torch usage text",
    )


def validate_plists() -> None:
    export_path = ROOT / "Config" / "ExportOptions-Development.plist"
    with export_path.open("rb") as handle:
        export = plistlib.load(handle)
    require(export["method"] == "debugging", "Export method must use Xcode's current Debugging name")
    require(export["signingStyle"] == "automatic", "Expected automatic signing")


def validate_assets() -> None:
    for catalog in ASSETS.rglob("Contents.json"):
        json.loads(catalog.read_text(encoding="utf-8"))

    icon_set = ASSETS / "AppIcon.appiconset"
    contents = json.loads((icon_set / "Contents.json").read_text(encoding="utf-8"))
    referenced = {item["filename"] for item in contents["images"] if "filename" in item}
    require("AppIcon-1024.png" in referenced, "Missing marketing icon reference")
    require(len(contents["images"]) == 1, "Expected the modern single-size iOS icon schema")
    only_icon = contents["images"][0]
    require(only_icon.get("idiom") == "universal", "Single-size icon must use universal idiom")
    require(only_icon.get("platform") == "ios", "Single-size icon must target iOS")

    for filename in referenced:
        icon = icon_set / filename
        require(icon.exists(), f"Missing icon file: {filename}")
        width, height = png_size(icon)
        require(width == height, f"App icon is not square: {filename}")
        require(png_color_type(icon) in {0, 2, 3}, f"App icon must not contain alpha: {filename}")
    require(png_size(icon_set / "AppIcon-1024.png") == (1024, 1024), "Marketing icon must be 1024px")


def validate_safety_contract() -> None:
    controller = (APP / "Models" / "ExperienceController.swift").read_text(encoding="utf-8")
    root = (APP / "Views" / "RootView.swift").read_text(encoding="utf-8")
    torch = (APP / "Services" / "TorchController.swift").read_text(encoding="utf-8")
    brightness = (APP / "Services" / "BrightnessController.swift").read_text(encoding="utf-8")

    for token in ("brightnessController.restore()", "torchController.turnOff()", "hapticsController.stop()"):
        require(token in controller, f"Missing emergency cleanup call: {token}")
    require("newPhase != .active" in root, "Scene inactivity cleanup is missing")
    require("accessibilityDimFlashingLights" in root, "Dim Flashing Lights is not honored")
    require("accessibilityReduceMotion" in root, "Reduce Motion is not honored")
    require("setTorchModeOn" in torch and "0.01...SafetyPolicy.maximumTorchLevel" in torch, "Torch cap missing")
    require("originalBrightness" in brightness and "func restore" in brightness, "Brightness restore missing")

    swift_files = list(APP.rglob("*.swift"))
    source = "\n".join(path.read_text(encoding="utf-8") for path in swift_files)
    require(not re.search(r"torchMode\s*=\s*\.on", source), "Do not use uncapped maximum torch mode")
    require("Timer.scheduledTimer" not in source, "Frame effects should not use high-frequency timers")
    require("wantsExtendedDynamicRangeContent = shouldRun && !snapshot.dimFlashingLights" in source,
            "EDR must turn off while idle or Dim Flashing Lights is enabled")
    require("snapshot.isRunning, liveElapsed < snapshot.sessionDuration" in source,
            "Renderer must enforce the absolute session cutoff")
    require("thermalState != .serious" in torch and "thermalState != .critical" in torch,
            "Torch activation must reject serious thermal state")
    require("reduceMotion: reduceMotion || dimFlashingLights" in controller,
            "Dim Flashing Lights must also freeze high-frequency motion")
    require("self.stop(reason: reason" in controller,
            "Thermal forced-off must stop the whole high-load experience")


def validate_paths() -> None:
    required = [
        APP / "App" / "EmojiOverdriveApp.swift",
        APP / "Views" / "RootView.swift",
        APP / "Rendering" / "MetalBackgroundView.swift",
        APP / "Rendering" / "EmojiOrbitCanvas.swift",
    ]
    for path in required:
        require(path.exists(), f"Missing source: {path.relative_to(ROOT)}")


def main() -> int:
    checks = [validate_spec, validate_plists, validate_assets, validate_safety_contract, validate_paths]
    for check in checks:
        check()
        print(f"PASS {check.__name__}")
    print("Static validation passed. Swift compilation still requires macOS + Xcode.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
