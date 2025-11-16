" neotodo.vim - Plugin loader for NeoTODO
" Maintainer: Mike Perrow
" Version: 0.1.0

" Prevent loading the plugin twice
if exists('g:loaded_neotodo')
  finish
endif
let g:loaded_neotodo = 1

" Require Neovim 0.7.0 or later
if !has('nvim-0.7.0')
  echohl WarningMsg
  echomsg 'neotodo requires Neovim >= 0.7.0'
  echohl None
  finish
endif

" The plugin is loaded via Lua, nothing else needed here
