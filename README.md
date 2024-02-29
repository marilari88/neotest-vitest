# neotest-vitest

This plugin provides a [Vitest](https://vitest.dev/) adapter for the [Neotest](https://github.com/rcarriga/neotest) framework.

Credits to [neotest-jest](https://github.com/haydenmeade/neotest-jest)

## Known issues

- test.each is currently not well supported (WIP)

## How to install it

### Lazy

```lua
{
  "nvim-neotest/neotest",
  dependencies = {
    ...,
    "marilari88/neotest-vitest",
  },
  config = function()
    require("neotest").setup({
      ...,
      adapters = {
        require("neotest-vitest"),
      }
    })
  end,
}
```

### Packer

```lua
use({
  "nvim-neotest/neotest",
  requires = {
    ...,
    "marilari88/neotest-vitest",
  }
  config = function()
    require("neotest").setup({
      ...,
      adapters = {
        require("neotest-vitest")
      }
    })
  end
})
```

Make sure you have Treesitter installed with the right language parser installed

```
:TSInstall javascript
```

## Configuration
```lua
{
  "nvim-neotest/neotest",
  dependencies = {
    ...,
    "marilari88/neotest-vitest",
  },
  config = function()
    require("neotest").setup({
      ...,
      adapters = {
        require("neotest-vitest") {
          -- Filter directories when searching for test files. Useful in large projects (see Filter directories notes).
          filter_dir = function(name, rel_path, root)
            return name ~= "node_modules"
          end,
        },
      }
    })
  end,
}
```

### Stricter file parsing to determine test files

Use `is_test_file` option to add a custom criteria for test file discovery.

```lua
---Custom criteria for a file path to determine if it is a vitest test file.
---@async
---@param file_path string Path of the potential vitest test file
---@return boolean
is_test_file = function(file_path)
    -- Check if the project is "my-peculiar-project"
    if string.match(file_path, "my-peculiar-project") then
        -- Check if the file path includes something else
        if string.match(file_path, "/myapp/") then
            -- eg. only files in __tests__ are to be considered
            return string.match(file_path, "__tests__")
        end
    end
    return false
end,
```

### Filter directories

Use `filter_dir` option to limit directories to be searched for tests.

```lua
---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
filter_dir = function(name, rel_path, root)
  local full_path = root .. "/" .. rel_path

  if root:match("projects/my-large-monorepo") then
    if full_path:match("^unit_tests") then
      return true
    else
      return false
    end
  else
    return name ~= "node_modules"
  end
end
```

### Watch mode mappings

```lua

vim.api.nvim_set_keymap(
    "n", 
    "<leader>twr", 
    "<cmd>lua require('neotest').run.run({ vitestCommand = 'vitest --watch' })<cr>", 
    {desc = "Run Watch"}
)

vim.api.nvim_set_keymap(
    "n",
    "<leader>twf",
    "<cmd>lua require('neotest').run.run({ vim.fn.expand("%"), vitestCommand = 'vitest --watch' })<cr>",
    {desc = "Run Watch File"}
)

```

## Usage

![usage preview](https://user-images.githubusercontent.com/32909388/185812063-d05d9cc7-b9aa-43ed-915b-cf156e3f0c52.gif)

See neotest's documentation for more information on how to run tests.

## :gift: Contributing

Please raise a PR if you are interested in adding new functionality or fixing any bugs. When submitting a bug, please include an example spec that can be tested.

To trigger the tests for the adapter, run:

```sh
./scripts/test
```

## Bug Reports

Please file any bug reports and I _might_ take a look if time permits otherwise please submit a PR, this plugin is intended to be by the community for the community.
