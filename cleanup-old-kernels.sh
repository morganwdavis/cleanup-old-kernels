#!/bin/sh
#
# cleanup-old-kernels.sh - Purge old kernel packages and orphaned directories
# POSIX-compliant, Debian-family (Ubuntu/Mint) safe
#
# What is removed:
#   - Old linux-image, linux-headers, linux-modules, and linux-tools packages
#     * Protects current running kernel and newest installed kernel versions
#   - Orphaned directories under /usr/src, /usr/lib/linux-tools*, /usr/lib/modules*, /lib/modules
#     * Only directories corresponding to removed kernel versions are deleted
#
# What is preserved:
#   - Current running kernel
#   - Newest installed kernel
#   - Any packages or directories not matching kernel version patterns

# shellcheck disable=SC3040,SC3043,SC3050
set -eu

show_usage() {
    cat <<EOF
Usage: $0 [-y|--yes] [-n|--dry-run]

Options:
  -h, --help        Show this help message and exit
  -y, --yes         Skip confirmations for non-interactive use
  -n, --dry-run     Show packages that would be removed without deleting anything
EOF
}

# Defaults
dry_run=0
assume_yes=0
apt_args="--auto-remove"

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)
            apt_args="$apt_args -y"
            assume_yes=1
            ;;
        -n|--dry-run|--dryrun)
            dry_run=1
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# --- System checks ---
command -v dpkg >/dev/null 2>&1 || { echo "dpkg required" >&2; exit 1; }
command -v apt-get >/dev/null 2>&1 || { echo "apt-get required" >&2; exit 1; }

# --- Helper to extract base version ---
get_base_version() {
    # Extract the base version (e.g., 6.1.0-18) from a full kernel version or package name
    printf "%s\n" "$1" | sed -nE 's/.*([0-9]+\.[0-9]+\.[0-9]+-[0-9]+).*/\1/p'
}

# --- Wrapper function ---
perform_cleanup() {
    _dry_run=$1

    current_kernel=$(uname -r)

    # Get all versioned kernel-related packages in one go
    all_versioned_pkgs=$(dpkg-query -W -f='${Package}\n' 'linux-*-*-*' 2>/dev/null | grep -E 'linux-(image|headers|modules|tools)' || true)
    [ -n "$all_versioned_pkgs" ] || { echo "No kernel packages found. Nothing to do."; return; }

    # Determine newest kernel
    versioned_images=$(printf "%s\n" "$all_versioned_pkgs" | grep '^linux-image-[0-9]' || true)
    newest_kernel=$(printf "%s\n" "$versioned_images" | grep -v unsigned | sort -V | tail -1)

    echo "Current running kernel: $current_kernel"
    echo "Newest installed kernel: $newest_kernel"

    current_base=$(get_base_version "$current_kernel")
    newest_base=$(get_base_version "$newest_kernel")
    protected_versions="$current_base $newest_base"

    is_protected() {
        ver="$1"
        # POSIX-safe matching
        case " $protected_versions " in
            *" $ver "*) return 0 ;;
            *) return 1 ;;
        esac
    }

    # --- Determine removable packages ---
    to_remove_images=""
    to_remove_headers=""
    to_remove_modules=""
    to_remove_tools=""

    for pkg in $all_versioned_pkgs; do
        ver=$(get_base_version "$pkg")
        [ -n "$ver" ] || continue
        is_protected "$ver" && continue
        case "$pkg" in
            linux-image-*)   to_remove_images="$to_remove_images $pkg" ;;
            linux-headers-*) to_remove_headers="$to_remove_headers $pkg" ;;
            linux-modules-*) to_remove_modules="$to_remove_modules $pkg" ;;
            linux-tools-*)   to_remove_tools="$to_remove_tools $pkg" ;;
        esac
    done

    # --- Show removal plan ---
    if [ -z "$to_remove_images" ] && [ -z "$to_remove_headers" ] && \
       [ -z "$to_remove_modules" ] && [ -z "$to_remove_tools" ]; then
        echo "No old kernel packages to remove."
        nothing_to_remove=1
    else
        nothing_to_remove=0
        echo ""
        echo "The following old kernel packages will be removed:"
        for pkg in $to_remove_images $to_remove_headers $to_remove_modules $to_remove_tools; do
            echo "  $pkg"
        done
    fi

    # --- Dry-run or confirmation ---
    if [ "$_dry_run" -eq 1 ]; then
        echo ""
        echo "(Dry run: nothing was removed)"
        return
    fi

    if [ $assume_yes -eq 0 ] && [ $nothing_to_remove -eq 0 ]; then
        echo ""
        printf "Proceed with actual removal? [y/N] "
        # shellcheck disable=SC2162
        read -r ans || true
        case "$ans" in
            [Yy]*) ;;
            *) echo "Aborted."; return ;;
        esac
    fi

    # --- Remove packages ---
    if [ $nothing_to_remove -eq 0 ]; then
        echo ""
        echo "Running apt-get purge..."
        # shellcheck disable=SC2086
        apt-get $apt_args purge $to_remove_images $to_remove_headers $to_remove_modules $to_remove_tools
    fi

    # --- Remove leftover orphaned directories ---
    echo ""
    echo "Checking for orphaned kernel directories..."
    cleanup_kernel_dirs() {
        base_dir="$1"
        [ -d "$base_dir" ] || return 0
        for dir in "$base_dir"/*; do
            [ -d "$dir" ] || continue
            dir_name=$(basename "$dir")
            ver=$(get_base_version "$dir_name")
            [ -n "$ver" ] || continue
            # Only remove directories starting with 'linux-'
            case "$dir_name" in
                linux-*) ;;
                *) continue ;;
            esac
            is_protected "$ver" && continue
            echo "  Removing orphaned: $dir"
            rm -rf "$dir" || true
        done
    }

    for d in /usr/src /usr/lib/linux-tools /usr/lib/modules /lib/modules /usr/lib/linux-tools-*; do
        cleanup_kernel_dirs "$d"
    done

    echo ""
    echo "Cleanup complete. You may want to run 'update-grub' to update the bootloader menu."
}

# --- Execution ---
perform_cleanup "$dry_run"
