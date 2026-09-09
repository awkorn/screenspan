# ScreenSpan

An iOS life chart based on automatic Screen Time activity. Life Grid, Stats, and Progress share one privacy-preserving report to avoid requesting activity again on every tab change.

Open `ScreenSpan.xcodeproj`, select the ScreenSpan scheme, and run on a physical iPhone with Family Controls provisioning. The Simulator can validate layout and host navigation but cannot establish real Screen Time loading performance.

```sh
xcodegen generate
Scripts/test-calculations.sh
# Optional: build a separate Simulator app with clearly labeled sample data
python3 Scripts/build-design-preview.py
```

See [the architecture investigation and physical-device checklist](docs/SCREEN_TIME_ARCHITECTURE.md) for Apple's constraints, implemented changes, verification, and remaining release work. The working flow provides reports and goal planning; app blocking and paid features are not enabled.
