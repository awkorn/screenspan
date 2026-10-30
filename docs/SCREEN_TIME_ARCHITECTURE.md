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

Onboarding: welcome → birth date → the user's guess at their daily phone time → what they'd rather do with more time → Screen Time access → five reveal panels → the reduction plan (top apps → starting points → plan) → paywall. Without Screen Time access there's nothing to enforce, so a single daily goal replaces the plan steps. The guess, intentions, age, goal, and the plan's picks and starting points are user-entered and stored in the App Group; the report reads them.

The plan steps use one more report context, `.appAverages`: up to three apps with their seven-day daily average. On the first step it's unfiltered, so it lists the user's top apps while they pick them in `FamilyActivityPicker`. On the second it's filtered to the picked tokens, and the user dials in their own starting point for each beside it, because the measured averages can't leave the report. The plan screen then shows each app's weekly limits to its target (adjustable in 15-minute steps) and the lifetime time back. Picks and entries are kept as a draft (`PlanDraftItem`) until the plan starts after purchase, or right away for subscribers; declining Pro keeps the draft. The reveal panels (`OnboardingRevealPanels`) are one `.onboardingOverview` report stacked vertically; the host clips and offsets the same report to show each panel in order, so there is one extension request and no activity-derived navigation state returns to the host. Panels: guess vs. measured average (tap to reveal), lifetime years on the phone (tap to reveal), life grid, the yearly cost (days per year, pickups per year, top app's lifetime projection, and conversions into the user's intentions with stated assumptions), and the years back at 1/2/3 hours a day.

The pre-permission screen has no skip or delay option and its button says "Continue", per App Review guidance on custom messages before permission requests. If the system prompt is declined, or the report has not appeared after 20 seconds, the user can continue with their own estimate; the host then renders the same panels from that guess, labeled as an estimate. The report itself falls back to the guess, also labeled, when Screen Time returns no recent activity. That keeps the flow usable on review devices with no history.

The dashboard query (`ActivitySummary.dashboardInterval`) covers **completed calendar days** from the week before the user's start date through yesterday, grouped daily, iPhones only, and capped at 35 days. It excludes iPads and the partial current day. Life Grid and Stats use only the last seven of those days, so their numbers are unchanged; Progress uses the full range. Multiple reporting iPhones may contribute to the same day. Averages use days actually returned; absent days are not invented zeros. Explicit zero-duration days are retained. The UI shows the reported-day count.

### Progress: life regained since starting

The host records `trackingStartDate` when onboarding completes (existing users are backfilled to their first launch of this version). It is a date the host already knows, not usage. The report reads it and computes `LifeRegainedProgress` in-process:

- **Starting pace:** average of the reported days in the seven days before the start date (at least three days). This is the same window the onboarding projection measured.
- **Current pace:** average of reported completed days since the start date.
- **On track to regain:** projected phone time to the planning age at the starting pace minus the same projection at the current pace (`ProjectionCalculator.calculateRegained`), never negative. "Back already" sums starting pace minus each tracked day.
- **Lifetime comparison:** two bars on one scale, phone years at the starting pace and at the current pace, with the difference drawn as time won back.
- **Chart:** faint daily bars plus a trailing seven-day average line (shown once three days of that window are reported, broken at gaps rather than interpolated), with the pre-start week shaded and the starting pace and goal as reference lines.
- **Daily goal:** one square per calendar day since starting (up to 14), green at or under the goal, red over, dashed when not reported, plus the current streak. A missing day ends a streak because it cannot be confirmed.

### Stats and Life Grid

Stats describes the last seven completed days: the lifetime projection, the waking-life donut, daily average, pickups per day, full 24-hour days a year at that average, and the top five apps by daily average with each app's lifetime projection. Per-app detail is read only for those seven daily segments; older segments contribute just their totals, so the 35-day query does not pay for app-level detail it never shows. App names and icons render from `Application` tokens with FamilyControls' `Label`, inside the extension. They are never logged, stored, or sent to the host. Pickups are app pickups plus pickups without app activity.

Life Grid draws one square per month, 30 per row (32 even rows for an 80-year life), with age labels every 15 years. The slider is an in-report what-if: it starts at the seven-day average ("Now") and has tappable Goal and Start markers. Grid squares show lived months, projected phone months at the slider's pace, and, when a starting pace is known, months won back compared with it (green).

The report extension can read the App Group but its writes are silently dropped, and Screen Time appears to keep about a month of history (not documented by Apple; based on developer reports). So the measured starting week eventually falls out of range, and the report cannot save it. Settings therefore offers an optional, user-entered starting point. Progress uses the measured week whenever at least three of its days are returned and the user's entry only after that. With neither, Progress asks for an entry instead of inventing one. The user's entry is user input, like the goal, and is the only "starting" value stored.

Considered and rejected: a second report for Progress (another extension request and load), a global extension cache (rejected earlier for filter/authorization reasons, and it would not survive the extension being discarded), and DeviceActivityMonitor threshold events written to the App Group. The last could keep months of daily history, but it needs a FamilyActivityPicker selection, a new extension target and provisioning, coarse thresholds, and it would put usage-derived values in the App Group, contrary to this document's privacy model.

The life chart initially represents the measured average. Its slider is an in-report what-if control; it does not persist activity-dependent values to the host. Goals are saved by the host's onboarding or Settings views. A Canvas draws exactly one square per month with an accessible summary.

Projections use 365-day, 24-hour years. The waking-time percentage separately assumes 16 waking hours. Invalid inputs and exhausted planning horizons cannot produce negative grid counts. Combined daily usage is capped at 24 hours for the lifetime projection; the waking-time percentage is capped at 100%.

Notifications remain unimplemented; the app does not prompt for them.

## Blocking and ScreenSpan Pro

Reports, Life Grid, Stats, and Progress are free. ScreenSpan Pro, an auto-renewing subscription (`com.screenspan.subscription.annual` with a free-trial introductory offer, and `com.screenspan.subscription.monthly`, in one subscription group), unlocks blocking:

- **Focus blocks:** block the distraction list for 15 minutes to 4 hours, with a live countdown.
- **Schedules:** repeating windows (Bedtime, Work hours, Slow mornings, or custom) on chosen weekdays, including overnight windows.
- **Daily limits:** a shared allowance for chosen apps; once used, they're blocked until midnight.
- **Reduction plan:** up to three apps, each with its own daily limit that steps down a week at a time from the amount the user says they spend now to a target (default: half). Each cut is about a fifth of the current limit, 10–30 minutes in whole 5s, so 3h goes 2h 30m → 2h → 1h 30m and 1h goes 50m → 40m → 30m; a remainder under 10 minutes joins the last cut or is split evenly. On a step's seventh day the user can step down, hold for another week, or ease back to the previous limit (or, on the first step, a cut half as big). Every plan change, including the first limit, starts at the next midnight: each limit covers whole days, setting up in the evening doesn't block time already spent, and easing back can't lift a block that's on now. Under strict mode, removing an app waits for midnight too. The plan stores only the user's entries and the limits derived from them (`ReductionCourse`), never usage.
- **Strict mode:** focus blocks can't end early, and a running schedule can't be turned off, edited, or deleted. Daily limits can tighten immediately, but loosening one (more time, fewer apps, off, or deleted) is held as a pending change until the next midnight, when today's allowance resets anyway. The app never learns whether a limit was reached, so the rule doesn't depend on it. Strict mode itself can only be turned off when nothing is blocking, and with limits on it switches off at midnight. The app applies due changes on launch, foreground, and opening Blocking. Until then the monitor applies a due change that removes or disables a limit, and doesn't shield a limit whose new allowance exceeds the threshold iOS is still watching.
- **Shield screen:** names the paused app, why it's blocked and until when, followed by one brief reminder about time gained, control over attention, or choosing to stop despite the pull to keep going. Six messages rotate in 15-minute windows shared across apps, so repeated attempts don't generate new advice. Copy does not depend on onboarding goals or track attempts. Its consistent **Close app** button closes the app. See [the copy rationale and research](BLOCK_SCREEN_COPY.md).

### How it works

`FamilyActivityPicker` returns opaque tokens. `BlockingConfiguration` (the distraction list, focus block, schedules, limits, strict mode) is saved as JSON in the App Group. It contains only user choices and tokens, never usage, consistent with the privacy model above. App names and icons are drawn from tokens by iOS.

Each rule (`BlockingRule`) has its own `ManagedSettingsStore` and `DeviceActivityName`, so lifting one never lifts another. The app applies shields immediately; DeviceActivity monitoring lets `ScreenSpanMonitor` apply and clear them later while the app isn't running:

- Focus block: a one-off interval; the monitor clears the shield at its end.
- Schedule: one daily-repeating interval per schedule. On `intervalDidStart` the monitor checks the weekday the window started on, so overnight windows belong to the evening they begin. This keeps one activity per schedule rather than one per weekday (iOS allows 20 activities per app; ScreenSpan caps schedules and limits at 8 each, plus the focus block and up to three plan apps).
- Daily limit: a 00:00–23:59 interval with one threshold event; the monitor shields on `eventDidReachThreshold` and clears at the next interval. On iOS 17.4+ the event includes time already used today.
- Plan app: the same daily interval, with a threshold event for each limit that is in force or scheduled (`planLimit.<minutes>`), so a step due at midnight applies without the app. Reaching a threshold means usage is over any limit at or below it, so the monitor shields when the limit in force is at most the event's minutes and ignores tomorrow's tighter threshold today. Reconcile restarts plan monitoring only when the watched thresholds are out of date, because a restart before iOS 17.4 forgets time already used today.

`BlockingService.reconcile()` runs on launch and foreground. It re-applies shields for blocks that should be running, clears ones that shouldn't, and restarts missing monitoring, so missed extension callbacks heal when the app opens.

Shields are applied only with a verified entitlement. `StoreKitService` checks `Transaction.currentEntitlements` at launch and listens to `Transaction.updates`. It records the result (`free`, `trial`, `premium`) in the App Group; the extensions refuse to apply shields without it. Losing Pro clears every shield and stops monitoring but keeps the user's setup for resubscribing. Blocking is never turned off on a cold start before StoreKit answers.

### Paywall

Shown after the plan step at the end of onboarding (skipped for existing subscribers), from the dashboard's Block button, and from Settings. After a plan, its title names the plan's time back. It has a visible close button. Prices, trial length, and the per-month equivalent come from StoreKit. The renewal terms sit beside the purchase button. Restore Purchases, Terms of Use (Apple's standard EULA), and the Privacy Policy are linked from the paywall and Settings. Settings shows the plan, trial or renewal date, and Apple's manage-subscriptions sheet. After a purchase in onboarding the plan starts; without a plan, Blocking opens with the app picker.

### Before App Review

1. **Family Controls distribution entitlement for every target.** Done October 23, 2026: Family Controls (Distribution) is Assigned and enabled on `com.screenspan` and the four extension App IDs, `com.screenspan.deviceactivityreport` (report), `com.screenspan.deviceactivity` (monitor), `com.screenspan.shieldconfiguration` (shield), and `com.screenspan.shieldaction`. A local App Store export signs all five with `com.apple.developer.family-controls`. A new extension needs the request from the ⊕ on its App ID's Capability Requests tab, then the Distribution capability turned on.
2. **App Store Connect:** create the subscription group and both products with the IDs above, the annual free-trial introductory offer, localized names, and review screenshots of the paywall. Submit them with the app version.
3. **Privacy policy:** replace `AppConstants.Legal.privacyPolicy` with the URL entered in App Store Connect. If you publish your own terms, replace `termsOfUse` too and add it to the app description.
4. **Review notes:** explain that blocking needs Screen Time authorization (a real device with a passcode) and a subscription, and that StoreKit sandbox purchases unlock it.

### Device checks for blocking

The Simulator can show the screens, but it can't grant Screen Time access without a device passcode, and it doesn't enforce shields. On a physical iPhone, run from Xcode (which uses `ScreenSpan.storekit`) or TestFlight sandbox:

1. Buy the annual trial; confirm Blocking opens with the picker and Settings shows the trial end date. Restore on a second install.
2. Start a 15-minute focus block; open a blocked app and check the shield's name, reason, end time, and supportive message. Confirm it lifts at the end with ScreenSpan force-quit.
3. Add a schedule that starts in two minutes and one that crosses midnight on selected weekdays only. Confirm each turns on and off with the app closed, and that unselected days stay unblocked.
4. Add a 15-minute daily limit, use the app past it, and confirm the shield; confirm it clears after midnight.
5. With strict mode on, confirm End early, schedule toggles, editing, and deleting are unavailable while blocking, and strict mode can't be turned off until it ends. Raise and delete a daily limit; both should show as taking effect at midnight, and apply after it. With limits on, turning strict mode off should wait until midnight.
6. Expire or refund the subscription in the StoreKit transaction manager; confirm shields lift on next launch and the setup remains.
7. Add a plan app in the evening; confirm nothing blocks until midnight, then that it blocks at its first limit the next day. Step down (move the start date back in a debug build), leave ScreenSpan closed past midnight, and confirm the new limit applies and that today's limit still applied the evening before. Ease back and confirm a running block stays until midnight.

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
- Verified the required analysis → life chart → goal progression in the isolated sample-data preview (`--onboarding`), using the same two-panel report viewport as the host app.
- Both entitlement definitions and the existing signing team are now declared in `project.yml`, so regenerating the Xcode project does not remove them.

On a physical iPhone with approved provisioning and real Screen Time history:

1. Measure from opening the dashboard to its first visible grid for at least five cold starts, both soon after onboarding (about a 7–14 day query) and with a start date 30+ days ago (the 35-day cap). Record iOS version, device, and whether this was immediately after first authorization. Compare against the previous build on the same device.
2. Switch Life Grid → Stats → Progress → Life Grid repeatedly. Confirm no blank reload and no new `Report aggregation started` log for ordinary tab changes.
3. Open and close Settings without edits, then change the goal and close again. Expect no reload for the first case and one intentional refresh for the second. Verify the goal reference line changes.
4. Compare the displayed completed days against Apple's Screen Time using the same device scope. Test no data, explicit zero activity, partial history, and multiple iPhones.
5. Revoke and regrant permission; foreground after midnight; force quit; test explicit Refresh and offline use. Confirm unavailable activity never becomes a fabricated number.
6. Check larger Dynamic Type, VoiceOver slider adjustment, and a smaller iPhone.
7. In Settings, move "Started ScreenSpan" back 10 days, then 40 days. Confirm Progress shows a measured starting pace for the first, and asks for a starting point for the second until one is entered. Confirm Stats numbers do not change and Life Grid shows won-back months only with a starting pace.
8. Compare Stats' top apps and pickups with Apple's Screen Time for the same seven days. Note whether app names or icons fail to render.

The report logs aggregation start/end and elapsed time only. That measures work after iOS invokes the extension, not total cold-start delay. Observe the UI to measure end-to-end latency. Do not add usage values or app identities to diagnostics.
