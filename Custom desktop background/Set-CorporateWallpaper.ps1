<#
.SYNOPSIS
    Sets corporate wallpaper and removes old wallpaper files.
.AUTHOR
    Sethu Kumar B
.VERSION
    1.6 - Genericised file names for public repo
#>

param (
    [string]$Image
)

# --- Configuration ---
$NewWallpaperFile  = "New_Wallpaper.jpg"       # <-- Update with new wallpaper filename
$OldWallpaperFiles = @(                        # <-- Add old wallpaper filenames to remove
    "Old_Wallpaper_v1.jpg",
    "Old_Wallpaper_v1.png",
    "Old_Wallpaper_v2.jpg"
)
$WallpaperDir = "C:\Windows\web\wallpaper\Windows"

# Fallback if $Image not passed
if (-not $Image) { $Image = "$WallpaperDir\$NewWallpaperFile" }

# --- Remove old wallpapers ---
foreach ($file in $OldWallpaperFiles) {
    $fullPath = "$WallpaperDir\$file"
    if (Test-Path -Path $fullPath) {
        Remove-Item -Path $fullPath -Force
        Write-Output "Deleted: $file"
    }
}

# --- Copy new wallpaper to destination ---
Copy-Item "$PSScriptRoot\$NewWallpaperFile" $WallpaperDir -Force

# --- Set wallpaper via Win32 API ---
Function Set-WallPaper {
    param ([string]$Image)
    if (-not ([System.Management.Automation.PSTypeName]'Params').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Params {
    [DllImport("User32.dll", CharSet=CharSet.Unicode)]
    public static extern int SystemParametersInfo(Int32 uAction, Int32 uParam, String lpvParam, Int32 fuWinIni);
}
"@
    }
    $SPI_SETDESKWALLPAPER = 0x0014
    $fWinIni = 0x01 -bor 0x02
    [Params]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $Image, $fWinIni) | Out-Null
}

# --- Set wallpaper style to Fit in logged-in user's registry hive ---
Function Set-WallpaperStyleFit {
    $loggedInUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
    if (-not $loggedInUser) {
        Write-Output "No logged-in user detected. Skipping registry wallpaper style update."
        return
    }

    $userSID = (New-Object System.Security.Principal.NTAccount($loggedInUser)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value

    $regPath = "HKU:\$userSID\Control Panel\Desktop"

    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    }

    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value "6"   # 6 = Fit
        Set-ItemProperty -Path $regPath -Name "TileWallpaper"  -Value "0"
        Write-Output "Wallpaper style set to Fit for user: $loggedInUser ($userSID)"
    } else {
        Write-Output "Registry path not found for SID: $userSID"
    }
}

Set-WallPaper -Image $Image
Set-WallpaperStyleFit
