#!/bin/bash

# Usage: ./sync-tags.sh <source remote> <destination remote>
# Example: ./sync-tags.sh upstream origin

main() {
    local remote_count=0
    local source_remote=
    local destination_remote=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            [-]*)
                error_exit "Unexpected option: \"$1\""
                ;;
            *)
                remote_count=$(($remote_count + 1))
                case "$remote_count" in
                    1)
                        check_remote $1 || error_exit "Invalid source remote: \"$1\""
                        source_remote="$1"
                        ;;
                    2)
                        check_remote $1 || error_exit "Invalid destination remote: \"$1\""
                        destination_remote="$1"
                        [[ "$source_remote" = "$destination_remote" ]] && {
                            error_exit "Supply different source and destination remotes"
                        }
                        ;;
                    *)
                        ;;
                esac
                shift
                ;;
        esac
    done

    [[ "$remote_count" = "2" ]] || {
        error_exit "Supply source and destination remotes as arguments"
    }

    # Get a list of refspecs we can use to fetch and push missing tags, like:
    # +refs/tags/missing-tag-01:refs/tags/missing-tag-01
    # +refs/tags/missing-tag-02:refs/tags/missing-tag-02
    # ...
    mapfile -t MISSING_TAG_REFSPECS < \
        <( diff --unchanged-line-format='' \
                --old-line-format='' \
                --new-line-format='%L' \
                <( git ls-remote --tags --refs --sort="version:refname" $destination_remote ) \
                <( git ls-remote --tags --refs --sort="version:refname" $source_remote ) \
            | cut -f 2 \
            | sed -E 's/^(.*)$/+\1:\1/g' )
    [[ -n "${MISSING_TAG_REFSPECS[@]}" ]] || {
        no_error_exit "Tags up to date."
    }

    printf '%q\n' "${MISSING_TAG_REFSPECS[@]}" | xargs -r git fetch --quiet $source_remote || {
        MISSING_TAG_REFSPECS=("Failed to fetch missing tags from ${source_remote}:" "${MISSING_TAG_REFSPECS[@]}")
        error_exit "${MISSING_TAG_REFSPECS[@]}"
    }
    printf '%q\n' "${MISSING_TAG_REFSPECS[@]}" | xargs -r git push --quiet --no-verify $destination_remote || {
        MISSING_TAG_REFSPECS=("Failed to push missing tags to ${destination_remote}:" "${MISSING_TAG_REFSPECS[@]}")
        error_exit "${MISSING_TAG_REFSPECS[@]}"
    }
    MISSING_TAG_REFSPECS=("Successfully added missing tags from ${source_remote} to ${destination_remote}:" "${MISSING_TAG_REFSPECS[@]}")
    no_error_exit "${MISSING_TAG_REFSPECS[@]}"
}

check_remote() {
    [[ $# -eq 1 ]] || {
        return 1
    }
    git remote get-url $1 > /dev/null 2>&1
    return
}

error_exit() {
    [[ $# -gt 0 ]] && {
        echo "Fatal: $1" >&2
        shift
    }
    for msg in "$@"; do
        echo "$msg" >&2
    done
    echo
    exit 1
}

no_error_exit() {
    for msg in "$@"; do
        echo "$msg"
    done
    echo
    exit 0
}

main "$@" || error_exit
exit 0
