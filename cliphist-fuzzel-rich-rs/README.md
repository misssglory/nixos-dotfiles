# cliphist-fuzzel-rich

Wayland clipboard picker for `cliphist` + `fuzzel`, written in Rust.

## Features

- cached text stats and previews
- parallel metadata refresh for uncached text entries
- thumbnails for image clipboard entries
- synthetic display IDs starting from `0`
- age on the left, stats aligned on the right
- composite selection workflow for combining multiple text entries
- remembers the previously selected row across composite relaunches when supported by your fuzzel version

## Keybinds expected in `fuzzel.ini`

```ini
[key-bindings]
custom-1=Alt+1
custom-2=Alt+2
custom-3=Alt+3
custom-4=Alt+4
custom-10=Alt+0
```

These map to:

- `Enter`: copy selected entry normally
- `Alt+1`: delete selected entry
- `Alt+2`: append selected text entry to composite buffer
- `Alt+3`: copy composite buffer to clipboard and clear it
- `Alt+4`: clear composite buffer
- `Alt+0`: wipe cliphist history

## Composite mode

Composite text is stored in:

- `$XDG_STATE_HOME/cliphist/composite.txt`

Last selected row is stored in:

- `$XDG_STATE_HOME/cliphist/selected-index.txt`

By default, after `Alt+2`, `Alt+3`, or `Alt+4`, the program relaunches itself so the prompt updates immediately and tries to keep the current row selected using `fuzzel --select-index` when available.

Disable that behavior with:

```sh
cliphist-fuzzel-rich --no-relaunch-after-composite-action
```

## Build

```sh
cargo build --release
```

Binary will be at:

```sh
target/release/cliphist-fuzzel-rich
```

## Example run

```sh
cliphist-fuzzel-rich
```

Custom separator between appended entries:

```sh
cliphist-fuzzel-rich --composite-separator "\n---\n"
```
