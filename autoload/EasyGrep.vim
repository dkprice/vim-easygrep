
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

" ResultList Functions {{{
" GetErrorList {{{
function! EasyGrep#GetErrorList()
    if g:EasyGrepWindow == 0
        return getqflist()
    else
        return getloclist(0)
    endif
endfunction
"}}}
" GetErrorListName {{{
function! EasyGrep#GetErrorListName()
    if g:EasyGrepWindow == 0
        return 'quickfix'
    else
        return 'location list'
    endif
endfunction
"}}}
" SetErrorList {{{
function! EasyGrep#SetErrorList(lst)
    if g:EasyGrepWindow == 0
        call setqflist(a:lst)
    else
        call setloclist(0,a:lst)
    endif
endfunction
"}}}
" GotoStartErrorList {{{
function! EasyGrep#GotoStartErrorList()
    if g:EasyGrepWindow == 0
        cfirst
    else
        lfirst
    endif
endfunction
"}}}
"}}}

