-- lua/supermaven-nvim/context_manager.lua

local api = vim.api
local config = require("supermaven-nvim.config")

local M = {}

local state = {
  win_id = nil,
  buf_id = nil,
  paths = {}, -- Store the paths displayed in the window to map line numbers to paths
}

-- Redraws the content of the management window
local function redraw_buffer()
  if not state.buf_id or not api.nvim_buf_is_valid(state.buf_id) then
    return
  end

  api.nvim_buf_set_option(state.buf_id, "modifiable", true)

  local header_lines = {
    "Supermaven Context Manager",
    "==========================",
    "Press <Enter> on a path to toggle its permission.",
    "✓ = Allowed, ✗ = Denied. The most specific rule wins.",
    "Press 'q' or <Esc> to close.",
    "", -- Spacer
  }

  local content_lines = {}
  state.paths = {} -- Reset the list of paths for this redraw

  local current_file = api.nvim_buf_get_name(0)
  if current_file == "" then
    table.insert(content_lines, "No file open to manage.")
  else
    local path_to_scan = current_file
    while path_to_scan and path_to_scan ~= "" and path_to_scan ~= "/" do
      table.insert(state.paths, 1, path_to_scan) -- Add to front to keep correct order
      path_to_scan = vim.fn.fnamemodify(path_to_scan, ":h")
    end
  end

  for _, path in ipairs(state.paths) do
    local is_allowed = config.is_path_allowed(path)
    local status_icon = is_allowed and "✓" or "✗"
    table.insert(content_lines, string.format("[%s] %s", status_icon, path))
  end

  local all_lines = vim.list_extend(header_lines, content_lines)
  api.nvim_buf_set_lines(state.buf_id, 0, -1, false, all_lines)

  -- Apply syntax highlighting to the status icons
  local header_offset = #header_lines
  for i, _ in ipairs(state.paths) do
    local path = state.paths[i]
    local is_allowed = config.is_path_allowed(path)
    local highlight_group = is_allowed and "DiffAdd" or "DiffDelete"
    -- Line numbers are 1-based.
    api.nvim_buf_add_highlight(state.buf_id, -1, highlight_group, header_offset + i - 1, 1, 2)
  end

  api.nvim_buf_set_option(state.buf_id, "modifiable", false)
end

-- Called when <Enter> is pressed in the window
local function toggle_permission()
  local line_num = api.nvim_win_get_cursor(0)[1]
  local header_offset = 6
  -- Calculate index into our paths table
  local path_index = line_num - header_offset

  if path_index >= 0 and path_index < #state.paths then
    local path = state.paths[path_index + 1]
    -- Toggle the permission. If it doesn't exist (nil), it inherits.
    -- To toggle, we read the *current* state (which could be inherited) and set the opposite.
    local current_permission = config.is_path_allowed(path)
    config.state.context_permissions[path] = not current_permission

    redraw_buffer()
    api.nvim_win_set_cursor(0, { line_num, 0 }) -- Keep cursor position
  end
end

function M.open()
  if state.win_id and api.nvim_win_is_valid(state.win_id) then
    api.nvim_set_current_win(state.win_id)
    return
  end

  state.buf_id = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(state.buf_id, "filetype", "supermaven-context")

  local width = math.max(80, math.floor(api.nvim_get_option("columns") * 0.7))
  local height = math.max(10, math.floor(api.nvim_get_option("lines") * 0.5))
  local row = math.floor((api.nvim_get_option("lines") - height) / 2)
  local col = math.floor((api.nvim_get_option("columns") - width) / 2)

  state.win_id = api.nvim_open_win(state.buf_id, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.keymap.set("n", "<Enter>", toggle_permission, { buffer = state.buf_id, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", function() api.nvim_win_close(state.win_id, true) end, { buffer = state.buf_id, nowait = true, silent = true })
  vim.keymap.set("n", "q", function() api.nvim_win_close(state.win_id, true) end, { buffer = state.buf_id, nowait = true, silent = true })

  redraw_buffer()
end

return M
