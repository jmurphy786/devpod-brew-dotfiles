return {
  'bullets-vim/bullets.vim',
  ft = { 'markdown', 'text', 'gitcommit' },
  config = function()
    vim.g.bullets_enabled_file_types = { 'markdown', 'text', 'gitcommit' }
    vim.g.bullets_enable_in_empty_buffers = 0
    vim.g.bullets_checkbox_markers = ' .oOX'
    vim.g.bullets_outline_levels = { 'ROM', 'ABC', 'num', 'abc', 'rom', 'std-' }
  end,
}
