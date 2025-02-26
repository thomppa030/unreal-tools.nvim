if exists('g:loaded_unreal_tools')
  finish
endif

let g:loaded_unreal_tools = 1

if get(g:, 'unreal_tools_disable', 0)
  finish
endif
