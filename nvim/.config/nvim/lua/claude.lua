-- Claude AI integration
local M = {}

-- Append to current file
M.append = function()
  local current_file = vim.fn.expand('%:p')
  
  -- Check if it's a markdown file
  if not current_file:match('%.md$') then
    vim.notify('Not a markdown file!', vim.log.levels.WARN)
    return
  end
  
  -- Save current file before running
  vim.cmd('write')
  
  -- Run claude-ai in append mode
  local cmd = string.format('silent !claude-ai append "%s"', current_file)
  vim.cmd(cmd)
  
  -- Reload the file to see changes
  vim.cmd('edit!')
  vim.cmd('normal! G')  -- Go to end of file
  
  vim.notify('✓ Response added', vim.log.levels.INFO)
end

-- Create new conversation
M.new = function()
  -- Run claude-ai in new mode
  vim.cmd('silent !claude-ai new')
  
  -- Find the newly created file (most recent in convos dir)
  local convos_dir = vim.fn.expand('$HOME/claude-convos')
  local files = vim.fn.systemlist(
    string.format('find "%s" -name "*.md" -type f -printf "%%T@ %%p\\n" 2>/dev/null | sort -rn | head -1 | cut -d" " -f2-', convos_dir)
  )
  
  if #files > 0 and files[1] ~= '' then
    vim.cmd('edit ' .. files[1])
    vim.notify('✓ New conversation created', vim.log.levels.INFO)
  end
end

-- Setup keymaps
M.setup = function()
  vim.keymap.set('n', '<leader>ma', M.append, { desc = 'Claude: Append to current file' })
  vim.keymap.set('n', '<leader>mn', M.new, { desc = 'Claude: New conversation' })
end

return M
