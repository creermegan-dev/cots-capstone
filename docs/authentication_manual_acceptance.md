# Authentication manual acceptance checklist

Run these checks during the group testing session with dedicated test email
addresses. Do not use an Administrator or Expert account for Diver signup.

## Already verified automatically

- [x] Signup sends only ordinary profile metadata: full name, phone, job title,
      and organization. It cannot choose a privileged role, activation state,
      or field approval.
- [x] The confirmation callback accepts only
      `cots-monitor://auth-callback/` and safely ignores unrelated links.
- [x] Repeated callback delivery and profile completion are idempotent.
- [x] Expired, invalid, rate-limited, and unconfirmed-email errors have safe
      user messages.
- [x] Android declares the callback deep link and the Windows build registers
      and forwards the callback protocol.
- [x] Hosted email signup is enabled, confirmation is required, the callback is
      allow-listed, and anonymous profile completion is denied.

## Pending email-code and new-device checks (Vivo V25 and Windows)

Email confirmation now uses a 6-digit code typed into the app instead of a
link (see `docs/DEVICE_VERIFICATION.md`). The link callback code remains but
is no longer used.

- [ ] Create a new Diver with a dedicated test email. Pass when the app says
      the account was created and a code email arrives (check Spam).
- [ ] Sign in with that account. Pass when the "Verify your email" screen
      appears and no data screen is shown.
- [ ] Enter a wrong code. Pass when a clear error appears and nothing loads.
- [ ] Enter the correct code. Pass when the account opens, the profile shows
      the submitted name, phone, job title, and organization, and field work
      is still blocked until Administrator approval.
- [ ] Sign out and sign in again on the same device. Pass when no code is
      requested.
- [ ] Sign in to the same account on a second device (or after reinstalling).
      Pass when "Verify this device" appears and a code email arrives.
- [ ] Tap **Send new code** immediately. Pass when the button shows a
      countdown and no second email is sent before it ends.
- [ ] Wait more than 10 minutes after the password step, then enter the code.
      Pass when the app asks you to sign in again instead of trusting the
      device.
- [ ] Tap **Cancel and sign out** on the code screen. Pass when the app
      returns to the start screen.
- [ ] Use a wrong password on a new device. Pass when "Incorrect email or
      password" appears and no code is sent.
- [ ] After the hosted migration is applied, open an older app build that was
      already signed in. Pass when it cannot load data (it predates device
      verification) and the new build asks for one code.
- [ ] Repeat the new-device check on the Windows build.

## Pending email-service checks

- [ ] Confirm delivery to the email providers the group will demonstrate.
- [ ] Check sender name, subject, spam placement, link expiry, and resend delay.
- [ ] Record Supabase's free email rate limits observed during testing and avoid
      rapid repeated sends during the defense.

## Following authentication stages

- [ ] Password recovery and password-change acceptance tests.
- [ ] Mandatory initial-password changes for privileged accounts.
- [ ] Saved-session, logout, account-switch, and disabled-account tests.
- [ ] Optional: authenticator-app two-factor authentication for Administrator
      and Expert accounts.
