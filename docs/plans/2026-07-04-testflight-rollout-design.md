# TestFlight Rollout — design / runbook

**Goal:** An Imeto colleague installs the app on their own iPhone, signs in with their
`@imeto.com` account, and thereafter sees colleague names on incoming calls and can call them
by name from the native Phone app.

**Why this doc:** The code is built and verified on the Simulator, but "shipped" ≠ "in
colleagues' hands." Getting there is a distribution + rollout phase that is mostly *not* code.
This is the ordered path, with an owner on every step.

**Decisions locked (2026-07-04):** beta channel = **TestFlight**; Imeto **enrolled in the Apple
Developer Program** ✅ (gate cleared); Google OAuth consent screen = **Internal** ✅.

**Owner key:** 🧑 = you (Imeto IT manager — you hold the admin access for every 🧑 step: Apple
enrollment, ABM/MDM, the Google Workspace console) · 🤖 = I can do it here.

**Production channel note:** TestFlight is the fast path to prove it on a real device and run a
beta. For the eventual org-wide rollout you (as IT manager) have a better option than a 90-day
beta: **Apple Business Manager + MDM** pushes the app silently to managed iPhones with no
per-user invite and no expiry. Recommended shape: **TestFlight now → ABM/MDM for GA.** Both use
the same signed build; only the delivery differs. See Stage 5 note.

**MDM licensing caveat (verified 2026-07-26):** Imeto's current **Google Workspace Business**
edition does **not** include company-owned iOS device management — Google's
[docs](https://knowledge.workspace.google.com/admin/devices/set-up-company-owned-ios-device-management)
gate it to Enterprise / Frontline / Education / **Cloud Identity Premium**. The silent path
therefore needs one of: the **Cloud Identity Premium** add-on (per-user, keeps Business) with
Google as the MDM, **or** a standalone MDM (Apple Business Essentials / Jamf / Kandji / Mosyle /
Intune). All routes also require **ABM + ADE + Apple VPP** and distributing this app as an **ABM
Custom App** (separate App Review). A real project with licensing cost — not needed for the
TestFlight beta.

---

## The gate — CLEARED ✅

- [x] 🧑 Enroll Imeto in the Apple Developer Program → org **Team ID provided** and wired via
      `DEVELOPMENT_TEAM` (read at `xcodegen generate` time; lands only in the gitignored
      `.xcodeproj`, never committed). Signing verified against the org team (Xcode account
      signed in; `Apple Distribution: Imeto Consulting AB`).

---

## Stage 1 — Google auth works for everyone (do first; free; unblocks sign-in)

Today only I can sign in if the OAuth consent screen is in External/Testing with me as a test
user. Colleagues would hit "access denied."

- [x] 🧑 OAuth consent screen **User type = Internal** (org-only) — done. Any `@imeto.com`
      account can sign in with no per-user allowlist and no Google app verification.
- [x] People API enabled (org) — already done.
- [x] Admin console → external directory sharing → "organization data" — already done.

**Verify:** a *second* `@imeto.com` account (not the original test user) signs in and sees the
directory list.

## Stage 2 — App polish real users will see (🤖, done)

- [x] 🤖 App **icon** — monochrome Imeto-brand mark (person + call badge), 1024px, wired via
      `app/Sources/Assets.xcassets/AppIcon.appiconset`. Verified compiled into the built app
      (`Assets.car` → `AppIcon`, `CFBundleIconName = AppIcon`).
- [x] 🤖 **Launch screen** (minimal system launch screen, `UILaunchScreen {}`) + **display name**
      "WorkspaceContacts" — both set in `project.yml`.
- [x] 🤖 **Privacy manifest** `app/Sources/PrivacyInfo.xcprivacy` (UserDefaults reason CA92.1;
      no tracking; no collected data) — required for App Store upload; verified bundled.
- [x] 🤖 **Privacy policy** drafted → [`../rollout/privacy-policy.md`](../rollout/privacy-policy.md).
      🧑 host it at a stable URL (required by App Store Connect).
- [x] 🤖 **App Privacy** answers pre-filled → [`../rollout/app-store-privacy.md`](../rollout/app-store-privacy.md).

## Stage 3 — Signing config for distribution (🤖 prep, 🧑 finish)

- [x] 🤖 Parameterized the team in `app/project.yml`: `DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}`
      + `CODE_SIGN_STYLE: Automatic`. The env value is read at `xcodegen generate` time and only
      reaches the gitignored `.xcodeproj` — **never committed**.
- [x] 🤖 Bundle id `com.imeto.workspacecontacts.app` **auto-registered** and the Apple
      Distribution cert + App Store profile created by the pipeline's export step
      (`-allowProvisioningUpdates`). Signed a real `.ipa` — **no device needed**: we archive
      *unsigned* (`CODE_SIGNING_ALLOWED=NO`) and sign for distribution at export, so the "team
      has no devices" error never applies (dev-portal device registration is only for
      development/ad-hoc builds, not App Store/TestFlight).

## Stage 4 — App Store Connect + first build (needs the account)

- [x] 🧑 App Store Connect app record created — app id `6794820862`, bundle id above.
- [x] 🤖 Archive + export pipeline built & verified: [`scripts/build-testflight.sh`](../../scripts/build-testflight.sh)
      produces a distribution-signed `.ipa` device-free. It reads `DEVELOPMENT_TEAM` from the env,
      writes only into gitignored `app/build/`, and bumps the build number via `BUILD_NUMBER`
      (TestFlight needs a higher one each upload).
- [x] 🤖 **First build uploaded** — v0.1.0 (build 1). Signing + upload both go through the
      account signed into Xcode (Account Holder). **No API key needed**: an App Manager key
      can't cloud-sign (`Cloud signing permission error`); only an Admin key could, so the
      signed-in account is the path. Upload result: `Upload succeeded. Uploaded WorkspaceContacts`.
- [x] 🤖 **Build 2 uploaded** (v0.1.0 build 2) — carries the contacts-permission fix below.
      `BUILD_NUMBER=2 ./scripts/build-testflight.sh`; attached to the external group and
      submitted for review. Each new external build gets its own review pass.
- [ ] 🧑 Fill App Privacy (from Stage 2), add the privacy policy URL. Privacy page is written and
      PR'd ([imeto-web#14](https://github.com/imeto-consulting/imeto-web/pull/14) →
      `imeto.com/workspacecontacts-privacy.html`); merge + deploy, then paste the URL.
      *Required before App Store release; the beta is running without it.*

## Stage 5 — TestFlight testers + invites

- [x] 🤖 **External group + public link live** — group "Imeto Colleagues"; build 1 **APPROVED**
      by Beta App Review (2026-08-13). Public link: **https://testflight.apple.com/join/CFqNQQjZ**
      — one URL for all of Imeto, no per-person invite, testers need no App Store Connect access.
      Runbook + reviewer notes: [`../rollout/external-testflight.md`](../rollout/external-testflight.md).
- [x] 🤖 Reviewer sign-in solved — dedicated `applereview@imeto.com` demo account (the app's
      Internal OAuth means reviewers can't otherwise pass sign-in). **Keep it alive and
      sign-in-able**: every new external build is re-reviewed. Cloud Identity Free is enough.
- [x] 🤖 Andreas invited as an external tester (`andreas.tornstrom.andersson@imeto.com`).
- [ ] 🧑 Share the public link company-wide (e.g. via `everyone@imeto.com` / Slack) once build 2
      clears review. Teaser copy: [`../rollout/launch-kit.md`](../rollout/launch-kit.md).
      *Note: a group alias can't be a tester — TestFlight testers are individual Apple IDs, which
      is exactly why the public link is the mechanism for "everyone".*
- [x] 🤖 Onboarding note drafted → [`../rollout/onboarding.md`](../rollout/onboarding.md)
      (install → sign in → allow Contacts → "Enable & sync" → the iCloud-propagation caveat).

## Stage 5b — Contacts permission (from real beta feedback)

- [x] 🤖 iOS 18 **limited access** ("Select Contacts") is now a supported path. The sync gate
      required `.authorized`, so picking the privacy-friendly option threw `accessDenied` and the
      app synced nothing. It now accepts `.limited` too — we never read the address book, only
      contacts we created, so limited access is sufficient. Also fixed: the "Imeto Directory"
      CNGroup was the sole source of truth for *remove all*, so a missing group deleted nothing
      **yet still cleared the ref map — permanently stranding contacts the app had created**.
      Removal now works from the group *and* the persisted map. Shipped in build 2.
- [ ] 🧑 Confirm on a real device that a `.limited` grant still permits the writes. `simctl`
      cannot produce iOS 18 limited access (`contacts-limited` reports `.authorized`, raw 3), so
      only a human tapping "Select Contacts" proves it.

## Stage 6 — The actual end-to-end proof

- [ ] 🧑 A colleague on a physical iPhone: install → sign in → sync, then **have someone in the
      directory call them and confirm the name shows on the incoming-call screen**, and that
      typing the name in Phone finds them. This is the one thing no simulator can prove
      (previously logged in the roadmap's "Later").

---

## Ongoing constraints (carried from build)

- Builds expire every **90 days** on TestFlight — re-upload to keep a beta group live.
- Contacts land in the user's **real address book** and may sync to iCloud (no on-device
  isolation API). Consent copy + "Remove all synced contacts" + sign-out cleanup already
  handle this; the onboarding note must state it plainly.
- Never commit the org Team ID to the shared repo (same rule that kept the personal team out).

## Status — first build is on TestFlight; only the on-device proof remains

Team ID provided; the build pipeline ([`scripts/build-testflight.sh`](../../scripts/build-testflight.sh))
archives + distribution-signs a real `.ipa` **device-free** and uploads via the signed-in Xcode
account. **v0.1.0 build 1 is uploaded** (`Upload succeeded`) and processing in App Store Connect
(app id `6794820862`). What remains (**no physical device is needed until step 3**):

1. 🧑 Once processing finishes (a few min; usually an email), **add yourself as an internal
   tester** in TestFlight (Stage 5) — no beta review for internal testers.
2. 🧑 Install via the **TestFlight** app, sign in with `@imeto.com`, allow Contacts, Enable & sync.
3. 🧑 **Stage 6** — the one true end-to-end proof: have someone in the directory call that iPhone
   and confirm the colleague's **name shows on the incoming-call screen**. Any Imeto iPhone that
   installs from TestFlight works — nothing to register. This is the only device-dependent step.

Re-uploads (builds expire every 90 days): `BUILD_NUMBER=2 ./scripts/build-testflight.sh` (bump the
number each time). Before **external** testing or App Store: fill App Privacy + host the privacy policy.
