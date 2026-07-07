vim.opt.runtimepath:prepend(".")
vim.o.swapfile = false

local api = vim.api
local fn = vim.fn

local passed, failed = 0, 0
local failures = {}

local LINES = {
	"one quick brown", -- z nowhere here; q at col 4
	"fox jumps over", -- x at col 2
	"the lazy dog z", -- z at col 6 and col 13
	"quiet zebra quits", -- q col 0 and 12, z col 6
}

local function reset()
	pcall(vim.cmd, "silent! only!")
	pcall(vim.cmd, "silent! %bwipeout!")
	api.nvim_buf_set_lines(0, 0, -1, false, LINES)
	api.nvim_win_set_cursor(0, { 1, 0 })
end

local function test(name, body)
	reset()
	local ok, err = pcall(body)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		failures[#failures + 1] = ("  ✗ %s\n    %s"):format(name, err)
	end
end

local function eq(actual, expected, label)
	if not vim.deep_equal(actual, expected) then
		error(("%s: expected %s, got %s"):format(label or "eq", vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

local function ok(condition, label)
	if not condition then
		error(label or "expected truthy", 2)
	end
end

local function feed(keys)
	api.nvim_feedkeys(api.nvim_replace_termcodes(keys, true, false, true), "tx", false)
end

local quickdraw = require("quickdraw")
quickdraw.setup()

local function marks(group)
	local found = {}
	for _, mark in ipairs(api.nvim_buf_get_extmarks(0, quickdraw._ns, 0, -1, { details = true })) do
		if not group or mark[4].hl_group == group then
			found[#found + 1] = { mark[2] + 1, mark[3], mark[4].hl_group }
		end
	end
	return found
end

test("setup rejects everything except colors", function()
	ok(not pcall(quickdraw.setup, { delay_ms = 100 }), "unknown options must be rejected")
	ok(not pcall(quickdraw.setup, { colors = { rank4 = "#ffffff" } }), "unknown color must be rejected")
	ok(not pcall(quickdraw.setup, { colors = { rank1 = "matcha" } }), "non-hex color must be rejected")
	ok(not pcall(quickdraw.setup, { colors = "green" }), "colors must be a table")
end)

test("color options are applied to the highlight groups", function()
	eq(api.nvim_get_hl(0, { name = "QuickdrawRank1", link = false }).fg, 0xA8C080, "matcha default")
	eq(api.nvim_get_hl(0, { name = "QuickdrawRank2", link = false }).fg, 0xE07A5F, "terracotta default")
	eq(api.nvim_get_hl(0, { name = "QuickdrawRank3", link = false }).fg, 0x8DA9C4, "stoneware blue default")

	quickdraw.setup({ colors = { rank1 = "#123456" } })
	eq(api.nvim_get_hl(0, { name = "QuickdrawRank1", link = false }).fg, 0x123456, "custom color applied")
	eq(api.nvim_get_hl(0, { name = "QuickdrawRank2", link = false }).fg, 0xE07A5F, "other color untouched")

	quickdraw.setup({ colors = { rank1 = "#a8c080" } })
end)

test("f jumps across lines to the next occurrence", function()
	feed("fz")
	eq(api.nvim_win_get_cursor(0), { 3, 6 }, "landed on the z in lazy")
end)

test("counts reach later occurrences", function()
	feed("2fz")
	eq(api.nvim_win_get_cursor(0), { 3, 13 }, "second z")
end)

test("t stops before the character", function()
	feed("tz")
	eq(api.nvim_win_get_cursor(0), { 3, 5 }, "the character before z")
end)

test("F searches backward", function()
	api.nvim_win_set_cursor(0, { 4, 0 })
	feed("Fx")
	eq(api.nvim_win_get_cursor(0), { 2, 2 }, "x on the fox line")
end)

test("T lands after the character going backward", function()
	api.nvim_win_set_cursor(0, { 4, 0 })
	feed("Tx")
	eq(api.nvim_win_get_cursor(0), { 2, 3 }, "just after x")
end)

test("semicolon repeats and comma reverses", function()
	feed("fq")
	eq(api.nvim_win_get_cursor(0), { 1, 4 }, "first q")
	feed(";")
	eq(api.nvim_win_get_cursor(0), { 4, 0 }, "next q")
	feed(",")
	eq(api.nvim_win_get_cursor(0), { 1, 4 }, "back again")
end)

test("cross-line jumps push the jumplist", function()
	feed("fz")
	feed("<C-o>")
	eq(api.nvim_win_get_cursor(0), { 1, 0 }, "ctrl-o returns")
end)

test("operator f is inclusive across lines", function()
	feed("dfx")
	eq(fn.getline(1), " jumps over", "deleted through the x inclusively")
end)

test("dot repeat replays the multiline delete", function()
	feed("dfz")
	eq(fn.getline(1), "y dog z", "first delete through the z in lazy")
	feed(".")
	eq(fn.getline(1), "", "dot deleted through the next z")
	eq(fn.getline(2), "quiet zebra quits", "later lines untouched")
end)

test("visual f extends the selection", function()
	feed("vfz")
	eq(api.nvim_get_mode().mode, "v", "still in visual mode")
	eq(api.nvim_win_get_cursor(0), { 3, 6 }, "selection reaches the z")
	feed("<Esc>")
end)

test("rank painting colors first occurrences and dims the rest", function()
	quickdraw._paint(false)
	local rank1 = marks("QuickdrawRank1")
	ok(#rank1 > 0, "rank one marks exist")
	local found_z = false
	for _, mark in ipairs(rank1) do
		if mark[1] == 3 and mark[2] == 6 then
			found_z = true
		end
	end
	ok(found_z, "the first z is a rank-one target")
	ok(#marks("QuickdrawDim") > 0, "dim layer present")
	ok(#marks("QuickdrawRank2") > 0, "rank two present")
end)

test("whitespace is never painted", function()
	quickdraw._paint(false)
	for _, mark in ipairs(marks("QuickdrawRank1")) do
		local char = fn.getline(mark[1]):sub(mark[2] + 1, mark[2] + 1)
		ok(char ~= " " and char ~= "\t", "no whitespace targets painted")
	end
end)

test("the trail stays for repeats and clears on other keys", function()
	feed("fz")
	ok(#marks() > 0, "trail painted after landing")
	feed("j")
	vim.wait(100, function()
		return #marks() == 0
	end, 10)
	eq(#marks(), 0, "trail cleared by a non-repeat key")
end)

test("multibyte characters are matched and positioned by byte", function()
	api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "the αβγ row" })
	api.nvim_win_set_cursor(0, { 1, 0 })
	feed("fβ")
	eq(api.nvim_win_get_cursor(0), { 2, 6 }, "byte column of β")
end)

test("no occurrence means no movement", function()
	feed("f!")
	eq(api.nvim_win_get_cursor(0), { 1, 0 }, "cursor unmoved")
end)

print(("\nquickdraw: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	print(table.concat(failures, "\n"))
	vim.cmd("cquit!")
else
	vim.cmd("quitall!")
end
