#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="Vaishnav-Sabari-Girish/sbor"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TEMP_DIR="/tmp/sbor-install-$$"
GITHUB_API="https://api.github.com/repos/$REPO"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error flag
INSTALLATION_FAILED=0

# Helper functions - ALL OUTPUT TO STDERR
log() {
  echo -e "${BLUE}[INFO]${NC} $1" >&2
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
  INSTALLATION_FAILED=1
}

fatal_error() {
  echo -e "${RED}[FATAL]${NC} $1" >&2
  INSTALLATION_FAILED=1
  cleanup
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
  log "Checking dependencies..."

  local missing_deps=()

  if ! command_exists curl && ! command_exists wget; then
    missing_deps+=("curl or wget")
  fi

  if ! command_exists cmake; then
    missing_deps+=("cmake")
  fi

  if ! command_exists make; then
    missing_deps+=("make")
  fi

  if ! command_exists gcc && ! command_exists clang; then
    missing_deps+=("gcc or clang")
  fi

  if ! command_exists tar; then
    missing_deps+=("tar")
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    fatal_error "Missing dependencies: ${missing_deps[*]}"
  fi

  success "All dependencies found"
}

# Get latest release info - FIXED TO NOT POLLUTE OUTPUT
get_latest_release() {
  log "Fetching latest release information..."

  local api_url="$GITHUB_API/releases/latest"
  local release_info

  if command_exists curl; then
    release_info=$(curl -s "$api_url" 2>/dev/null)
  elif command_exists wget; then
    release_info=$(wget -qO- "$api_url" 2>/dev/null)
  fi

  if [ -z "$release_info" ]; then
    fatal_error "Failed to fetch release information from GitHub API"
  fi

  log "Parsing release information..."

  # More robust JSON parsing
  local tag_name=$(echo "$release_info" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

  if [ -z "$tag_name" ]; then
    fatal_error "Could not parse tag_name from release information"
  fi

  log "Found release: $tag_name"

  # Use the direct GitHub archive URL instead of API tarball URL
  local download_url="https://github.com/$REPO/archive/$tag_name.tar.gz"
  log "Download URL: $download_url"

  # ONLY output the result to stdout, everything else goes to stderr
  echo "$tag_name|$download_url"
}

# Download and extract
download_and_extract() {
  local tag_name="$1"
  local download_url="$2"

  log "Creating temporary directory: $TEMP_DIR"
  mkdir -p "$TEMP_DIR" || fatal_error "Could not create temporary directory"

  log "Downloading sbor $tag_name..."
  cd "$TEMP_DIR" || fatal_error "Could not change to temporary directory"

  log "Debug: tag_name='$tag_name'"
  log "Debug: download_url='$download_url'"

  # Enhanced download with better error handling
  if command_exists curl; then
    log "Using curl to download..."
    # Add flags for better compatibility: follow redirects, fail on HTTP errors, show progress
    if ! curl -fsSL --connect-timeout 30 --max-time 300 "$download_url" -o sbor.tar.gz; then
      log "Curl failed with exit code: $?"
      log "Trying alternative download method..."

      # Try with GitHub's direct download approach
      local alt_url="https://codeload.github.com/$REPO/tar.gz/$tag_name"
      log "Alternative URL: $alt_url"

      if ! curl -fsSL --connect-timeout 30 --max-time 300 "$alt_url" -o sbor.tar.gz; then
        fatal_error "Download failed with both primary and alternative URLs"
      fi
    fi
  elif command_exists wget; then
    log "Using wget to download..."
    if ! wget --timeout=30 --tries=3 -q "$download_url" -O sbor.tar.gz; then
      log "Wget failed, trying alternative URL..."
      local alt_url="https://codeload.github.com/$REPO/tar.gz/$tag_name"

      if ! wget --timeout=30 --tries=3 -q "$alt_url" -O sbor.tar.gz; then
        fatal_error "Download failed with both wget URLs"
      fi
    fi
  fi

  # Verify download
  if [ ! -f "sbor.tar.gz" ]; then
    fatal_error "Downloaded file is missing"
  fi

  if [ ! -s "sbor.tar.gz" ]; then
    fatal_error "Downloaded file is empty"
  fi

  # Check if file looks like a tarball
  if ! file sbor.tar.gz 2>/dev/null | grep -q "gzip compressed"; then
    log "File type check:"
    file sbor.tar.gz 2>/dev/null || log "file command failed"
    log "File size: $(ls -lh sbor.tar.gz | awk '{print $5}')"
    log "First few bytes:"
    hexdump -C sbor.tar.gz | head -3 >&2
    fatal_error "Downloaded file doesn't appear to be a valid gzip archive"
  fi

  log "Download completed ($(du -h sbor.tar.gz | cut -f1))"

  log "Extracting archive..."
  if ! tar -xzf sbor.tar.gz; then
    log "Tar extraction failed. File contents:"
    ls -la sbor.tar.gz >&2
    head -c 100 sbor.tar.gz | hexdump -C >&2
    fatal_error "Failed to extract archive"
  fi

  # Find the extracted directory
  local extracted_dir=$(find . -maxdepth 1 -type d -name "*sbor*" | head -1)
  if [ -z "$extracted_dir" ]; then
    # Try finding any directory that's not the current one
    extracted_dir=$(find . -maxdepth 1 -type d ! -name "." | head -1)
  fi

  if [ -z "$extracted_dir" ] || [ ! -d "$extracted_dir" ]; then
    log "Available files/directories:"
    ls -la >&2
    fatal_error "Could not find extracted directory"
  fi

  log "Found extracted directory: $extracted_dir"
  cd "$extracted_dir" || fatal_error "Could not change to extracted directory"

  # Verify we have the necessary files
  if [ ! -f "CMakeLists.txt" ]; then
    log "Contents of extracted directory:"
    ls -la >&2
    fatal_error "This doesn't appear to be a valid sbor source directory (no CMakeLists.txt)"
  fi

  success "Downloaded and extracted sbor $tag_name"
}

# Build sbor
build_sbor() {
  log "Building sbor..."

  log "Current directory: $(pwd)"

  mkdir -p build || fatal_error "Could not create build directory"
  cd build || fatal_error "Could not change to build directory"

  log "Running cmake..."
  if ! cmake .. -DCMAKE_BUILD_TYPE=Release; then
    fatal_error "CMake configuration failed"
  fi

  log "Running make..."
  local cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
  if ! make -j"$cpu_count"; then
    fatal_error "Build failed"
  fi

  if [ ! -f "sbor" ]; then
    log "Build directory contents:"
    ls -la >&2
    fatal_error "Build completed but sbor executable not found"
  fi

  # Test the executable
  log "Testing built executable..."
  if ! ./sbor version >/dev/null 2>&1; then
    warning "Built executable failed version check, but continuing..."
  fi

  success "Build completed successfully"
}

# Install sbor
install_sbor() {
  log "Installing sbor to $INSTALL_DIR..."

  # Check if install directory exists
  if [ ! -d "$INSTALL_DIR" ]; then
    log "Creating install directory: $INSTALL_DIR"
    if [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
      if command_exists sudo; then
        sudo mkdir -p "$INSTALL_DIR" || fatal_error "Could not create install directory"
      else
        fatal_error "Cannot create $INSTALL_DIR and sudo is not available"
      fi
    else
      mkdir -p "$INSTALL_DIR" || fatal_error "Could not create install directory"
    fi
  fi

  # Check if we need sudo for installation
  if [ ! -w "$INSTALL_DIR" ]; then
    if command_exists sudo; then
      warning "Installing to $INSTALL_DIR requires sudo privileges"
      sudo cp sbor "$INSTALL_DIR/" || fatal_error "Installation failed (sudo cp)"
      sudo chmod +x "$INSTALL_DIR/sbor" || fatal_error "Could not set executable permissions"
    else
      fatal_error "Cannot write to $INSTALL_DIR and sudo is not available"
    fi
  else
    cp sbor "$INSTALL_DIR/" || fatal_error "Installation failed (cp)"
    chmod +x "$INSTALL_DIR/sbor" || fatal_error "Could not set executable permissions"
  fi

  # Verify installation
  if [ ! -f "$INSTALL_DIR/sbor" ]; then
    fatal_error "Installation verification failed - sbor not found at $INSTALL_DIR/sbor"
  fi

  success "sbor installed to $INSTALL_DIR/sbor"
}

# Cleanup
cleanup() {
  if [ -d "$TEMP_DIR" ]; then
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" || warning "Could not remove temporary directory"
    success "Cleanup completed"
  fi
}

# Verify installation
verify_installation() {
  log "Verifying installation..."

  # Check if sbor is in PATH
  if command_exists sbor; then
    local version=$(sbor version 2>/dev/null || echo "unknown")
    success "sbor is installed and working!"
    log "Version: $version"
    log "Location: $(which sbor)"
  else
    # Check if it exists at install location
    if [ -f "$INSTALL_DIR/sbor" ]; then
      warning "sbor is installed but not found in PATH"
      log "Executable location: $INSTALL_DIR/sbor"

      # Test direct execution
      local version=$("$INSTALL_DIR/sbor" version 2>/dev/null || echo "unknown")
      log "Version (direct): $version"

      # Check if install directory is in PATH
      if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        warning "$INSTALL_DIR is not in your PATH"
        log "Add this line to your ~/.bashrc or ~/.zshrc:"
        log "export PATH=\"$INSTALL_DIR:\$PATH\""
        log ""
        log "Or run sbor directly with: $INSTALL_DIR/sbor"
      fi
    else
      error "sbor installation verification failed"
      log "Expected location: $INSTALL_DIR/sbor"
    fi
  fi
}

# Main installation process
main() {
  echo "🚀 SBOR Installation Script" >&2
  echo "==========================" >&2
  echo >&2

  # Only cleanup on successful completion, not on errors
  trap 'if [ $INSTALLATION_FAILED -eq 0 ]; then cleanup; fi' EXIT

  check_dependencies

  local release_info
  release_info=$(get_latest_release)
  local tag_name=$(echo "$release_info" | cut -d'|' -f1)
  local download_url=$(echo "$release_info" | cut -d'|' -f2)

  download_and_extract "$tag_name" "$download_url"
  build_sbor
  install_sbor

  echo >&2
  verify_installation
  echo >&2

  if [ $INSTALLATION_FAILED -eq 0 ]; then
    success "Installation completed! 🎉"
    log "You can now use 'sbor' command"
    log "Run 'sbor help' to get started"
  else
    error "Installation completed with errors"
    log "Please check the error messages above"
  fi
}

# Show usage if requested
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "SBOR Installation Script"
  echo
  echo "Usage:"
  echo "  curl -sSL https://raw.githubusercontent.com/Vaishnav-Sabari-Girish/sbor/main/install.sh | bash"
  echo "  wget -qO- https://raw.githubusercontent.com/Vaishnav-Sabari-Girish/sbor/main/install.sh | bash"
  echo
  echo "Environment Variables:"
  echo "  INSTALL_DIR    Installation directory (default: /usr/local/bin)"
  echo
  echo "Examples:"
  echo "  INSTALL_DIR=~/.local/bin bash install.sh    # Install to user directory"
  echo
  exit 0
fi

# Run main installation
main "$@"
