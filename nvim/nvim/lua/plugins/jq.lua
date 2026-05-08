return {
  'cenk1cenk2/jq.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'grapp-dev/nui-components.nvim'
  },
  config = function()
    require('jq').setup()
  end
}
