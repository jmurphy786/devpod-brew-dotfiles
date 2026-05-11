return {
  'okuuva/auto-save.nvim',
  event = { 'InsertLeave', 'TextChanged' },
  opts = {
    enabled = true,
    execution_message = {
      enabled = false,  -- Don't show save messages
    },
    trigger_events = {
      immediate_save = { 'BufLeave', 'FocusLost' },
      defer_save = { 'InsertLeave', 'TextChanged' },
    },
    condition = function(buf)
      local fn = vim.fn
      local utils = require('auto-save.utils.data')
      
      -- Don't save if readonly, unnamed, or special buffer
      if fn.getbufvar(buf, '&modifiable') == 1 
         and utils.not_in(fn.getbufvar(buf, '&filetype'), {}) 
         and fn.expand('%') ~= '' then
        return true
      end
      return false
    end,
    write_all_buffers = false,
    debounce_delay = 5000,  -- 5 seconds
  },
}
