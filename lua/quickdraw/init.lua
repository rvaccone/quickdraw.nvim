local api = vim.api
local fn = vim.fn

local M = {}

local ns = api.nvim_create_namespace("quickdraw")
M._ns = ns

local ESC = api.nvim_replace_termcodes("<Esc>", true, true, true)
local CTRL_C = api.nvim_replace_termcodes("<C-c>", true, true, true)
local PLUG = api.nvim_replace_termcodes("<Plug>(quickdraw-op)", true, true, true)

local RANK_GROUPS = { "QuickdrawRank1", "QuickdrawRank2", "QuickdrawRank3" }

---@type { kind: "f"|"t", backward: boolean, char: string }|nil
local last = nil
---@type { kind: "f"|"t", backward: boolean, char: string }|nil
local pending_op = nil
local trail_active = false

---@param names string[]
---@param fallback integer
---@return integer
local function fg_of(names, fallback)
	for _, name in ipairs(names) do
		local ok, hl = pcall(api.nvim_get_hl, 0, { name = name, link = false })
		if ok and hl.fg then
			return hl.fg
		end
	end
	return fallback
end

--- The letters themselves are restyled — bold, colored from your theme's
--- diagnostic palette so the three ranks are unmistakably distinct — never
--- boxed with a background. Override the groups to restyle.
local function ensure_highlights()
	api.nvim_set_hl(0, "QuickdrawRank1", {
		fg = fg_of({ "DiagnosticError", "ErrorMsg" }, 0xFF5F5F),
		bold = true,
		default = true,
	})
	api.nvim_set_hl(0, "QuickdrawRank2", {
		fg = fg_of({ "DiagnosticWarn", "WarningMsg" }, 0xFFAF00),
		bold = true,
		default = true,
	})
	api.nvim_set_hl(0, "QuickdrawRank3", {
		fg = fg_of({ "DiagnosticInfo", "Function" }, 0x5FAFFF),
		bold = true,
		default = true,
	})
	api.nvim_set_hl(0, "QuickdrawDim", { link = "Comment", default = true })
end

local generation = 0
local timers = {}

local function stop_timers()
	for timer in pairs(timers) do
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		timers[timer] = nil
	end
end

local function clear()
	generation = generation + 1
	stop_timers()
	trail_active = false
	api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

---@param l integer
---@return { c: string, col: integer }[]
local function line_chars(l)
	local out = {}
	local off = 0
	for _, c in ipairs(fn.split(fn.getline(l), "\\zs")) do
		out[#out + 1] = { c = c, col = off }
		off = off + #c
	end
	return out
end

--- Every visible, unfolded character ahead of the cursor, in travel order.
---@param backward boolean
---@return { [1]: integer, [2]: { c: string, col: integer } }[]
local function chars_ahead(backward)
	local cursor = api.nvim_win_get_cursor(0)
	local lnum, col = cursor[1], cursor[2]
	local list = {}
	if not backward then
		for l = lnum, fn.line("w$") do
			if fn.foldclosed(l) == -1 then
				for _, ch in ipairs(line_chars(l)) do
					if l > lnum or ch.col > col then
						list[#list + 1] = { l, ch }
					end
				end
			end
		end
	else
		for l = lnum, fn.line("w0"), -1 do
			if fn.foldclosed(l) == -1 then
				local chars = line_chars(l)
				for i = #chars, 1, -1 do
					local ch = chars[i]
					if l < lnum or ch.col < col then
						list[#list + 1] = { l, ch }
					end
				end
			end
		end
	end
	return list
end

local function paint_dim()
	for l = fn.line("w0"), fn.line("w$") do
		local width = #fn.getline(l)
		if width > 0 then
			api.nvim_buf_set_extmark(0, ns, l - 1, 0, {
				end_col = width,
				hl_group = "QuickdrawDim",
				priority = 200,
			})
		end
	end
end

---@class QuickdrawMark
---@field l integer
---@field col integer
---@field len integer
---@field group string
---@field dist integer Line distance from the cursor

---@param backward boolean
---@return QuickdrawMark[]
local function collect_marks(backward)
	local cursor_line = api.nvim_win_get_cursor(0)[1]
	local counts = {}
	local marks = {}
	for _, item in ipairs(chars_ahead(backward)) do
		local l, ch = item[1], item[2]
		if ch.c ~= " " and ch.c ~= "\t" then
			local n = (counts[ch.c] or 0) + 1
			counts[ch.c] = n
			if n <= 3 then
				marks[#marks + 1] = {
					l = l,
					col = ch.col,
					len = #ch.c,
					group = RANK_GROUPS[n],
					dist = math.abs(l - cursor_line),
				}
			end
		end
	end
	return marks
end

---@param mark QuickdrawMark
local function set_mark(mark)
	api.nvim_buf_set_extmark(0, ns, mark.l - 1, mark.col, {
		end_col = mark.col + mark.len,
		hl_group = mark.group,
		priority = 210,
	})
end

--- Color every reachable character by its occurrence rank: rank 1 lands
--- with `fx`, rank 2 with `2fx`, rank 3 with `3fx`. Whitespace is
--- jumpable but never painted. Everything else dims.
---@param backward boolean
function M._paint(backward)
	clear()
	paint_dim()
	for _, mark in ipairs(collect_marks(backward)) do
		set_mark(mark)
	end
end

local BLOOM_MS_PER_LINE = 7

--- The bloom: dim lands at once with the cursor line's targets, then the
--- ranks sweep outward one line-distance at a time while you hold the
--- key. Any keypress interrupts mid-sweep; typing at speed sees at most
--- one frame.
---@param backward boolean
local function reveal(backward)
	clear()
	local gen = generation
	paint_dim()

	local pending = collect_marks(backward)
	table.sort(pending, function(a, b)
		return a.dist < b.dist
	end)

	local index = 1
	while pending[index] and pending[index].dist == 0 do
		set_mark(pending[index])
		index = index + 1
	end
	vim.cmd("redraw")
	if not pending[index] then
		return
	end

	local uv = vim.uv or vim.loop
	local started = uv.now()
	local timer = assert(uv.new_timer())
	timers[timer] = true
	timer:start(
		16,
		16,
		vim.schedule_wrap(function()
			if gen ~= generation then
				return
			end
			local through = math.floor((uv.now() - started) / BLOOM_MS_PER_LINE)
			while pending[index] and pending[index].dist <= through do
				set_mark(pending[index])
				index = index + 1
			end
			vim.cmd("redraw")
			if not pending[index] then
				if not timer:is_closing() then
					timer:stop()
					timer:close()
				end
				timers[timer] = nil
			end
		end)
	)
end

--- After landing, the nearest occurrences of the character stay lit so
--- `;` and `,` become read decisions instead of blind repeats.
---@param char string
local function paint_trail(char)
	clear()
	for _, backward in ipairs({ false, true }) do
		local n = 0
		for _, item in ipairs(chars_ahead(backward)) do
			local l, ch = item[1], item[2]
			if ch.c == char then
				n = n + 1
				if n > 3 then
					break
				end
				api.nvim_buf_set_extmark(0, ns, l - 1, ch.col, {
					end_col = ch.col + #ch.c,
					hl_group = RANK_GROUPS[n],
					priority = 210,
				})
			end
		end
	end
	trail_active = true
end

---@param char string
---@param backward boolean
---@param count integer
---@return integer|nil lnum, integer|nil col
local function find(char, backward, count)
	local seen = 0
	for _, item in ipairs(chars_ahead(backward)) do
		if item[2].c == char then
			seen = seen + 1
			if seen == count then
				return item[1], item[2].col
			end
		end
	end
end

--- `t` stops beside the character: before it going forward, after it
--- going backward.
---@return integer|nil lnum, integer|nil col
local function adjust_t(l, col, backward, char_len)
	local chars = line_chars(l)
	if not backward then
		local previous = nil
		for _, ch in ipairs(chars) do
			if ch.col == col then
				break
			end
			previous = ch
		end
		if previous then
			return l, previous.col
		end
		return nil
	end
	for _, ch in ipairs(chars) do
		if ch.col == col + char_len then
			return l, ch.col
		end
	end
	return nil
end

--- Execute a jump. Cross-line jumps push the jumplist so <C-o> returns;
--- same-line jumps stay native and do not. Forward jumps in
--- operator-pending mode force inclusion, matching native f/t; backward
--- stays exclusive, matching native F/T.
---@param kind "f"|"t"
---@param backward boolean
---@param char string
---@param count integer
function M.jump(kind, backward, char, count)
	local l, col = find(char, backward, count or 1)
	if not l then
		return
	end
	if kind == "t" then
		l, col = adjust_t(l, col, backward, #char)
		if not l then
			return
		end
	end

	local cursor = api.nvim_win_get_cursor(0)
	if l == cursor[1] and col == cursor[2] then
		return
	end

	local mode = api.nvim_get_mode().mode
	if l ~= cursor[1] and (mode == "n" or mode:sub(1, 2) == "no") then
		vim.cmd("normal! m'")
	end
	-- Forward f/t are inclusive motions; forced motions (dvf, dVf) keep
	-- the user's explicit override.
	if mode == "no" and not backward then
		vim.cmd("normal! v")
	end

	api.nvim_win_set_cursor(0, { l, col })
	last = { kind = kind, backward = backward, char = char }

	if mode == "n" then
		paint_trail(char)
	end
end

--- Redo does not record characters consumed by getchar, so a jump taken
--- directly inside operator-pending mode cannot dot-repeat. Instead the
--- pending operator is allowed to abort and the whole change is re-fed as
--- typed keys through a <Plug> mapping that jumps from cache — typed keys
--- land in the redo register, so `.` replays the entire change natively.
---@param kind "f"|"t"
---@param backward boolean
---@param char string
---@param count integer
local function op_redispatch(kind, backward, char, count)
	pending_op = { kind = kind, backward = backward, char = char }
	local mode = api.nvim_get_mode().mode
	local forced = mode:sub(3)
	local keys = tostring(count) .. '"' .. vim.v.register .. vim.v.operator .. forced .. PLUG
	api.nvim_feedkeys(keys, "t", false)
end

---@param kind "f"|"t"
---@param backward boolean
---@return fun()
local function motion(kind, backward)
	return function()
		local count = vim.v.count1
		local operator_pending = api.nvim_get_mode().mode:sub(1, 2) == "no"
		reveal(backward)

		local ok, char = pcall(fn.getcharstr)
		clear()
		if not ok or char == "" or char == ESC or char == CTRL_C or char:byte(1) == 0x80 then
			return
		end

		if operator_pending then
			op_redispatch(kind, backward, char, count)
			return
		end
		M.jump(kind, backward, char, count)
	end
end

---@param reverse boolean
---@return fun()
local function repeat_last(reverse)
	return function()
		if not last then
			return
		end
		local backward = last.backward
		if reverse then
			backward = not backward
		end
		if api.nvim_get_mode().mode:sub(1, 2) == "no" then
			op_redispatch(last.kind, backward, last.char, vim.v.count1)
			return
		end
		M.jump(last.kind, backward, last.char, vim.v.count1)
	end
end

---@param opts table|nil
function M.setup(opts)
	if opts ~= nil and next(opts) ~= nil then
		error("quickdraw.nvim has no options")
	end

	ensure_highlights()
	api.nvim_create_autocmd("ColorScheme", {
		group = api.nvim_create_augroup("Quickdraw", { clear = true }),
		callback = ensure_highlights,
	})

	vim.keymap.set("o", "<Plug>(quickdraw-op)", function()
		if pending_op then
			M.jump(pending_op.kind, pending_op.backward, pending_op.char, vim.v.count1)
		end
	end, { desc = "Quickdraw operator target" })

	local modes = { "n", "x", "o" }
	vim.keymap.set(modes, "f", motion("f", false), { desc = "Quickdraw f" })
	vim.keymap.set(modes, "F", motion("f", true), { desc = "Quickdraw F" })
	vim.keymap.set(modes, "t", motion("t", false), { desc = "Quickdraw t" })
	vim.keymap.set(modes, "T", motion("t", true), { desc = "Quickdraw T" })
	vim.keymap.set(modes, ";", repeat_last(false), { desc = "Quickdraw repeat" })
	vim.keymap.set(modes, ",", repeat_last(true), { desc = "Quickdraw repeat reversed" })

	-- The trail clears on the first key that is not a repeat.
	vim.on_key(function(key, typed)
		if not trail_active then
			return
		end
		local pressed = (typed and typed ~= "") and typed or key
		if pressed ~= "" and pressed ~= ";" and pressed ~= "," then
			trail_active = false
			vim.schedule(clear)
		end
	end, ns)
end

return M
