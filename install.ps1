#Requires -Version 5.1

param(
    [string]$InstallDir = "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps",
    [switch]$Help
)

# Show help
if ($Help) {
    Write-Host "SBOR Installation Script for Windows PowerShell"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  powershell -ExecutionPolicy Bypass -Command `"iwr -useb https://raw.githubusercontent.com/Vaishnav-Sabari-Girish/sbor/main/install.ps1 | iex`""
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -InstallDir    Installation directory (default: WindowsApps)"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1 -InstallDir `"C:\Tools`""
    Write-Host ""
    exit 0
}

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Hide progress bars for faster downloads

$Config = @{
    Repo = "Vaishnav-Sabari-Girish/sbor"
    InstallDir = $InstallDir
    TempDir = Join-Path $env:TEMP "sbor-install-$(Get-Random)"
    GitHubApi = "https://api.github.com/repos/Vaishnav-Sabari-Girish/sbor"
}

# Global error flag
$Global:InstallationFailed = $false

# Helper functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Write-FatalError {
    param([string]$Message)
    Write-Log $Message "ERROR"
    $Global:InstallationFailed = $true
    Remove-TempFiles
    exit 1
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Test-Dependencies {
    Write-Log "Checking dependencies..."
    
    $missingDeps = @()
    
    if (-not (Test-CommandExists "cmake")) {
        $missingDeps += "cmake"
    }
    
    # Check for compiler
    $hasCompiler = $false
    if (Test-CommandExists "cl") {
        Write-Log "Found MSVC compiler" "SUCCESS"
        $script:Compiler = "MSVC"
        $hasCompiler = $true
    } elseif (Test-CommandExists "gcc") {
        Write-Log "Found GCC compiler" "SUCCESS"
        $script:Compiler = "GCC"
        $hasCompiler = $true
    }
    
    if (-not $hasCompiler) {
        $missingDeps += "Visual Studio Build Tools or MinGW"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Log "Missing dependencies: $($missingDeps -join ', ')" "ERROR"
        Write-Log "Please install the missing dependencies and try again" "ERROR"
        exit 1
    }
    
    Write-Log "All dependencies found" "SUCCESS"
}

function Get-LatestRelease {
    Write-Log "Fetching latest release information..."
    
    try {
        $releaseInfo = Invoke-RestMethod -Uri "$($Config.GitHubApi)/releases/latest"
        $tagName = $releaseInfo.tag_name
        
        if (-not $tagName) {
            throw "Invalid release information - no tag_name found"
        }
        
        Write-Log "Found release: $tagName"
        
        # Use direct GitHub archive URL
        $downloadUrl = "https://github.com/$($Config.Repo)/archive/$tagName.zip"
        Write-Log "Download URL: $downloadUrl"
        
        return @{
            TagName = $tagName
            DownloadUrl = $downloadUrl
        }
    } catch {
        Write-FatalError "Failed to fetch release information: $($_.Exception.Message)"
    }
}

function Download-And-Extract {
    param($Release)
    
    Write-Log "Downloading sbor $($Release.TagName)..."
    
    # Create temp directory
    try {
        New-Item -ItemType Directory -Path $Config.TempDir -Force | Out-Null
        Write-Log "Created temporary directory: $($Config.TempDir)"
    } catch {
        Write-FatalError "Could not create temporary directory: $($_.Exception.Message)"
    }
    
    $zipFile = Join-Path $Config.TempDir "sbor.zip"
    
    try {
        Write-Log "Debug: Downloading from $($Release.DownloadUrl)"
        
        # Download with better error handling
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Release.DownloadUrl, $zipFile)
        $webClient.Dispose()
        
        # Verify download
        if (-not (Test-Path $zipFile)) {
            throw "Downloaded file is missing"
        }
        
        $fileSize = (Get-Item $zipFile).Length
        if ($fileSize -eq 0) {
            throw "Downloaded file is empty"
        }
        
        Write-Log "Download completed ($([math]::Round($fileSize / 1MB, 2)) MB)"
        
        Write-Log "Extracting archive..."
        
        # Extract
        $extractDir = Join-Path $Config.TempDir "extracted"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractDir)
        
        # Find extracted directory
        $sourceDir = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
        if (-not $sourceDir) {
            throw "Could not find extracted source directory"
        }
        
        # Verify it's a valid sbor directory
        $cmakeFile = Join-Path $sourceDir.FullName "CMakeLists.txt"
        if (-not (Test-Path $cmakeFile)) {
            Write-Log "Contents of extracted directory:"
            Get-ChildItem $sourceDir.FullName | Format-Table Name, Length, LastWriteTime
            throw "This doesn't appear to be a valid sbor source directory (no CMakeLists.txt)"
        }
        
        Write-Log "Downloaded and extracted sbor $($Release.TagName)" "SUCCESS"
        Write-Log "Source directory: $($sourceDir.FullName)"
        
        return $sourceDir.FullName
        
    } catch {
        Write-FatalError "Download/extraction failed: $($_.Exception.Message)"
    }
}

function Build-Sbor {
    param([string]$SourceDir)
    
    Write-Log "Building sbor..."
    Write-Log "Source directory: $SourceDir"
    
    Push-Location $SourceDir
    
    try {
        # Create build directory
        $buildDir = Join-Path $SourceDir "build"
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        Set-Location $buildDir
        
        Write-Log "Running cmake..."
        
        # Configure and build
        if ($script:Compiler -eq "MSVC") {
            & cmake .. -DCMAKE_BUILD_TYPE=Release
            if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed (exit code: $LASTEXITCODE)" }
            
            & cmake --build . --config Release
            if ($LASTEXITCODE -ne 0) { throw "Build failed (exit code: $LASTEXITCODE)" }
            
            $executable = Join-Path $buildDir "Release\sbor.exe"
        } else {
            & cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
            if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed (exit code: $LASTEXITCODE)" }
            
            & cmake --build .
            if ($LASTEXITCODE -ne 0) { throw "Build failed (exit code: $LASTEXITCODE)" }
            
            $executable = Join-Path $buildDir "sbor.exe"
        }
        
        if (-not (Test-Path $executable)) {
            Write-Log "Build directory contents:"
            Get-ChildItem $buildDir -Recurse | Format-Table Name, Length, FullName
            throw "Build completed but executable not found at $executable"
        }
        
        # Test the executable
        Write-Log "Testing built executable..."
        try {
            $version = & $executable version
            Write-Log "Executable test passed - version: $version"
        } catch {
            Write-Log "Built executable failed version check, but continuing..." "WARNING"
        }
        
        Write-Log "Build completed successfully" "SUCCESS"
        return $executable
        
    } catch {
        Write-FatalError "Build failed: $($_.Exception.Message)"
    } finally {
        Pop-Location
    }
}

function Install-SborExecutable {
    param([string]$ExecutablePath)
    
    Write-Log "Installing sbor to $($Config.InstallDir)..."
    
    try {
        # Create install directory if it doesn't exist
        if (-not (Test-Path $Config.InstallDir)) {
            Write-Log "Creating install directory: $($Config.InstallDir)"
            New-Item -ItemType Directory -Path $Config.InstallDir -Force | Out-Null
        }
        
        $destPath = Join-Path $Config.InstallDir "sbor.exe"
        Copy-Item -Path $ExecutablePath -Destination $destPath -Force
        
        # Verify installation
        if (-not (Test-Path $destPath)) {
            throw "Installation verification failed - sbor not found at $destPath"
        }
        
        Write-Log "sbor installed to $destPath" "SUCCESS"
        
    } catch {
        Write-FatalError "Installation failed: $($_.Exception.Message)"
    }
}

function Remove-TempFiles {
    Write-Log "Cleaning up temporary files..."
    
    try {
        if (Test-Path $Config.TempDir) {
            Remove-Item -Path $Config.TempDir -Recurse -Force
        }
        Write-Log "Cleanup completed" "SUCCESS"
    } catch {
        Write-Log "Cleanup warning: $($_.Exception.Message)" "WARNING"
    }
}

function Test-Installation {
    Write-Log "Verifying installation..."
    
    try {
        $version = & sbor version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "sbor is installed and working!" "SUCCESS"
            Write-Log "Version: $version"
            Write-Log "Location: $(Get-Command sbor | Select-Object -ExpandProperty Source)"
        } else {
            throw "sbor command failed"
        }
    } catch {
        Write-Log "sbor command not found in PATH" "WARNING"
        $expectedPath = Join-Path $Config.InstallDir "sbor.exe"
        Write-Log "The executable is installed at: $expectedPath"
        
        # Test direct execution
        if (Test-Path $expectedPath) {
            try {
                $version = & $expectedPath version
                Write-Log "Direct execution test passed - version: $version"
                Write-Log "Make sure $($Config.InstallDir) is in your PATH environment variable"
            } catch {
                Write-Log "Direct execution failed: $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

# Main installation process
function Start-Installation {
    Write-Host ""
    Write-Host "🚀 SBOR Installation Script for PowerShell" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Test-Dependencies
        
        $release = Get-LatestRelease
        $sourceDir = Download-And-Extract $release
        $executable = Build-Sbor $sourceDir
        Install-SborExecutable $executable
        
        Write-Host ""
        Test-Installation
        Write-Host ""
        Write-Log "Installation completed! 🎉" "SUCCESS"
        Write-Log "You can now use 'sbor' command"
        Write-Log "Run 'sbor help' to get started"
        Write-Host ""
        
    } catch {
        Write-Log "Installation failed: $($_.Exception.Message)" "ERROR"
        exit 1
    } finally {
        Remove-TempFiles
    }
}

# Run installation
Start-Installation
