# Supabase Step 2: Authentication

## Status

The Flutter authentication adapter, database hardening migrations, supervised
recovery tools, and tests are implemented. Migrations
`20261016000400_auth.sql` and
`20261019000100_fix_auth_directory_email_type.sql` have been applied to the
hosted `cots-monitor` test project (`kgfehorbjzhooxnnkfac`). No real
Administrator, Expert, or Diver account has been created.

The app uses Supabase Auth only when both `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` are supplied as compile-time values. Without them,
the existing Firebase authentication path remains available. A service-role
key must never be passed to the Flutter app.

## Implemented behavior

- Diver registration creates an ordinary account. Client metadata can set only
  the display name; it cannot grant a role, activate a privileged account, or
  verify field personnel.
- Login, profile loading, profile editing, current-password verification,
  password changes, session refresh, and logout use Supabase Auth when enabled.
- Sessions are stored with `flutter_secure_storage`, using Android keystore
  protection and Windows Credential Manager-backed encryption.
- Account roles are read from `privileged_role_slots`. The client does not trust
  role claims in signup metadata.
- The Administrator personnel directory is a restricted database function. It
  returns only the profile fields and email needed for verification and account
  support.
- Field-personnel verification remains an Administrator-only database action.
- Ordinary account recovery requires an Administrator identity check and a
  single-use, 15-minute approval. The new password is entered privately into
  the owner recovery tool. Administrator recovery uses the independent project
  owner procedure and cannot use the ordinary-user path.
- Initial setup cannot be sealed unless exactly one Administrator and one
  Expert exist in the two fixed privileged role slots.

## Hosted verification results

- The linked project was verified as `cots-monitor`, project reference
  `kgfehorbjzhooxnnkfac`.
- The first Step 2 pgTAP run found a PostgreSQL return-type mismatch in
  `administrator_personnel_directory()`: `auth.users.email` is `varchar`, while
  the function contract returns `text`.
- The corrective migration adds the explicit `u.email::text` cast and changes
  no tables, policies, roles, or authentication settings.
- The Step 2 pgTAP suite completed with **28/28 assertions passing** and no
  `not ok` results.
- The test transaction rolled back successfully. Synthetic Auth users,
  profiles, privileged role slots, and recovery requests all returned to zero.
  Total Auth users, profiles, privileged role slots, and recovery requests also
  remained zero, and initial setup remains unsealed.
- A final migration dry run reported that the remote database is up to date.

Local checks completed during Step 2:

- Full Flutter test suite: **46/46 passed**.
- Focused Supabase authentication tests: **5/5 passed**.
- Step 2 static security checks: **17/17 passed**.
- Focused analysis of the final authentication hardening files: no issues.
- A Windows build was attempted but did not progress past NuGet dependency
  resolution, so a successful Windows compilation is still unconfirmed.

## Hosted configuration still required

These operations require separate approval because they change the hosted test
project or create temporary identities:

1. Keep **Confirm Email** enabled and configure the Site URL / redirect URLs for
   the deployed app. Signup now shows a verification prompt and supports
   resending the confirmation email. Verified email is also required before
   authenticator-based two-factor enrollment.
2. Run the hosted synthetic authentication test. It creates temporary synthetic
   Divers and removes them afterward.
3. Test login, session restoration, logout, and secure local session storage on
   Android and Windows.
4. After those checks pass, run the privileged-account setup tool and privately
   enter the real Administrator and Expert details and passwords.

The initial setup needs the project URL and the service-role key. The key is
entered through a masked prompt and is used only by the local owner tool. The
Flutter app needs only the project URL and publishable key.

## Commands

Confirm that the hosted migration history is current:

```powershell
npx --yes supabase@2.121.0 db push --linked --dry-run --skip-vault --agent no --output-format text
```

The Step 2 pgTAP suite was run with:

```powershell
npx --yes supabase@2.121.0 db query --linked --file supabase/tests/database/step2_auth_security.test.sql --agent no --output-format text
```

After separate approval to create temporary test identities, run:

```powershell
.\scripts\test_supabase_auth_cloud.ps1 -SupabaseUrl https://PROJECT_REF.supabase.co
```

The test prompts privately for the publishable and service-role keys, creates
two random synthetic Divers, checks signup/login and denial rules, and removes
the synthetic profiles and Auth identities in `finally` cleanup.

Create the real fixed privileged identities only after testing:

```powershell
.\scripts\setup_supabase_privileged_accounts.ps1 -SupabaseUrl https://PROJECT_REF.supabase.co
```

The tool checks that setup is empty and unsealed, masks all passwords and the
service-role key, creates confirmed identities, assigns the two fixed roles,
and seals setup. If setup fails before sealing, it attempts to remove only the
identities created by that run. Inspect the project before retrying if cleanup
reports a warning.

Build or run the Flutter app with public configuration only:

```powershell
flutter run -d windows --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=PUBLIC_KEY
```

Use the same two `--dart-define` values for Android. Do not save credentials in
source control. Windows builds using `flutter_secure_storage` require the C++
ATL component in Visual Studio Build Tools. Android already targets the plugin's
minimum API level, and app-data backup is disabled to avoid restoring encrypted
session data without its device key.

## Recovery operations

For ordinary users, the Administrator opens the personnel page, verifies the
person through the agreed in-person procedure, and creates a recovery approval.
The project owner runs:

```powershell
.\scripts\complete_supabase_password_recovery.ps1 -RequestId REQUEST_UUID -SupabaseUrl https://PROJECT_REF.supabase.co
```

The owner enters the service-role key and new password through masked prompts.
The request must still be approved and unexpired, and is permanently marked
consumed after the password update.

For the sole Administrator, the independent project owner verifies identity
outside the app and runs:

```powershell
.\scripts\complete_supabase_password_recovery.ps1 -IndependentAdministrator -SupabaseUrl https://PROJECT_REF.supabase.co
```

The tool targets only the identity occupying the Administrator slot and records
an immutable recovery audit event.

## Current migration boundary

Authentication and the personnel administration path can use Supabase. Detect,
Records, GIS, follow-up persistence, reassignment, images, and notifications
still use their existing Firebase repositories. When the app is launched with
Supabase configuration, those Firebase-protected data operations do not receive
a Firebase session. Their backend migration remains a later stage; local AI
inference and the existing UI code have not been removed.

This staged limitation must be tested visibly before distributing a Supabase
build. Firebase data and packages remain untouched so the existing build can be
used as the rollback path.
