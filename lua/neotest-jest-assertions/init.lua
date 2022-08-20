local s = require("say")

function Contains(state, arguments)
  if not type(arguments[1]) == "table" or #arguments ~= 2 then
    return false
  end

  for _, val in ipairs(arguments[1]) do
    if val == arguments[2] then
      return true
    end
  end

  return false
end

s:set("assertion.Contains.positive", "Expected %s \nto contain: %s")
s:set("assertion.Contains.negative", "Expected %s \nto not contain: %s")
assert:register(
  "assertion",
  "Contains",
  Contains,
  "assertion.Contains.positive",
  "assertion.Contains.negative"
)
