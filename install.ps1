<#
.SYNOPSIS
    Initializes the PowerShell environment by setting up a user profile and copying necessary files.
#>
[CmdletBinding()]
param(
    [String]$profileName = "Profile.ps1",

    [ValidateScript({ if (Test-Path $_) { return $true } else { throw "PowerShell profile path '$_' does not exist." } })]
    [String]$profileDestination = "$home\Documents\Powershell", # pwsh7 path

    [ValidateScript({ if (Test-Path $_) { return $true } else { throw "The specified file '$_' does not exist." } })]
    [string]$thisProfile = "$(Split-Path $MyInvocation.MyCommand.Source)\$profileName",

    [Switch]$VSCode = $(if (Get-Command code.cmd -ErrorAction SilentlyContinue) { [Switch]::Present } else { $Null })
)
# Default profile to append custom user profile dot-source
$defaultProfile = $profile.CurrentUserAllHosts

$thisDirectory = Split-Path $MyInvocation.MyCommand.Source

# the destination profile path
$targetProfile = "$profileDestination\$profileName"

# output profile discoveries
Write-Host "Source : $($MyInvocation.MyCommand.Source)"
Write-Host "Custom Profile: $thisProfile"
write-Host "Target Profile: $targetProfile"
Write-Host "Default Profile: $defaultProfile"

# # Create the destination profile directory if it does not exist
# if (!(Test-Path -Path $profileDestination)) {
#     New-Item -ItemType Directory -Path $profileDestination -Force
#     Write-Host "Created directory: $profileDestination" -ForegroundColor Yellow
# }


# # create default profile if it does not exist
# if (-not (Test-Path -Path $defaultProfile)) {
#     New-Item -ItemType File -Path $defaultProfile -Force | Out-Null
#     Write-Host "Created profile file: $($defaultProfile)" -ForegroundColor Yellow
# }

# Copy local profile to the target profile directory, if files do not match
if ((Get-FileHash $targetProfile -ErrorAction SilentlyContinue).Hash -ne (Get-FileHash $thisProfile).Hash) {
    try {
        Copy-Item $thisProfile $targetProfile -Force -PassThru
        Write-Host "Copied profile to: $targetProfile" -ForegroundColor Green
    } catch {
        throw "Failed to copy profile $thisProfile to $targetProfile!`n`t$_"
    }
}

# when the default profile is not the same as the targeted profile, appending dot-source of custom profile
if ($defaultProfile -ne $targetProfile) {
    $updatedProfile = $null
    # append string for custom user profile to be dot-sourced
    [string]$dotSourceProfile = ". '$targetProfile' @PSBoundParameters"
    
    # Read current profile
    try {
        Write-Host "Reading existing profile content from: $defaultProfile"
        $existingProfile = Get-Content -Path $defaultProfile -Raw -ErrorAction Stop
        Write-Host "Existing Profile content: $existingProfile"
    } catch {
        write-warning "Failed to read the profile file: $defaultProfile!`n`t$_"
    }
    
    # if the profile is null, initialize it with our dot-sourced custom profile
    if (-not $existingProfile) {
        Write-Host "Profile file is empty, initializing with custom user profile."
        $updatedProfile = "[CmdletBinding()]`nparam()`n$dotSourceProfile"
    }

    # ensure the profile content has [CmdletBinding()] definition
    if ($existingProfile -notlike "*`[CmdletBinding`(*`)`]*") {
        Write-Host "[CmdletBinding()] not found in profile, adding it to update"
        $updatedProfile = "[CmdletBinding()]"
        # ensure the profile content has Param() block definition
        if ($existingProfile -notlike "*param(*") {
            Write-Host "Param() not found in profile, adding it to update"
            $updatedProfile = "$updatedProfile`nparam()"
        }
        $updatedProfile = "$updatedProfile`n$existingProfile"
    }

    # ensure the profile content has a dot-source for the custom user profile
    if ($existingProfile -notlike "*$dotSourceProfile*" ) {
        Write-Host "Dot-source for custom user profile not found in profile, adding it to update"
        $dotSourceProfile = "`n# dot-source custom user profile - $(get-date -f 'yyyy-MM-dd HH:mm:ss')`n$dotSourceProfile"
        if (-not $updatedProfile) { $updatedProfile = $existingProfile }
        $updatedProfile = "$updatedProfile`n$dotSourceProfile"
    }

    # commit any updated profile content
    if ($updatedProfile -and ($existingProfile -ne $updatedProfile)) {
        Write-Host "Updating profile file with new content: $updatedProfile"
        Set-Content -Path $defaultProfile -Value $updatedProfile -Force
        Write-Host "Updated profile file: $($defaultProfile)" -ForegroundColor Green
    } else {
        Write-Host "No changes made to profile file: $($defaultProfile)"
    }
}

# # Dot-source the default profile to apply the changes
Write-Host "Dot-sourcing the default profile: $defaultProfile"
. "$defaultProfile" @PSBoundParameters
Write-Host "Profile loaded from: $defaultProfile" -ForegroundColor Green

if ($VSCode) {
    Write-Host "Applying default VSCode settings..."
    try { Get-Command code.cmd -ErrorAction Stop | Out-Null } catch { throw "VS Code installation unknown, command 'code.cmd' not found!`n`t$_" }

    try {
        $thisUserSettings = "$thisDirectory\.vscode\Settings.json"
        $currentUserSettings = "$env:APPDATA\Code\User\settings.json"
        Copy-Item $thisUserSettings $currentUserSettings -Force -PassThru -ErrorAction Stop
        Write-Host "Updated VSCode user settings. Replaced [$currentUserSettings] with [$thisUserSettings] successfully!" -ForegroundColor Green
    } catch {
        throw "Failed to update VS Code user settings.json!`n`t$_"
    }

    # Open Profile workspace in VS Code
    # defaultWorkspace = "$thisDirectory\.vscode\*.code-workspace"
    # if (test-path $defaultWorkspace  ) { code.cmd $defaultWorkspace }
}

# Copy Windows Terminal settings file path
# Search for wt.exe / WindowsTerminal.exe directory
# Copy-Item ..\.WindowsTerminal\settings.json $env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
