[CmdletBinding(DefaultParameterSetName = 'Supervised')]
param(
  [Parameter(Mandatory, ParameterSetName = 'Supervised')]
  [guid]$RequestId,
  [Parameter(Mandatory, ParameterSetName = 'Administrator')]
  [switch]$IndependentAdministrator,
  [string]$SupabaseUrl = $env:SUPABASE_URL
)

$ErrorActionPreference = 'Stop'

function Read-PrivateText([string]$Prompt) {
  $secure = Read-Host $Prompt -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function Invoke-CotsSupabase(
  [string]$Method,
  [string]$Path,
  [hashtable]$Headers,
  [object]$Body = $null
) {
  $parameters = @{
    Method = $Method
    Uri = "$($script:BaseUrl)$Path"
    Headers = $Headers
    ContentType = 'application/json'
  }
  if ($null -ne $Body) { $parameters.Body = ($Body | ConvertTo-Json -Depth 8 -Compress) }
  Invoke-RestMethod @parameters
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  $SupabaseUrl = Read-Host 'Supabase project URL'
}
$script:BaseUrl = $SupabaseUrl.Trim().TrimEnd('/')
if ($script:BaseUrl -notmatch '^https://[a-z0-9-]+\.supabase\.co$') {
  throw 'Expected an HTTPS Supabase project URL.'
}

$serviceRoleKey = Read-PrivateText 'Service-role key'
$headers = @{ apikey = $serviceRoleKey; Authorization = "Bearer $serviceRoleKey" }

try {
  if ($IndependentAdministrator) {
    $slots = Invoke-CotsSupabase GET '/rest/v1/privileged_role_slots?select=user_id&role=eq.administrator' $headers
    if ($slots.Count -ne 1) { throw 'Exactly one Administrator slot is required.' }
    $subjectId = $slots[0].user_id
    $verificationReference = (Read-Host 'Independent owner verification reference').Trim()
    if ([string]::IsNullOrWhiteSpace($verificationReference)) {
      throw 'An independent verification reference is required.'
    }
  } else {
    $request = Invoke-CotsSupabase GET "/rest/v1/recovery_requests?select=id,subject_id,status,expires_at&id=eq.$RequestId" $headers
    if ($request.Count -ne 1 -or $request[0].status -ne 'approved') {
      throw 'The recovery request is missing or is not approved.'
    }
    if ([datetime]$request[0].expires_at -le [datetime]::UtcNow) {
      throw 'The recovery approval has expired.'
    }
    $subjectId = $request[0].subject_id
  }

  $newPassword = Read-PrivateText 'New password'
  $confirmation = Read-PrivateText 'Confirm new password'
  if ($newPassword.Length -lt 8) { throw 'Password must contain at least 8 characters.' }
  if ($newPassword -cne $confirmation) { throw 'Passwords do not match.' }

  Invoke-CotsSupabase PUT "/auth/v1/admin/users/$subjectId" $headers @{
    password = $newPassword
  } | Out-Null

  if ($IndependentAdministrator) {
    $recordId = Invoke-CotsSupabase POST '/rest/v1/rpc/record_independent_administrator_recovery' $headers @{
      person = $subjectId; verification_ref = $verificationReference
    }
    Write-Host "Administrator password updated and audit record created: $recordId"
  } else {
    Invoke-CotsSupabase POST '/rest/v1/rpc/consume_supervised_recovery' $headers @{
      rid = $RequestId; person = $subjectId
    } | Out-Null
    Write-Host 'Password updated and the supervised recovery approval was consumed.'
  }
} finally {
  $newPassword = $null
  $confirmation = $null
  $serviceRoleKey = $null
  $headers = $null
}
