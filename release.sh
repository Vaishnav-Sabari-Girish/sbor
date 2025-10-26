#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="Vaishnav-Sabari-Girish/sbor"
HOMEBREW_FORMULA_PATH="$HOME/Desktop/My_Projects/homebrew-taps/Formula/sbor.rb"
ARCHIVE_BASE_URL="https://github.com/$REPO/archive"

# Include the acp function
acp() {
  # Check if gum is installed
  if ! command -v gum >/dev/null 2>&1; then
    echo 'Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum'
    return 1
  fi

  # Stage all changes
  git add .

  # Prompt for commit message using gum
  commit_msg=$(gum input --placeholder 'commit message')
  if [ -z "$commit_msg" ]; then
    echo 'Error: Commit message cannot be empty'
    return 1
  fi

  # Commit changes
  git commit -m "$commit_msg"

  # Prompt for branch name using gum
  branch=$(git branch | gum choose | sed 's/^* //')
  if [ -z "$branch" ]; then
    echo 'Error: Branch name cannot be empty'
    return 1
  fi

  # Verify branch exists
  if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
    echo "Error: Branch $branch does not exist"
    return 1
  fi

  # Checkout the specified branch
  git checkout "$branch"

  # Get all remote names into an array
  remotes=($(git remote))

  # Push to all remotes
  for remote in "${remotes[@]}"; do
    echo "Debug: Pushing to remote - $remote"
    git push "$remote" "$branch"
  done

  echo 'Changes added, committed, and pushed to all remotes'
}

# Function to get current version from main.c (COMPLETELY FIXED)
get_current_version() {
  # Extract just the version number, nothing else
  local version_line=$(grep '#define VERSION' src/main.c)
  local version=$(echo "$version_line" | cut -d'"' -f2 | sed 's/V//')
  echo "$version"
}

# Function to increment version (COMPLETELY FIXED - NO EXTRA OUTPUT)
increment_version() {
  local current_version=$1
  local IFS='.'
  read -ra parts <<<"$current_version"

  # Show current version info (to stderr so it doesn't interfere with return value)
  echo "Current version: ${parts[0]}.${parts[1]}.${parts[2]}" >&2
  echo "Choose increment type:" >&2

  # Use gum to choose increment type
  local increment_type
  increment_type=$(printf "patch\nminor\nmajor" | gum choose)

  # Calculate new version
  case $increment_type in
  patch)
    parts[2]=$((parts[2] + 1))
    ;;
  minor)
    parts[1]=$((parts[1] + 1))
    parts[2]=0
    ;;
  major)
    parts[0]=$((parts[0] + 1))
    parts[1]=0
    parts[2]=0
    ;;
  esac

  # Output ONLY the new version (to stdout)
  echo "${parts[0]}.${parts[1]}.${parts[2]}"
}

# Function to update version in files (USING SD)
update_version_files() {
  local new_version=$1

  echo "📝 Updating version in source files..."

  # Update main.c using sd
  sd '#define VERSION "V[^"]*"' "#define VERSION \"V$new_version\"" src/main.c

  # Update CMakeLists.txt using sd
  sd 'VERSION [0-9]+\.[0-9]+\.[0-9]+' "VERSION $new_version" CMakeLists.txt

  echo "✅ Updated version to $new_version in:"
  echo "   - src/main.c"
  echo "   - CMakeLists.txt"
}

# Function to create GitHub release (FIXED TAG HANDLING)
create_github_release() {
  local version=$1
  local tag="v$version"

  echo "📝 Enter release notes:"
  local notes
  notes=$(gum write --placeholder "Enter release notes here..." --char-limit 500)

  if [ -z "$notes" ]; then
    notes="Release $tag"
  fi

  echo "🚀 Creating GitHub release $tag..."

  # Debug: Show exactly what tag we're trying to create
  echo "DEBUG: Tag will be: '$tag'"
  echo "DEBUG: Version is: '$version'"

  gh release create "$tag" \
    --title "$tag" \
    --notes "$notes" \
    --repo "$REPO"

  echo "✅ GitHub release $tag created successfully!"
}

# Function to get SHA256 hash
get_sha256() {
  local version=$1
  local url="$ARCHIVE_BASE_URL/v${version}.tar.gz"

  echo "🔐 Calculating SHA256 for v$version..."

  local sha256
  sha256=$(gum spin --spinner dot --title "Downloading and calculating SHA256..." -- \
    bash -c "curl -sL '$url' | shasum -a 256 | cut -d' ' -f1")

  echo "$sha256"
}

# Function to update homebrew formula (USING SD)
update_homebrew_formula() {
  local version=$1
  local sha256=$2

  echo "🍺 Updating Homebrew formula..."

  if [ ! -f "$HOMEBREW_FORMULA_PATH" ]; then
    echo "❌ Homebrew formula not found at: $HOMEBREW_FORMULA_PATH"
    echo "⚠️  Please make sure the homebrew-taps repository exists at the expected location"
    return 1
  fi

  # Update using sd
  sd 'url ".*"' "url \"https://github.com/$REPO/archive/v$version.tar.gz\"" "$HOMEBREW_FORMULA_PATH"
  sd 'sha256 ".*"' "sha256 \"$sha256\"" "$HOMEBREW_FORMULA_PATH"
  sd 'version ".*"' "version \"$version\"" "$HOMEBREW_FORMULA_PATH"

  echo "✅ Updated Homebrew formula with:"
  echo "   - Version: $version"
  echo "   - SHA256: $sha256"
  echo "   - URL: https://github.com/$REPO/archive/v$version.tar.gz"
  echo "   - File: $HOMEBREW_FORMULA_PATH"
}

# Function to show changes for confirmation
show_changes() {
  local version=$1
  local sha256=$2

  echo "📋 Summary of changes made:"
  echo
  echo "🔹 New Version: $version"
  echo "🔹 Files Updated: src/main.c, CMakeLists.txt, $(basename "$HOMEBREW_FORMULA_PATH")"
  echo "🔹 GitHub Release: Created v$version"
  echo "🔹 SHA256: $sha256"
  echo "🔹 Formula Path: $HOMEBREW_FORMULA_PATH"
  echo
  echo "🔍 Changed files:"

  # Show git diff for local changes
  if git diff --quiet; then
    echo "   - No local changes to commit"
  else
    echo "   - Local changes in sbor repository:"
    git diff --name-only | sed 's/^/     /'
  fi

  # Show homebrew formula changes if accessible
  if [ -f "$HOMEBREW_FORMULA_PATH" ]; then
    echo "   - Homebrew formula updated: $(basename "$HOMEBREW_FORMULA_PATH")"
  fi
}

# Main execution
main() {
  echo "🚀 SBOR Release Automation Script"
  echo

  # Check dependencies
  for cmd in gum gh git sd; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "❌ Required command not found: $cmd"
      case $cmd in
      sd) echo "   Install with: cargo install sd" ;;
      esac
      exit 1
    fi
  done

  # Check if we're in the right directory
  if [ ! -f "src/main.c" ] || [ ! -f "CMakeLists.txt" ]; then
    echo "❌ Please run this script from the sbor project root directory"
    exit 1
  fi

  # Get current version (clean extraction)
  current_version=$(get_current_version)
  if [ -z "$current_version" ]; then
    echo "❌ Could not parse current version from src/main.c"
    echo "Expected format: #define VERSION \"V0.1.6\""
    exit 1
  fi

  echo "📦 Current version: $current_version"

  # Get new version (clean increment)
  new_version=$(increment_version "$current_version")

  # Validate new version format
  if [[ ! "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format: '$new_version'"
    echo "Expected format: x.y.z (e.g., 0.1.7)"
    exit 1
  fi

  echo "🆙 New version will be: $new_version"

  echo
  if ! gum confirm "Continue with release v$new_version?"; then
    echo "🚫 Release cancelled"
    exit 0
  fi

  # Step 1: Update version files
  update_version_files "$new_version"
  echo

  # Step 2: Create GitHub release
  create_github_release "$new_version"
  echo

  # Step 3: Get SHA256
  echo "⏳ Waiting a moment for GitHub to process the release..."
  sleep 3

  sha256=$(get_sha256 "$new_version")
  echo "🔐 SHA256: $sha256"
  echo

  # Step 4: Update Homebrew formula
  update_homebrew_formula "$new_version" "$sha256"
  echo

  # Step 5: Show changes and get confirmation
  show_changes "$new_version" "$sha256"
  echo

  if ! gum confirm "🚀 Push these changes to repositories?"; then
    echo "🚫 Push cancelled - changes are staged but not pushed"
    exit 0
  fi

  # Step 6: Commit and push using acp function
  echo "📤 Committing and pushing changes..."
  acp

  # Step 7: Handle homebrew formula changes
  if [ -f "$HOMEBREW_FORMULA_PATH" ]; then
    echo "🍺 Homebrew formula has been updated!"
    echo "📍 Formula location: $HOMEBREW_FORMULA_PATH"

    if gum confirm "🤔 Commit and push Homebrew formula changes automatically?"; then
      HOMEBREW_DIR="$(dirname "$HOMEBREW_FORMULA_PATH")/.."
      cd "$HOMEBREW_DIR"

      echo "📁 Now in homebrew-taps directory: $(pwd)"

      git add Formula/sbor.rb
      git commit -m "Update sbor to v$new_version"

      if git remote | grep -q origin; then
        git push origin main
        echo "✅ Pushed homebrew formula changes to origin/main"
      else
        echo "⚠️  No 'origin' remote found in homebrew-taps repo"
        echo "💡 Please push manually: git push <remote> <branch>"
      fi

      cd - >/dev/null
    else
      echo "💡 Remember to commit homebrew formula changes manually:"
      echo "   cd '$HOMEBREW_DIR'"
      echo "   git add Formula/sbor.rb"
      echo "   git commit -m 'Update sbor to v$new_version'"
      echo "   git push origin main"
    fi
  fi

  echo
  echo "🎉 Release v$new_version completed successfully!"
  echo "📋 Summary:"
  echo "   ✅ Version updated to v$new_version"
  echo "   ✅ GitHub release created"
  echo "   ✅ Homebrew formula updated"
  echo "   ✅ Changes committed and pushed"
}

# Run main function
main "$@"
