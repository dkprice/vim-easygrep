
" Initialization {{{
if exists("g:loaded_easygrep_autoload") || &cp || !has("quickfix")
    finish
endif
let g:loaded_easygrep_autoload = "2.0"
" Check for Vim version 700 or greater {{{
if v:version < 700
    echo "Sorry, EasyGrep ".g:EasyGrepVersion." ONLY runs with Vim 7.0 and greater."
    finish
endif
" }}}
" }}}

" Helper Functions {{{
" countstr {{{
function! EasyGrep#countstr(str, ele)
    let end = len(a:str)
    let c = 0
    let i = 0
    while i < end
        if a:str[i] == a:ele
            let c += 1
        endif
        let i += 1
    endwhile

    return c
endfunction
"}}}
" unique {{{
function! EasyGrep#unique(lst)
    if empty(a:lst)
        return a:lst
    endif

    let lst = a:lst
    call sort(lst)

    let end = len(lst)
    let i = 1
    let lastSeen = lst[0]
    while i < end
        if lst[i] == lastSeen
            call remove(lst, i)
            let end -= 1
        else
            let i += 1
        endif
    endwhile

    return lst
endfunction
"}}}
" BackToForwardSlash {{{
function! EasyGrep#BackToForwardSlash(arg)
    return substitute(a:arg, '\\', '/', 'g')
endfunction
"}}}
" ForwardToBackSlash {{{
function! EasyGrep#ForwardToBackSlash(arg)
    return substitute(a:arg, '/', '\\', 'g')
endfunction
"}}}
" GetBuffersOutput {{{
function! EasyGrep#GetBuffersOutput(all)
    let optbang = a:all ? "!" : ""
    redir => bufoutput
    exe "silent! buffers".optbang
    " This echo clears a bug in printing that shows up when it is not present
    silent! echo ""
    redir END

    return bufoutput
endfunction
" }}}
" GetBufferIdList {{{
function! EasyGrep#GetBufferIdList()
    let bufoutput = EasyGrep#GetBuffersOutput(0)

    let bufids = []
    for i in split(bufoutput, "\n")
        let s1 = 0
        while i[s1] == ' '
            let s1 += 1
        endwhile

        let s2 = stridx(i, ' ', s1) - 1
        let id = str2nr(i[s1 : s2])

        call add(bufids, id)
    endfor

    return bufids
endfunction
" }}}
" GetBufferNamesList {{{
function! EasyGrep#GetBufferNamesList()
    let bufoutput = EasyGrep#GetBuffersOutput(0)

    let bufNames = []
    for i in split(bufoutput, "\n")
        let s1 = stridx(i, '"') + 1
        let s2 = stridx(i, '"', s1) - 1
        let str = i[s1 : s2]

        if str[0] == '[' && str[len(str)-1] == ']'
            continue
        endif

        if str != "" && has("win32") && str[0] == "/"
            " Add the drive prefix
            let str = fnamemodify(str, ":p")
        endif

        call add(bufNames, str)
    endfor

    return bufNames
endfunction
" }}}
" GetBufferDirsList {{{
function! EasyGrep#GetBufferDirsList()
    let dirs = {}
    let bufs = EasyGrep#GetBufferNamesList()
    let currDir = EasyGrep#GetCwdEscaped()
    for buf in bufs
        let d = fnamemodify(expand(buf), ":.:h")
        if empty(d)
            let d = currDir
        elseif has("win32") && d[0] == "/"
            " Add the drive prefix but remove the trailing slash
            let d = fnamemodify(d, ":p:s-/$--")
        endif
        let dirs[d]=1
    endfor
    " Note that this returns a unique set of directories
    return sort(keys(dirs))
endfunction
" }}}
" GetVisibleBuffers {{{
function! EasyGrep#GetVisibleBuffers()
    let tablist = []
    for i in range(tabpagenr('$'))
       call extend(tablist, tabpagebuflist(i + 1))
    endfor
    let tablist = EasyGrep#unique(tablist)
    return tablist
endfunction
" }}}
" IsListOpen {{{
function! EasyGrep#IsListOpen(name)
    let bufoutput = EasyGrep#GetBuffersOutput(1)
    return match(bufoutput, "\\[".a:name." List\\]", 0, 0) != -1
endfunction
" }}}
" IsQuickfixListOpen {{{
function! EasyGrep#IsQuickfixListOpen()
    let a = EasyGrep#IsListOpen("Quickfix")
    return EasyGrep#IsListOpen("Quickfix")
endfunction
" }}}
" IsLocationListOpen {{{
function! EasyGrep#IsLocationListOpen()
    return EasyGrep#IsListOpen("Location")
endfunction
" }}}
" GetCwdEscaped {{{
function! EasyGrep#GetCwdEscaped()
    return EasyGrep#FileEscape(getcwd())
endfunction
"}}}
" EscapeList/ShellEscapeList {{{
function! EasyGrep#FileEscape(item)
    return escape(a:item, ' \')
endfunction
function! EasyGrep#ShellEscape(item)
    return shellescape(a:item, 1)
endfunction
function! EasyGrep#DoEscapeList(lst, seperator, func)
    let escapedList = []
    for item in a:lst
        let e = a:func(item).a:seperator
        call add(escapedList, e)
    endfor
    return escapedList
endfunction
function! EasyGrep#EscapeList(lst, seperator)
    return EasyGrep#DoEscapeList(a:lst, a:seperator, function("EasyGrep#FileEscape"))
endfunction
function! EasyGrep#ShellEscapeList(lst, seperator)
    return EasyGrep#DoEscapeList(a:lst, a:seperator, function("EasyGrep#ShellEscape"))
endfunction
"}}}
" GetSavedVariableName {{{
function! EasyGrep#GetSavedVariableName(var)
    let var = a:var
    if match(var, "g:") == 0
        let var = substitute(var, "g:", "g_", "")
    endif
    return "s:saved_".var
endfunction
" }}}
" SaveVariable {{{
function! EasyGrep#SaveVariable(var)
    if empty(a:var)
        return
    endif
    let savedName = EasyGrep#GetSavedVariableName(a:var)
    if match(a:var, "g:") == 0
        execute "let ".savedName." = ".a:var
    else
        execute "let ".savedName." = &".a:var
    endif
endfunction
" }}}
" RestoreVariable {{{
" if a second variable is present, indicate no unlet
function! EasyGrep#RestoreVariable(var, ...)
    let doUnlet = a:0 == 1
    let savedName = EasyGrep#GetSavedVariableName(a:var)
    if exists(savedName)
        if match(a:var, "g:") == 0
            execute "let ".a:var." = ".savedName
        else
            execute "let &".a:var." = ".savedName
        endif
        if doUnlet
            unlet savedName
        endif
    endif
endfunction
" }}}
" OnOrOff {{{
function! EasyGrep#OnOrOff(num)
    return a:num == 0 ? 'off' : 'on'
endfunction
"}}}
" Trim {{{
function! EasyGrep#Trim(s)
    let len = strlen(a:s)

    let beg = 0
    while beg < len
        if a:s[beg] != " " && a:s[beg] != "\t"
            break
        endif
        let beg += 1
    endwhile

    let end = len - 1
    while end > beg
        if a:s[end] != " " && a:s[end] != "\t"
            break
        endif
        let end -= 1
    endwhile

    return strpart(a:s, beg, end-beg+1)
endfunction
"}}}
" ClearNewline {{{
function! EasyGrep#ClearNewline(s)
    if empty(a:s)
        return a:s
    endif

    let lastchar = strlen(a:s)-1
    if char2nr(a:s[lastchar]) == 10
        return strpart(a:s, 0, lastchar)
    endif

    return a:s
endfunction
"}}}
" Info/Warning/Error {{{
function! EasyGrep#Log(message)
    if exists("g:EasyGrepEnableLogging")
        echohl Title | echomsg "[EasyGrep] Log: ".a:message | echohl None
    endif
endfunction
function! EasyGrep#Info(message)
    echohl Normal | echomsg "[EasyGrep] Info: ".a:message | echohl None
endfunction
function! EasyGrep#Warning(message)
    echohl WarningMsg | echomsg "[EasyGrep] Warning: ".a:message | echohl None
endfunction
function! EasyGrep#Error(message)
    echohl ErrorMsg | echomsg "[EasyGrep] Error: ".a:message | echohl None
endfunction
function! EasyGrep#InternalFailure(message)
    echoerr a:message
    call EasyGrep#Info("Please record the error message above and contact EasyGrep's author for help in resolving this issue")
endfunction
"}}}
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

