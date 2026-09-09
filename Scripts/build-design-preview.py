#!/usr/bin/env python3
"""Build the real report views with visibly labeled fixtures in a separate app.

No Screen Time authorization, real usage, production app writes, or device install.
Requires Xcode and xcodegen. Prints the built Simulator app path.
"""
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
preview = Path(tempfile.mkdtemp(prefix="screenspan-design-"))
source = (root / "ScreenSpanReport/ScreenSpanReportExtension.swift").read_text()
# Keep the exact scene/view code while the fixture app owns the entry point.
(preview / "ReportScenes.swift").write_text(source.replace("@main\n", "", 1))
(preview / "PreviewApp.swift").write_text((root / "Tests/DesignPreviewApp.swift").read_text())
# A separate preference domain prevents fixture settings touching production.
constants = (root / "Shared/SharedConstants.swift").read_text()
(preview / "SharedConstants.swift").write_text(constants.replace(
    "group.com.screenspan.shared", "com.screenspan.designpreview.settings"))
q = lambda path: json.dumps(str(path))
(preview / "project.yml").write_text(f"""name: ScreenSpanPreview
options:
  deploymentTarget:
    iOS: "17.0"
targets:
  ScreenSpanPreview:
    type: application
    platform: iOS
    sources:
      - path: {q(root / 'Shared')}
        excludes: [SharedConstants.swift]
      - path: SharedConstants.swift
      - path: {q(root / 'ScreenSpanReport')}
        excludes:
          - ScreenSpanReportExtension.swift
          - DeviceActivityReport+Contexts.swift
          - "*.entitlements"
          - Info.plist
      - path: ReportScenes.swift
      - path: PreviewApp.swift
      - path: {q(root / 'ScreenSpan/Resources/Fonts/Geist')}
        buildPhase: resources
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.screenspan.designpreview
      GENERATE_INFOPLIST_FILE: YES
      TARGETED_DEVICE_FAMILY: 1
    info:
      path: Info.plist
      properties:
        UILaunchScreen: {{}}
        UIAppFonts: [GeistVF.ttf, GeistItalicVF.ttf, GeistMonoVF.ttf, GeistMonoItalicVF.ttf]
""")
subprocess.run(["xcodegen", "generate", "--spec", str(preview / "project.yml")], check=True)
subprocess.run([
    "xcodebuild", "-project", str(preview / "ScreenSpanPreview.xcodeproj"),
    "-scheme", "ScreenSpanPreview", "-configuration", "Debug", "-sdk", "iphonesimulator",
    "-derivedDataPath", str(preview / "build"), "CODE_SIGNING_ALLOWED=NO", "build"
], check=True)
print(preview / "build/Build/Products/Debug-iphonesimulator/ScreenSpanPreview.app")
