#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="Vaishnav-Sabari-Girish/sbor"
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

# Function to get current version from main.c
get_current_version() {
  # Extract version more reliably
  local version=$(grep '#define VERSION' src/main.c | sed 's/.*"V\([^"]*\)".*/\1/')

  # Validate version format
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$version"
  else
    echo "ERROR: Invalid version format extracted: '$version'" >&2
    return 1
  fi
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

  # Update main.c using sd
  sd '#define VERSION "V[^"]*"' "#define VERSION \"V$new_version\"" src/main.c

  # Update CMakeLists.txt using sd
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

# Function to get SHA256 hash
get_sha256() {
  local version=$1
  local url="$ARCHIVE_BASE_URL/v${version}.tar.gz"

  printf "🔐 Calculating SHA256 for v%s...\n" "$version" >&2

  local sha256
  sha256=$(curl -sL "$url" 2>/dev/null | shasum -a 256 2>/dev/null | awk '{print $1}')

  # Trim any whitespace and validate
  sha256=$(echo "$sha256" | tr -d '[:space:]')

  if [[ ${#sha256} -eq 64 ]] && [[ "$sha256" =~ ^[a-f0-9]+$ ]]; then
    printf "%s\n" "$sha256"
  else
    printf "Error: Invalid SHA256 received: '%s'\n" "$sha256" >&2
    return 1
  fi
}

# Main execution
main() {
  echo "🚀 SBOR Release Script (Core Functions Only)"
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

  # Step 1: Get current version
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

  # Step 2: Update version files
  update_version_files "$new_version"
  echo

  # Step 3: Commit and push using acp
  echo "📤 Committing version changes..."
  acp
  echo

  # Step 4: Create GitHub release
  create_github_release "$new_version"
  echo

  # Step 5: Get SHA256
  echo "⏳ Waiting for GitHub to process the release..."
  sleep 5

  sha256=$(get_sha256 "$new_version")

  echo
  echo "🎉 Release completed successfully!"
  echo "📋 Release Information:"
  echo "   🏷️  Version: $new_version"
  echo "   🔗 URL: https://github.com/$REPO/archive/v$new_version.tar.gz"
  echo "   🔐 SHA256: $sha256"
  echo
  echo "📝 For Homebrew formula update:"
  echo "   version \"$new_version\""
  echo "   url \"https://github.com/$REPO/archive/v$new_version.tar.gz\""
  echo "   sha256 \"$sha256\""
}

# Run main function
main "$@"
