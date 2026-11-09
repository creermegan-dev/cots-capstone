[CmdletBinding()]
param(
  [string]$SupabaseUrl = $env:SUPABASE_URL
)

$ErrorActionPreference = 'Stop'

function Read-PrivateText([string]$Prompt) {
  $secure = Read-Host $Prompt -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  }
}

function Read-ConfirmedPassword([string]$Label) {
  $first = Read-PrivateText "$Label password"
  $second = Read-PrivateText "Confirm $Label password"
  if ($first.Length -lt 8) { throw "$Label password must contain at least 8 characters." }
  if ($first -cne $second) { throw "$Label passwords do not match." }
  return $first
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
$headers = @{
  apikey = $serviceRoleKey
  Authorization = "Bearer $serviceRoleKey"
}
$administrator = $null
$expert = $null
$setupCompleted = $false

try {
  $setup = Invoke-CotsSupabase GET '/rest/v1/setup_state?select=completed_at&singleton=eq.true' $headers
  $slots = Invoke-CotsSupabase GET '/rest/v1/privileged_role_slots?select=role,user_id' $headers
  if ($setup.Count -ne 1) { throw 'Setup-state row is missing.' }
  if ($null -ne $setup[0].completed_at -or $slots.Count -ne 0) {
    throw 'Privileged setup has already started or is sealed. Inspect it before retrying.'
  }

  $administratorEmail = (Read-Host 'Administrator email').Trim().ToLowerInvariant()
  $administratorName = (Read-Host 'Administrator full name').Trim()
  $expertEmail = (Read-Host 'Expert email').Trim().ToLowerInvariant()
  $expertName = (Read-Host 'Expert full name').Trim()
  if ($administratorEmail -eq $expertEmail) {
    throw 'Administrator and Expert must use different accounts.'
  }
  if ([string]::IsNullOrWhiteSpace($administratorName) -or
      [string]::IsNullOrWhiteSpace($expertName)) {
    throw 'Both names are required.'
  }

  $administratorPassword = Read-ConfirmedPassword 'Administrator'
  $expertPassword = Read-ConfirmedPassword 'Expert'
  if ($administratorPassword -ceq $expertPassword) {
    throw 'Administrator and Expert must use different passwords.'
  }

  Write-Host 'Creating the two confirmed Supabase Auth identities...'
  $administrator = Invoke-CotsSupabase POST '/auth/v1/admin/users' $headers @{
    email = $administratorEmail
    password = $administratorPassword
    email_confirm = $true
    user_metadata = @{ full_name = $administratorName }
  }
  $expert = Invoke-CotsSupabase POST '/auth/v1/admin/users' $headers @{
    email = $expertEmail
    password = $expertPassword
    email_confirm = $true
    user_metadata = @{ full_name = $expertName }
  }

  Invoke-CotsSupabase POST '/rest/v1/rpc/appoint_initial_role' $headers @{
    wanted = 'administrator'; person = $administrator.id
  } | Out-Null
  Invoke-CotsSupabase POST '/rest/v1/rpc/appoint_initial_role' $headers @{
    wanted = 'expert'; person = $expert.id
  } | Out-Null
  Invoke-CotsSupabase POST '/rest/v1/rpc/complete_initial_setup' $headers @{} | Out-Null
  $setupCompleted = $true

  Write-Host 'Privileged setup completed: one Administrator and one Expert.'
  Write-Host "Administrator user ID: $($administrator.id)"
  Write-Host "Expert user ID: $($expert.id)"
} catch {
  if (-not $setupCompleted) {
    # Auth user creation and database setup cannot share one transaction.
    # Remove only identities created by this run so a retry cannot duplicate them.
    foreach ($createdUser in @($expert, $administrator)) {
      if ($null -ne $createdUser -and $null -ne $createdUser.id) {
        try {
          Invoke-CotsSupabase DELETE "/rest/v1/privileged_role_slots?user_id=eq.$($createdUser.id)" $headers | Out-Null
          Invoke-CotsSupabase DELETE "/rest/v1/profiles?id=eq.$($createdUser.id)" $headers | Out-Null
          Invoke-CotsSupabase DELETE "/auth/v1/admin/users/$($createdUser.id)" $headers | Out-Null
        } catch {
          Write-Warning "Could not remove partially created user $($createdUser.id). Inspect the project before retrying."
        }
      }
    }
  }
  throw
} finally {
  $administratorPassword = $null
  $expertPassword = $null
  $serviceRoleKey = $null
  $headers = $null
}
