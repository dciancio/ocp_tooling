#!/usr/bin/env bash
#
# omcdownload.sh - Download the omc binary for analyzing must-gathers
# Compatible with: bash 3.2+ on Linux and macOS
#
# Usage:
#   omcdownload.sh [-v VERSION] [-a ARCH] [-o OS] [-h]
#
# Options:
#   -v VERSION  Release tag or "latest" (e.g. latest, 3.20.0, v3.20.0)
#   -a ARCH     Architecture: amd64, arm64, ppc64le
#               (aliases: x86_64→amd64, aarch64→arm64)
#   -o OS       Target OS: linux, darwin
#               (aliases: macos/mac→darwin)
#   -h          Show this help message
#
# If options are omitted, the script prompts interactively.
# Host OS/arch are detected and offered as the default selection.
#
# Examples:
#   omcdownload.sh -v latest -a arm64 -o darwin
#   omcdownload.sh -v 3.20.0 -a amd64 -o linux
#   omcdownload.sh                         # fully interactive
#

# zsh compatibility: use 0-based arrays and field splitting like bash/ksh
[ -n "${ZSH_VERSION:-}" ] && emulate -L ksh 2>/dev/null

set -euo pipefail

REPO="gmeghnag/omc"
API_BASE="https://api.github.com/repos/${REPO}"
DOWNLOAD_BASE="https://github.com/${REPO}/releases/download"

VERSION=""
ARCH=""
OS_NAME=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [-v VERSION] [-a ARCH] [-o OS] [-h]

Download the omc binary for analyzing must-gathers.

Options:
  -v VERSION  Release tag or "latest" (e.g. latest, 3.20.0, v3.20.0)
  -a ARCH     Architecture: amd64, arm64, ppc64le
              (aliases: x86_64→amd64, aarch64→arm64)
  -o OS       Target OS: linux, darwin
              (aliases: macos/mac→darwin)
  -h          Show this help message

If options are omitted, the script prompts interactively.

Examples:
  $(basename "$0") -v latest -a arm64 -o darwin
  $(basename "$0") -v 3.20.0 -a amd64 -o linux
  $(basename "$0")   # fully interactive
EOF
    exit 0
}

require_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl is required but was not found in PATH." >&2
        exit 1
    fi
}

detect_host_os() {
    case "$(uname -s 2>/dev/null)" in
        Darwin) echo "darwin" ;;
        Linux)  echo "linux" ;;
        *)      echo "linux" ;;
    esac
}

detect_host_arch() {
    case "$(uname -m 2>/dev/null)" in
        x86_64|amd64)           echo "amd64" ;;
        aarch64|arm64)          echo "arm64" ;;
        ppc64le|ppc64)          echo "ppc64le" ;;
        *)                      echo "amd64" ;;
    esac
}

normalize_os() {
    typeset value
    value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$value" in
        linux)            echo "linux" ;;
        darwin|macos|mac) echo "darwin" ;;
        *)
            echo "Error: Invalid OS '$1'. Must be: linux or darwin." >&2
            exit 1
            ;;
    esac
}

normalize_arch() {
    typeset value
    value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$value" in
        amd64|x86_64|x64) echo "amd64" ;;
        arm64|aarch64)    echo "arm64" ;;
        ppc64le|ppc64)    echo "ppc64le" ;;
        *)
            echo "Error: Invalid architecture '$1'. Must be: amd64, arm64, or ppc64le." >&2
            exit 1
            ;;
    esac
}

normalize_version() {
    typeset value="$1"
    if [[ -z "$value" ]]; then
        echo "Error: Version cannot be empty." >&2
        exit 1
    fi
    if [[ "$value" == "latest" ]]; then
        echo "latest"
        return 0
    fi
    # Accept both 3.20.0 and v3.20.0; store without leading v for display,
    # but resolve to a GitHub tag later.
    value="${value#v}"
    echo "$value"
}

# Portable helpers: macOS ships BSD sed (no \? /\+), so avoid GNU-only regex.

github_get() {
    typeset url="$1"
    # Do not use -f here so callers can fall back on non-200 responses.
    curl -sSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$url"
}

extract_tag_names() {
    # From GitHub API JSON or HTML, emit version numbers newest-first (no leading v).
    # Works with BSD and GNU grep/sed.
    grep -o '"tag_name"[[:space:]]*:[[:space:]]*"v[^"]*"' 2>/dev/null \
        | sed 's/.*"v//;s/"$//' \
        | awk 'NF && !seen[$0]++'
}

extract_tag_names_from_html() {
    grep -oE "/${REPO}/releases/tag/v[0-9][0-9.]*" 2>/dev/null \
        | sed 's|.*/v||' \
        | awk 'NF && !seen[$0]++'
}

fetch_release_tags() {
    typeset body tags
    body=$(github_get "${API_BASE}/releases?per_page=50" || true)
    tags=$(printf '%s\n' "$body" | extract_tag_names)

    if [[ -z "$tags" ]]; then
        # Fallback: scrape public releases HTML (avoids API rate limits / BSD sed issues).
        body=$(curl -sSL "https://github.com/${REPO}/releases" || true)
        tags=$(printf '%s\n' "$body" | extract_tag_names_from_html)
    fi

    printf '%s\n' "$tags"
}

resolve_latest_tag() {
    typeset body tag
    body=$(github_get "${API_BASE}/releases/latest" || true)
    tag=$(printf '%s\n' "$body" | extract_tag_names | head -1)

    if [[ -z "$tag" ]]; then
        tag=$(fetch_release_tags | head -1)
    fi

    if [[ -n "$tag" ]]; then
        echo "v${tag#v}"
    fi
}

extract_omc_asset_names() {
    grep -o '"name"[[:space:]]*:[[:space:]]*"omc_[^"]*"' 2>/dev/null \
        | sed 's/.*"omc_/omc_/;s/"$//' \
        | awk 'NF && !seen[$0]++'
}

list_release_assets() {
    typeset tag="$1"
    typeset body assets
    body=$(github_get "${API_BASE}/releases/tags/${tag}" || true)
    assets=$(printf '%s\n' "$body" | extract_omc_asset_names)

    if [[ -z "$assets" ]]; then
        # Fallback: probe known asset names with HTTP HEAD (no API required).
        assets=$(probe_known_assets "$tag")
    fi

    printf '%s\n' "$assets"
}

probe_known_assets() {
    typeset tag="$1"
    typeset prefix suffix candidate url
    prefix=$(os_asset_prefix)

    while IFS= read -r suffix; do
        [[ -z "$suffix" ]] && continue
        for candidate in "${prefix}_${suffix}" "${prefix}_${suffix}.tar.gz"; do
            url="${DOWNLOAD_BASE}/${tag}/${candidate}"
            if curl -fsI -o /dev/null "$url" 2>/dev/null; then
                echo "$candidate"
            fi
        done
    done <<EOF
$(arch_asset_suffixes)
EOF
}

os_asset_prefix() {
    case "$OS_NAME" in
        linux)  echo "omc_Linux" ;;
        darwin) echo "omc_Darwin" ;;
    esac
}

arch_asset_suffixes() {
    # Prefer names that match release assets for this arch.
    case "$ARCH" in
        amd64)
            echo "x86_64"
            echo "amd64"
            ;;
        arm64)
            echo "arm64"
            echo "aarch64"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
    esac
}

select_asset() {
    typeset tag="$1"
    typeset assets
    assets=$(list_release_assets "$tag")
    if [[ -z "$assets" ]]; then
        echo "Error: No assets found for release ${tag}." >&2
        exit 1
    fi

    typeset prefix
    prefix=$(os_asset_prefix)

    typeset suffix
    while IFS= read -r suffix; do
        [[ -z "$suffix" ]] && continue

        # Prefer a raw binary asset when available.
        if echo "$assets" | grep -qx "${prefix}_${suffix}"; then
            echo "${prefix}_${suffix}"
            return 0
        fi

        # Fall back to tar.gz (common for Linux arm64 / ppc64le).
        if echo "$assets" | grep -qx "${prefix}_${suffix}.tar.gz"; then
            echo "${prefix}_${suffix}.tar.gz"
            return 0
        fi
    done <<EOF
$(arch_asset_suffixes)
EOF

    echo "Error: No matching omc asset for OS=${OS_NAME} ARCH=${ARCH} in release ${tag}." >&2
    echo "Available assets:" >&2
    echo "$assets" | sed 's/^/  /' >&2
    exit 1
}

prompt_os() {
    typeset host_os
    host_os=$(detect_host_os)
    echo ""
    echo "Select target OS:"
    echo "  1) linux"
    echo "  2) darwin (macOS)"
    echo ""
    echo "  Detected host OS: ${host_os}"
    echo "  q) Quit"
    echo ""
    while true; do
        printf "Enter choice [1-2, q] (default=%s): " "$host_os"
        read -r choice
        [[ -z "$choice" ]] && choice="$host_os"
        case "$choice" in
            1|linux|Linux) OS_NAME="linux"; return 0 ;;
            2|darwin|Darwin|macos|mac|Mac|MacOS) OS_NAME="darwin"; return 0 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection. Please enter 1, 2, or q." ;;
        esac
    done
}

prompt_arch() {
    typeset host_arch
    host_arch=$(detect_host_arch)
    echo ""
    echo "Select architecture:"
    echo "  1) amd64   (x86_64)"
    echo "  2) arm64   (aarch64)"
    if [[ "$OS_NAME" == "linux" ]]; then
        echo "  3) ppc64le"
    fi
    echo ""
    echo "  Detected host arch: ${host_arch}"
    echo "  b) Back         q) Quit"
    echo ""
    while true; do
        if [[ "$OS_NAME" == "linux" ]]; then
            printf "Enter choice [1-3, b, q] (default=%s): " "$host_arch"
        else
            printf "Enter choice [1-2, b, q] (default=%s): " "$host_arch"
        fi
        read -r choice
        [[ -z "$choice" ]] && choice="$host_arch"
        case "$choice" in
            1|amd64|x86_64) ARCH="amd64"; return 0 ;;
            2|arm64|aarch64) ARCH="arm64"; return 0 ;;
            3|ppc64le)
                if [[ "$OS_NAME" != "linux" ]]; then
                    echo "ppc64le is only available for linux."
                    continue
                fi
                ARCH="ppc64le"; return 0
                ;;
            b|B) return 1 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection." ;;
        esac
    done
}

pick_from_list() {
    typeset _arr_name=$1
    typeset label=$2
    eval "typeset total=\${#${_arr_name}[@]}"

    if [[ "$total" -eq 0 ]]; then
        echo "Error: No entries found." >&2
        exit 1
    fi

    typeset page_size=20
    typeset page=0
    typeset max_page=$(( (total - 1) / page_size ))

    while true; do
        typeset start=$(( page * page_size ))
        typeset end=$(( start + page_size ))
        [[ "$end" -gt "$total" ]] && end=$total

        echo ""
        echo "--- ${label}: Page $((page + 1)) of $((max_page + 1)) ($total entries) ---"
        echo ""
        typeset i
        for (( i = start; i < end; i++ )); do
            eval "typeset _val=\${${_arr_name}[$i]}"
            printf "  %4d) %s\n" "$((i + 1))" "$_val"
        done
        echo ""
        echo "  0) latest"
        if [[ "$max_page" -gt 0 ]]; then
            echo "  n) Next page   p) Previous page"
        fi
        echo "  b) Back         q) Quit"
        echo ""
        printf "Enter number to select, or 0/n/p/b/q: "; read -r input

        case "$input" in
            0|latest|Latest)
                PICKED="latest"
                return 0
                ;;
            n|N)
                if [[ "$page" -lt "$max_page" ]]; then
                    page=$(( page + 1 ))
                else
                    echo "Already on the last page."
                fi
                ;;
            p|P)
                if [[ "$page" -gt 0 ]]; then
                    page=$(( page - 1 ))
                else
                    echo "Already on the first page."
                fi
                ;;
            b|B) return 1 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *)
                if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= total )); then
                    eval "PICKED=\${${_arr_name}[$((input - 1))]}"
                    return 0
                else
                    echo "Invalid selection. Enter a number between 0 and $total."
                fi
                ;;
        esac
    done
}

prompt_version() {
    echo ""
    echo "Fetching available omc release tags from GitHub ..."
    typeset tags
    tags=$(fetch_release_tags)
    if [[ -z "$tags" ]]; then
        echo "Error: Failed to retrieve release tags from GitHub." >&2
        exit 1
    fi

    typeset tag_entries=()
    while IFS= read -r entry; do
        [[ -n "$entry" ]] && tag_entries+=("$entry")
    done <<< "$tags"

    if pick_from_list tag_entries "omc release tags"; then
        VERSION="$PICKED"
        return 0
    fi
    return 1
}

validate_os_arch_combo() {
    if [[ "$OS_NAME" == "darwin" && "$ARCH" == "ppc64le" ]]; then
        echo "Error: ppc64le is not available for darwin/macOS builds of omc." >&2
        exit 1
    fi
}

download_file() {
    typeset url="$1"
    typeset outfile="$2"
    echo "Downloading: $url"
    curl -fL --progress-bar -o "$outfile" "$url" || {
        echo "Error: Download failed: $url" >&2
        exit 1
    }
}

install_binary() {
    typeset asset="$1"
    typeset downloaded="$2"

    rm -f omc

    case "$asset" in
        *.tar.gz)
            tar -xzf "$downloaded" omc 2>/dev/null || tar -xzf "$downloaded"
            if [[ ! -f omc ]]; then
                echo "Error: Archive '$asset' did not contain an 'omc' binary." >&2
                exit 1
            fi
            rm -f "$downloaded"
            ;;
        *)
            mv "$downloaded" omc
            ;;
    esac

    chmod 755 omc
}

# --- CLI parsing ---

while getopts ":v:a:o:h" opt; do
    case "$opt" in
        v) VERSION="$OPTARG" ;;
        a) ARCH="$OPTARG" ;;
        o) OS_NAME="$OPTARG" ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; exit 1 ;;
        *) echo "Error: Unknown option -$OPTARG" >&2; usage ;;
    esac
done

require_curl

if [[ -n "$OS_NAME" ]]; then
    OS_NAME=$(normalize_os "$OS_NAME")
fi
if [[ -n "$ARCH" ]]; then
    ARCH=$(normalize_arch "$ARCH")
fi
if [[ -n "$VERSION" ]]; then
    VERSION=$(normalize_version "$VERSION")
fi

# --- Interactive prompts for missing parameters ---

if [[ -z "$OS_NAME" || -z "$ARCH" || -z "$VERSION" ]]; then
    typeset local_step="os"
    [[ -n "$OS_NAME" && -z "$ARCH" ]] && local_step="arch"
    [[ -n "$OS_NAME" && -n "$ARCH" && -z "$VERSION" ]] && local_step="version"

    while true; do
        case "$local_step" in
            os)
                OS_NAME=""
                ARCH=""
                VERSION=""
                prompt_os
                local_step="arch"
                ;;
            arch)
                ARCH=""
                VERSION=""
                if prompt_arch; then
                    local_step="version"
                else
                    local_step="os"
                fi
                ;;
            version)
                VERSION=""
                if prompt_version; then
                    break
                else
                    local_step="arch"
                fi
                ;;
        esac
    done
fi

validate_os_arch_combo

# --- Resolve release tag and asset ---

TAG=""
if [[ "$VERSION" == "latest" ]]; then
    TAG=$(resolve_latest_tag)
    if [[ -z "$TAG" ]]; then
        echo "Error: Failed to resolve latest omc release tag." >&2
        exit 1
    fi
else
    TAG="v${VERSION#v}"
fi

ASSET=$(select_asset "$TAG")
URL="${DOWNLOAD_BASE}/${TAG}/${ASSET}"

echo ""
echo "============================================"
echo "  Tool          : omc"
echo "  Version/Tag   : ${TAG}"
echo "  OS            : ${OS_NAME}"
echo "  Architecture  : ${ARCH}"
echo "  Asset         : ${ASSET}"
echo "  Download URL  : ${URL}"
echo "  Output        : ./omc"
echo "============================================"
echo ""

printf "Proceed with download? [y/N]: "; read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

TMPFILE="${ASSET}.partial"
download_file "$URL" "$TMPFILE"
install_binary "$ASSET" "$TMPFILE"

echo ""
echo "Verifying downloaded binary..."
if command -v file >/dev/null 2>&1; then
    file ./omc | sed 's/^/  /'
else
    ls -l ./omc | sed 's/^/  /'
fi

echo ""
echo "Done. omc ${TAG} ready (${OS_NAME}/${ARCH})."
