local async = require("nio").tests
local discovery = require("neotest-vitest.discovery")

describe("configured file discovery", function()
  local system
  local calls
  before_each(function()
    discovery.refresh()
    system = vim.system
    calls = {}
    vim.system = function(command, options, callback)
      table.insert(calls, { command = command, options = options })
      callback({ code = 0, stdout = '[{"file":"component.test.tsx"},{"file":"custom.check.ts"}]' })
    end
  end)
  after_each(function()
    vim.system = system
  end)

  async.it("uses the runner's file list instead of test suffixes", function()
    local context = { command = "vitest", cwd = vim.fn.getcwd(), config = "vite.config.ts", env = { TEST_MODE = "fixture" } }
    assert.is_true(discovery.contains(context.cwd .. "/component.test.tsx", context))
    assert.is_true(discovery.contains(context.cwd .. "/custom.check.ts", context))
    assert.is_false(discovery.contains(context.cwd .. "/journey.test.ts", context))
    assert.equals(1, #calls)
    assert.same({ "vitest", "list", "--filesOnly", "--json", "--watch=false", "--config=vite.config.ts" }, calls[1].command)
    assert.same(context.env, calls[1].options.env)
  end)

  async.it("separates configurations and supports explicit refresh", function()
    local context = { command = "vitest", cwd = vim.fn.getcwd() }
    discovery.contains("journey.test.ts", context)
    context.config = "other.config.ts"
    discovery.contains("journey.test.ts", context)
    assert.equals(2, #calls)
    discovery.refresh()
    discovery.contains("journey.test.ts", context)
    assert.equals(3, #calls)
  end)

  async.it("reports a failed list without claiming tests or retrying every file", function()
    vim.system = function(_, _, callback)
      table.insert(calls, true)
      callback({ code = 1, stderr = "Unsupported list command" })
    end
    local context = { command = "vitest", cwd = vim.fn.getcwd() }
    assert.has_error(function() discovery.contains("journey.test.ts", context) end)
    assert.has_error(function() discovery.contains("component.test.tsx", context) end)
    assert.equals(1, #calls)
  end)
end)
