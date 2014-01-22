
" Initialization {{{
if exists("g:loaded_easygrep_autoload") || &cp || !has("quickfix")
    finish
endif
let g:loaded_easygrep_autoload = "1.2"
" Check for Vim version 700 or greater {{{
if v:version < 700
    echo "Sorry, EasyGrep ".g:EasyGrepVersion." ONLY runs with Vim 7.0 and greater."
    finish
endif
" }}}
" }}}

