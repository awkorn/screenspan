# ScreenSpan: automatic reports without repeated loading

Investigated September 8, 2026. This is a working prototype architecture, not a claim of measured device performance or App Store approval.

## What Apple supports

The ordinary `DeviceActivityReport` API renders usage through a sandboxed extension. Apple explicitly prevents moving sensitive content outside that extension's address space. An App Group cache of totals, derived projections, screenshots, URL callbacks, or other return channels is not an appropriate solution. The host may send user-entered settings into the report; activity and activity-derived values remain inside it. [Apple: DeviceActivityReport](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport)

There is now a direct data API, `DeviceActivityData.activityData(filteredBy:using:)`, with a cached retrieval policy. However, customer installations require both physical EU location and an EU Apple Account. Development may work elsewhere, which can give a misleading impression of worldwide availability. It also requires the App and Website Usage entitlement and `approvedWithDataAccess`. It is not the basis for this broadly available build. [Apple: direct activity data](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitydata%28filteredby%3Ausing%3A%29), [Apple: authorization](https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess)

The existing Family Controls entitlement requires permission for App Store distribution. Confirm distribution provisioning for the app and report extension before TestFlight/App Store testing. Build success with code signing disabled does not establish this. [Apple: Family Controls entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls)

## Why the previous implementation was expensive

- Each dashboard tab constructed a different report. Switching tabs discarded the prior report view and could trigger another system request.
- Projection, life chart, and a paywall subtitle each embedded another report during onboarding.
- The projection filter requested 28 days, across iPhone and iPad. History requested eight weeks.
- The in-process cache was only keyed by a broad context category, not by the actual filter or authorization session. It could not avoid waiting for iOS to create the extension in the first place.
- A grid created approximately 960 individual SwiftUI views and rescaled counts to fill complete rows despite claiming one cell per month.
- History fabricated a curve from one average, with apparent percentage improvements and savings that were not measurements.

## Current implementation

`MainTabView` mounts one `.dashboard` report with a stable filter and identity. Life Grid, Stats, and Progress are tabs *inside* that report. They reuse one immutable payload; switching tabs cannot request another report configuration from the host. There is no shared persistent usage cache.

The host remains responsible for authorization, Settings, help, and explicit refresh. Opening Settings keeps the report mounted. Dismissing Settings only replaces it if age, planning age, or goal changed. Returning to the foreground refreshes the date window if the calendar day changed. Revoking permission removes the report.

Onboarding's projection and life chart similarly share one `.onboardingOverview` report. The user can continue to goal selection while it loads. After choosing a goal, onboarding completes; there is no second report just to populate a paywall subtitle.

The query covers seven **completed calendar days**, grouped daily, and includes iPhones. It excludes iPads and the partial current day. Multiple reporting iPhones may contribute to the same day. The average uses days actually returned; absent days are not invented zeros. Explicit zero-duration days are retained. The UI shows the reported-day count.

The report retains actual daily values for Progress. Bars show the observed values, including gaps, with the user-entered goal as a reference. No synthetic history, prior-period comparison, or achieved-savings claim is shown. A separate "At your goal, you could reclaim" section calculates potential time savings and labels the assumption explicitly.

The life chart initially represents the measured average. Its slider is an in-report what-if control; it does not persist activity-dependent values to the host. Goals are saved by the host's onboarding or Settings views. A Canvas draws exactly one square per month with an accessible summary.

Projections use 365-day, 24-hour years. The waking-time percentage separately assumes 16 waking hours. Invalid inputs and exhausted planning horizons cannot produce negative grid counts. Combined daily usage is capped at 24 hours for the lifetime projection; the waking-time percentage is capped at 100%.

The existing paywall, StoreKit, notification, and blocking scaffolds are not a finished paid product. The working flow exposes reports and goal planning for free. It does not prompt for notifications, claim to block apps, or sell placeholder benefits. Implement those independently with supported APIs before restoring the paid flow.

The app uses the reference design's light appearance. Report roots independently set a light color scheme and explicit navy text, because they do not reliably inherit the host's appearance. Secondary copy and chart axis labels use opaque dark gray on white/pale-gray surfaces. The isolated design preview accepts `--dark` to check that the report remains readable when its surrounding app requests Dark Mode.

## What remains outside our control

iOS still controls extension startup and activity delivery. There is no claim that a first load, a force-quit/relaunch, an explicit refresh, or an OS-discarded report will be instant. This change removes repeat requests caused by app navigation and reduces the query size; it does not establish that the original 30-second cold start is fixed.

The host has no reliable report-ready callback. It therefore does not infer readiness from a timer, write readiness flags from the extension, or poll a usage cache. Loading copy sits behind the report, and host help/refresh/settings remain available even if the report stays blank.

## Verification and device acceptance

Completed locally:

- Debug Simulator builds and signed physical-iPhone builds for the app and report extension with Xcode 26.3. Verified Family Controls and App Group entitlements in both signed bundles. Installed on the paired iPhone 16 Pro after the user unlocked it and approved installation. The user observed approximately 15 seconds for the first dashboard load after onboarding, followed by successful tab switching without further loading. This is one user-reported run, not a cold-start benchmark.
- `Scripts/test-calculations.sh`: 135 checks covering consistent units, invalid/zero inputs, out-of-range ages, grid counts, missing versus explicit-zero days, per-day grouping, and DST.
- Native Simulator inspection of the actual welcome, birth-date, and authorization screens.
- Separate, visibly labeled synthetic-data preview of the actual dashboard SwiftUI views: grid, donut, daily chart, and all tab buttons. This validates layout and view interactions, not the report service or real activity access.
- Both entitlement definitions and the existing signing team are now declared in `project.yml`, so regenerating the Xcode project does not remove them.

On a physical iPhone with approved provisioning and real Screen Time history:

1. Measure from opening the dashboard to its first visible grid for at least five cold starts. Record iOS version, device, and whether this was immediately after first authorization. Compare against the previous build on the same device.
2. Switch Life Grid → Stats → Progress → Life Grid repeatedly. Confirm no blank reload and no new `Report aggregation started` log for ordinary tab changes.
3. Open and close Settings without edits, then change the goal and close again. Expect no reload for the first case and one intentional refresh for the second. Verify the goal reference line changes.
4. Compare the displayed completed days against Apple's Screen Time using the same device scope. Test no data, explicit zero activity, partial history, and multiple iPhones.
5. Revoke and regrant permission; foreground after midnight; force quit; test explicit Refresh and offline use. Confirm unavailable activity never becomes a fabricated number.
6. Check larger Dynamic Type, VoiceOver slider adjustment, and a smaller iPhone.

The report logs aggregation start/end and elapsed time only. That measures work after iOS invokes the extension, not total cold-start delay. Observe the UI to measure end-to-end latency. Do not add usage values or app identities to diagnostics.
