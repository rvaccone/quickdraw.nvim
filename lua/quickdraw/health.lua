local health = vim.health

local M = {}

function M.check()
	health.start("quickdraw.nvim")

	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim >= 0.10")
	else
		health.error("quickdraw.nvim requires Neovim 0.10 or newer")
	end

	if vim.fn.maparg("f", "n") ~= "" then
		health.ok("f/t/F/T and ;/, are mapped")
	else
		health.warn("setup() has not been called")
	end

	if pcall(require, "eyeliner") then
		health.warn("eyeliner.nvim is loaded: both plugins highlight f/t targets, disable one")
	end
end

return M
