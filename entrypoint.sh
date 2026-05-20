#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Changelog Generator — GitHub Action
# Auto-generates CHANGELOG.md from Conventional Commits
# =============================================================================

# --- Parse inputs -----------------------------------------------------------
INPUT_TOKEN="${1:-$GITHUB_TOKEN}"
INPUT_TAG_PREFIX="${2:-v}"
INPUT_OUTPUT_FILE="${3:-CHANGELOG.md}"
INPUT_HEADER="${4:-}"
INPUT_RELEASE_BRANCH="${5:-}"
INPUT_INCLUDE_COMMITS="${6:-}"
INPUT_EXCLUDE_TYPES="${7:-}"
INPUT_GROUP_BY_SCOPE="${8:-false}"
INPUT_INCLUDE_LINKS="${9:-true}"
INPUT_INCLUDE_BREAKING="${10:-true}"
INPUT_CREATE_RELEASE="${11:-false}"
INPUT_UNRELEASED_LABEL="${12:-Unreleased}"
INPUT_COMPARE_URL="${13:-}"
INPUT_PREMIUM_TEMPLATE="${14:-classic}"
INPUT_PREMIUM_EMOJIS="${15:-false}"
INPUT_PREMIUM_SUMMARY="${16:-false}"
INPUT_PREMIUM_CONTRIBUTORS="${17:-false}"
INPUT_PREMIUM_LINKS="${18:-github}"

# --- Configuration ----------------------------------------------------------
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || true)}"
GITHUB_REF_NAME="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)}"
GITHUB_SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"

# Derive compare URL base
REPO_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"

cd "$GITHUB_WORKSPACE"

# --- Helper Functions -------------------------------------------------------

log()  { echo "[changelog-generator] $*"; }
warn() { echo "[changelog-generator] WARNING: $*" >&2; }
err()  { echo "[changelog-generator] ERROR: $*" >&2; exit 1; }

# Detect if the repo has a sponsor file (SPONSORS.md or .github/FUNDING.yml)
has_sponsor_file() {
    [[ -f "SPONSORS.md" || -f ".github/FUNDING.yml" ]]
}

# Check if we're running with a sponsor token or have sponsor flag
is_sponsor() {
    # If premium settings are explicitly enabled, treat as sponsor
    [[ "${INPUT_PREMIUM_SUMMARY}" == "true" ]] && return 0
    return 1
}

# Emoji map for commit types
get_emoji() {
    local type="$1"
    case "$type" in
        feat)     echo "✨" ;;
        fix)      echo "🐛" ;;
        perf)     echo "⚡" ;;
        refactor) echo "♻️" ;;
        docs)     echo "📝" ;;
        style)    echo "💄" ;;
        test)     echo "✅" ;;
        chore)    echo "🔧" ;;
        build)    echo "📦" ;;
        ci)       echo "👷" ;;
        revert)   echo "⏪" ;;
        breaking) echo "💥" ;;
        *)        echo "" ;;
    esac
}

# Commit type display names
get_type_label() {
    local type="$1"
    case "$type" in
        feat)     echo "Features" ;;
        fix)      echo "Bug Fixes" ;;
        perf)     echo "Performance Improvements" ;;
        refactor) echo "Code Refactoring" ;;
        docs)     echo "Documentation" ;;
        style)    echo "Styles" ;;
        test)     echo "Tests" ;;
        chore)    echo "Chores" ;;
        build)    echo "Build System" ;;
        ci)       echo "Continuous Integration" ;;
        revert)   echo "Reverts" ;;
        breaking) echo "⚠️ Breaking Changes" ;;
        *)        echo "$type" ;;
    esac
}

# Get all tags sorted by version
get_tags_sorted() {
    local prefix="${1:-}"
    if [[ -n "$prefix" ]]; then
        git tag -l "${prefix}*" --sort=-version:refname 2>/dev/null || true
    else
        git tag --sort=-version:refname 2>/dev/null || true
    fi
}

# Extract version from tag
get_version_from_tag() {
    local tag="$1"
    local prefix="${2:-}"
    if [[ -n "$prefix" ]]; then
        echo "${tag#$prefix}"
    else
        echo "$tag"
    fi
}

# Parse conventional commit
parse_commit() {
    local message="$1"
    local type="" scope="" breaking=false description="$message"
    
    # Match conventional commit pattern: type(scope)!: description
    if [[ "$message" =~ ^([a-zA-Z]+)(\([^)]*\))?(!)?:[[:space:]]*(.*) ]]; then
        type="${BASH_REMATCH[1]}"
        scope="${BASH_REMATCH[2]}"  # includes parens
        scope="${scope#\(}"
        scope="${scope%\)}"
        [[ "${BASH_REMATCH[3]}" == "!" ]] && breaking=true
        description="${BASH_REMATCH[4]}"
    fi
    
    # Check for BREAKING CHANGE in body (we can't easily get body from log, so check message for footer)
    if [[ "$message" =~ BREAKING[[:space:]]+CHANGE ]]; then
        breaking=true
    fi
    
    echo "$type||$scope||$breaking||$description"
}

# Generate compare URL
get_compare_url() {
    local from="$1"
    local to="$2"
    if [[ -n "$INPUT_COMPARE_URL" ]]; then
        local url="${INPUT_COMPARE_URL}"
        url="${url//\{\{from\}\}/$from}"
        url="${url//\{\{to\}\}/$to}"
        echo "$url"
    else
        echo "${REPO_URL}/compare/${from}...${to}"
    fi
}

# Get commit link
get_commit_link() {
    local sha="$1"
    echo "${REPO_URL}/commit/${sha}"
}

# Get issue link
get_issue_link() {
    local issue="$1"
    echo "${REPO_URL}/issues/${issue}"
}

# Detect next version based on commits since last tag
detect_next_version() {
    local current_version="$1"
    local prefix="$2"
    local has_breaking=false
    local has_feat=false
    local has_fix=false
    
    # Parse commits since last tag
    local since_range="${current_version:+${prefix}${current_version}..HEAD}"
    since_range="${since_range:-HEAD}"
    
    while IFS= read -r msg; do
        local parsed type breaking
        parsed=$(parse_commit "$msg")
        type=$(echo "$parsed" | cut -d'|' -f1)
        breaking=$(echo "$parsed" | cut -d'|' -f3)
        
        [[ "$breaking" == "true" ]] && has_breaking=true
        [[ "$type" == "feat" ]] && has_feat=true
        [[ "$type" == "fix" ]] && has_fix=true
    done < <(git log "$since_range" --format="%s" 2>/dev/null || true)
    
    if [[ -z "$current_version" ]]; then
        echo "0.1.0"
        return
    fi
    
    # Strip leading v if present
    local ver="${current_version#v}"
    IFS='.' read -r major minor patch <<< "$ver"
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    if $has_breaking; then
        echo "$((major + 1)).0.0"
    elif $has_feat; then
        echo "${major}.$((minor + 1)).0"
    else
        echo "${major}.${minor}.$((patch + 1))"
    fi
}

# Generate changelog content
generate_changelog() {
    local output_file="$1"
    local header_content="$2"
    local tag_prefix="$3"
    local all_commits=""
    local changelog=""
    
    # Use default header if none provided
    if [[ -z "$header_content" ]]; then
        header_content="# Changelog\n\nAll notable changes to this project will be documented in this file.\n\nThe format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),\nand this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n"
    fi
    # Interpret escape sequences
    header_content=$(echo -e "$header_content")
    
    # Get included types
    local include_types=""
    if [[ -n "$INPUT_INCLUDE_COMMITS" ]]; then
        include_types="$INPUT_INCLUDE_COMMITS"
    else
        include_types="feat,fix,perf,refactor,docs,style,test,chore,build,ci,revert"
    fi
    
    # Get excluded types
    local exclude_types="$INPUT_EXCLUDE_TYPES"
    
    # Split include types into array
    IFS=',' read -ra type_arr <<< "$include_types"
    
    # Get all tags sorted (newest first)
    mapfile -t tags < <(get_tags_sorted "$tag_prefix" | head -100)
    
    changelog="$header_content\n\n"
    
    # --- Collect unreleased commits ---
    local unreleased_commits=""
    local unreleased_range=""
    
    if [[ ${#tags[@]} -gt 0 ]]; then
        unreleased_range="${tags[0]}..HEAD"
    else
        unreleased_range="HEAD"
    fi
    
    if git rev-parse --verify HEAD &>/dev/null; then
        unreleased_commits=$(git log "$unreleased_range" --format="%H||%s||%an||%ai" 2>/dev/null || true)
    fi
    
    # --- Generate unreleased section ---
    local unreleased_entries=""
    local breaking_entries=""
    
    if [[ -n "$unreleased_commits" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local sha msg author date
            sha=$(echo "$line" | cut -d'|' -f1)
            msg=$(echo "$line" | cut -d'|' -f2)
            author=$(echo "$line" | cut -d'|' -f3)
            date=$(echo "$line" | cut -d'|' -f4)
            
            local parsed type scope breaking description
            parsed=$(parse_commit "$msg")
            type=$(echo "$parsed" | cut -d'|' -f1)
            scope=$(echo "$parsed" | cut -d'|' -f2)
            breaking=$(echo "$parsed" | cut -d'|' -f3)
            description=$(echo "$parsed" | cut -d'|' -f4-)
            
            [[ -z "$type" ]] && type="other"
            [[ -z "$description" ]] && description="$msg"
            
            # Check exclusion
            local excluded=false
            IFS=',' read -ra exclude_arr <<< "$exclude_types"
            for ex in "${exclude_arr[@]}"; do
                [[ "$type" == "$ex" ]] && excluded=true
            done
            $excluded && continue
            
            # Check inclusion
            local included=false
            for inc in "${type_arr[@]}"; do
                [[ "$type" == "$inc" ]] && included=true
            done
            $included || continue
            
            # Build entry
            local emoji=""
            if [[ "${INPUT_PREMIUM_EMOJIS}" == "true" ]]; then
                emoji="$(get_emoji "$type") "
            fi
            
            local entry="- ${emoji}**${description}**"
            if [[ -n "$scope" ]]; then
                entry="- ${emoji}**${scope}:** ${description}"
            fi
            
            if [[ "${INPUT_INCLUDE_LINKS}" == "true" ]]; then
                entry="${entry} ([${sha:0:7}]($(get_commit_link "$sha")))"
                # Extract and link issues
                if [[ "$description" =~ '#'([0-9]+) ]]; then
                    local issue_num="${BASH_REMATCH[1]}"
                    entry="${entry} ([#${issue_num}]($(get_issue_link "$issue_num")))"
                fi
            fi
            
            if [[ "${INPUT_PREMIUM_CONTRIBUTORS}" == "true" ]] && [[ -n "$author" ]]; then
                entry="${entry} — ${author}"
            fi
            
            if [[ "$breaking" == "true" ]]; then
                breaking_entries="${breaking_entries}\n- 💥 **${description}**"
                if [[ -n "$scope" ]]; then
                    breaking_entries="${breaking_entries} (${scope})"
                fi
            fi
            
            unreleased_entries="${unreleased_entries}\n${entry}"
        done <<< "$unreleased_commits"
    fi
    
    # --- Generate version sections (newest first) ---
    local all_sections=""
    local prev_tag=""
    local latest_version=""
    local latest_release_notes=""
    local release_notes=""
    
    # Unreleased section first
    if [[ -n "$unreleased_entries" ]]; then
        local unreleased_section="## [${INPUT_UNRELEASED_LABEL}]\n"
        
        if [[ "${INPUT_INCLUDE_BREAKING}" == "true" ]] && [[ -n "$breaking_entries" ]]; then
            unreleased_section="${unreleased_section}\n### ⚠️ Breaking Changes\n${breaking_entries}\n"
        fi
        
        if [[ "${INPUT_GROUP_BY_SCOPE}" == "true" ]]; then
            # Group by type
            for type_key in "${type_arr[@]}"; do
                local type_entries=""
                while IFS= read -r entry; do
                    [[ -z "$entry" ]] && continue
                    if [[ "$entry" == *"**$(get_type_label "$type_key" | tr '[:upper:]' '[:lower:]')**"* ]] || [[ "$entry" == *"**${type_key}**"* ]] || true; then
                        # Check if entry matches this type by scanning the original messages
                        :
                    fi
                done <<< "$(echo -e "$unreleased_entries")"
                # Simpler approach: just dump all entries under types
            done
            
            # Group by type using the collected entries
            local grouped=""
            for type_key in "${type_arr[@]}"; do
                local type_label=$(get_type_label "$type_key")
                local type_msgs=""
                while IFS= read -r entry; do
                    [[ -z "$entry" ]] && continue
                    # Match entries by checking the raw commit messages again
                    local entry_msg="${entry#- }"
                    entry_msg="${entry_msg#\*\*}"
                    entry_msg="${entry_msg%%\*\**}"
                    # Too complex for shell; simpler grouping below
                    true
                done <<< "$(echo -e "$unreleased_entries")"
            done
            
            # Simpler: just group all unreleased by type
            unreleased_section="${unreleased_section}\n$(generate_grouped_section "$unreleased_range" "${type_arr[*]}" "$exclude_types" "" "")"
        else
            unreleased_section="${unreleased_section}\n$(echo -e "$unreleased_entries" | sort -t'-' -k2)"
        fi
        
        all_sections="${unreleased_section}\n\n"
    fi
    
    # Generate sections for each tag
    local tag_count=${#tags[@]}
    for ((i=0; i<tag_count; i++)); do
        local tag="${tags[$i]}"
        local version
        version=$(get_version_from_tag "$tag" "$tag_prefix")
        
        local next_ref=""
        if [[ -z "$prev_tag" ]]; then
            next_ref="HEAD"
        else
            next_ref="$prev_tag"
        fi
        
        local range="${tag}..${next_ref}"
        # For the latest tag, compare with next_ref (which is HEAD or next tag)
        # Actually for tagged release, commit range is tag..next_ref
        # But the tag itself has a commit:
        local tag_sha
        tag_sha=$(git rev-list -n 1 "$tag" 2>/dev/null || true)
        
        # Actually, get commits between this tag and the previous (newer) tag
        local from_ref=""
        if [[ $i -lt $((tag_count - 1)) ]]; then
            from_ref="${tags[$((i+1))]}"
        else
            # Oldest tag — compare from root
            from_ref=""
        fi
        
        local compare_from=""
        local compare_to="$tag"
        local log_range
        if [[ -z "$from_ref" ]]; then
            # First tag — all commits up to this tag
            log_range="$tag"
        else
            log_range="${from_ref}..${tag}"
        fi
        
        # Get commits for this version
        local version_commits
        version_commits=$(git log "$log_range" --format="%H||%s||%an||%ai" 2>/dev/null || true)
        
        if [[ -z "$version_commits" ]]; then
            prev_tag="$tag"
            continue
        fi
        
        # Get tag date for display
        local tag_date
        tag_date=$(git log -1 --format="%Y-%m-%d" "$tag" 2>/dev/null || echo "")
        
        # Build section
        local section="## [${version}] - ${tag_date}\n"
        local section_breaking=""
        local section_entries=""
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local sha2 msg2 author2
            sha2=$(echo "$line" | cut -d'|' -f1)
            msg2=$(echo "$line" | cut -d'|' -f2)
            author2=$(echo "$line" | cut -d'|' -f3)
            
            local parsed2 type2 scope2 breaking2 description2
            parsed2=$(parse_commit "$msg2")
            type2=$(echo "$parsed2" | cut -d'|' -f1)
            scope2=$(echo "$parsed2" | cut -d'|' -f2)
            breaking2=$(echo "$parsed2" | cut -d'|' -f3)
            description2=$(echo "$parsed2" | cut -d'|' -f4-)
            
            [[ -z "$type2" ]] && type2="other"
            [[ -z "$description2" ]] && description2="$msg2"
            
            # Check exclusion
            local excluded2=false
            IFS=',' read -ra exclude_arr2 <<< "$exclude_types"
            for ex2 in "${exclude_arr2[@]}"; do
                [[ "$type2" == "$ex2" ]] && excluded2=true
            done
            $excluded2 && continue
            
            # Check inclusion
            local included2=false
            for inc2 in "${type_arr[@]}"; do
                [[ "$type2" == "$inc2" ]] && included2=true
            done
            $included2 || continue
            
            local emoji2=""
            [[ "${INPUT_PREMIUM_EMOJIS}" == "true" ]] && emoji2="$(get_emoji "$type2") "
            
            local entry2="- ${emoji2}**${description2}**"
            if [[ -n "$scope2" ]]; then
                entry2="- ${emoji2}**${scope2}:** ${description2}"
            fi
            
            if [[ "${INPUT_INCLUDE_LINKS}" == "true" ]]; then
                entry2="${entry2} ([${sha2:0:7}]($(get_commit_link "$sha2")))"
                if [[ "$description2" =~ '#'([0-9]+) ]]; then
                    local issue_num2="${BASH_REMATCH[1]}"
                    entry2="${entry2} ([#${issue_num2}]($(get_issue_link "$issue_num2")))"
                fi
            fi
            
            if [[ "${INPUT_PREMIUM_CONTRIBUTORS}" == "true" ]] && [[ -n "$author2" ]]; then
                entry2="${entry2} — ${author2}"
            fi
            
            if [[ "$breaking2" == "true" ]]; then
                section_breaking="${section_breaking}\n- 💥 **${description2}**"
            fi
            
            section_entries="${section_entries}\n${entry2}"
        done <<< "$version_commits"
        
        if [[ "${INPUT_INCLUDE_BREAKING}" == "true" ]] && [[ -n "$section_breaking" ]]; then
            section="${section}\n### ⚠️ Breaking Changes\n${section_breaking}\n"
        fi
        
        section="${section}\n${section_entries}\n"
        
        # Store latest version info for output
        if [[ -z "$latest_version" ]]; then
            latest_version="$version"
            latest_release_notes="$section"
        fi
        
        all_sections="${all_sections}${section}\n\n"
        prev_tag="$tag"
    done
    
    # Add compare links footer
    if [[ "${INPUT_INCLUDE_LINKS}" == "true" ]]; then
        all_sections="${all_sections}\n---\n"
        for ((i=0; i<tag_count; i++)); do
            local t="${tags[$i]}"
            local v
            v=$(get_version_from_tag "$t" "$tag_prefix")
            local prev_link=""
            if [[ $i -lt $((tag_count - 1)) ]]; then
                prev_link="${tags[$((i+1))]}"
                all_sections="${all_sections}\n[${v}]: $(get_compare_url "$prev_link" "$t")"
            else
                if [[ $i -eq $((tag_count - 1)) ]]; then
                    # Oldest tag - compare from first commit
                    all_sections="${all_sections}\n[${v}]: $(get_compare_url "" "$t")"
                fi
            fi
        done
        if [[ -n "$unreleased_entries" ]]; then
            local unreleased_ref="${tags[0]:-HEAD}"
            all_sections="${all_sections}\n[${INPUT_UNRELEASED_LABEL}]: $(get_compare_url "$unreleased_ref" "HEAD")"
        fi
    fi
    
    # Write the final changelog
    echo -e "$changelog$all_sections" > "$output_file"
    log "Changelog written to $output_file"
    
    # Generate premium AI summary if enabled
    if [[ "${INPUT_PREMIUM_SUMMARY}" == "true" ]]; then
        generate_premium_summary "$output_file"
    fi
    
    # Create GitHub Release if enabled
    if [[ "${INPUT_CREATE_RELEASE}" == "true" ]] && [[ -n "$latest_version" ]]; then
        create_github_release "$latest_version" "$latest_release_notes" "$tag_prefix"
    fi
    
    # Set outputs
    local full_content
    full_content=$(cat "$output_file")
    echo "changelog<<EOFCHANGELOG" >> "$GITHUB_OUTPUT"
    echo "$full_content" >> "$GITHUB_OUTPUT"
    echo "EOFCHANGELOG" >> "$GITHUB_OUTPUT"
    echo "version=${latest_version}" >> "$GITHUB_OUTPUT"
    
    local release_notes_clean
    release_notes_clean=$(echo "$latest_release_notes" | sed 's/\[\([^]]*\)\] - [0-9-]*//')
    echo "release-notes<<EOFNOTES" >> "$GITHUB_OUTPUT"
    echo "$release_notes_clean" >> "$GITHUB_OUTPUT"
    echo "EOFNOTES" >> "$GITHUB_OUTPUT"
}

# Generate grouped section (by commit type)
generate_grouped_section() {
    local range="$1"
    shift
    local types_str="$1"
    shift
    local exclude_str="$1"
    shift
    
    IFS=' ' read -ra type_list <<< "$types_str"
    IFS=',' read -ra exclude_list <<< "$exclude_str"
    
    local output=""
    
    for type_key in "${type_list[@]}"; do
        local label
        label=$(get_type_label "$type_key")
        local entries=""
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local sha msg
            sha=$(echo "$line" | cut -d'|' -f1)
            msg=$(echo "$line" | cut -d'|' -f2)
            
            local parsed type scope breaking description
            parsed=$(parse_commit "$msg")
            type=$(echo "$parsed" | cut -d'|' -f1)
            scope=$(echo "$parsed" | cut -d'|' -f2)
            breaking=$(echo "$parsed" | cut -d'|' -f3)
            description=$(echo "$parsed" | cut -d'|' -f4-)
            
            [[ "$type" != "$type_key" ]] && continue
            [[ -z "$description" ]] && description="$msg"
            
            local emoji=""
            [[ "${INPUT_PREMIUM_EMOJIS}" == "true" ]] && emoji="$(get_emoji "$type") "
            
            local entry="- ${emoji}**${description}**"
            if [[ -n "$scope" ]]; then
                entry="- ${emoji}**${scope}:** ${description}"
            fi
            if [[ "${INPUT_INCLUDE_LINKS}" == "true" ]]; then
                entry="${entry} ([${sha:0:7}]($(get_commit_link "$sha")))"
            fi
            entries="${entries}\n${entry}"
        done < <(git log "$range" --format="%H||%s" 2>/dev/null || true)
        
        if [[ -n "$entries" ]]; then
            output="${output}\n### ${label}\n${entries}\n"
        fi
    done
    
    echo -e "$output"
}

# Generate premium summary
generate_premium_summary() {
    local changelog_file="$1"
    local summary_file="CHANGELOG_SUMMARY.md"
    
    # Count commit types from changelog
    local feat_count=0
    local fix_count=0
    local change_count=0
    
    feat_count=$(grep -c '^\*\*Features\*\*' "$changelog_file" 2>/dev/null || echo 0)
    fix_count=$(grep -c '^\*\*Bug Fixes\*\*' "$changelog_file" 2>/dev/null || echo 0)
    
    # Count actual entries
    local total_entries
    total_entries=$(grep -c '^- \*\*' "$changelog_file" 2>/dev/null || echo 0)
    
    cat > "$summary_file" << EOF
## 📊 Release Summary

> *Executive summary generated by Changelog Generator ★ Premium*

| Metric | Value |
|--------|-------|
| Changes documented | ${total_entries} entries |
| Latest release | ${latest_version:-N/A} |

**Key Highlights:**
EOF
    
    if [[ "$feat_count" -gt 0 ]] || grep -q "Features" "$changelog_file" 2>/dev/null; then
        echo "- ✨ New features added to enhance functionality" >> "$summary_file"
    fi
    if [[ "$fix_count" -gt 0 ]] || grep -q "Bug Fixes" "$changelog_file" 2>/dev/null; then
        echo "- 🐛 Bug fixes applied for improved stability" >> "$summary_file"
    fi
    
    log "Premium summary generated: $summary_file"
}

# Create GitHub Release
create_github_release() {
    local version="$1"
    local notes="$2"
    local prefix="$3"
    local tag="${prefix}${version}"
    
    # Check if release already exists
    local existing
    existing=$(curl -s -H "Authorization: token ${INPUT_TOKEN}" \
        "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/releases/tags/${tag}" 2>/dev/null || true)
    
    if echo "$existing" | jq -e '.id' &>/dev/null; then
        log "Release $tag already exists, skipping."
        return
    fi
    
    # Extract clean notes (remove markdown links for release body)
    local body
    body=$(echo "$notes" | head -50)
    
    local payload
    payload=$(jq -n \
        --arg tag "$tag" \
        --arg name "Release ${version}" \
        --arg body "$body" \
        '{tag_name: $tag, name: $name, body: $body, draft: false, prerelease: false}')
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: token ${INPUT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/releases")
    
    if echo "$response" | jq -e '.id' &>/dev/null; then
        log "GitHub Release created: ${tag}"
    else
        local err_msg
        err_msg=$(echo "$response" | jq -r '.message // "unknown error"')
        warn "Failed to create release: $err_msg"
    fi
}

# Detect sponsor status and print badge
detect_sponsor_status() {
    if has_sponsor_file || [[ "${INPUT_PREMIUM_SUMMARY}" == "true" ]] || [[ "${INPUT_PREMIUM_EMOJIS}" == "true" ]] || [[ "${INPUT_PREMIUM_CONTRIBUTORS}" == "true" ]]; then
        log "★ Sponsor features enabled — thank you for your support!"
        if [[ "${INPUT_PREMIUM_SUMMARY}" == "true" ]]; then
            log "  Premium: AI-style executive summary enabled"
        fi
        if [[ "${INPUT_PREMIUM_EMOJIS}" == "true" ]]; then
            log "  Premium: Emoji decorations enabled"
        fi
        if [[ "${INPUT_PREMIUM_CONTRIBUTORS}" == "true" ]]; then
            log "  Premium: Contributor attribution enabled"
        fi
        return 0
    fi
    return 1
}

# --- Main Execution ---------------------------------------------------------

log "Changelog Generator starting..."
log "Repository: ${GITHUB_REPOSITORY}"
log "Branch: ${GITHUB_REF_NAME}"
log "Output: ${INPUT_OUTPUT_FILE}"
log "Tag prefix: '${INPUT_TAG_PREFIX}'"

# Detect sponsor features
detect_sponsor_status || true

# Configure git for safe operations
git config --global --add safe.directory "$GITHUB_WORKSPACE" 2>/dev/null || true

# Fetch all tags
git fetch --tags --force 2>/dev/null || true

# Generate the changelog
generate_changelog "$INPUT_OUTPUT_FILE" "$INPUT_HEADER" "$INPUT_TAG_PREFIX"

log "✅ Changelog generation complete!"
