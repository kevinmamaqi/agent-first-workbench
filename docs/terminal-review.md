# Terminal and editor review

Human shortcuts are interactive; agents use deterministic commands:

| Human | Agent |
| --- | --- |
| `f`, `ff` | `fd`, `rg --files`; following symlinks is explicit |
| `s QUERY` | `rg --json QUERY` |
| `gd`, `gds`, `changed` | Plain Git status and diff |
| `mdopen FILE.md` | macOS: `open -g -a MarkEdit FILE.md` |
| `cmark FILE.md` | `cmux markdown open FILE.md --focus false` |
| `preview FILE.pdf` | `cmux open FILE.pdf --no-focus` |

Zsh includes `ff`, `mdopen`, and `preview`. Human Markdown review opens MarkEdit
normally; unsolicited agent handoffs use `-g` to preserve focus. `cmark` is the
explicit read-only cmux viewer. Install MarkEdit separately for this workflow.

On Linux, `preview` opens Markdown in `$EDITOR`. Other artifacts require a
supported bridge or a reported path. Remote completion stays recoverable from
tmux, files, checks, and Git when the Mac is disconnected.

## Editor parity

Both installers include full Vim and the same Helix preferences. The Helix
picker includes hidden files while respecting ignore rules. Configuration is
in `config/helix/config.toml`; inspect with `hx --health` and reload with
`:config-reload`. See the [Helix guide](https://docs.helix-editor.com/configuration.html).

| Action | Helix | Vim |
| --- | --- | --- |
| Pick a file | Space, then `f` | Shell `f` helper |
| Insert | `i` | `i` |
| Normal mode | Escape | Escape |
| Save | `:w` | `:w` |
| Save and quit | `:wq` | `:wq` |
| Quit without saving | `:q!` | `:q!` |

Helix uses selection-first editing; shared save/quit commands do not make
all Vim commands interchangeable.
