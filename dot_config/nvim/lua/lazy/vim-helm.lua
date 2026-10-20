return {
  {
    'towolf/vim-helm',
    init = function()
      vim.filetype.add {
        extension = {
          gotmpl = 'helm',
        },
        pattern = {
          ['.*/templates/.*%.ya?ml'] = 'helm',
          ['.*/templates/.*%.tpl'] = 'helm',
          ['helmfile.*%.ya?ml'] = 'helm',
        },
      }
    end,
  },
}
