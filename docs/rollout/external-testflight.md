# External TestFlight — company-wide beta via public link

Goal: every Imeto colleague can install WorkspaceContacts from one shared link, with no App
Store Connect access. Reaches up to 10,000 testers. Costs a **one-time Beta App Review** and
some metadata. This doc is the paste-ready copy + the click path.

> **Prerequisite you should not skip:** prove Stage 6 on one physical iPhone first (internal
> testing) — a real incoming call shows a colleague's name. Same build; roll out only after it's
> proven on hardware.

## The one thing that needs a decision from you: the reviewer's sign-in

The app signs in with Google Workspace restricted to `@imeto.com` (OAuth consent screen =
Internal). An Apple beta reviewer has no `@imeto.com` account, so **they cannot sign in** unless
you give them one. Reviews get rejected when the reviewer is stuck at a login they can't pass.

**Do this:** create a throwaway demo user, e.g. `beta-review@imeto.com`, and put its credentials
in App Review Information → *Sign-In Required*. Caveats:
- Google Sign-In may challenge an unfamiliar login (new device/location). If possible, sign into
  that demo account once from a browser and approve the "was this you?" prompt beforehand, or keep
  it without hardware-key 2FA so the reviewer isn't blocked.
- It only needs to be a real directory user so the sync has something to show; it needs no admin
  rights. Suspend or delete it after approval.

## Click path in App Store Connect

1. **TestFlight** tab → left sidebar **External Testing** → **+** next to Groups → name it
   e.g. *Imeto* → Create.
2. Open the group → **Builds** → **+** → add **1 (0.1.0)**.
3. Fill **Test Information** (below) and **App Review Information** (the demo account + notes).
4. Submit the build for **Beta App Review**. Approval is usually within a day.
5. After approval: in the group, enable **Public Link** → copy the URL → share it company-wide
   (Slack / email — the launch-kit teaser in [`launch-kit.md`](launch-kit.md) is written for this).

Re-uploads later: minor build bumps to the same version usually **don't** need a fresh full
review — only significant changes do. So the 90-day re-uploads are mostly friction-free.

---

## Paste-ready copy

### Test Information → Beta App Description (testers see this)
> WorkspaceContacts adds your Imeto colleagues to your iPhone Contacts so their names show on
> incoming calls and you can call them by name from the Phone app. Sign in with your @imeto.com
> account, allow Contacts access, and tap **Enable & sync**. To remove everything later, use
> **Remove all synced contacts** or just sign out.

### Test Information → What to Test
> 1. Sign in with your @imeto.com account.
> 2. Allow Contacts, tap Enable & sync — your colleagues appear in Contacts.
> 3. Have a colleague call you: their **name** should show on the incoming-call screen.
> 4. In the Phone app or Spotlight, type a colleague's name — you should find them.
> Report anything missing, wrong, or slow.

### Test Information → Feedback email
> `<a real inbox — your address or a shared one, e.g. it@imeto.com>`

### App Review Information → Sign-In Required: **Yes**
- **User name:** `beta-review@imeto.com`  *(demo account you create)*
- **Password:** `<the demo account's password>`

### App Review Information → Notes (paste)
> WorkspaceContacts is an internal tool for employees of Imeto Consulting AB. It signs in with
> Google Workspace (Google Sign-In) restricted to @imeto.com accounts, reads the company
> directory via the Google People API, and writes colleagues into the device's Contacts so their
> names appear on incoming calls and they can be called by name.
>
> To review: launch the app, tap Sign in, and use the demo @imeto.com account above. Google may
> show a one-time "verify it's you" prompt — the account is a standard Google Workspace user and
> the credentials are valid. After sign-in, allow Contacts access and tap "Enable & sync"; the
> directory (a handful of demo colleagues) is written to Contacts.
>
> The app collects no analytics and no personal data beyond what the user syncs into their own
> Contacts (see the bundled privacy manifest and our privacy policy). There is no server; the
> app talks only to Google's APIs over HTTPS.

## Privacy (required before external distribution)
- **App Privacy** answers → enter from [`app-store-privacy.md`](app-store-privacy.md).
- **Privacy policy** → host [`privacy-policy.md`](privacy-policy.md) at a stable URL and paste
  the URL into App Information → Privacy Policy URL.
