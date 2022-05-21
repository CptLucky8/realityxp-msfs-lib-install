New-Variable "Reality XP MSFS LibInstall License" @'

# MIT License                                                                   
#                                                                               
# RXP Installation Helpers Library for Microsoft Flight Simulator               
# Copyright(c) 2020-2022 Jean-Luc Dupiot - Reality XP                           
#                                                                               
# Permission is hereby granted, free of charge, to any person obtaining a copy  
# of this software and associated documentation files(the "Software"), to deal  
# in the Software without restriction, including without limitation the rights  
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell   
# copies of the Software, and to permit persons to whom the Software is         
# furnished to do so, subject to the following conditions :                     
#                                                                               
# The above copyright notice and this permission notice shall be included in    
# all copies or substantial portions of the Software; This banner shall not     
# be modified nor removed.                                                      
#                                                                               
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE    
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     
# THE SOFTWARE.                                                                 

'@ -Option Constant

# PromptYesNo
# Show-MessageBox
# Select-ItemList
# Select-Folder
# Test-PathExists
# Test-FileExists
# Test-DirExists
# Get-FsStoreVersion
# Get-FsAppDataPath
# Get-FsPackagesPath
# Get-FsCommunityPath
# Get-FsOfficialPath
# Find-FsPackagePath

# =======================================================
# Internal Helpers
# =======================================================
#region

# $script:FsStoreVers     # The MSFS store version ("Steam", "OneStore").
# $script:FsStorePath     # The MSFS parent path to "UserCfg.opt".
# $script:FsPacksPath     # The MSFS InstalledPackagesPath path.

<#
.Synopsis
    Using Shell32 known folders should be more robust than env vars.
​#>
Add-Type @"

    using System;
    using System.Runtime.InteropServices;

    public static class KnownFolder
    {
        public static readonly Guid LocalAppData = new Guid( "F1B32785-6FBA-4FCF-9D55-7B8E7F157091" );
        public static readonly Guid RoamingAppData = new Guid( "3EB685DB-65F9-4CF6-A03A-E3EF65729F3D" );
    }

    public class shell32
    {
        [DllImport("shell32.dll")]
        private static extern int SHGetKnownFolderPath(
             [MarshalAs(UnmanagedType.LPStruct)] 
             Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr pszPath 
        );

        public static string GetKnownFolderPath(Guid rfid) {
           IntPtr pszPath;
           if (SHGetKnownFolderPath(rfid, 0, IntPtr.Zero, out pszPath) != 0)
               return "";
           string path = Marshal.PtrToStringUni(pszPath);
           Marshal.FreeCoTaskMem(pszPath);
           return path;
        }
    }
"@

<#
.Synopsis
    Locate the parent path to the UserCfg.opt file.

.Description
    This is the per-user local app data folder where MSFS stores runtime data.
    This function also saves the store version (Steam or OneStore)
​#>
Function FsAutoDetectStore {
    if ($null -ne $script:FsStorePath) { return $True }
        
    # copyright notice: do not remove
    ((${Reality XP MSFS LibInstall License} -replace '#', '') -split "`n") | Select-Object -First 5 | ForEach-Object { Write-Host "$_" -BackgroundColor Black -ForegroundColor Yellow }
    
    try {
        $steamPath = Join-Path $([shell32]::GetKnownFolderPath([KnownFolder]::RoamingAppData)) "Microsoft Flight Simulator\UserCfg.opt"
        $steamPathExists = Test-FileExists($steamPath)

        $storePath = Join-Path $([shell32]::GetKnownFolderPath([KnownFolder]::LocalAppData)) "Packages\Microsoft.FlightSimulator_8wekyb3d8bbwe\LocalCache\UserCfg.opt"
        $storePathExists = Test-FileExists($storePath)

        if ($steamPathExists -and $storePathExists) {
            Write-Host ""
            Write-Host "It looks like both Steam and Store versions are installed"
            if ((PromptYesNo "Do you want to continue with the Steam version?")) { $storePathExists = $false } else { $steamPathExists = $false }
        }
        if ($steamPathExists) {
            $script:FsStoreVers = "Steam"
            $script:FsStorePath = (Split-Path $steamPath)
            return $True
        }
        if ($storePathExists) {
            $script:FsStoreVers = "OneStore"
            $script:FsStorePath = (Split-Path $storePath)
            return $True
        }
    } catch {}
    $script:FsStoreVers = $null
    $script:FsStorePath = $null
    return $False
}

<#
.Synopsis
    Locate the parent path to the 'Official' and the 'Community' folders.

.Description
    This path is set with the 'InstalledPackagesPath' property in the 'UserCfg.opt' file.
    This function also outputs an error message once, whether it fails or the path is invalid.
​#>
Function FsAutoDetectPackages {
    if ($null -ne $script:FsPacksPath) { return $True }

    if (FsAutoDetectStore) {
        $err = $null
        $usercfgPath = Join-Path $script:FsStorePath "UserCfg.opt"
        if (Test-Path $usercfgPath) { 
            if ((Select-String -Path $usercfgPath -Pattern 'InstalledPackagesPath' -List) -match '"([^"]*)"') {
                $path = $matches[1]
                if (Test-Path $path) {
                    $script:FsPacksPath = $path
                    return $True
       
                } else { $err = "InstalledPackagesPath not found: $path" }
            } else { $err = "InstalledPackagesPath entry missing: $userCfgPath" }
        } else { $err = "UserCfg.opt file not found" }

        $script:FsPacksPath = $null
        if ($null -eq $script:FsErrConfig) {
            $script:FsErrConfig = $err
            Write-Host ""
            Write-Host $err -BackgroundColor Black -ForegroundColor Red
        }
    }
    return $False
}

#endregion

# =======================================================
# UI Functions
# =======================================================
#region

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

<#
.Synopsis
    Display a system message box.
​#>
Function Show-MessageBox {
    Param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]$Msg,
        [string]$Title = 'Message Box',
        [System.Windows.MessageBoxButton]$Button = [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Question
    )
    return [System.Windows.MessageBox]::Show($Msg, $Title, $Button, $Icon)
}

<#
.Synopsis
    Prompt the user and wait for Y or N.
​#>
Function PromptYesNo {
    Param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]$Msg,
        [switch]$Box
    )
    if ($Box -or $psISE) {
        # "ReadKey" not supported in PowerShell ISE.
        $result = Show-MessageBox($Msg, 'Select an option...')
        if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return $false }
        return $true
    }
    :prompt while ($true) {
        Write-Host ($Msg + "  (type Y or N)")  -NoNewLine -BackgroundColor Black -ForegroundColor Yellow
        switch ([console]::ReadKey($true).Key) {
            { $_ -eq [System.ConsoleKey]::Y } { break prompt }
            { $_ -eq [System.ConsoleKey]::N } { return $false }
            default {
                # displayedMessage.length - errorMessage.length = 9
                if ($Msg.Length -gt 9) { $padding = ($Msg.Length - 9) } else { $padding = 0 }
                Write-Host ("`rOnly 'Y' or 'N' allowed!" + " "*($padding)) -ForegroundColor Red 
            }
        }
    }
    Write-Host ""
    return $true
}

<#
.Synopsis
    Display a list of selectable items.

.Example
    $selected = Select-ItemList -Items "1st", "2nd", "3rd"
    if ($null -ne $selected) { }
​#>
Function Select-ItemList {
    Param(
        [ValidateNotNullOrEmpty()]
        [string[]]$Items = @("..."),
        [string]$Title = "Selection",
        [string]$Desc = "Select an item:",
        [int]$Width = 300,
        [int]$Height = 300,
        [int]$SelectedIndex = -1,
        [switch]$NoResize,
        [switch]$AsIndex
    )
    [int]$CenterX = [int]$Width / 2
    [int]$ButtonX = [int]$CenterX - 75
    [int]$ButtonY = [int]$Height - 80
    [int]$LabelW = [int]$Width - 20
    [int]$ListW = [int]$Width - 40
    [int]$ListH = [int]$Height - 130

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size($Width,$Height)
    $form.StartPosition = 'CenterScreen'

    if ($NoResize) {
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog;
        $form.SizeGripStyle = [System.Windows.Forms.SizeGripStyle]::Hide
        $form.MinimizeBox = $false;
        $form.MaximizeBox = $false;
    }
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size([int]$LabelW,20)
    $label.Text = $Desc
    $form.Controls.Add($label)
    
    $butAccept = New-Object System.Windows.Forms.Button
    $butAccept.Location = New-Object System.Drawing.Point([int]$ButtonX, [int]$ButtonY)
    $butAccept.Size = New-Object System.Drawing.Size(75,23)
    $butAccept.Text = 'OK'
    $butAccept.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($butAccept)
    $form.AcceptButton = $butAccept

    $butCancel = New-Object System.Windows.Forms.Button
    $butCancel.Location = New-Object System.Drawing.Point($CenterX, [int]$ButtonY)
    $butCancel.Size = New-Object System.Drawing.Size(75,23)
    $butCancel.Text = 'Cancel'
    $butCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($butCancel)
    $form.CancelButton = $butCancel

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10,40)
    $listBox.Size = New-Object System.Drawing.Size([int]$ListW,20)
    $listBox.Height = [int]$ListH
    $listBox.BeginUpdate();
    foreach($it in $Items) { [void] $listBox.Items.Add($it) }
    $listBox.EndUpdate();
    $form.Controls.Add($listBox)
    $form.Topmost = $true

    # this enables using the return key to quickly accept a default item.
    if ($SelectedIndex -ge 0) { $listBox.SelectedIndex = $SelectedIndex }

    if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::Ok) {
        if ($AsIndex) { return $listBox.SelectedIndex }
        else { return $listBox.SelectedItem }
    }
    if ($AsIndex) { return -1 }
    return $null
}

<#
.Synopsis
    Open a 'browse to folder' system dialog.
​#>
Function Select-Folder() {
    Param(
        [string]$Path = $null,
        [string]$Title = "Select the folder..."
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $diag = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($Path -eq $null) { $diag.RootFolder = "MyComputer" }
    $diag.Description = $Title
    $diag.SelectedPath = $Path
    if ($diag.ShowDialog() -eq "OK") { return $diag.SelectedPath }
    else { return $null }
}

#endregion

# =======================================================
# Test Path Functions
# =======================================================
#region

Function Test-PathExists($Path) {
    if (($null -ne $Path) -and (Test-Path $Path)) { return $true }
    return $false
}

Function Test-FileExists($Path) {
    if (($null -ne $Path) -and (Test-Path $Path -PathType Leaf)) { return $true }
    return $false
}

Function Test-DirExists($Path) {
    if (($null -ne $Path) -and (Test-Path $Path -PathType Container)) { return $true }
    return $false
}

#endregion

# =======================================================
# FS Path Functions
# =======================================================
#region

<#
.Synopsis
    Get the FS store type (Steam or OneStore)
#>
Function Get-FsStoreVersion {
    return $script:FsStoreVers
}

<#
.Synopsis
    Get a valid FS application path or null.

.Example
    $path = Get-FsAppDataPath -Path 'Content.xml'

    Get the full path to 'content.xml' file.
​#>
Function Get-FsAppDataPath {
    Param( [string]$Path )
    
    if (FsAutoDetectStore) { 
        if ($null -eq $Path) { $Path = "" }
        $fullPath = Join-Path $script:FsStorePath $Path
        if (Test-Path $fullPath) { return $fullPath }
    }
    return $null
}

<#
.Synopsis
    Get a valid FS installed package path or null.

.Example
    $path = Get-FsPackagesPath("Community")

    Get the full path to the Community folder found in 'InstalledPackagesPath'
​#>
Function Get-FsPackagesPath {
    Param( [string]$Path )
    
    if (FsAutoDetectPackages) { 
        if ($null -eq $Path) { $Path = "" }
        $fullPath = Join-Path $script:FsPacksPath $Path
        if (Test-Path $fullPath) { return $fullPath }
    }
    return $null
}

<#
.Synopsis
    Get a valid FS Community package path or null.

.Example
    $path = Get-FsCommunityPath("flybywire-aircraft-a320-neo\manifest.json")

    Get the full path to this optional community package file.
​#>
function Get-FsCommunityPath {
    Param( [string]$Path )

    $packagesPaths = (Get-FsPackagesPath("")), (Get-FsAppDataPath("Packages\"))
    foreach ($base in $packagesPaths) {
        if ($null -ne $base) {
            if ($null -eq $Path) { $Path = "" }
            $fullPath = Join-Path (Join-Path $base "Community\") $Path
            if (Test-Path $fullPath) { return $fullPath }
        }
    }
    return $null
}

<#
.Synopsis
    Get a valid FS Official Packages path or null.

.Example
    $path = Get-FsOfficialPath("fs-base/manifest.json")

    Get the full path to this mandatory official package file
​#>
function Get-FsOfficialPath {
    Param( [string]$Path )

    if (FsAutoDetectPackages) {
        $packagesPaths = (Get-FsPackagesPath("")), (Get-FsAppDataPath("Packages\"))
        foreach ($base in $packagesPaths) {
            if ($null -ne $base) {
                if ($null -eq $Path) { $Path = "" }
                $fullPath = Join-Path (Join-Path (Join-Path $base "Official\") $script:FsStoreVers) $Path
                if (Test-Path $fullPath) { return $fullPath }
            }
        }
    }
    return $null
}

<#
.Synopsis
    Get any valid FS Packages path with user assistance if needed.
    
.Description
    This function automatically locate the package path in either or both Official (1st) and Community (2nd).
    It can prompt the user to manually select the package root path if none was automatically found.

.Example
    $path = Find-FsPackagePath("fs-base/manifest.json") -Official

    Get the full path to the Official package file, otherwise prompt the user to locate 'fs-base'.
​
.Example
    $path = Find-FsPackagePath -Path "flybywire-aircraft-a320-neo\manifest.json" -Community

    Get the full path to the Community package file, otherwise prompt the user to locate 'flybywire-aircraft-a320-neo'.
​
.Example
    $path = Find-FsPackagePath("package-name/manifest.json") -NoPrompt
    
    Get the full path to 'package-name/manifest.json' or return null.
#>
Function Find-FsPackagePath {
    [CmdletBinding(DefaultParameterSetName='OfficialAndCommunity')]
    Param( 
        [Parameter(Mandatory, Position=0)]
        [Parameter(ParameterSetName='OfficialAndCommunity')]
        [Parameter(ParameterSetName='OfficialOnly')]
        [Parameter(ParameterSetName='CommunityOnly')]
        [string]$Path,
        
        # Silently return $null if not found.
        [switch]$NoPrompt,
        # Join user selected path parent with Path if true,
        # otherwise join user selected path with child of Path.
        [switch]$StrictMatch,
        
        # Path is an Official Packages only.
        [Parameter(ParameterSetName='OfficialOnly')]
        [switch]$Official,
        
        # Path is a Community Package only.
        [Parameter(ParameterSetName='CommunityOnly')]
        [switch]$Community
    )
    
    $packagePath = $null
    if (($null -eq $packagePath) -and (!$Community)) { $packagePath = Get-FsOfficialPath($Path)  }
    if (($null -eq $packagePath) -and (!$Official )) { $packagePath = Get-FsCommunityPath($Path) }
    if (($null -ne $packagePath) -or  ( $NoPrompt )) { return $packagePath }

    $folderName = $Path.Split('\')[0]
    
    # Write-Host ""
    Write-Host "`rPackage not found: $Path" -BackgroundColor Black -ForegroundColor Red
    Write-Host ""
    Write-Host "  '$folderName' should be located alongside other packages 'asobo-aircraft-xxxx', 'microsoft-airport-xxxx', etc..."
    Write-Host ""
    if (($null -eq $script:FsStoreVers) -or ("Steam" -eq $script:FsStoreVers)) {
        Write-Host "  Custom Location Example:"
        Write-Host "  - {drive}:\FS2020\Official\Steam\$folderName" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Standard Locations (Steam):"
        Write-Host "  - \steamapps\common\MicrosoftFlightSimulator\Additional Packages\Official\Steam\$folderName" -ForegroundColor DarkGray
        Write-Host "  - {drive}:\Users\{user name}\AppData\Roaming\Microsoft Flight Simulator\Packages\Official\Steam\$folderName" -ForegroundColor DarkGray
    }
    if (($null -eq $script:FsStoreVers) -or ("OneStore" -eq $script:FsStoreVers)) {
        Write-Host "  Custom Location Example:"
        Write-Host "  - {drive}:\FS2020\Official\OneStore\$folderName" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Standard Location (Store):"
        Write-Host "  - {drive}:\Users\{user name}\AppData\Local\Packages\Microsoft.FlightSimulator_8wekyb3d8bbwe\LocalCache\Packages\Official\OneStore\$folderName" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Browse to the '$folderName' package location... (hidden folders must be visible)" -ForegroundColor Yellow

    $defaultPath = Get-FsPackagesPath("")
    if ($null -eq $defaultPath) {
         $defaultPath = Get-FsAppDataPath("Packages\") 
    }

    while ($true) {
        $packagePath = Select-Folder -Path $defaultPath -Title "Select the '$folderName' folder..."
        if ($null -ne $packagePath) {
            if ($StrictMatch) {
                $packagePath = Join-Path (Split-Path $packagePath) $Path
            } else {
                $packagePath = Join-Path $packagePath $Path.Substring($folderName.Length)
            }
            if (Test-Path $packagePath) { return $packagePath  }

            Write-Host "Invalid path: $packagePath`n" -BackgroundColor Black -ForegroundColor Red
            if (!(PromptYesNo "Do you want to retry?")) { return $null }
        
        } else { return $null }
    }
}

#endregion
