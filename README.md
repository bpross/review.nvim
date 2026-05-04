# review.nvim

Leave inline review comments on local diffs without pushing to GitHub. Comments are stored in `.review.md` at the git root in a format readable by AI agents (Claude, Codex, etc.).

## Usage

| Key | Action |
|-----|--------|
| `<leader>rc` | Add a comment on the current line |
| `<leader>ro` | Open `.review.md` in a split |
| `<leader>rs` | Refresh virtual text annotations |

In the comment float: `<C-s>` to save, `q` or `<Esc>` to cancel.

Comments appear as inline virtual text on annotated lines and are written to `.review.md`:

```markdown
## Review Comments

- [src/foo.go:42] This logic doesn't handle nil users
  Fix: Check for nil before dereferencing
```

## Installation

```lua
-- lazy.nvim
{
  "bpross/review.nvim",
  lazy = false,
  config = function()
    require("review").setup()
  end,
  keys = {
    { "<leader>rc", function() require("review").add_comment() end, desc = "Add review comment" },
    { "<leader>ro", function() require("review").open_review() end, desc = "Open .review.md" },
    { "<leader>rs", function() require("review").show_comments() end, desc = "Refresh review comments" },
  },
}
```

## Comment format

The `.review.md` format matches the [agent-pipeline](https://github.com/moovfinancial/agent-pipeline) review convention — `[file:line]` headers with an optional indented `Fix:` line. Any agent that understands that format can consume these comments directly.
