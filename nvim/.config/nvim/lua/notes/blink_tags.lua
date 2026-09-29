-- blink.cmp source offering only registered tags (see notes.tags): on the
-- frontmatter `tags: [..]` line (after `[`, `,` or a space) and after `#` in
-- note bodies. `[[` stays markdown-oxide's link completion.
local util = require("notes.util")
local tags = require("notes.tags")

local source = {}

-- True when `row` (1-based) is a frontmatter `tags:` line or a `- item` under one.
function source.in_frontmatter_tags(bufnr, row, before)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fm_end = tags.frontmatter_end(lines)
  -- fm_end == 0 with a leading "---" means the frontmatter is still being typed.
  if lines[1] ~= "---" or row < 2 or (fm_end > 0 and row >= fm_end) then
    return false
  end
  if before:match("^%s*tags:") then
    return true
  end
  if before:match("^%s*%-") then
    for i = row - 1, 2, -1 do
      if lines[i]:match("^%s*tags:%s*$") then
        return true
      elseif not lines[i]:match("^%s*%-") then
        break
      end
    end
  end
  return false
end

-- Returns (start_col, with_hash) for a tag being typed before the cursor,
-- or nil when the cursor isn't in a tag position.
function source.tag_start(bufnr, row, before)
  if source.in_frontmatter_tags(bufnr, row, before) then
    if before:match("^%s*tags:$") then
      return
    end
    return before:match("()[A-Za-z0-9/_-]*$"), false
  end
  local s = before:match("()#[A-Za-z0-9/_-]*$")
  if s and (s == 1 or before:sub(s - 1, s - 1):match("%s")) then
    return s, true
  end
end

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  return vim.bo.filetype == "markdown" and util.buf_vault(0) ~= nil
end

function source:get_trigger_characters()
  return { "#", "[", "," }
end

function source:get_completions(ctx, callback)
  local root = util.buf_vault(ctx.bufnr)
  local row, col = ctx.cursor[1], ctx.cursor[2]
  local start, with_hash = source.tag_start(ctx.bufnr, row, ctx.line:sub(1, col))
  if not root or not start then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  local kind = require("blink.cmp.types").CompletionItemKind.Keyword
  local items = {}
  for _, tag in ipairs((tags.registry(root))) do
    local text = with_hash and ("#" .. tag) or tag
    table.insert(items, {
      label = text,
      filterText = tag,
      kind = kind,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
      textEdit = {
        newText = text,
        range = {
          start = { line = row - 1, character = start - 1 },
          ["end"] = { line = row - 1, character = col },
        },
      },
    })
  end
  callback({ items = items, is_incomplete_forward = false, is_incomplete_backward = false })
end

return source
