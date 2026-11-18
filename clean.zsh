#!/usr/bin/env zsh

zmodload zsh/datetime

typeset -gA CLEAN_COLOR
CLEAN_COLOR=(
    name  34
    pct   36
    size  32
    rate  33
    time  35
    fill  32
    empty 90
)

typeset -ga CLEAN_DIRS=(
    "$HOME/Pictures/Screenshots"
    "/home/jonathan/Téléchargements"
)

LARGE_FILE_BYTES=1073741824

_clean_size() {
    local -F value=$1
    local -a units=(B KiB MiB GiB TiB)
    local -i index=1

    while (( value >= 1024 && index < 5 )); do
        (( value /= 1024, index++ ))
    done

    printf '%.1f %s' "$value" "${units[index]}"
}

_clean_time() {
    local -i seconds=${1%.*}
    printf '%02d:%02d' $(( seconds / 60 )) $(( seconds % 60 ))
}

_clean_draw() {
    emulate -L zsh

    local name=$1 total=$2 pct=$3 start=$4 first=$5
    local -i cols=${COLUMNS:-80}
    local -i filled=$(( cols * pct / 100 ))
    local -F done=$(( total * pct / 100.0 ))
    local -F elapsed=$(( EPOCHREALTIME - start )) rate=0 eta=0
    local esc=$'\e[' reset=$'\e[0m'

    (( elapsed > 0 )) && rate=$(( done / elapsed ))
    (( rate > 0 )) && eta=$(( (total - done) / rate ))

    local sizes="$(_clean_size "$done") / $(_clean_size "$total")"
    local speed="$(_clean_size "$rate")/s"
    local times="$(_clean_time "$elapsed") eta $(_clean_time "$eta")"
    local rest="  ${pct}%  ${sizes}  ${speed}  ${times}"
    local -i room=$(( cols - ${#rest} - 1 ))

    (( room < 4 )) && room=4
    (( ${#name} > room )) && name="${name[1,room-1]}…"

    local info="${esc}1;${CLEAN_COLOR[name]}m${name}${reset}"
    info+="  ${esc}${CLEAN_COLOR[pct]}m${pct}%${reset}"
    info+="  ${esc}${CLEAN_COLOR[size]}m${sizes}${reset}"
    info+="  ${esc}${CLEAN_COLOR[rate]}m${speed}${reset}"
    info+="  ${esc}${CLEAN_COLOR[time]}m${times}${reset}"

    local fill=${(l:filled::━:)}
    local empty=${(l:cols-filled::━:)}

    (( first )) || printf '\e[2A'
    printf '\r\e[K%s\n' "$info"
    printf '\r\e[K%s%s%s%s%s%s\n' \
        "${esc}${CLEAN_COLOR[fill]}m" "$fill" "$reset" \
        "${esc}${CLEAN_COLOR[empty]}m" "$empty" "$reset"
}

clean() {
    emulate -L zsh
    setopt local_options pipefail

    local force=0 dir file item answer temp_list
    local item_count=0 current=0 pct
    local total_files=0 total_bytes=0 files bytes
    local -F start
    local -a targets large_files

    if [[ ${1-} == "-f" ]]; then
        force=1
        shift
    fi

    if (( $# > 0 )); then
        print -u2 -- "Usage: ${0:t} [-f]"
        return 2
    fi

    for dir in "${CLEAN_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            print -- "Skipped, directory not found: $dir"
            continue
        fi

        dir=${dir:A}

        if [[ "$dir" == "/" || "$dir" == "$HOME" ]]; then
            print -u2 -- "Deletion refused: $dir"
            continue
        fi

        targets+=("$dir")
    done

    if (( ${#targets} == 0 )); then
        print -- "No valid directories."
        return 0
    fi

    if (( ! force )); then
        print -- ""
        print -- "Directories to empty:"
        for dir in "${targets[@]}"; do
            print -- "  • $dir"
        done

        print -n -- "Empty these directories? [Y/n] "
        read -r answer </dev/tty || return 1

        if [[ "$answer" == [nN] || "$answer" == [nN][oO] ]]; then
            print -- "Cancelled."
            return 0
        fi

        for dir in "${targets[@]}"; do
            while IFS= read -r -d '' file; do
                large_files+=("$file")
            done < <(
                command find "$dir" -type f \
                    -size +"$(( LARGE_FILE_BYTES - 1 ))c" \
                    -print0 2>/dev/null
            )
        done

        if (( ${#large_files} > 0 )); then
            print -- ""
            print -- "Large files detected (1 GiB or larger):"
            print -l -- "${large_files[@]}"
            print -n -- "Continue and delete them? [y/N] "
            read -r answer </dev/tty || return 1

            if [[ "$answer" != [yY] && "$answer" != [yY][eE][sS] ]]; then
                print -- "Cancelled."
                return 0
            fi
        fi
    fi

    temp_list=$(command mktemp) || {
        print -u2 -- "Could not create a temporary file."
        return 1
    }

    for dir in "${targets[@]}"; do
        files=$(command find "$dir" -type f -printf '.' 2>/dev/null | wc -c)
        bytes=$(command find "$dir" -type f -printf '%s\n' 2>/dev/null |
            awk '{ sum += $1 } END { printf "%.0f", sum }')

        total_files=$(( total_files + files ))
        total_bytes=$(( total_bytes + bytes ))

        command find "$dir" -mindepth 1 -maxdepth 1 -print0 \
            >> "$temp_list" 2>/dev/null
    done

    item_count=$(command awk 'BEGIN { RS = "\0" } END { print NR }' "$temp_list")

    if (( item_count > 0 )); then
        print -- ""
        print -- "Deleting items..."

        start=$EPOCHREALTIME
        while IFS= read -r -d '' item; do
            if ! command rm -rf -- "$item"; then
                command rm -f -- "$temp_list"
                print -u2 -- "Failed to delete: $item"
                return 1
            fi

            (( current++ ))
            pct=$(( current * 100 / item_count ))
            _clean_draw "Cleaning" "$item_count" "$pct" "$start" "$(( current == 1 ))"
        done < "$temp_list"
    fi

    command rm -f -- "$temp_list"

    print -- ""
    print -- "Cleanup summary"
    printf '  Files deleted:   %s\n' "$total_files"
    printf '  Space reclaimed: %s\n' "$(_clean_size "$total_bytes")"
}
