local async = require("nio").tests
local Tree = require("neotest.types").Tree
local plugin = require("neotest-vitest")({
  vitestCommand = "vitest",
})
require("neotest-vitest-assertions")
A = function(...)
  print(vim.inspect(...))
end

describe("adapter enabled", function()
  async.it("vitest simple repo", function()
    assert.Not.Nil(plugin.root("./spec"))
  end)

  async.it("disable adapter no package.json", function()
    assert.Nil(plugin.root("."))
  end)

  async.it("enable adapter for monorepo with vitest at root", function()
    assert.Not.Nil(plugin.root("./spec-monorepo"))
  end)
end)

describe("is_test_file", function()
  async.it("matches vitest files", function()
    assert.is.truthy(plugin.is_test_file("./spec/basic.test.ts"))
  end)

  async.it("does not match plain js files", function()
    assert.is.falsy(plugin.is_test_file("./index.ts"))
  end)

  async.it("does not match file name ending with test", function()
    assert.is.falsy(plugin.is_test_file("./setupVitest.ts"))
  end)

  async.it("does not match test in repo with jest", function()
    assert.is.falsy(plugin.is_test_file("./spec-jest/basic.test.ts"))
  end)

  async.it("matches vitest files in monorepo", function()
    assert.is.truthy(plugin.is_test_file("./spec-monorepo/packages/example/basic.test.ts"))
    assert.is.truthy(plugin.is_test_file("./spec-monorepo/apps/todo/todo.test.tsx"))
  end)
end)

describe("discover_positions", function()
  async.it("provides meaningful names from a basic spec", function()
    local positions = plugin.discover_positions("./spec/basic.test.ts"):to_list()

    local expected_output = {
      {
        name = "basic.test.ts",
        type = "file",
      },
      {
        {
          name = "describe text",
          type = "namespace",
        },
        {
          {
            name = "1",
            type = "test",
          },
          {
            name = "2",
            type = "test",
          },
          {
            name = "3",
            type = "test",
          },
          {
            name = "4",
            type = "test",
          },
        },
      },
    }

    assert.equals(expected_output[1].name, positions[1].name)
    assert.equals(expected_output[1].type, positions[1].type)
    assert.equals(expected_output[2][1].name, positions[2][1].name)
    assert.equals(expected_output[2][1].type, positions[2][1].type)

    assert.equals(5, #positions[2])
    for i, value in ipairs(expected_output[2][2]) do
      assert.is.truthy(value)
      local position = positions[2][i + 1][1]
      assert.is.truthy(position)
      assert.equals(value.name, position.name)
      assert.equals(value.type, position.type)
    end
  end)

  async.it("provides meaningful names for array driven tests", function()
    local positions = plugin.discover_positions("./spec/array.test.ts"):to_list()

    local expected_output = {
      {
        name = "array.test.ts",
        type = "file",
      },
      {
        {
          name = "describe text",
          type = "namespace",
        },
        {
          {
            name = "Array1",
            type = "test",
          },
          {
            name = "Array2",
            type = "test",
          },
          {
            name = "Array3",
            type = "test",
          },
          {
            name = "Array4",
            type = "test",
          },
        },
      },
    }

    assert.equals(expected_output[1].name, positions[1].name)
    assert.equals(expected_output[1].type, positions[1].type)
    assert.equals(expected_output[2][1].name, positions[2][1].name)
    assert.equals(expected_output[2][1].type, positions[2][1].type)
    assert.equals(5, #positions[2])
    for i, value in ipairs(expected_output[2][2]) do
      assert.is.truthy(value)
      local position = positions[2][i + 1][1]
      assert.is.truthy(position)
      assert.equals(value.name, position.name)
      assert.equals(value.type, position.type)
    end
  end)
end)

describe("build_spec", function()
  async.it("builds command for file test", function()
    local positions = plugin.discover_positions("./spec/basic.test.ts"):to_list()
    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)
    local spec = plugin.build_spec({ tree = tree })

    assert.is.truthy(spec)
    local command = spec.command
    assert.is.truthy(command)
    assert.contains(command, "vitest")
    assert.contains(command, "--run")
    assert.contains(command, "--reporter=verbose")
    assert.contains(command, "--testNamePattern=.*")
    assert.contains(command, "--config=./spec/vite.config.ts")
    assert.contains(command, "./spec/basic.test.ts")
    assert.is.truthy(spec.context.file)
    assert.is.truthy(spec.context.results_path)
  end)

  async.it("builds command for namespace", function()
    local positions = plugin.discover_positions("./spec/basic.test.ts"):to_list()

    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)

    local spec = plugin.build_spec({ tree = tree:children()[1] })

    assert.is.truthy(spec)
    local command = spec.command
    assert.is.truthy(command)
    assert.contains(command, "vitest")
    assert.contains(command, "--run")
    assert.contains(command, "--reporter=verbose")
    assert.contains(command, "--testNamePattern=^ describe text")
    assert.contains(command, "--config=./spec/vite.config.ts")
    assert.contains(command, "./spec/basic.test.ts")
    assert.is.truthy(spec.context.file)
    assert.is.truthy(spec.context.results_path)
  end)

  async.it("uses vite config", function()
    local positions = plugin.discover_positions("./spec/config/vite/basic.test.ts"):to_list()

    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)

    local spec = plugin.build_spec({ tree = tree:children()[1] })

    assert.is.truthy(spec)
    local command = spec.command
    assert.is.truthy(command)
    assert.contains(command, "--config=./spec/config/vite/vite.config.ts")
  end)

  async.it("uses vitest config over vite config", function()
    local positions = plugin.discover_positions("./spec/config/vitest/basic.test.ts"):to_list()

    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)

    local spec = plugin.build_spec({ tree = tree:children()[1] })

    assert.is.truthy(spec)
    local command = spec.command
    assert.is.truthy(command)
    assert.contains(command, "--config=./spec/config/vitest/vitest.config.ts")
  end)
end)
