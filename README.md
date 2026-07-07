<!-- Header -->
<div align="center">
    <h1>Quickdraw.nvim</h1>
    <p>
        Press f. See how far it reaches.
        <br />
        <a href="#about">About</a>
        ·
        <a href="#installation">Installation</a>
        ·
        <a href="#how-it-works">How it works</a>
        ·
        <a href="#highlights">Highlights</a>
        ·
        <a href="#contributing">Contributing</a>
    </p>
</div>

## About

Quickdraw.nvim extends `f`, `t`, `F`, and `T` to reach any visible line and
shows you the cost of every jump before you take it. When you press `f`,
the view dims and each reachable character is colored by how many
keystrokes it takes to land on it:

- First color: `fx` lands here.
- Second color: `2fx` lands here.

You type real characters from the text. There are no hint labels to read
and no new motions to learn. If the character you want is not lit, it is
more than two occurrences away, and a plugin built for long jumps is the
better tool.

Quickdraw has no configuration. It requires Neovim 0.10+.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended):

```lua
{
    "rvaccone/quickdraw.nvim",
    opts = {},
}
```

> [!NOTE]
> Quickdraw remaps `f`, `t`, `F`, `T`, `;`, and `,`. Disable plugins that
> highlight the same motions, such as eyeliner.nvim or quick-scope.

## How it works

- `f` and `t` search forward through the visible window, `F` and `T`
  backward. Folded lines are skipped: if you cannot see it, you cannot
  target it.
- Highlights appear the moment you press the key and clear the moment you
  act. Whitespace is jumpable but never painted.
- Counts work natively: the tier colors are exactly the counts you can
  type.
- `;` repeats and `,` reverses. After you land, the nearest occurrences of
  your character stay lit until you press something else, so a repeat is a
  decision you read, not a guess.
- Jumps to another line push the jumplist, so `<C-o>` returns. Jumps on
  the same line stay native and do not.
- Operators work across lines: `dfx`, `cfx`, and `yfx` behave like their
  native versions, and `.` repeats the whole change.

## Highlights

The letters themselves are recolored and bolded; nothing is drawn behind
them. The two rank colors come from your theme's diagnostic palette, so
they read as distinct in any colorscheme, and transparency carries
through. Override any group to restyle:

| Group            | Default                    | Meaning                 |
| ---------------- | -------------------------- | ----------------------- |
| `QuickdrawRank1` | `DiagnosticError` fg, bold | Lands with `fx`         |
| `QuickdrawRank2` | `DiagnosticWarn` fg, bold  | Lands with `2fx`        |
| `QuickdrawDim`   | Linked to `Comment`        | Everything out of reach |

`:checkhealth quickdraw` reports version, keymaps, and conflicts.

## Contributing

```sh
make test       # run the test suite
make fmt-check  # check formatting with stylua
```
