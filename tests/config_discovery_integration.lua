-- Run with Neovim's adapter dependencies on runtimepath and a modern Vitest:
-- VITEST_BINARY=/path/to/vitest nvim --headless -u NONE \
--   '+set rtp^=.' '+luafile tests/config_discovery_integration.lua' +qa
local nio = require("nio")
local discovery = require("neotest-vitest.discovery")
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/excluded", "p")
local function write(name, contents)
  vim.fn.writefile(vim.split(contents, "\n"), root .. "/" .. name)
end
write("package.json", '{"type":"module"}')
write("vite.config.mjs", 'export default { test: { include: ["**/*.test.tsx", "**/*.check.ts"], exclude: ["**/excluded/**"] } }')
write("component.test.tsx", "throw new Error('File listing must not collect tests')")
write("custom.check.ts", "throw new Error('File listing must not collect tests')")
write("excluded/ignored.test.tsx", "throw new Error('Excluded')")
write("journey.test.ts", "throw new Error('Belongs to another runner')")
local done, failure = false, nil
nio.run(function()
  local ok, err = pcall(function()
    local context = { command = assert(vim.env.VITEST_BINARY), cwd = root, config = root .. "/vite.config.mjs" }
    assert(discovery.contains(root .. "/component.test.tsx", context))
    assert(discovery.contains(root .. "/custom.check.ts", context))
    assert(not discovery.contains(root .. "/journey.test.ts", context))
    assert(not discovery.contains(root .. "/excluded/ignored.test.tsx", context))
    write("vite.config.mjs", 'export default { test: { include: ["**/*.test.ts"] } }')
    discovery.refresh()
    assert(discovery.contains(root .. "/journey.test.ts", context))
    assert(not discovery.contains(root .. "/component.test.tsx", context))
  end)
  failure = not ok and err or nil
  done = true
end)
assert(vim.wait(120000, function() return done end), "Integration timed out")
vim.fn.delete(root, "rf")
assert(not failure, failure)
print("Real Vitest config discovery integration passed")
