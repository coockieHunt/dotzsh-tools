zmodload zsh/datetime

typeset -gA UNWRAP_COLOR
UNWRAP_COLOR=(
    name  34
    pct   36
    size  32
    rate  33
    time  35
    fill  32
    empty 90
)

_unwrap_size() {
    local -F v=$1
    local -a u=(B KiB MiB GiB TiB)
    local -i i=1
    while (( v >= 1024 && i < 5 )); do
        (( v /= 1024, i++ ))
    done
    printf '%.1f %s' $v ${u[i]}
}

_unwrap_time() {
    local -i s=${1%.*}
    printf '%02d:%02d' $(( s / 60 )) $(( s % 60 ))
}

_unwrap_draw() {
    local name=$1 total=$2 pct=$3 start=$4 first=$5
    local -i cols=${COLUMNS:-80}
    local -i filled=$(( cols * pct / 100 ))
    local -F got=$(( total * pct / 100.0 ))
    local -F elapsed=$(( EPOCHREALTIME - start )) rate=0 eta=0
    local e=$'\e[' r=$'\e[0m'

    (( elapsed > 0 )) && rate=$(( got / elapsed ))
    (( rate > 0 )) && eta=$(( (total - got) / rate ))

    local sizes="$(_unwrap_size $got) / $(_unwrap_size $total)"
    local speed="$(_unwrap_size $rate)/s"
    local times="$(_unwrap_time $elapsed) eta $(_unwrap_time $eta)"
    local rest_txt="  ${pct}%  ${sizes}  ${speed}  ${times}"
    local -i room=$(( cols - ${#rest_txt} - 1 ))
    (( room < 4 )) && room=4
    (( ${#name} > room )) && name="${name[1,room-1]}…"

    local info="${e}1;${UNWRAP_COLOR[name]}m${name}${r}"
    info+="  ${e}${UNWRAP_COLOR[pct]}m${pct}%${r}"
    info+="  ${e}${UNWRAP_COLOR[size]}m${sizes}${r}"
    info+="  ${e}${UNWRAP_COLOR[rate]}m${speed}${r}"
    info+="  ${e}${UNWRAP_COLOR[time]}m${times}${r}"

    local fill=${(l:filled::━:)}
    local empty=${(l:cols-filled::━:)}

    (( first )) || printf '\e[2A'
    printf '\r\e[K%s\n' "$info"
    printf '\r\e[K%s%s%s%s%s%s\n' "${e}${UNWRAP_COLOR[fill]}m" "$fill" "$r" "${e}${UNWRAP_COLOR[empty]}m" "$empty" "$r"
}

_unwrap_render() {
    emulate -L zsh
    local name=$1 total=$2 pct last=0
    local -F start=$EPOCHREALTIME
    local -i first=1
    while read -r pct; do
        [[ $pct == <-> ]] || continue
        (( pct > 100 )) && pct=100
        last=$pct
        _unwrap_draw "$name" $total $pct $start $first
        first=0
    done
    (( last < 100 )) && _unwrap_draw "$name" $total 100 $start $first
}

unwrap() {
    emulate -L zsh
    setopt local_options pipefail

    local f=$1 dest=${2:-.}
    [[ -z $f ]] && { echo "Usage: unwrap <archive> [destination]"; return 1 }
    [[ -f $f ]] || { echo "File not found: $f"; return 1 }
    mkdir -p -- "$dest" || return 1

    local mime=$(file -b --mime-type -- "$f")
    local total=$(stat -c %s -- "$f")
    local -a dec sink

    case $mime in
        application/gzip)    dec=(gzip -dc) ;;
        application/x-bzip2) dec=(bzip2 -dc) ;;
        application/x-xz)    dec=(xz -dc) ;;
        application/x-lzma)  dec=(xz -dc --format=lzma) ;;
        application/zstd)    dec=(zstd -dc) ;;
        application/x-lz4)   dec=(lz4 -dc) ;;
        application/x-tar)   dec=(cat) ;;

        application/zip|application/x-7z-compressed|application/vnd.rar|application/x-rar)
            7z x -y -bso0 -bsp1 -o"$dest" -- "$f" \
                | tr '\r' '\n' \
                | grep --line-buffered -oE '[0-9]+%' \
                | sed -u 's/%//' \
                | _unwrap_render "${f:t}" $total \
                && echo "Extracted to $dest"
            return ;;

        *)
            echo "Unsupported format: $mime"
            return 1 ;;
    esac

    if [[ ${f:l} == (*.tar|*.tar.*|*.tgz|*.tbz|*.tbz2|*.txz|*.tzst|*.tlz4) ]]; then
        sink=(tar -x -C "$dest" -f -)
    else
        sink=(dd of="$dest/${f:t:r}" bs=1M status=none)
    fi

    local rc
    if (( $+commands[pv] )); then
        { command pv -n -i 0.1 -- "$f" 2>&3 | "${dec[@]}" | "${sink[@]}"; } 3>&1 1>&2 \
            | _unwrap_render "${f:t}" $total
        rc=${pipestatus[1]}
    else
        cat -- "$f" | "${dec[@]}" | "${sink[@]}"
        rc=$?
    fi
    (( rc == 0 )) && echo "Extracted to $dest"
    return $rc
}

compdef _files unwrap
