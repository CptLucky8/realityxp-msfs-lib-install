# realityxp-msfs-lib-install
RXP Installation Helpers Library for Microsoft Flight Simulator

Example:

    Write-Host "Searching files..." -NoNewline

    $AsoboUiPath = "fs-base\scenery\Global\Asobo_UI\Asobo_UI.BGL"
    $path = Find-FsPackagePath $AsoboUiPath
    if ($null -eq $path) {
        Write-Host "`nPackage not found: " $AsoboUiPath -ForegroundColor Red
        Exit
    }
    Write-Host "`n  $path" -NoNewline
    Write-Host " ($(Get-FsStoreVersion))" -ForegroundColor DarkGray
    
Output:
    
      X:\MyCustomPathToFs2020\Official\OneStore\fs-base\scenery\Global\Asobo_UI\Asobo_UI.BGL (OneStore)
