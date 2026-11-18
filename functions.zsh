mkcd() {
    [[ -z $1 ]] && { echo "Usage: mkcd <directory>"; return 1 }
    mkdir -p -- "$1" && cd -- "$1"
}

bak() {
    emulate -L zsh
    [[ -z $1 ]] && { echo "Usage: bak <file|directory> [...]"; return 1 }

    local f dst rc=0
    for f in "$@"; do
        f=${f%/}
        [[ -e $f ]] || { echo "Not found: $f"; rc=1; continue }
        dst="$f.bak"
        [[ -e $dst ]] && dst="$f.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a -- "$f" "$dst" && echo "$f -> $dst" || rc=1
    done
    return $rc
}

compdef _directories mkcd
