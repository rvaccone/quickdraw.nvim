local health = vim.health

local M = {}

local MOTIONS = { "f", "F", "t", "T", ";", "," }

function M.check()
	health.start("quickdraw.nvim")

	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim >= 0.10")
	else
		health.error("quickdraw.nvim requires Neovim 0.10 or newer")
	end

	if vim.o.termguicolors then
		health.ok("'termguicolors' is on; the rank colors will render")
	else
		health.warn("'termguicolors' is off; the rank colors need it", {
			"Set vim.o.termguicolors = true",
		})
	end

	local missing = {}
	local taken = {}
	for _, lhs in ipairs(MOTIONS) do
		local map = vim.fn.maparg(lhs, "n", false, true)
		if map.lhs == nil then
			missing[#missing + 1] = lhs
		elseif not (map.desc or ""):match("^Quickdraw") then
			taken[#taken + 1] = ("`%s` is mapped by %s"):format(lhs, map.desc or map.rhs or "another plugin")
		end
	end

	if #missing == #MOTIONS then
		health.warn("No quickdraw mappings found. Was setup() called?")
	elseif #taken > 0 then
		health.warn("Some motions belong to another plugin:", taken)
	else
		health.ok("f, t, F, T, ; and , belong to quickdraw")
	end

	if pcall(require, "eyeliner") then
		health.warn("eyeliner.nvim is loaded: both plugins highlight f/t targets, disable one")
	end
end

return M
