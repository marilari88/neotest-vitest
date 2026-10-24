local nio = require("nio")

local M = {}
local cache = {}

---Invalidate the runner's file lists without changing Neotest's running state.
function M.refresh()
  cache = {}
end

---Ask Vitest to evaluate its own include/exclude and workspace configuration.
---@async
---@param path string
---@param context table
---@return boolean
function M.contains(path, context)
  local command = vim.split(context.command, "%s+")
  vim.list_extend(command, { "list", "--filesOnly", "--json", "--watch=false" })
  if context.config then
    table.insert(command, "--config=" .. context.config)
  end
  local key = vim.inspect({ command, context.cwd, context.env })
  local entry = cache[key]
  if not entry then
    entry = { ready = nio.control.future() }
    cache[key] = entry
    local ok, files = pcall(function()
      local result = nio.control.future()
      vim.system(command, { cwd = context.cwd, env = context.env, text = true, timeout = 60000 }, function(output)
        result.set(output)
      end)
      local output = result.wait()
      nio.scheduler()
      assert(output.code == 0, "Vitest file discovery failed: " .. (output.stderr or ""))
      local report = vim.json.decode(output.stdout)
      assert(type(report) == "table" and vim.islist(report), "Invalid Vitest file list")
      local discovered = {}
      for _, file in ipairs(report) do
        local name = type(file) == "string" and file or file.file
        assert(type(name) == "string", "Invalid Vitest file entry")
        local absolute = name:sub(1, 1) == "/" and name or context.cwd .. "/" .. name
        discovered[vim.fs.normalize(vim.fn.fnamemodify(absolute, ":p"))] = true
      end
      return discovered
    end)
    entry.files = ok and files or {}
    entry.error = not ok and files or nil
    entry.ready.set()
  else
    entry.ready.wait()
    nio.scheduler()
  end
  -- A failed list must not fall back to filename heuristics and claim another
  -- runner's tests. Keep the error cached until an explicit refresh.
  if entry.error then
    error(entry.error)
  end
  return entry.files[vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))] == true
end

return M
