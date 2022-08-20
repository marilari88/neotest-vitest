local async = require("plenary.async.tests")
local Tree = require("neotest.types").Tree
require("neotest-jest-assertions")
A = function(...)
  print(vim.inspect(...))
end

local binary_override = function()
  return "mybinaryoverride"
end
local config_override = function()
  return "./spec/jest.config.ts"
end

describe("build_spec with override", function()
  async.it("builds command", function()
    local plugin = require("neotest-jest")({
      jestCommand = binary_override,
      jestConfigFile = config_override,
      env = { override = "override", adapter_override = true },
    })

    local positions = plugin.discover_positions("./spec/basic.test.ts"):to_list()
    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)
    local spec = plugin.build_spec({ nil, { env = { spec_override = true } }, tree = tree })

    assert.is.truthy(spec)

    local command = spec.command
    assert.is.truthy(command)
    assert.contains(command, binary_override())
    assert.contains(command, "--json")
    assert.contains(command, "--config=" .. config_override())
    assert.contains(command, "--testNamePattern='.*'")
    assert.contains(command, "./spec/basic.test.ts")
    assert.is.truthy(spec.context.file)
    assert.is.truthy(spec.context.results_path)
    assert.is.same(
      spec.env,
      { override = "override", adapter_override = true, spec_override = true }
    )
  end)
end)
