# zettel.nvim

[Zettelkasten](https://de.wikipedia.org/wiki/Zettelkasten) plugin for neovim.

## Setup

**Lazy.nvim:**
```lua
{
    "tadachs/zettel.nvim",
    config = true,
    opts = {
      root_dir = "~/notes/zettelkasten", -- root dir for notes
      format = "md", -- file ending for notes
      link_pattern = "%[%[([^%]]+)%]%]", -- pattern for matching links
      tag_pattern = "#([%w%-%_]+)", -- pattern for matching tags
      title_pattern = "^# (.*)$", -- pattern for matching title of file
      open_cmd = "edit", -- command used for opening files
    },
    cond = function() -- so it only gets loaded in the note directory
      local current_file_path = vim.api.nvim_buf_get_name(0)
      return current_file_path:match(".*/zettelkasten/.*")
    end,
    dependencies = { "nvim-telescope/telescope.nvim" },
},
```


## Usage
`zettel.nvim` creates a graph from a directory containing notes. This allows
the user to easily see outgoing and incoming links with telescope. It also
provides easy linking between nodes using the `[[ID]]` syntax (which can be
partly customized).

**Example Setup:**
```lua
-- use autocommand to only set bindings in buffer in note directory
local zettel_group = vim.api.nvim_create_augroup("Zettelkasten", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinEnter", "BufRead", "BufNewFile" },
  {
    pattern = vim.fn.expand("~") .. "/notes/zettelkasten/*.md",
    callback = function()
      local zettelkasten = require "zettel"
      vim.keymap.set("n", "<CR>", zettelkasten.follow_link_under_cursor, { buffer = true })
      vim.keymap.set("i", "<c-]>", zettelkasten.insert_new_link, { buffer = true })
      vim.keymap.set("n", "<leader>ti", "<cmd>Telescope zettel find_incoming<CR>",
        { buffer = true })
      vim.keymap.set("n", "<leader>to",  "<cmd>Telescope zettel find_outgoing<CR>",
        { buffer = true })
      vim.keymap.set("n", "<leader>ta",   "<cmd>Telescope zettel find_all<CR>",
        { buffer = true })
      vim.keymap.set("i", "<c-[>", "<cmd>Telescope zettel insert_link<CR>",
        { buffer = true })
    end,
    group = zettel_group,
  })
```

## TODO

- [ ] telescope for tags
- [ ] don't depend on telescope, provide commands for quickfixlist/loclist as well

