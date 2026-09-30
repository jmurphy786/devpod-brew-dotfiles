-- ctrl+h/j/k/l across nvim splits and herdr panes. herdr's nav.sh plugin action
-- passes the key to nvim when it is in the foreground; at the edge of the nvim
-- layout this hands focus back with `herdr pane focus`. No plugin: vim-tmux-
-- navigator only talks to tmux.
local dirs = { h = "left", j = "down", k = "up", l = "right" }

local function navigate(key)
  local win = vim.fn.winnr()
  vim.cmd("wincmd " .. key)
  if vim.fn.winnr() ~= win or vim.env.HERDR_ENV == nil then
    return
  end
  vim.system({
    vim.env.HERDR_BIN_PATH or "herdr", "pane", "focus", "--current", "--direction", dirs[key],
  })
end

return {
  {
    name = "herdr-navigator",
    dir = vim.fn.stdpath("config"),
    virtual = true,
    keys = vim.tbl_map(function(key)
      return { "<C-" .. key .. ">", function() navigate(key) end, mode = { "n", "t" }, desc = "Navigate " .. dirs[key] }
    end, vim.tbl_keys(dirs)),
  },
}
