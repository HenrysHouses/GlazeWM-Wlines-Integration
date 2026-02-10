Write-Host "Select program to run"
$AppIcon = "C:/Users/Henri/Desktop/hello.png"
$TARGET_DIR = $args[0]
if (-not $TARGET_DIR) {
    $TARGET_DIR = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
}

$TEMPNAME = "$env:TEMP\targetprograms_list_wlines.txt"
$TEMPPATH = "$env:TEMP\programspaths_list_wlines.txt"

if (-not (Test-Path $TEMPNAME) -or -not (Test-Path $TEMPPATH)) {
    Add-Content -Path $TEMPNAME -Value "Refresh Cache"

    $programheader = New-BTHeader Synopsis "wlines-run: rescan starting"
    $title = "Creating temp files for indexed files"
    $message = "Searching for files with extensions: '.lnk', '.exe', '.bat', '.ps1' and ignored '.ini'\n$"
    New-BurntToastNotification -AppLogo $AppIcon -Text "$title", "$message" -Header $programheader

    $startMenuDirs = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",    # User
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" # All Users / system
    )

    # Helper function to safely enumerate files / read admin accessible files
    function Get-FilesSafely {
        param([string]$Path)
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction Stop |
            Where-Object { -not $_.PSIsContainer -and $_.Extension -ne '.ini' }  # Only files
        } catch {
            Write-Warning "Cannot access folder: $Path"
            return @()
        }
    }

    # scan start menu
    foreach ($dir in $startMenuDirs) {
        Write-Host "Scanning Start Menu folder: $dir"
        $files = Get-FilesSafely $dir
        foreach ($file in $files) {
            Add-Content -Path $TEMPNAME -Value $file.Name
            Add-Content -Path $TEMPPATH -Value $file.FullName
        }
    }

    # path env applications
    $pathDirs = $env:PATH -split ';' |
    Where-Object { $_ -and (Test-Path $_) } |
    ForEach-Object {
        try {
            (Resolve-Path $_).Path.TrimEnd('\')
        } catch {
            $null
        }
    } | Sort-Object -Unique

    foreach ($dir in $pathDirs) {
        Write-Host "Checking directory: $dir"
        Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.lnk', '.exe', '.bat', '.ps1' } |
        ForEach-Object {
            $FULL_PATH = $_.FullName
            $FILENAME  = $_.Name
            Add-Content -Path $TEMPNAME -Value $FILENAME
            Add-Content -Path $TEMPPATH -Value $FULL_PATH
        }
    }

    Add-Content -Path $TEMPNAME -Value "Debug Wline Notification"
    $programheader = New-BTHeader Synopsis "wlines-run: rescan complete"
    $title = "Reindexed filepaths"
    $message = "Loaded all marked executable files: '.lnk', '.exe', '.bat', '.ps1' and ignored '.ini'"
    New-BurntToastNotification -AppLogo $AppIcon -Text "$title", "$message" -Header $programheader
}


Write-Output $TEMPPATH
Write-Output $TEMPNAME

$FILE = "$TEMPNAME"
$FILECONTENT = Get-Content -Path $FILE -Raw

$SELECTION = & wlines-rofi -InputContent $FILECONTENT "Run"
Write-Output "wlines selection: $SELECTION"
if ( $SELECTION -eq "Refresh Cache")
{
    Write-Host "Refreshing"
    Remove-Item -Path "$TEMPNAME"
    Remove-Item -Path "$TEMPPATH"
    # & 'C:\Users\Henri\bin\wlines-run.ps1'
    return
}

if ( $SELECTION -eq "Debug Wline Notification")
{
    Write-Host "Notifying"
    $programheader = New-BTHeader Synopsis "wlines-run: Debug"
    $title = "Manual Debug"
    $message = "Everything OK with? $SELECTION"
    New-BurntToastNotification -AppLogo $AppIcon -Text "$title", "$message" -Header $programheader
    return
}

if ([string]::IsNullOrWhiteSpace($SELECTION)) {
    return
}

$specialChars = @('(', ')', '{', '}', '[', ']', '`', '$', '"', ';', '<', '>', '&', '|')

foreach ($char in $specialChars) {
    $SELECTION = $SELECTION -replace [regex]::Escape($char), "`\$char"
}

$MATCHEDPATH = cat "$TEMPPATH" | rg --no-heading --line-buffered "\\$SELECTION"
Write-Output "target: $MATCHEDPATH"


if ($MATCHEDPATH) {
    Start-Process -FilePath $MATCHEDPATH
} else {
    Write-Output "No matching path found."
    Write-Host "An error occured, could not launch the program: $SELECTION"
    $programheader = New-BTHeader Synopsis "wlines-run: Error"
    $title = "An Error Occured"
    $message = "Could not launch the program: $SELECTION"
    New-BurntToastNotification -AppLogo $AppIcon -Text "$title", "$message" -Header $programheader
}
