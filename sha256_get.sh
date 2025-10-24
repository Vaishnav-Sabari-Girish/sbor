#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="Vaishnav-Sabari-Girish/sbor"
ARCHIVE_BASE_URL="https://github.com/$REPO/archive"

# Colors for gum styling
INFO_STYLE="--foreground 212"
SUCCESS_STYLE="--foreground 48"
ERROR_STYLE="--foreground 196"

# Function to get latest release tag using GitHub CLI
get_latest_version() {
  gh release view --repo "$REPO" --json tagName --jq '.tagName' 2>/dev/null
}

# Function to get SHA256 with progress indication
get_sha256() {
  local version=$1
  local url="$ARCHIVE_BASE_URL/${version}.tar.gz"

  gum spin --spinner dot --title "Downloading and calculating SHA256..." -- \
    curl -sL "$url" | shasum -a 256 | cut -d' ' -f1
}

# Main execution
main() {
  gum style $INFO_STYLE "🔍 Fetching latest release information..."

  # Get latest version
  VERSION=$(get_latest_version)

  if [[ -z "$VERSION" ]]; then
    gum style $ERROR_STYLE "❌ Failed to fetch latest version. Make sure you're authenticated with 'gh auth login'"
    exit 1
  fi

  gum style $SUCCESS_STYLE "📦 Latest version: $VERSION"

  # Get SHA256
  gum style $INFO_STYLE "🔐 Calculating SHA256 checksum..."
  SHA256=$(get_sha256 "$VERSION")

  # Display results with nice formatting
  echo
  gum style --border normal --padding "1 2" --margin "1 0" \
    "$(gum style --bold 'Version:') $VERSION" \
    "$(gum style --bold 'SHA256:') $SHA256" \
    "$(gum style --bold 'URL:') $ARCHIVE_BASE_URL/${VERSION}.tar.gz"

  # Option to copy to clipboard (if available)
  if command -v pbcopy &>/dev/null || command -v xclip &>/dev/null; then
    if gum confirm "📋 Copy SHA256 to clipboard?"; then
      if command -v pbcopy &>/dev/null; then
        echo "$SHA256" | pbcopy
        gum style $SUCCESS_STYLE "✅ SHA256 copied to clipboard (macOS)"
      elif command -v xclip &>/dev/null; then
        echo "$SHA256" | xclip -selection clipboard
        gum style $SUCCESS_STYLE "✅ SHA256 copied to clipboard (Linux)"
      fi
    fi
  fi
}

main "$@"
