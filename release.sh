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

# Function to clean up backup files
cleanup_backup_files() {
  echo "🧹 Cleaning up backup files..."

  # Remove any .bak files in the project
  find . -name "*.bak" -type f -delete 2>/dev/null || true

  # Remove any .tmp files that might be left over
  find . -name "*.tmp*" -type f -delete 2>/dev/null || true

  echo "✅ Backup files cleaned up"
}

# Function to get current version from main.c
get_current_version() {
  local version_line=$(grep '#define VERSION' src/main.c)
  local version=$(echo "$version_line" | cut -d'"' -f2 | sed 's/V//')
  echo "$version"
}

# Function to increment version
increment_version() {
  local current_version=$1
  local IFS='.'
  read -ra parts <<<"$current_version"

  echo "Current version: ${parts[0]}.${parts[1]}.${parts[2]}" >&2
  echo "Choose increment type:" >&2

  local increment_type
  increment_type=$(printf "patch\nminor\nmajor" | gum choose)

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

  echo "${parts[0]}.${parts[1]}.${parts[2]}"
}

# Function to update version in files
update_version_files() {
  local new_version=$1

  echo "📝 Updating version in source files..."

  sd '#define VERSION "V[^"]*"' "#define VERSION \"V$new_version\"" src/main.c
  sd 'VERSION [0-9]+\.[0-9]+\.[0-9]+' "VERSION $new_version" CMakeLists.txt

  echo "✅ Updated version to $new_version in:"
  echo "   - src/main.c"
  echo "   - CMakeLists.txt"
}

# Function to create GitHub release
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

  gh release create "$tag" \
    --title "$tag" \
    --notes "$notes" \
    --repo "$REPO"

  echo "✅ GitHub release $tag created successfully!"
}

# Function to get SHA256 hash (COMPLETELY ISOLATED)
get_sha256() {
  local version=$1
  local url="$ARCHIVE_BASE_URL/v${version}.tar.gz"

  # Show progress to stderr only
  printf "🔐 Calculating SHA256 for v%s...\n" "$version" >&2

  # Get SHA256 in complete isolation - redirect all possible output
  local sha256
  sha256=$(curl -sL "$url" 2>/dev/null | shasum -a 256 2>/dev/null | awk '{print $1}')

  # Trim any whitespace and validate
  sha256=$(echo "$sha256" | tr -d '[:space:]')

  # Validate format
  if [[ ${#sha256} -eq 64 ]] && [[ "$sha256" =~ ^[a-f0-9]+$ ]]; then
    printf "%s\n" "$sha256"
  else
    printf "Error: Invalid SHA256 received: '%s'\n" "$sha256" >&2
    return 1
  fi
}

# Function to update homebrew formula (SAFER)
update_homebrew_formula() {
  local version=$1
  local sha256=$2

  printf "🍺 Updating Homebrew formula...\n"

  if [ ! -f "$HOMEBREW_FORMULA_PATH" ]; then
    printf "❌ Homebrew formula not found at: %s\n" "$HOMEBREW_FORMULA_PATH"
    return 1
  fi

  # Use more precise patterns for sd
  sd 'url "https://github\.com/[^/]+/[^/]+/archive/v[^"]*\.tar\.gz"' "url \"https://github.com/$REPO/archive/v$version.tar.gz\"" "$HOMEBREW_FORMULA_PATH"

  sd 'sha256 "[a-f0-9]*"' "sha256 \"$sha256\"" "$HOMEBREW_FORMULA_PATH"

  sd 'version "[0-9]+\.[0-9]+\.[0-9]+"' "version \"$version\"" "$HOMEBREW_FORMULA_PATH"

  printf "✅ Updated Homebrew formula with:\n"
  printf "   - Version: %s\n" "$version"
  printf "   - SHA256: %s\n" "$sha256"
  printf "   - URL: https://github.com/%s/archive/v%s.tar.gz\n" "$REPO" "$version"
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

  if git diff --quiet; then
    echo "   - No local changes to commit"
  else
    echo "   - Local changes in sbor repository:"
    git diff --name-only | sed 's/^/     /'
  fi

  if [ -f "$HOMEBREW_FORMULA_PATH" ]; then
    echo "   - Homebrew formula updated: $(basename "$HOMEBREW_FORMULA_PATH")"
  fi

  local backup_files=$(find . -name "*.bak" -o -name "*.tmp*" 2>/dev/null || true)
  if [ -n "$backup_files" ]; then
    echo "   - Backup files found (will be cleaned up after approval):"
    echo "$backup_files" | sed 's/^/     /'
  fi
}

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

  # Get current version
  current_version=$(get_current_version)
  if [ -z "$current_version" ]; then
    echo "❌ Could not parse current version from src/main.c"
    exit 1
  fi

  echo "📦 Current version: $current_version"

  # Get new version
  new_version=$(increment_version "$current_version")

  if [[ ! "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format: '$new_version'"
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

  # Step 2: Use acp() function to commit version changes BEFORE creating release
  echo "📤 Committing version changes before creating release..."
  echo "   Use your custom commit message to describe the version bump"
  acp # This will commit and push the version changes

  echo "✅ Version changes committed and pushed using acp()"
  echo

  # Step 3: NOW create GitHub release (will use the new committed version)
  create_github_release "$new_version"
  echo

  # Step 4: Get SHA256
  echo "⏳ Waiting for GitHub to process the release..."
  sleep 3

  sha256=$(get_sha256 "$new_version")
  echo "🔐 SHA256: $sha256"
  echo

  # Step 5: Update Homebrew formula
  update_homebrew_formula "$new_version" "$sha256"
  echo

  # Step 6: Show changes and get confirmation
  show_changes "$new_version" "$sha256"
  echo

  if ! gum confirm "🚀 Push Homebrew formula changes?"; then
    echo "🚫 Homebrew update cancelled"
    cleanup_backup_files
    exit 0
  fi

  # Step 7: Clean up backup files
  cleanup_backup_files
  echo

  # Step 8: Handle homebrew formula changes (separate repo)
  if [ -f "$HOMEBREW_FORMULA_PATH" ]; then
    echo "🍺 Homebrew formula has been updated!"

    if gum confirm "🤔 Commit and push Homebrew formula changes automatically?"; then
      HOMEBREW_DIR="$(dirname "$HOMEBREW_FORMULA_PATH")/.."
      cd "$HOMEBREW_DIR"

      echo "📁 Now in homebrew-taps directory: $(pwd)"

      # Clean up backup files in homebrew repo too
      find . -name "*.bak" -type f -delete 2>/dev/null || true

      git add Formula/sbor.rb
      git commit -m "Update sbor to v$new_version"
      git push origin main
      echo "✅ Pushed homebrew formula changes"

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
  echo "   ✅ Version updated to v$new_version and committed via acp()"
  echo "   ✅ GitHub release created from new commit"
  echo "   ✅ Homebrew formula updated"
  echo "   ✅ All changes pushed"
}

# Run main function
main "$@"
