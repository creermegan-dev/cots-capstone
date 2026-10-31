# New-device verification (email code)

## What it does

- **Sign up:** the account is created immediately. Supabase emails a one-time
  code.
- **First sign-in:** after the email and password, the app asks for that code.
  This verifies the email and trusts the device in one step.
- **Later sign-ins on the same device:** email and password only.
- **Sign-in on a new device** (another phone, a laptop, or a reinstalled app):
  the password is checked, then a new code is emailed and must be entered.
- **Administrator approval** is unchanged and still controls field work.

Codes are emailed (never SMS), so the feature has no cost.

## Why it cannot be skipped

Supabase issues a login session as soon as the password is correct. If the
check lived only in the app, someone with the password could call the API
directly and never see the code screen. The check is therefore enforced by the
database itself (`20261030000200_trusted_devices.sql`):

1. Every table and the private evidence buckets carry a *restrictive* policy:
   data is returned only to a **trusted session**.
2. The role and eligibility helpers used by database functions also require a
   trusted session.
3. A gate runs before every API request and rejects untrusted sessions, except
   for the one function that registers a device.

A session becomes trusted only when the device presents its secret and either
(a) that device is already trusted for the account, or (b) the same device
proved **both** the password and the email code within ten minutes. The proof
comes from the `amr` claim inside the signed session token issued by Supabase
Auth, so the app cannot fake it. The device secret is random, stored in the
Android keystore / Windows Credential Manager, and only its SHA-256 hash is
saved on the server.

Service-role workers (the evidence verifier and its schedule) are not affected.

## Limitations to state during the defense

- Reinstalling the app or clearing its data counts as a new device.
- The device secret proves "this installation", not the person. Losing an
  unlocked phone that is already trusted is not prevented by this feature;
  Administrator deactivation or device revocation handles that.
- Each new device sends one email, so a reliable email sender matters.
- There is no in-app screen yet to list or revoke devices (optional future
  work). The project owner can revoke with SQL:
  `update cots_private.trusted_devices set revoked_at = now() where user_id = '<id>';`

## Rollout order (do not skip steps)

Pause group testing first: the database change signs everyone out, and older
app builds cannot sign in afterwards.

1. **Email delivery.** Supabase Dashboard → Authentication → Emails → SMTP
   Settings. A free sender (Brevo free tier or a Gmail app password) is
   strongly recommended; the built-in sender is heavily rate limited.
2. **Email templates** (Authentication → Emails → Templates). Both must show
   the code `{{ .Token }}`:
   - **Confirm signup** — subject `Your COTS Monitor verification code`, body:
     ```html
     <h2>Verify your email</h2>
     <p>Your COTS Monitor verification code is:</p>
     <p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
     <p>Enter it in the app the first time you sign in.
     If you did not create an account, ignore this email.</p>
     ```
   - **Magic Link** — subject `Your COTS Monitor sign-in code`, body:
     ```html
     <h2>Sign-in code for a new device</h2>
     <p>Your COTS Monitor code is:</p>
     <p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
     <p>If you did not just sign in, change your password and contact the
     Administrator.</p>
     ```
   Keep **Confirm email** enabled.
3. **Local checks** (PowerShell, from the project folder):
   ```powershell
   flutter analyze
   flutter test
   ```
   Optional, with Docker running: `npx supabase start`, then
   `npx supabase migration up` and `npx supabase test db`.
4. **Hosted database** (with group approval):
   ```powershell
   npx --yes supabase@2.121.0 db push --linked --dry-run
   npx --yes supabase@2.121.0 db push --linked
   npx --yes supabase@2.121.0 db query --linked --file supabase/tests/database/step6_trusted_devices.test.sql --agent no --output-format text
   npx --yes supabase@2.121.0 functions deploy verify-evidence --project-ref kgfehorbjzhooxnnkfac
   ```
   The test file rolls back everything it creates.
5. **Rebuild and redistribute the app** with the same `--dart-define` values.
   Everyone signs in again and enters one code per device.
6. **Administrator and Expert:** their account emails must receive mail before
   step 4, or they will not be able to sign in on a new device.

## Emergency rollback

`supabase/deploy/rollback_trusted_devices.sql` removes enforcement while
keeping the data, and makes the app stop asking new devices for a code. Run it
only with group approval (for example if email delivery fails during the
defense). Brand-new accounts still need their signup code unless **Confirm
email** is also switched off in the dashboard. To re-enable, run the
migration's policy, helper, `register_device`, and pre-request sections again.
