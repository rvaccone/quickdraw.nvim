-- Self-contained config for the VHS demo tape. Run from the repo root:
--   vhs demo/quickdraw.tape
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

vim.o.termguicolors = true
vim.o.number = true
vim.o.cursorline = true
vim.o.swapfile = false

-- The default colorscheme is nearly monochrome, so the dim ground would
-- not read on camera. Habamax ships with Neovim and has real contrast.
vim.cmd.colorscheme("habamax")

require("quickdraw").setup()
