---@diagnostic disable: undefined-field
local async = require("neotest.async")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local util = require("neotest-vitest.util")

---@class neotest.VitestOptions
---@field vitestCommand? string|fun(): string
---@field vitestConfigFile? string|fun(): string
---@field env? table<string, string>|fun(): table<string, string>
---@field cwd? string|fun(): string

---@type neotest.Adapter
local adapter = { name = "neotest-vitest" }

adapter.root = lib.files.match_root_pattern("package.json")

---@param file_path? string
---@return boolean
function adapter.is_test_file(file_path)
  if file_path == nil then
    return false
  end

  if string.match(file_path, "__tests__") then
    return true
  end

  for _, x in ipairs({ "spec", "test" }) do
    for _, ext in ipairs({ "js", "jsx", "coffee", "ts", "tsx" }) do
      if string.match(file_path, x .. "%." .. ext .. "$") then
        return true
      end
    end
  end

  return false
end

---@param s string
---@param boolean
local function isTemplateLiteral(s)
  return string.sub(s, 1, 1) == "`"
end

---@param s string
---@param string
local function getStringFromTemplateLiteral(s)
  local matched = string.match(s, "^`(.*)`$")
  if not matched then
    return s
  end
  return (
    matched
      :gsub("%${.*}", ".*") -- template literal ${var}
      :gsub("%%s", "\\w*") -- test each %s string param
      :gsub("%%i", "\\d*") -- test each %i integer param
      :gsub("%%d", ".*") -- test each %d number param
      :gsub("%%f", ".*") -- test each %f float param
      :gsub("%%j", ".*") -- test each %j json param
      :gsub("%%o", ".*") -- test each %o object param
      :gsub("%%#", "\\d*") -- test each %# index param
  )
end

---@async
---@return neotest.Tree | nil
function adapter.discover_positions(path)
  local query = [[
    ; -- Namespaces --
    ; Matches: `describe('context')`
    ((call_expression
      function: (identifier) @func_name (#eq? @func_name "describe")
      arguments: (arguments [(template_string) @namespace.name (string (string_fragment) @namespace.name)]  [(arrow_function) (function)])
    )) @namespace.definition
    ; Matches: `describe.only('context')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "describe")
      )
      arguments: (arguments [(template_string) @namespace.name (string (string_fragment) @namespace.name)]  [(arrow_function) (function)])
    )) @namespace.definition
    ; Matches: `describe.each(['data'])('context')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "describe")
        )
      )
      arguments: (arguments [(template_string) @namespace.name (string (string_fragment) @namespace.name)]  [(arrow_function) (function)])
    )) @namespace.definition

    ; -- Tests --
    ; Matches: `test('test') / it('test')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "it" "test")
      arguments: (arguments [(template_string) @test.name (string (string_fragment) @test.name)]  [(arrow_function) (function)])
    )) @test.definition
    ; Matches: `test.only('test') / it.only('test')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "test" "it")
      )
      arguments: (arguments [(template_string) @test.name (string (string_fragment) @test.name)]  [(arrow_function) (function)])
    )) @test.definition
    ; Matches: `test.each(['data'])('test') / it.each(['data'])('test')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "it" "test")
        )
      )
      arguments: (arguments [(template_string) @test.name (string (string_fragment) @test.name)]  [(arrow_function) (function)])
    )) @test.definition
  ]]

  local parsedTree = lib.treesitter.parse_positions(path, query, { nested_tests = true })

  -- trovare il nodo da aggiornare
  -- creare un nuovo nodo con la nuova chiave (verificare la posizione del nodo)
  -- recuperare il parent
  -- aggiornare il children del padre
  -- cancellare vecchio nodo
  for _, node in parsedTree:iter_nodes() do
    if #node:children() > 0 then
      for _, pos in node:iter_nodes() do
        if pos:data().type == "test" then
          local test = pos:data()
          if isTemplateLiteral(test.name) then
            local testNode = parsedTree:get_key(test.id)
            local originalId = test.id
            if not testNode then
              return
            end
            local parent = testNode:parent()
            if not parent then
              return
            end

            test.name = getStringFromTemplateLiteral(test.name)
            test.id = test.path .. "::" .. test.name
            print(getStringFromTemplateLiteral("`ciao belli ${fa}`"))
            print(test.id)

            --[[ vim.pretty_print(parent) ]]
            --[[ vim.pretty_print(parent._children) ]]
            --[[ vim.pretty_print(parent._children[1]) ]]
            for i, child in pairs(parent._children) do
              if originalId == child:data().id then
                parent._children[i]:data().id = test.id
              end
            end
            testNode._parent = parent
          end
        end
      end
    end
  end

  return parsedTree
end

---@param path string
---@return string
local function getVitestCommand(path)
  local rootPath = util.find_node_modules_ancestor(path)
  local vitestBinary = util.path.join(rootPath, "node_modules", ".bin", "vitest")

  if util.path.exists(vitestBinary) then
    return vitestBinary
  end

  return "vitest"
end

local vitestConfigPattern = util.root_pattern("vitest.config.{js,ts}")

---@param path string
---@return string|nil
local function getVitestConfig(path)
  local rootPath = vitestConfigPattern(path)

  if not rootPath then
    return nil
  end

  local vitestJs = util.path.join(rootPath, "vitest.config.js")
  local vitestTs = util.path.join(rootPath, "vitest.config.ts")

  if util.path.exists(vitestTs) then
    return vitestTs
  end

  return vitestJs
end

---@param s string
---@param string
local function prepareTestPattern(s)
  return (
    s
      :gsub("%(", "%\\(")
      :gsub("%)", "%\\)")
      :gsub("%]", "%\\]")
      :gsub("%[", "%\\[")
      :gsub("%+", "%\\+")
      :gsub("%-", "%\\-")
      :gsub("%?", "%\\?")
      :gsub("%$", "%\\$")
      :gsub("%^", "%\\^")
      :gsub("%/", "%\\/")
  )
end

local function get_strategy_config(strategy, command)
  local config = {
    dap = function()
      return {
        name = "Debug Vitest Tests",
        type = "pwa-node",
        request = "launch",
        args = { unpack(command, 2) },
        runtimeExecutable = command[1],
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
      }
    end,
  }
  if config[strategy] then
    return config[strategy]()
  end
end

local function getEnv(specEnv)
  return specEnv
end

---@param path string
---@return string|nil
local function getCwd(path)
  return nil
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function adapter.build_spec(args)
  local results_path = async.fn.tempname() .. ".json"
  local tree = args.tree

  if not tree then
    return
  end

  local pos = args.tree:data()
  local testNamePattern = ".*"

  if pos.type == "test" then
    testNamePattern = prepareTestPattern(pos.name) .. "$"
  end

  if pos.type == "namespace" then
    testNamePattern = "^ " .. prepareTestPattern(pos.name)
  end

  local binary = getVitestCommand(pos.path)
  local config = getVitestConfig(pos.path) or "vitest.config.js"
  local command = vim.split(binary, "%s+")
  if util.path.exists(config) then
    -- only use config if available
    table.insert(command, "--config=" .. config)
  end

  vim.list_extend(command, {
    "--run",
    "--reporter=verbose",
    "--reporter=json",
    "--outputFile=" .. results_path,
    "--testNamePattern=" .. testNamePattern .. "",
    pos.path,
  })

  return {
    command = command,
    cwd = getCwd(pos.path),
    context = {
      results_path = results_path,
      file = pos.path,
    },
    strategy = get_strategy_config(args.strategy, command),
    env = getEnv(args[2] and args[2].env or {}),
  }
end

local function cleanAnsi(s)
  return s:gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+m", "")
    :gsub("\x1b%[%d+m", "")
end

local function findErrorPosition(file, errStr)
  -- Look for: /path/to/file.js:123:987
  local regexp = file:gsub("([^%w])", "%%%1") .. "%:(%d+)%:(%d+)"
  local _, _, errLine, errColumn = string.find(errStr, regexp)

  return errLine, errColumn
end

local function parsed_json_to_results(data, output_file, consoleOut)
  local tests = {}

  for _, testResult in pairs(data.testResults) do
    local testFn = testResult.name

    for _, assertionResult in pairs(testResult.assertionResults) do
      local status, name = assertionResult.status, assertionResult.title

      if name == nil then
        logger.error("Failed to find parsed test result ", assertionResult)
        return {}
      end

      local keyid = testFn

      for _, value in ipairs(assertionResult.ancestorTitles) do
        if value ~= "" then
          keyid = keyid .. "::" .. value
        end
      end

      keyid = keyid .. "::" .. name

      if status == "pending" then
        status = "skipped"
      end

      if status ~= "skipped" then
        tests[keyid] = {
          status = status,
          short = name .. ": " .. status,
          output = consoleOut,
          location = assertionResult.location,
        }
      end

      if not vim.tbl_isempty(assertionResult.failureMessages) then
        local errors = {}

        for i, failMessage in ipairs(assertionResult.failureMessages) do
          local msg = cleanAnsi(failMessage)
          local errorLine, errorColumn = findErrorPosition(testFn, msg)

          errors[i] = {
            line = (errorLine or assertionResult.location.line) - 1,
            column = (errorColumn or 1) - 1,
            message = msg,
          }

          tests[keyid].short = tests[keyid].short .. "\n" .. msg
        end

        tests[keyid].errors = errors
      end
    end
  end

  return tests
end

---@async
---@param spec neotest.RunSpec
---@return neotest.Result[]
function adapter.results(spec, b, tree)
  local output_file = spec.context.results_path

  local success, data = pcall(lib.files.read, output_file)

  if not success then
    logger.error("No test output file found ", output_file)
    return {}
  end

  local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

  if not ok then
    logger.error("Failed to parse test output json ", output_file)
    return {}
  end

  local results = parsed_json_to_results(parsed, output_file, b.output)

  return results
end

local is_callable = function(obj)
  return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

setmetatable(adapter, {
  ---@param opts neotest.VitestOptions
  __call = function(_, opts)
    if is_callable(opts.vitestCommand) then
      getVitestCommand = opts.vitestCommand
    elseif opts.vitestCommand then
      getVitestCommand = function()
        return opts.vitestCommand
      end
    end
    if is_callable(opts.vitestConfigFile) then
      getVitestConfig = opts.vitestConfigFile
    elseif opts.vitestConfigFile then
      getVitestConfig = function()
        return opts.vitestConfigFile
      end
    end
    if is_callable(opts.env) then
      getEnv = opts.env
    elseif opts.env then
      getEnv = function(specEnv)
        return vim.tbl_extend("force", opts.env, specEnv)
      end
    end
    if is_callable(opts.cwd) then
      getCwd = opts.cwd
    elseif opts.cwd then
      getCwd = function()
        return opts.cwd
      end
    end
    return adapter
  end,
})

return adapter
