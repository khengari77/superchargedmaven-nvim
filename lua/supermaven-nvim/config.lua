local default_config = {
  keymaps = {
    accept_suggestion = "<Tab>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = {},
  disable_inline_completion = false,
  disable_keymaps = false,
  condition = function()
    return false
  end,
  log_level = "info",
}

local M = {}

M.config = vim.deepcopy(default_config)

-- This is the new state table for our dynamic rules.
M.state = {
  -- e.g., { ["/path/to/project"] = false } means denied.
  context_permissions = {},
}

M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.config), args or {})
end

---Checks if a given file path is allowed based on user context rules.
---It checks the path and all its parent directories. The most specific rule wins.
---@param file_path string The full path of the file to check.
---@return boolean: true if allowed, false if explicitly denied.
function M.is_path_allowed(file_path)
  if not file_path or file_path == "" then
    return false
  end

  local path_to_check = file_path
  -- Default to allowed unless a rule says otherwise.
  local permission = true

  while path_to_check and path_to_check ~= "" and path_to_check ~= "/" do
    local p_status = M.state.context_permissions[path_to_check]
    if p_status ~= nil then
      -- A rule exists for this path. This is the most specific rule we've found
      -- so far, so it wins. We break to not check less specific parent dirs.
      permission = p_status
      break
    end
    -- Move to the parent directory
    path_to_check = vim.fn.fnamemodify(path_to_check, ":h")
  end

  return permission
end

return M
