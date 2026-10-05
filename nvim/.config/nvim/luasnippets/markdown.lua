local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

-- Fenced code block snippet: trigger(s) -> ```lang ... ```
-- Higher priority on short triggers so ";cs" / ";ts" beat their ";css" / ";tsx" prefix matches.
local function fence(trigs, lang, priority)
  local out = {}
  for _, trig in ipairs(type(trigs) == "table" and trigs or { trigs }) do
    table.insert(
      out,
      s({ trig = trig, priority = priority or 1000 }, {
        t("```" .. lang),
        t({ "", "" }),
        i(1),
        t({ "", "```" }),
      })
    )
  end
  return out
end

local snippets = {}
local function add(list)
  vim.list_extend(snippets, list)
end

add(fence(";bash", "bash"))
add(fence({ ";cs", ";csharp" }, "csharp", 2000))
add(fence(";html", "html"))
add(fence(";css", "css"))
add(fence(";js", "javascript", 2000))
add(fence(";tsx", "tsx"))
add(fence(";ts", "typescript", 2000))
add(fence(";json", "json"))
add(fence({ ";yaml", ";yml" }, "yaml"))

return snippets
