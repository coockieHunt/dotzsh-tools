# zsh-toolbox

A small zsh toolbox for your terminal: archive extraction with a progress bar, directory cleanup, everyday helpers, and a shared color palette.

## Contents

| File            | Purpose                                                              |
| --------------- | -------------------------------------------------------------------- |
| `unwrap.zsh`    | Archive extraction with progress bar, transfer rate and ETA          |
| `clean.zsh`     | Empties temporary folders (screenshots, downloads) with confirmation |
| `functions.zsh` | Small helpers: `mkcd`, `bak`                                         |
| `colors.zsh`    | Color palette (accent, directory, git, error, muted)                 |

## Installation

```zsh
git clone https://github.com/<your-user>/zsh-toolbox.git ~/.zsh-toolbox
```

Then add this to your `~/.zshrc`:

```zsh
source ~/.zsh-toolbox/colors.zsh
source ~/.zsh-toolbox/functions.zsh
source ~/.zsh-toolbox/unwrap.zsh
source ~/.zsh-toolbox/clean.zsh
```

Reload your shell:

```zsh
source ~/.zshrc
```

## Usage

### `unwrap`: extract an archive

Automatically detects the format from its MIME type and shows a progress bar (percentage, size, transfer rate, elapsed time, ETA).

```zsh
unwrap <archive> [destination]
```

```zsh
unwrap backup.tar.gz
unwrap photos.zip ~/Pictures/photos
unwrap logs.xz /tmp/logs
```

**Supported formats:** `gzip`, `bzip2`, `xz`, `lzma`, `zstd`, `lz4`, `tar`, `zip`, `7z`, `rar` (including `.tar.*`, `.tgz`, `.tbz2`, `.txz` variants, etc.).

**Dependencies:**

- `file`, `stat`, `tar`, and the matching decompression tools
- `7z` (p7zip) for zip / 7z / rar
- `pv` _(optional)_ for progress on tar and compressed stream formats

### `clean`: empty temporary folders

Empties the folders listed in `CLEAN_DIRS` (by default: screenshots and downloads) after asking for confirmation.

```zsh
clean       # with confirmation (and a warning for files ≥ 1 GiB)
clean -f    # no confirmation
```

When finished, a summary shows the number of files deleted and the space reclaimed.

**Safety:** `clean` refuses to empty `/` and `$HOME`.

**Configuration:** edit the `CLEAN_DIRS` array at the top of `clean.zsh`:

```zsh
typeset -ga CLEAN_DIRS=(
    " $ HOME/Pictures/Screenshots"
    " $ HOME/Downloads"
)
```

### `mkcd`: create a directory and enter it

```zsh
mkcd my/new/directory
```

### `bak`: quick backup

Copies a file or directory to `.bak` (with a timestamp if a `.bak` already exists).

```zsh
bak config.toml          # -> config.toml.bak
bak file1 dir2           # multiple targets at once
```

## Customization

Progress bar colors are set through the `UNWRAP_COLOR` and `CLEAN_COLOR` arrays (ANSI codes). The hex palette in `colors.zsh` can be used for your prompt or other scripts.

## Requirements

- zsh 5.x or newer
- Linux (uses GNU `stat -c` and `find -printf`)

## License

MIT, see [LICENSE](LICENSE).
