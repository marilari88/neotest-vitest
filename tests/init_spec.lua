local async = require("nio").tests
local Tree = require("neotest.types").Tree

---@type neotest.Adapter
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

  async.it("enable adapter for monorepo with vitest in workspace package", function()
    assert.Not.Nil(plugin.root("./spec-monorepo-no-root-dep"))
  end)
end)

describe("is_test_file", function()
  local original_dir
  before_each(function()
    original_dir = vim.api.nvim_eval("getcwd()")
  end)

  after_each(function()
    vim.api.nvim_set_current_dir(original_dir)
  end)

  async.it("matches vitest files", function()
    vim.api.nvim_set_current_dir("./spec")
    assert.is.truthy(plugin.is_test_file("./spec/basic.test.ts"))
  end)

  async.it("does not match plain js files", function()
    assert.is.falsy(plugin.is_test_file("./index.ts"))
  end)

  async.it("does not match file name ending with test", function()
    assert.is.falsy(plugin.is_test_file("./setupVitest.ts"))
  end)

  async.it("does not match test in repo with jest", function()
    vim.api.nvim_set_current_dir("./spec-jest")
    assert.is.falsy(plugin.is_test_file("./basic.test.ts"))
  end)

  async.it("matches vitest files in monorepo", function()
    vim.api.nvim_set_current_dir("./spec-monorepo")
    assert.is.truthy(plugin.is_test_file("./packages/example/basic.test.ts"))
  end)

  async.it("Matches vitest files in monorepo with vitest in workspace package", function()
    vim.api.nvim_set_current_dir("./spec-monorepo-no-root-dep")
    assert.is.truthy(plugin.is_test_file("./packages/example/basic.test.ts"))
    -- This is a test file but the example-no-vitest package does not have vitest
    -- It should still match because vitest is required by the "example" package
    -- and vitest is therefore available in the monorepo.
    -- Commenting out the final line in init.lua:hasVitestDependency causes this test to fail.
    assert.is.truthy(plugin.is_test_file("./packages/example-no-vitest/basic.test.ts"))
  end)
end)

describe("discover_positions", function()
  local function discover_positions(file_path)
    local positions = plugin.discover_positions(file_path):to_list()
    local function remove_range(obj)
      local islist = vim.islist or vim.tbl_islist
      if islist(obj) then
        vim.tbl_map(remove_range, obj)
      else
        obj["range"] = nil
      end
    end
    remove_range(positions)
    return positions
  end
  async.it("provides meaningful names from a basic spec", function()
    local positions = discover_positions("./spec/basic.test.ts")
    local expected_output = {
      {
        id = "./spec/basic.test.ts",
        name = "basic.test.ts",
        path = "./spec/basic.test.ts",
        type = "file",
      },
      {
        {
          id = "./spec/basic.test.ts::describe arrow function",
          name = "describe arrow function",
          path = "./spec/basic.test.ts",
          type = "namespace",
        },
        {
          {
            id = "./spec/basic.test.ts::describe arrow function::foo",
            name = "foo",
            path = "./spec/basic.test.ts",
            type = "test",
          },
        },
        {
          {
            id = "./spec/basic.test.ts::describe arrow function::bar(error)",
            name = "bar(error)",
            path = "./spec/basic.test.ts",
            type = "test",
          },
        },
      },
      {
        {
          id = "./spec/basic.test.ts::describe vanilla function",
          name = "describe vanilla function",
          path = "./spec/basic.test.ts",
          type = "namespace",
        },
        {
          {
            id = "./spec/basic.test.ts::describe vanilla function::foo",
            name = "foo",
            path = "./spec/basic.test.ts",
            type = "test",
          },
        },
        {
          {
            id = "./spec/basic.test.ts::describe vanilla function::bar",
            name = "bar",
            path = "./spec/basic.test.ts",
            type = "test",
          },
        },
      },
    }
    assert.is.same(expected_output, positions)
  end)

  async.it("provides meaningful names for array driven tests", function()
    local positions = discover_positions("./spec/array.test.ts")
    local expected_output = {
      {
        id = "./spec/array.test.ts",
        name = "array.test.ts",
        path = "./spec/array.test.ts",
        type = "file",
      },
      {
        {
          id = "./spec/array.test.ts::describe text",
          name = "describe text",
          path = "./spec/array.test.ts",
          type = "namespace",
        },
        {
          {
            id = "./spec/array.test.ts::describe text::Array1",
            name = "Array1",
            path = "./spec/array.test.ts",
            type = "test",
          },
        },
        {
          {
            id = "./spec/array.test.ts::describe text::Array2",
            name = "Array2",
            path = "./spec/array.test.ts",
            type = "test",
          },
        },
        {
          {
            id = "./spec/array.test.ts::describe text::Array3",
            name = "Array3",
            path = "./spec/array.test.ts",
            type = "test",
          },
        },
        {
          {
            id = "./spec/array.test.ts::describe text::Array4",
            name = "Array4",
            path = "./spec/array.test.ts",
            type = "test",
          },
        },
      },
    }
    assert.is.same(expected_output, positions)
  end)
end)

describe("build_spec", function()
  local raw_tempname
  before_each(function()
    raw_tempname = require("neotest.async").fn.tempname
    require("neotest.async").fn.tempname = function()
      return "/tmp/foo"
    end
  end)
  after_each(function()
    require("neotest.async").fn.tempname = raw_tempname
  end)

  describe("test name pattern", function()
    async.it("file level", function()
      local positions = plugin.discover_positions("./spec/nested.test.ts"):to_list()
      local tree = Tree.from_list(positions, function(pos)
        return pos.id
      end)
      local spec = plugin.build_spec({ tree = tree })
      local command = spec.command
      assert.contains(spec.command, "--testNamePattern=.*")
    end)
    async.it("first level", function()
      local positions = plugin.discover_positions("./spec/nested.test.ts"):to_list()
      local tree = Tree.from_list(positions, function(pos)
        return pos.id
      end)
      local spec = plugin.build_spec({ tree = tree:children()[1] })
      assert.contains(spec.command, "--testNamePattern=^\\s?first\\slevel")
    end)
    async.it("second level", function()
      local positions = plugin.discover_positions("./spec/nested.test.ts"):to_list()
      local tree = Tree.from_list(positions, function(pos)
        return pos.id
      end)
      local spec = plugin.build_spec({ tree = tree:children()[1]:children()[1] })
      assert.contains(spec.command, "--testNamePattern=^\\s?first\\slevel\\ssecond\\slevel")
    end)
    async.it("test level", function()
      local positions = plugin.discover_positions("./spec/nested.test.ts"):to_list()
      local tree = Tree.from_list(positions, function(pos)
        return pos.id
      end)
      local spec = plugin.build_spec({ tree = tree:children()[1]:children()[1]:children()[1] })
      assert.contains(spec.command, "--testNamePattern=^\\s?first\\slevel\\ssecond\\slevel\\sfoo$")
    end)
    async.it("test level 2", function()
      local positions = plugin.discover_positions("./spec/nested.test.ts"):to_list()
      local tree = Tree.from_list(positions, function(pos)
        return pos.id
      end)
      local spec = plugin.build_spec({ tree = tree:children()[1]:children()[1]:children()[2] })
      assert.contains(
        spec.command,
        "--testNamePattern=^\\s?first\\slevel\\ssecond\\slevel\\sbar\\(error\\)$"
      )
    end)
  end)

  async.it("builds command for file test", function()
    local positions = plugin.discover_positions("./spec/basic.test.ts"):to_list()
    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)
    local spec = plugin.build_spec({ tree = tree })
    assert.is.truthy(spec)
    local expected_command = {
      "vitest",
      "--config=./spec/vite.config.ts",
      "--watch=false",
      "--reporter=verbose",
      "--reporter=json",
      "--outputFile=/tmp/foo.json",
      "--testNamePattern=.*",
      -- "spec/basic.test.ts",
    }
    assert.is.same(expected_command, vim.list_slice(spec.command, 0, #spec.command - 1))
    assert.is.truthy(spec.context.file)
    assert.is.truthy(spec.context.results_path)
  end)

  async.it("builds command passed vitest command ", function()
    local positions = plugin.discover_positions("./spec/basic.test.ts"):to_list()
    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)
    local spec = plugin.build_spec({ vitestCommand = "vitest --watch", tree = tree })

    assert.is.truthy(spec)
    local expected_command = {
      "vitest",
      "--watch",
      "--config=./spec/vite.config.ts",
      "--watch=false",
      "--reporter=verbose",
      "--reporter=json",
      "--outputFile=/tmp/foo.json",
      "--testNamePattern=.*",
      -- "spec/basic.test.ts",
    }
    assert.is.same(expected_command, vim.list_slice(spec.command, 0, #spec.command - 1))
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
    local expected_command = {
      "vitest",
      "--config=./spec/vite.config.ts",
      "--watch=false",
      "--reporter=verbose",
      "--reporter=json",
      "--outputFile=/tmp/foo.json",
      "--testNamePattern=^\\s?describe\\sarrow\\sfunction",
      -- "spec/basic.test.ts",
    }
    assert.is.same(expected_command, vim.list_slice(spec.command, 0, #spec.command - 1))
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
    local expected_command = {
      "vitest",
      "--config=./spec/config/vite/vite.config.ts",
      "--watch=false",
      "--reporter=verbose",
      "--reporter=json",
      "--outputFile=/tmp/foo.json",
      "--testNamePattern=^\\s?1$",
      -- "spec/config/vite/basic.test.ts",
    }
    assert.is.same(expected_command, vim.list_slice(spec.command, 0, #spec.command - 1))
    assert.is.truthy(spec.context.file)
    assert.is.truthy(spec.context.results_path)
  end)

  async.it("uses vitest config over vite config", function()
    local positions = plugin.discover_positions("./spec/config/vitest/basic.test.ts"):to_list()

    local tree = Tree.from_list(positions, function(pos)
      return pos.id
    end)

    local spec = plugin.build_spec({ tree = tree:children()[1] })

    assert.is.truthy(spec)
    local expected_command = {
      "vitest",
      "--config=./spec/config/vitest/vitest.config.ts",
      "--watch=false",
      "--reporter=verbose",
      "--reporter=json",
      "--outputFile=/tmp/foo.json",
      "--testNamePattern=^\\s?1$",
      -- "spec/config/vitest/basic.test.ts",
    }
    assert.is.same(expected_command, vim.list_slice(spec.command, 0, #spec.command - 1))
    assert.is.truthy(spec.context.file)
    assert.is.truthy(spec.context.results_path)
  end)
end)
