[CmdletBinding()]
param(
  [string]$SupabaseUrl = $env:SUPABASE_URL
)

$ErrorActionPreference = 'Stop'

function Read-PrivateText([string]$Prompt) {
  $secure = Read-Host $Prompt -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function Invoke-Json(
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
  if ($null -ne $Body) {
    $parameters.Body = $Body | ConvertTo-Json -Depth 8 -Compress
  }
  Invoke-RestMethod @parameters
}

function Assert-Forbidden(
  [string]$Name,
  [string]$Method,
  [string]$Path,
  [hashtable]$Headers,
  [object]$Body = $null
) {
  try {
    Invoke-Json $Method $Path $Headers $Body | Out-Null
    throw "FAIL ${Name}: request unexpectedly succeeded."
  } catch {
    $status = [int]$_.Exception.Response.StatusCode
    if ($status -lt 400 -or $status -ge 500) { throw }
    Write-Host "PASS $Name"
  }
}

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  $SupabaseUrl = Read-Host 'Supabase project URL'
}
$script:BaseUrl = $SupabaseUrl.Trim().TrimEnd('/')
if ($script:BaseUrl -notmatch '^https://[a-z0-9-]+\.supabase\.co$') {
  throw 'Expected an HTTPS Supabase project URL.'
}

$publishableKey = Read-PrivateText 'Publishable or anon key'
$serviceRoleKey = Read-PrivateText 'Service-role key'
$publicHeaders = @{ apikey = $publishableKey }
$ownerHeaders = @{
  apikey = $serviceRoleKey
  Authorization = "Bearer $serviceRoleKey"
}
$createdUsers = [System.Collections.Generic.List[string]]::new()
$suffix = [guid]::NewGuid().ToString('N')
$passwordA = "S2a!$([guid]::NewGuid().ToString('N'))"
$passwordB = "S2b!$([guid]::NewGuid().ToString('N'))"

try {
  $signupA = Invoke-Json POST '/auth/v1/signup' $publicHeaders @{
    email = "step2-a-$suffix@example.com"
    password = $passwordA
    data = @{ full_name = 'Synthetic Diver A' }
  }
  if ($null -ne $signupA.user.id) { $createdUsers.Add($signupA.user.id) }
  if ([string]::IsNullOrWhiteSpace($signupA.access_token)) {
    throw 'Signup returned no session. Confirm Email must be disabled for the approved workflow.'
  }
  Write-Host 'PASS Diver signup creates an immediate session'

  $signupB = Invoke-Json POST '/auth/v1/signup' $publicHeaders @{
    email = "step2-b-$suffix@example.com"
    password = $passwordB
    data = @{ full_name = 'Synthetic Diver B' }
  }
  if ($null -ne $signupB.user.id) { $createdUsers.Add($signupB.user.id) }
  if ([string]::IsNullOrWhiteSpace($signupB.access_token)) {
    throw 'Second signup returned no session.'
  }
  Write-Host 'PASS Multiple Divers can register'

  $loginA = Invoke-Json POST '/auth/v1/token?grant_type=password' $publicHeaders @{
    email = "step2-a-$suffix@example.com"
    password = $passwordA
  }
  if ($loginA.user.id -ne $signupA.user.id) {
    throw 'FAIL Password login returned a different identity.'
  }
  Write-Host 'PASS Password login preserves identity'

  $userAHeaders = @{
    apikey = $publishableKey
    Authorization = "Bearer $($loginA.access_token)"
  }
  $ownProfile = Invoke-Json GET "/rest/v1/profiles?select=id,full_name,active,field_verified&id=eq.$($signupA.user.id)" $userAHeaders
  if ($ownProfile.Count -ne 1 -or $ownProfile[0].field_verified) {
    throw 'FAIL New Diver profile or verification default is incorrect.'
  }
  Write-Host 'PASS New Diver can read only the generated unverified profile'

  $otherProfile = Invoke-Json GET "/rest/v1/profiles?select=id&id=eq.$($signupB.user.id)" $userAHeaders
  if ($otherProfile.Count -ne 0) {
    throw 'FAIL Diver A could read Diver B profile.'
  }
  Write-Host 'PASS Divers cannot read another user profile'

  Assert-Forbidden 'Diver cannot self-verify' PATCH "/rest/v1/profiles?id=eq.$($signupA.user.id)" $userAHeaders @{
    field_verified = $true
  }
  Assert-Forbidden 'Diver cannot read the Administrator directory' POST '/rest/v1/rpc/administrator_personnel_directory' $userAHeaders @{}
  Assert-Forbidden 'Diver cannot approve supervised recovery' POST '/rest/v1/rpc/begin_supervised_recovery' $userAHeaders @{
    person = $signupB.user.id
    verification_ref = 'forged'
  }
} finally {
  foreach ($userId in $createdUsers) {
    try {
      Invoke-Json DELETE "/rest/v1/profiles?id=eq.$userId" $ownerHeaders | Out-Null
      Invoke-Json DELETE "/auth/v1/admin/users/$userId" $ownerHeaders | Out-Null
    } catch {
      Write-Warning "Synthetic user $userId could not be removed. Inspect it manually."
    }
  }
  $passwordA = $null
  $passwordB = $null
  $publishableKey = $null
  $serviceRoleKey = $null
  $publicHeaders = $null
  $ownerHeaders = $null
}

Write-Host 'All hosted Step 2 authentication checks passed; synthetic users were removed.'
