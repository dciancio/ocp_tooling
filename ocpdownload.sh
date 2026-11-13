#!/usr/bin/env bash
#
# ocpdownload.sh - Download OpenShift client and installer binaries
# Compatible with: bash 3.2+, ksh93+, zsh 5.0+
#
# Usage:
#   ocpdownload.sh [-r MAJOR] [-a ARCH] [-v VERSION] [-d DEFAULT_ARCH] [-h]
#
# Options:
#   -r MAJOR         Major release: v4, v5
#   -a ARCH          Architecture: multi, amd64, arm64, ppc64le, s390x
#   -v VERSION       Release version or channel (fetched dynamically from mirror), e.g.:
#                      4.16.3, candidate-4.17, fast-4.16,
#                      stable-4.16, latest-4.16,
#                      candidate, fast, stable, latest
#   -d DEFAULT_ARCH  Default arch for multi-arch install: amd64, arm64, ppc64le, s390x
#                    (only required when ARCH=multi)
#   -h               Show this help message
#
# If options are omitted, the script will prompt interactively.
# When prompting for version, the available versions/channels are fetched
# live from the OpenShift mirror.
#
# Examples:
#   ocpdownload.sh -r v4 -a amd64 -v stable-4.16
#   ocpdownload.sh -r v5 -a amd64 -v stable-4.18
#   ocpdownload.sh -r v4 -a multi -v 4.16.3 -d amd64
#   ocpdownload.sh -a arm64 -v latest-4.16        # defaults to interactive major version
#   ocpdownload.sh -r v4 -a amd64 -v candidate
#   ocpdownload.sh                                 # fully interactive
#

# zsh compatibility: use 0-based arrays and field splitting like bash/ksh
[ -n "${ZSH_VERSION:-}" ] && emulate -L ksh 2>/dev/null

set -euo pipefail

MIRROR_BASE="https://mirror.openshift.com/pub"
BASEURL=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [-r MAJOR] [-a ARCH] [-v VERSION] [-d DEFAULT_ARCH] [-h]

Download OpenShift client and installer binaries.

Options:
  -r MAJOR         Major release: v4, v5
  -a ARCH          Architecture: multi, amd64, arm64, ppc64le, s390x
  -v VERSION       Release version or channel (fetched dynamically from mirror), e.g.:
                     4.16.3, candidate-4.17, fast-4.16,
                     stable-4.16, latest-4.16,
                     candidate, fast, stable, latest
  -d DEFAULT_ARCH  Default arch for multi-arch install: amd64, arm64, ppc64le, s390x
                   (only required when ARCH=multi)
  -h               Show this help message

If options are omitted, the script will prompt interactively.

Examples:
  $(basename "$0") -r v4 -a amd64 -v stable-4.16
  $(basename "$0") -r v5 -a amd64 -v stable-4.18
  $(basename "$0") -r v4 -a multi -v 4.16.3 -d amd64
  $(basename "$0")   # fully interactive
EOF
    exit 0
}

MAJOR=""
ARCH=""
VERSION=""
DEFAULT_ARCH=""

while getopts ":r:a:v:d:h" opt; do
    case "$opt" in
        r) MAJOR="$OPTARG" ;;
        a) ARCH="$OPTARG" ;;
        v) VERSION="$OPTARG" ;;
        d) DEFAULT_ARCH="$OPTARG" ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; exit 1 ;;
        *) echo "Error: Unknown option -$OPTARG" >&2; usage ;;
    esac
done

set_baseurl() {
    BASEURL="${MIRROR_BASE}/openshift-${MAJOR}"
}

prompt_major_version() {
    echo ""
    echo "Select OpenShift major release:"
    echo "  1) v4   (openshift-v4)"
    echo "  2) v5   (openshift-v5)"
    echo ""
    echo "  q) Quit"
    echo ""
    while true; do
        printf "Enter choice [1-2, q]: "; read -r choice
        case "$choice" in
            1) MAJOR="v4"; set_baseurl; return 0 ;;
            2) MAJOR="v5"; set_baseurl; return 0 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection. Please enter 1, 2, or q." ;;
        esac
    done
}

validate_major() {
    case "$MAJOR" in
        v4|v5) ;;
        *) echo "Error: Invalid major release '$MAJOR'. Must be: v4 or v5." >&2; exit 1 ;;
    esac
}

prompt_arch() {
    echo ""
    echo "Select architecture:"
    echo "  1) multi"
    echo "  2) amd64"
    echo "  3) arm64"
    echo "  4) ppc64le"
    echo "  5) s390x"
    echo ""
    echo "  b) Back         q) Quit"
    echo ""
    while true; do
        printf "Enter choice [1-5, b, q]: "; read -r choice
        case "$choice" in
            1) ARCH="multi"; return 0 ;;
            2) ARCH="amd64"; return 0 ;;
            3) ARCH="arm64"; return 0 ;;
            4) ARCH="ppc64le"; return 0 ;;
            5) ARCH="s390x"; return 0 ;;
            b|B) return 1 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection. Please enter 1-5, b, or q." ;;
        esac
    done
}

fetch_versions() {
    typeset url="${BASEURL}/${ARCH}/clients/ocp/"
    echo "Fetching available versions from ${url} ..." >&2
    typeset listing
    listing=$(curl -sL "$url" | sed -n 's/.*href="\([^"]*\/\)".*/\1/p' | sed 's|/$||' | grep -v '^\.\.' | sort -t. -k1,1n -k2,2n -k3,3n)
    if [[ -z "$listing" ]]; then
        echo "Error: Failed to retrieve version list from ${url}" >&2
        exit 1
    fi
    echo "$listing"
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
        for (( i = start; i < end; i++ )); do
            eval "typeset _val=\${${_arr_name}[$i]}"
            printf "  %4d) %s\n" "$((i + 1))" "$_val"
        done
        echo ""
        if [[ "$max_page" -gt 0 ]]; then
            echo "  n) Next page   p) Previous page"
        fi
        echo "  b) Back         q) Quit"
        echo ""
        printf "Enter number to select, or n/p/b/q: "; read -r input

        case "$input" in
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
                    echo "Invalid selection. Enter a number between 1 and $total."
                fi
                ;;
        esac
    done
}

prompt_version() {
    typeset versions
    versions=$(fetch_versions)

    typeset candidate_entries=() fast_entries=() stable_entries=() latest_entries=()
    typeset release_minors=()
    typeset seen_minors=""

    typeset major_num="${MAJOR#v}"

    while IFS= read -r entry; do
        case "$entry" in
            candidate-${major_num}.*) candidate_entries+=("$entry") ;;
            candidate)                candidate_entries+=("$entry") ;;
            fast-${major_num}.*)      fast_entries+=("$entry") ;;
            fast)                     fast_entries+=("$entry") ;;
            stable-${major_num}.*)    stable_entries+=("$entry") ;;
            stable)                   stable_entries+=("$entry") ;;
            latest-${major_num}.*)    latest_entries+=("$entry") ;;
            latest)                   latest_entries+=("$entry") ;;
            ${major_num}.*)
                typeset minor="${entry%.*}"
                case "$seen_minors" in
                    *"|${minor}|"*) ;;
                    *)
                        seen_minors="${seen_minors}|${minor}|"
                        release_minors+=("$minor")
                        ;;
                esac
                ;;
        esac
    done <<< "$versions"

    while true; do
        echo ""
        echo "Select version type:"
        echo "  1) candidate   (${#candidate_entries[@]} entries)"
        echo "  2) fast         (${#fast_entries[@]} entries)"
        echo "  3) stable       (${#stable_entries[@]} entries)"
        echo "  4) latest       (${#latest_entries[@]} entries)"
        echo "  5) Release      (specific x.y.z versions)"
        echo ""
        echo "  b) Back         q) Quit"
        echo ""
        typeset cat_choice
        printf "Enter choice [1-5, b, q]: "; read -r cat_choice
        case "$cat_choice" in
            b|B) return 1 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            1)
                if pick_from_list candidate_entries "candidate channels"; then
                    VERSION="$PICKED"; return 0
                fi
                ;;
            2)
                if pick_from_list fast_entries "fast channels"; then
                    VERSION="$PICKED"; return 0
                fi
                ;;
            3)
                if pick_from_list stable_entries "stable channels"; then
                    VERSION="$PICKED"; return 0
                fi
                ;;
            4)
                if pick_from_list latest_entries "latest channels"; then
                    VERSION="$PICKED"; return 0
                fi
                ;;
            5)
                if pick_from_list release_minors "Release minor versions"; then
                    typeset chosen_minor="$PICKED"

                    typeset patch_versions=()
                    while IFS= read -r entry; do
                        if [[ "$entry" == "${chosen_minor}".* ]]; then
                            patch_versions+=("$entry")
                        fi
                    done <<< "$versions"

                    if pick_from_list patch_versions "Releases for ${chosen_minor}"; then
                        VERSION="$PICKED"; return 0
                    fi
                fi
                ;;
            *) echo "Invalid selection. Please enter 1-5, b, or q." ;;
        esac
    done
}

prompt_default_arch() {
    echo ""
    echo "Select default architecture for multi-arch installation:"
    echo "  1) amd64"
    echo "  2) arm64"
    echo "  3) ppc64le"
    echo "  4) s390x"
    echo ""
    echo "  b) Back         q) Quit"
    echo ""
    while true; do
        printf "Enter choice [1-4, b, q]: "; read -r choice
        case "$choice" in
            1) DEFAULT_ARCH="amd64"; return 0 ;;
            2) DEFAULT_ARCH="arm64"; return 0 ;;
            3) DEFAULT_ARCH="ppc64le"; return 0 ;;
            4) DEFAULT_ARCH="s390x"; return 0 ;;
            b|B) return 1 ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection. Please enter 1-4, b, or q." ;;
        esac
    done
}

validate_arch() {
    case "$ARCH" in
        multi|amd64|arm64|ppc64le|s390x) ;;
        *) echo "Error: Invalid architecture '$ARCH'. Must be: multi, amd64, arm64, ppc64le, or s390x." >&2; exit 1 ;;
    esac
}

validate_default_arch() {
    case "$DEFAULT_ARCH" in
        amd64|arm64|ppc64le|s390x) ;;
        *) echo "Error: Invalid default architecture '$DEFAULT_ARCH'. Must be: amd64, arm64, ppc64le, or s390x." >&2; exit 1 ;;
    esac
}

validate_version() {
    if [[ -z "$VERSION" ]]; then
        echo "Error: Version cannot be empty." >&2
        exit 1
    fi

    typeset versions
    versions=$(fetch_versions)
    if ! echo "$versions" | grep -qx "$VERSION"; then
        echo "Error: Version '$VERSION' not found on the mirror for architecture '$ARCH'." >&2
        echo "Run without -v to see available versions interactively." >&2
        exit 1
    fi
}

validate_no_default_arch_without_multi() {
    if [[ "$ARCH" != "multi" && -n "$DEFAULT_ARCH" ]]; then
        echo "Error: -d DEFAULT_ARCH is only valid when architecture is 'multi'." >&2
        exit 1
    fi
}

# --- Validate CLI parameters if provided ---

if [[ -n "$MAJOR" ]]; then
    validate_major
    set_baseurl
fi

if [[ -n "$ARCH" ]]; then
    validate_arch
    validate_no_default_arch_without_multi
    if [[ "$ARCH" == "multi" && -n "$DEFAULT_ARCH" ]]; then
        validate_default_arch
    fi
fi

if [[ -n "$MAJOR" && -n "$ARCH" && -n "$VERSION" ]]; then
    validate_version
fi

# --- Interactive prompts for missing parameters ---

if [[ -z "$MAJOR" || -z "$ARCH" || -z "$VERSION" ]]; then
    local_step="major"
    [[ -n "$MAJOR" && -z "$ARCH" ]] && local_step="arch"
    [[ -n "$MAJOR" && -n "$ARCH" && "$ARCH" == "multi" && -z "$DEFAULT_ARCH" ]] && local_step="default_arch"
    [[ -n "$MAJOR" && -n "$ARCH" && "$ARCH" != "multi" && -z "$VERSION" ]] && local_step="version"
    [[ -n "$MAJOR" && -n "$ARCH" && "$ARCH" == "multi" && -n "$DEFAULT_ARCH" && -z "$VERSION" ]] && local_step="version"

    while true; do
        case "$local_step" in
            major)
                MAJOR=""
                ARCH=""
                DEFAULT_ARCH=""
                VERSION=""
                prompt_major_version
                local_step="arch"
                ;;
            arch)
                ARCH=""
                DEFAULT_ARCH=""
                VERSION=""
                if prompt_arch; then
                    if [[ "$ARCH" == "multi" ]]; then
                        local_step="default_arch"
                    else
                        local_step="version"
                    fi
                else
                    local_step="major"
                fi
                ;;
            default_arch)
                DEFAULT_ARCH=""
                VERSION=""
                if prompt_default_arch; then
                    local_step="version"
                else
                    local_step="arch"
                fi
                ;;
            version)
                VERSION=""
                if prompt_version; then
                    break
                else
                    if [[ "$ARCH" == "multi" ]]; then
                        local_step="default_arch"
                    else
                        local_step="arch"
                    fi
                fi
                ;;
        esac
    done
fi

# --- Build the download URL ---

if [[ "$ARCH" == "multi" ]]; then
    OCPURL="${BASEURL}/${ARCH}/clients/ocp/${VERSION}/${DEFAULT_ARCH}/"
else
    OCPURL="${BASEURL}/${ARCH}/clients/ocp/${VERSION}/"
fi

# Determine OS platform
OS_PLATFORM="linux"
case "$(uname -s)" in
    Darwin) OS_PLATFORM="mac" ;;
    Linux)  OS_PLATFORM="linux" ;;
esac

# Determine the target binary architecture.
# For multi-arch, DEFAULT_ARCH selects the binary; otherwise ARCH does.
BIN_ARCH="$ARCH"
[[ "$ARCH" == "multi" ]] && BIN_ARCH="$DEFAULT_ARCH"

# Build the tarball filenames matching the mirror naming convention:
#   linux + amd64  → openshift-{client,install}-linux.tar.gz
#   linux + arm64  → openshift-{client,install}-linux-arm64.tar.gz
#   linux + ppc64le→ openshift-{client,install}-linux-ppc64le.tar.gz
#   linux + s390x  → openshift-{client,install}-linux-s390x.tar.gz
#   mac   + amd64  → openshift-{client,install}-mac.tar.gz
#   mac   + arm64  → openshift-{client,install}-mac-arm64.tar.gz
build_filename() {
    typeset component="$1"   # "client" or "install"
    if [[ "$OS_PLATFORM" == "mac" ]]; then
        if [[ "$BIN_ARCH" == "arm64" ]]; then
            echo "openshift-${component}-mac-arm64.tar.gz"
        else
            echo "openshift-${component}-mac.tar.gz"
        fi
    else
        case "$BIN_ARCH" in
            amd64)   echo "openshift-${component}-linux.tar.gz" ;;
            arm64)   echo "openshift-${component}-linux-arm64.tar.gz" ;;
            ppc64le) echo "openshift-${component}-linux-ppc64le.tar.gz" ;;
            s390x)   echo "openshift-${component}-linux-s390x.tar.gz" ;;
            *)       echo "openshift-${component}-linux.tar.gz" ;;
        esac
    fi
}

CLIENT_FILE="$(build_filename client)"
INSTALL_FILE="$(build_filename install)"

echo ""
echo "============================================"
echo "  Major Release : $MAJOR"
echo "  Architecture  : $ARCH"
[[ "$ARCH" == "multi" ]] && echo "  Default Arch  : $DEFAULT_ARCH"
echo "  Binary Arch   : $BIN_ARCH"
echo "  OS Platform   : $OS_PLATFORM"
echo "  Version       : $VERSION"
echo "  Download URL  : $OCPURL"
echo "  Client file   : $CLIENT_FILE"
echo "  Installer file: $INSTALL_FILE"
echo "============================================"
echo ""

printf "Proceed with download? [y/N]: "; read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

download() {
    typeset url="$1"
    typeset file="$2"
    if command -v curl &>/dev/null; then
        curl -LO --fail --progress-bar "$url" || { echo "Error: Download failed: $url" >&2; exit 1; }
    elif command -v wget &>/dev/null; then
        wget "$url" || { echo "Error: Download failed: $url" >&2; exit 1; }
    else
        echo "Error: Neither curl nor wget found." >&2; exit 1
    fi
}

echo ""
echo "Downloading OpenShift client..."
download "${OCPURL}${CLIENT_FILE}" "$CLIENT_FILE"

echo ""
echo "Downloading OpenShift installer..."
download "${OCPURL}${INSTALL_FILE}" "$INSTALL_FILE"

echo ""
echo "Extracting archives..."
tar xvfz "$CLIENT_FILE"
tar xvfz "$INSTALL_FILE"

echo ""
echo "Cleaning up..."
rm -f README.md
rm -f "${CLIENT_FILE}"*
rm -f "${INSTALL_FILE}"*

echo ""
echo "Verifying extracted binaries..."
for bin in oc kubectl openshift-install; do
    if [[ -f "$bin" ]]; then
        desc=$(file "$bin")
        echo "  $desc"
    fi
done

echo ""
echo "Done. OpenShift binaries ready (${OS_PLATFORM}/${BIN_ARCH})."
