# Email-code password recovery

The app's Forgot Password flow calls Supabase `/recover`, verifies the code
with `OtpType.recovery`, and updates the password with a separate in-memory
Auth client. It never uses a privileged key, trusts a device, edits a role, or
opens the dashboard. The user signs in normally after resetting the password.

## Hosted change pending approval

In Supabase Dashboard → Authentication → Email Templates → Reset Password,
back up the existing subject and body. Change only:

- Subject: `Reset your COTS Monitor password`
- Body: the contents of `recovery.html` in this directory.

The required variable is `{{ .Token }}`. Do not change signup, Magic Link,
SMTP credentials, device trust, role slots, RLS, or database data.
The current email sender must support delivery to the user's address; this
template does not change sender restrictions or Auth rate limits.

Do not send recovery messages or change real passwords merely to test.
Mocked HTTP/widget tests cover the app flow. Actual delivery and hosted settings
must be checked separately after the template update is approved.
Keep the existing supervised owner tools as a fallback.

References:

- https://supabase.com/docs/reference/dart/auth-resetpasswordforemail
- https://supabase.com/docs/reference/dart/auth-verifyotp
- https://supabase.com/docs/guides/auth/auth-email-templates
