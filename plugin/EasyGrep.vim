" Title:         EasyGrep
" Author:        Dan Price   vim@danprice.fastmail.net
"
" Goal:          To be an easy to use, powerful find and replace resource for
"                users of all skill levels.
" Usage:         This file should reside in the plugin directory and be
"                automatically sourced.
"
" License:       Public domain, no restrictions whatsoever
" Documentation: type ":help EasyGrep"
"
" Version:       1.2 -- Programs can inspect g:EasyGrepVersion

" Initialization {{{
if exists("g:EasyGrepVersion") || &cp || !has("quickfix")
    finish
endif
let g:EasyGrepVersion = "1.2"
" Check for Vim version 700 or greater {{{
if v:version < 700
    echo "Sorry, EasyGrep ".g:EasyGrepVersion." ONLY runs with Vim 7.0 and greater."
    finish
endif
" }}}
" }}}

" Internals {{{
" Helper Functions {{{
" countstr {{{
function! s:countstr(str, ele)
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
function! s:unique(lst)
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
function! s:BackToForwardSlash(arg)
    return substitute(a:arg, '\\', '/', 'g')
endfunction
"}}}
" ForwardToBackSlash {{{
function! s:ForwardToBackSlash(arg)
    return substitute(a:arg, '/', '\\', 'g')
endfunction
"}}}
" GetBuffersOutput {{{
function! s:GetBuffersOutput()
    redir => bufoutput
    silent! buffers
    " This echo clears a bug in printing that shows up when it is not present
    silent! echo ""
    redir END

    return bufoutput
endfunction
" }}}
" GetBufferIdList {{{
function! s:GetBufferIdList()
    let bufoutput = s:GetBuffersOutput()

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
function! s:GetBufferNamesList()
    let bufoutput = s:GetBuffersOutput()

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
function! s:GetBufferDirsList()
    let dirs = {}
    let bufs = s:GetBufferNamesList()
    for buf in bufs
        let d = fnamemodify(expand(buf), ":.:h")
        if d == ""
            let d = getcwd()
        elseif has("win32") && d[0] == "/"
            " Add the drive prefix and remove the trailing slash
            let d = fnamemodify(d, ":p:s-/$--")
        endif
        if empty(d)
            continue
        endif
        let dirs[d]=1
    endfor
    return keys(dirs)
endfunction
" }}}
" GetVisibleBuffers {{{
function! s:GetVisibleBuffers()
    let tablist = []
    for i in range(tabpagenr('$'))
       call extend(tablist, tabpagebuflist(i + 1))
    endfor
    let tablist = s:unique(tablist)
    return tablist
endfunction
" }}}
" EscapeList {{{
function! s:FileEscape(item)
    return escape(a:item, ' \')
endfunction
function! s:ShellEscape(item)
    return shellescape(a:item, 1)
endfunction
function! s:DoEscapeList(lst, seperator, func)
    let escapedList = []
    for item in a:lst
        let e = a:func(item).a:seperator
        call add(escapedList, e)
    endfor
    return escapedList
endfunction
function! s:EscapeList(lst, seperator)
    return s:DoEscapeList(a:lst, a:seperator, function("s:FileEscape"))
endfunction
function! s:ShellEscapeList(lst, seperator)
    return s:DoEscapeList(a:lst, a:seperator, function("s:ShellEscape"))
endfunction
"}}}
" Escape{{{
function! s:Escape(str, lst)
    let str = a:str
    for i in a:lst
        let str = escape(str, i)
    endfor
    return str
endfunction
"}}}
" EscapeSpecial {{{
function! s:EscapeSpecial(str)
    let lst = [ '\', '/', '^', '$' ]
    if &magic
        let magicLst = [ '*', '.', '~', '[', ']' ]
        call extend(lst, magicLst)
    endif
    return s:Escape(a:str, lst)
endfunction
"}}}
" IsRecursivePattern {{{
function! s:IsRecursivePattern(pattern)
    return stridx(a:pattern, "\*\*\/") == 0 ? 1 : 0
endfunction
" }}}
" GetSavedName {{{
function! s:GetSavedName(var)
    let var = a:var
    if match(var, "g:") == 0
        let var = substitute(var, "g:", "g_", "")
    endif
    return "s:saved_".var
endfunction
" }}}
" SaveVariable {{{
function! s:SaveVariable(var)
    if empty(a:var)
        return
    endif
    let savedName = s:GetSavedName(a:var)
    if match(a:var, "g:") == 0
        execute "let ".savedName." = ".a:var
    else
        execute "let ".savedName." = &".a:var
    endif
endfunction
" }}}
" RestoreVariable {{{
" if a second variable is present, indicate no unlet
function! s:RestoreVariable(var, ...)
    let doUnlet = a:0 == 1
    let savedName = s:GetSavedName(a:var)
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
function! s:OnOrOff(num)
    return a:num == 0 ? 'off' : 'on'
endfunction
"}}}
" Trim {{{
function! s:Trim(s)
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
function! s:ClearNewline(s)
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
" Warning/Error {{{
function! s:Info(message)
    echohl Normal | echomsg "[EasyGrep] Info: ".a:message | echohl None
endfunction
function! s:Warning(message)
    echohl WarningMsg | echomsg "[EasyGrep] Warning: ".a:message | echohl None
endfunction
function! s:Error(message)
    echohl ErrorMsg | echomsg "[EasyGrep] Error: ".a:message | echohl None
endfunction
function! s:InternalFailure(message)
    echoerr a:message
    call s:Info("Please record the error message above and contact EasyGrep's author for help in resolving this issue")
endfunction
"}}}
" }}}
" Script Variables {{{
let s:EasyGrepModeAll=0
let s:EasyGrepModeBuffers=1
let s:EasyGrepModeTracked=2
let s:EasyGrepModeUser=3
let s:EasyGrepNumModes = 4

" This is a special mode
let s:EasyGrepModeMultipleChoice=4
let s:EasyGrepNumModesWithSpecial = 5

let s:NumReplaceModeOptions = 3

let s:OptionsExplorerOpen = 0

let s:FilesToGrep = "*"
let s:TrackedExt  = "*"

function! s:GetReplaceWindowModeString(mode)
    if(a:mode < 0 || a:mode >= s:NumReplaceModeOptions)
        return "invalid"
    endif
    let ReplaceWindowModeStrings = [ "New Tab", "Split Windows", "autowriteall" ]
    return ReplaceWindowModeStrings[a:mode]
endfunction
let s:SortOptions = [ "Name", "Name Reversed", "Extension", "Extension Reversed" ]
let s:SortFunctions = [ "SortName", "SortNameReversed", "SortExtension", "SortExtensionReversed" ]
let s:SortChoice = 0

let s:Commands = [ "vimgrep", "grep" ]
let s:CommandChoice = 0
let s:LastSeenGrepprg = &grepprg
function! s:InitializeCommandChoice()
    let s:CommandChoice = g:EasyGrepCommand < len(s:Commands) ? g:EasyGrepCommand : 0
endfunction
let s:CurrentFileCurrentDirChecked = 0
let s:SanitizeLock = 0

" SetGatewayVariables {{{
function! s:SetGatewayVariables()
    echo
    call s:SaveVariable("lazyredraw")
    set lazyredraw
endfunction
" }}}
" ClearGatewayVariables {{{
function! s:ClearGatewayVariables()
    let s:CurrentFileCurrentDirChecked = 0
    call s:RestoreVariable("lazyredraw")
endfunction
" }}}

" }}}
" Common {{{
" Echo {{{
function! <sid>Echo(message)
    let str = ""
    if !s:OptionsExplorerOpen
        let str .= "[EasyGrep] "
    endif
    let str .= a:message
    echo str
endfunction
"}}}
" GetPatternList {{{
function! s:GetPatternList(sp, addAdditionalLocations)
    let sp = a:sp
    let addAdditionalLocations = a:addAdditionalLocations
    if s:IsModeBuffers()
        let str = join(s:EscapeList(s:GetBufferNamesList(), " "), sp)
        let addAdditionalLocations = 0
    elseif s:IsModeTracked()

        let str = s:TrackedExt
        let i = s:FindByPattern(s:TrackedExt)
        if i != -1
            let keyList = [ i ]
            let str = s:BreakDown(keyList)
        endif
    else
        let i = 0
        let numItems = len(s:Dict)
        let keyList = []
        while i < numItems
            if s:Dict[i][2] == 1
                call add(keyList, i)
            endif
            let i += 1
        endwhile

        if !empty(keyList)
            let str = s:BreakDown(keyList)
        else
            call s:InternalFailure("Keylist should not be empty")
            let str = "*"
        endif
    endif

    if addAdditionalLocations
        let filesToGrep = s:AddAdditionalLocationsToList(str, sp)
    else
        let filesToGrep = str
    endif

    let filesToGrep = s:Trim(filesToGrep)
    return filesToGrep
endfunction
" }}}
" BuildListOfFilesToGrep {{{
function! s:BuildListOfFilesToGrep(...)
    if a:0 > 0
        let sp = a:1
    else
        let sp = " "
    endif
    let s:FilesToGrep = s:GetPatternList(sp, 1)
    return s:FilesToGrep
endfunction
" }}}
" AddAdditionalLocationsToList {{{
function! s:AddAdditionalLocationsToList(str, sp)
    if empty(a:str)
        return a:str
    endif

    let str = a:str
    let sp = a:sp
    if !s:IsModeBuffers() && g:EasyGrepSearchCurrentBufferDir
        let str = s:AddBufferDirsToPatternList(str,sp)
    endif
    let patternList = split(str)

    if g:EasyGrepHidden
        let i = 0
        let size = len(patternList)
        while i < size
            let item = patternList[i]
            let lastpiece = strridx(item, '/')
            if lastpiece == -1 && item[0] == '.'
                " skip this item, it's already hidden
            elseif lastpiece != -1 && item[lastpiece+1] == '.'
                " skip this item, it's already hidden
            else
                if lastpiece == -1
                    let newItem = '.'.item
                else
                    let newItem  = strpart(item, 0, lastpiece+1)
                    let newItem .= "."
                    let newItem .= strpart(item, lastpiece+1)
                endif
                let i += 1
                let size += 1
                call insert(patternList, newItem, i)
            endif
            let i += 1
        endwhile
    endif

    let str = ""
    for item in patternList
        if g:EasyGrepRecursive && s:IsCommandVimgrep()
            let str .= "**/"
        endif
        let str .= item.sp
    endfor

    return str
endfunction
"}}}
" AddBufferDirsToPatternList {{{
function! s:AddBufferDirsToPatternList(str,sp)
    let str = a:str
    let sp = a:sp

    " Build a list of the directories in buffers
    let dirs = sort(s:GetBufferDirsList())

    let patternList = split(str, sp)

    let currDir = getcwd()
    let accepteddirs = [ currDir ]
    for key in dirs
        let newDir = key
        let addToList = 1
        if newDir == currDir || newDir == '.'
            let addToList = 0
        elseif g:EasyGrepRecursive
            for d in accepteddirs
                if s:IsRecursivelyReachable(d, newDir)
                    let addToList = 0
                    break
                endif
            endfor
        endif
        if addToList
            call add(accepteddirs, newDir)
            for p in patternList
                let str = str.sp.newDir."/".p
            endfor
        endif
    endfor
    return str
endfunction
"}}}
" FindByPattern {{{
function! s:FindByPattern(pattern)
    let pattern = a:pattern
    let i = 0
    let numItems = len(s:Dict)
    while i < numItems
        if i != s:EasyGrepModeTracked
            let patterns = split(s:Dict[i][1])
            for p in patterns
                if pattern ==# p
                    return i
                endif
            endfor
        endif
        let i += 1
    endwhile
    return -1
endfunction
" }}}
" IsRecursivelyReachable {{{
function! s:IsRecursivelyReachable(fromthisdir, target)
    let directoryTarget = fnamemodify(a:target, ":p:h")

    if match(directoryTarget, a:fromthisdir) != 0
        return 0
    endif

    return 1
endfunction
" }}}
" GetRecursiveMinimalSetList {{{
function! s:GetRecursiveMinimalSetList()

    let currDir = getcwd()
    let bufferdirs = sort(s:GetBufferDirsList())
    let bufferSetList = [ currDir ]

    for dir in bufferdirs
        let addToList = 1
        if dir == currDir || dir == '.'
            let addToList = 0
        else
            for d in bufferSetList
                if s:IsRecursivelyReachable(d, dir)
                    let addToList = 0
                    break
                endif
            endfor
        endif
        if addToList
            call add(bufferSetList, dir)
        endif
    endfor

    return bufferSetList
endfunction
" }}}
" GetDirectorySearchList {{{
function! s:GetDirectorySearchList()
    if g:EasyGrepSearchCurrentBufferDir
        if g:EasyGrepRecursive
            return s:GetRecursiveMinimalSetList()
        else
            return extend([getcwd()], s:GetBufferDirsList())
        endif
    else
        return [ getcwd() ]
    endif
endfunction
" }}}
" CheckIfCurrentFileIsSearched {{{
function! s:CheckIfCurrentFileIsSearched()
    if !g:EasyGrepExtraWarnings || s:CurrentFileCurrentDirChecked || g:EasyGrepSearchCurrentBufferDir
        return 1
    endif
    let s:CurrentFileCurrentDirChecked = 1
    if !empty(&buftype) " don't check for quickfix and others
        return 1
    endif
    if !s:IsModeBuffers()
        let currFile = bufname("%")
        if empty(currFile) && &modified
            call s:Warning("cannot search the current buffer because it is unnamed")
            return 0
        endif
        let fileDir = fnamemodify(currFile, ":p:h")
        if !empty(fileDir) && !g:EasyGrepSearchCurrentBufferDir
            let cwd = getcwd()
            let willmatch = 1
            if g:EasyGrepRecursive
                if match(fileDir, cwd) != 0
                    let willmatch = 0
                endif
            else
                if fileDir != cwd
                    let willmatch = 0
                endif
            endif
            if !willmatch
                call s:Warning("current file not searched, its directory [".fileDir."] doesn't match the working directory [".cwd."]")
                return 0
            endif
        endif
    endif
    return 1
endfunction
" }}}
" }}}
" OptionsExplorer {{{
" OpenOptionsExplorer {{{
function! s:OpenOptionsExplorer()
    let s:OptionsExplorerOpen = 1

    call s:CreateOptionsString()

    let windowLines = len(s:Options) + 1
    if g:EasyGrepFileAssociationsInExplorer
        let windowLines += len(s:Dict)
    else
        let windowLines += s:EasyGrepNumModes
    endif

    " split the window; fit exactly right
    exe "keepjumps botright ".windowLines."new"

    setlocal bufhidden=delete
    setlocal buftype=nofile
    setlocal nobuflisted
    setlocal noswapfile
    setlocal cursorline

    syn match Help    /^".*/
    highlight def link Help Special

    syn match Activated    /^>\w.*/
    highlight def link Activated Type

    syn match Selection    /^\ \w.*/
    highlight def link Selection String

    call s:MapOptionsKeys()

    call s:BuildListOfFilesToGrep()
    call s:FillWindow()
endfunction
" }}}
" Mapped Functions {{{
" EchoFilesSearched {{{
function! <sid>EchoFilesSearched()
    let filesToGrep = s:BuildListOfFilesToGrep("\n")

    if s:IsModeBuffers()
        let str = filesToGrep
    else
        let str = ""
        let patternList = split(filesToGrep)
        for p in patternList
            let s = glob(p)
            if !empty(s)
                let fileList = split(s, "\n")
                for f in fileList
                    if filereadable(f)
                        let str .= f."\n"
                    endif
                endfor
            endif
        endfor
    endif

    if !empty(str)
        call s:Echo("Files that will be searched")
        echo str
    else
        call s:Echo("No files match the current options")
    endif
    call s:BuildListOfFilesToGrep()
endfunction
"}}}
" SetFilesToExclude {{{
function! <sid>SetFilesToExclude()
    let filesToExclude = input("Enter patterns to exclude, seperated by a comma: ", g:EasyGrepFilesToExclude)
    let g:EasyGrepFilesToExclude = s:Trim(filesToExclude)

    call s:BuildListOfFilesToGrep()
    call s:RefreshAllOptions()

    if !empty(g:EasyGrepFilesToExclude)
        call s:Echo("Set patterns to exclude to (".g:EasyGrepFilesToExclude.")")
        if !s:CommandSupportsExclusions()
            call s:Echo("But note that your command, ".s:GetGrepCommandName().", does not support them. See the docs for supported programs.")
        endif
    else
        call s:Echo("Clearing patterns to exclude")
    endif
endfunction
"}}}
" EchoGrepCommand {{{
function! <sid>EchoGrepCommand()
    if !s:IsCommandVimgrep() && !s:ValidateGrepCommand()
        return 0
    endif

    let placeholder = "<pattern>"
    let dirAnnotation = "Current Directory:     "
    let grepCommand = s:GetGrepCommandLine(placeholder, "", 0, "", 1)
    if g:EasyGrepSearchCurrentBufferDir
        let dirs = s:GetDirectorySearchList()
        for d in dirs
            call s:Echo(dirAnnotation.d)
            let dirAnnotation = "Additional Directory:  "
        endfor
    else
        call s:Echo(dirAnnotation.getcwd())
    endif
    call s:Echo("VIM command:           ".grepCommand)
    if s:GetGrepCommandName() == "grep"
        let shellCommand = substitute(grepCommand, "grep", &grepprg, "")
        call s:Echo("Shell command:         ".shellCommand)
    endif
endfunction
"}}}
" EchoOptionsSet {{{
function! <sid>EchoOptionsSet()

    let optList = [
            \ "g:EasyGrepFileAssociations",
            \ "g:EasyGrepMode",
            \ "g:EasyGrepCommand",
            \ "g:EasyGrepRecursive",
            \ "g:EasyGrepSearchCurrentBufferDir",
            \ "g:EasyGrepIgnoreCase",
            \ "g:EasyGrepHidden",
            \ "g:EasyGrepFilesToExclude",
            \ "g:EasyGrepAllOptionsInExplorer",
            \ "g:EasyGrepWindow",
            \ "g:EasyGrepReplaceWindowMode",
            \ "g:EasyGrepOpenWindowOnMatch",
            \ "g:EasyGrepEveryMatch",
            \ "g:EasyGrepJumpToMatch",
            \ "g:EasyGrepInvertWholeWord",
            \ "g:EasyGrepFileAssociationsInExplorer",
            \ "g:EasyGrepExtraWarnings",
            \ "g:EasyGrepOptionPrefix",
            \ "g:EasyGrepReplaceAllPerFile"
            \ ]

    let str = ""
    for item in optList
        let q = type(eval(item))==1 ? "'" : ""
        let str .= "let ".item."=".q.eval(item).q."\n"
    endfor

    call s:Warning("The following options will be saved in the e register; type \"ep to paste into your .vimrc")
    redir @e
    echo str
    redir END

endfunction
"}}}
" SelectOptionExplorerLine {{{
function! <sid>SelectOptionExplorerLine()
    let pos = getpos(".")
    let line = pos[1]
    let choice = line - s:firstPatternLine

    call s:ActivateChoice(choice)
endfunction
" }}}
" ActivateAll {{{
function! <sid>ActivateAll()
    call s:ActivateChoice(s:EasyGrepModeAll)
endfunction
"}}}
" ActivateBuffers {{{
function! <sid>ActivateBuffers()
    call s:ActivateChoice(s:EasyGrepModeBuffers)
endfunction
"}}}
" ActivateTracked {{{
function! <sid>ActivateTracked()
    call s:ActivateChoice(s:EasyGrepModeTracked)
endfunction
"}}}
" ActivateUser {{{
function! <sid>ActivateUser()
    call s:ActivateChoice(s:EasyGrepModeUser)
endfunction
"}}}
" ActivateChoice {{{
function! s:ActivateChoice(choice)
    let choice = a:choice

    if choice < 0 || choice == s:EasyGrepNumModes
        return
    endif

    if choice < s:EasyGrepNumModes
        let selectedMode = choice
    else
        let selectedMode = s:EasyGrepModeMultipleChoice
    endif

    if s:IsCommandAck()
        if selectedMode != s:EasyGrepModeAll && selectedMode != s:EasyGrepModeBuffers
            call s:Error("Cannot activate '".s:GetModeName(selectedMode)."' mode when ".s:GetGrepProgramPair().", as this grepprg implements its own filtering")
            return
        endif
    endif

    " handles the space in between the default modes and file association list
    let choice -= choice >= s:EasyGrepNumModes ? 1 : 0

    let choicesThatAreModes = [ s:EasyGrepModeAll, s:EasyGrepModeBuffers, s:EasyGrepModeTracked, s:EasyGrepModeUser ]

    let wasActivatedBeforeChoice = (s:Dict[choice][2] == 1)
    let shouldBecomeActivated = (s:Dict[choice][2] == 0)

    let userStr = ""
    if choice == s:EasyGrepModeUser
        let userStr = input("Enter Grep Pattern: ", s:Dict[choice][1])
        if empty(userStr)
            let s:Dict[choice][1] = ""
            if !wasActivatedBeforeChoice
                return
            endif
        else
            " If the user's choice matches a pattern from the file association's
            " list, this gives the user the option of choosing that pattern instead
            let choice = s:GrepSetManual(userStr)
            if choice == -1
                return
            elseif choice == s:EasyGrepModeUser
                let s:Dict[choice][1] = userStr
            else "Activate the preset pattern
                let shouldBecomeActivated = 1
                let selectedMode = s:EasyGrepModeMultipleChoice
                let s:Dict[s:EasyGrepModeUser][1] = ""
                call s:ClearActivatedItems()
                call s:UpdateAllSelections()
            endif
        endif
    endif

    let additionalmessage = ""
    let allBecomesActivated = 0
    if shouldBecomeActivated
        " Handle any incompatible modes
        if choice == s:EasyGrepModeBuffers && g:EasyGrepRecursive == 1
            let additionalmessage = "And setting g:EasyGrepRecursive to 'Off', as only buffers are searched"
            let g:EasyGrepRecursive = 0
        elseif s:IsCommandAck() && !g:EasyGrepRecursive
            let additionalmessage = "And setting g:EasyGrepRecusive to 'On', as ".s:GetGrepProgramPair()." is inherently recursive"
            let g:EasyGrepRecursive = 1
        endif

        if count(choicesThatAreModes, choice) > 0
            call s:ClearActivatedItems()
            call s:UpdateAllSelections()
        else
            for c in choicesThatAreModes
                if s:Dict[c][2] == 1
                    let s:Dict[c][2] = 0
                    call s:UpdateSelectionLine(c)
                endif
            endfor
        endif

        let s:Dict[choice][2] = 1
    else
        if choice == s:EasyGrepModeAll || choice == s:EasyGrepModeBuffers || choice == s:EasyGrepModeTracked || (choice == s:EasyGrepModeUser && !empty(userStr))
            let shouldBecomeActivated = 1
        else
            let s:Dict[choice][2] = 0
            let shouldBecomeActivated = 0
            if s:HasActivatedItem() == 0
                let allBecomesActivated = 1
                let s:Dict[s:EasyGrepModeAll][2] = 1
                call s:UpdateSelectionLine(s:EasyGrepModeAll)
            endif
        endif
    endif

    call s:SetGrepMode(selectedMode)

    call s:UpdateSelectionLine(choice)
    call s:BuildListOfFilesToGrep()
    call s:RefreshAllOptions()

    let str = ""
    if choice == s:EasyGrepModeAll
        let str = "Activated (All)"
    else
        let e = shouldBecomeActivated ? "Activated" : "Deactivated"

        let keyName = s:Dict[choice][0]
        let str = e." (".keyName.")"
        if allBecomesActivated
            let str .= " -> Activated (All)"
        endif
    endif

    call s:Echo(str)
    if !empty(additionalmessage)
        call s:Echo(additionalmessage)
    endif
endfunction
"}}}
" Sort {{{
function! <sid>Sort()
    let s:SortChoice += 1
    if s:SortChoice == len(s:SortOptions)
        let s:SortChoice = 0
    endif

    let beg = s:EasyGrepNumModes
    let dictCopy = s:Dict[beg :]
    call sort(dictCopy, s:SortFunctions[s:SortChoice])
    let s:Dict[beg :] = dictCopy

    call s:RefreshAllOptions()
    call s:UpdateAllSelections()

    call s:Echo("Set sort to (".s:SortOptions[s:SortChoice].")")
endfunction
" }}}
" Sort Functions {{{
function! SortName(lhs, rhs)
    return a:lhs[0] == a:rhs[0] ? 0 : a:lhs[0] > a:rhs[0] ? 1 : -1
endfunction

function! SortNameReversed(lhs, rhs)
    let r = SortName(a:lhs, a:rhs)
    return r == 0 ? 0 : r == -1 ? 1 : -1
endfunction

function! SortExtension(lhs, rhs)
    return a:lhs[1] == a:rhs[1] ? 0 : a:lhs[1] > a:rhs[1] ? 1 : -1
endfunction

function! SortExtensionReversed(lhs, rhs)
    let r = SortExtension(a:lhs, a:rhs)
    return r == 0 ? 0 : r == -1 ? 1 : -1
endfunction
" }}}
" GetGrepCommandName {{{
function! s:GetGrepCommandName()
    return s:Commands[s:CommandChoice]
endfunction
" }}}
" GetGrepCommandNameWithOptions {{{
function! s:GetGrepCommandNameWithOptions()
    let name = s:GetGrepCommandName()
    if name == "grep"
        let name .= "='".&grepprg."'"
    endif
    return name
endfunction
" }}}
" GetGrepProgramName {{{
function! s:GetGrepProgramName()
    return substitute(&grepprg, "\\s.*", "", "")
endfunction
" }}}
" GetGrepProgramPair {{{
function! s:GetGrepProgramPair()
    return "(grepprg='".&grepprg."')"
endfunction
" }}}
" ToggleCommand {{{
function! <sid>ToggleCommand()
    let s:CommandChoice += 1
    if s:CommandChoice == len(s:Commands)
        let s:CommandChoice = 0
    endif
    let g:EasyGrepCommand = s:CommandChoice

    call s:BuildListOfFilesToGrep()
    call s:RefreshAllOptions()

    call s:Echo("Set command to (".s:GetGrepCommandNameWithOptions().")")
    if s:IsCommandAck()
        if s:IsModeTracked()
            call s:Echo("And setting g:EasyGrepMode to 'All', as ".s:GetGrepProgramPair()." implements its own filtering")
            call s:ForceGrepMode(s:EasyGrepModeAll)
        endif
        if !s:IsModeBuffers() && !g:EasyGrepRecursive
            call s:Echo("And setting g:EasyGrepRecusive to 'On', as ".s:GetGrepProgramPair()." is inherently recursive")
            let g:EasyGrepRecursive=1
        endif
    endif
endfunction
" }}}
" ToggleRecursion {{{
function! <sid>ToggleRecursion()
    if s:IsModeBuffers()
        call s:Warning("Recursive mode cant' be set when *Buffers* is activated")
        return
    endif

    let g:EasyGrepRecursive = !g:EasyGrepRecursive

    call s:BuildListOfFilesToGrep()
    call s:RefreshAllOptions()

    call s:Echo("Set recursive mode to (".s:OnOrOff(g:EasyGrepRecursive).")")
endfunction
" }}}
" ToggleIgnoreCase {{{
function! <sid>ToggleIgnoreCase()
    let g:EasyGrepIgnoreCase = !g:EasyGrepIgnoreCase
    call s:RefreshAllOptions()
    call s:Echo("Set ignore case to (".s:OnOrOff(g:EasyGrepIgnoreCase).")")
endfunction
" }}}
" ToggleHidden {{{
function! <sid>ToggleHidden()
    let g:EasyGrepHidden = !g:EasyGrepHidden

    call s:BuildListOfFilesToGrep()
    call s:RefreshAllOptions()

    call s:Echo("Set hidden files included to (".s:OnOrOff(g:EasyGrepHidden).")")
endfunction
" }}}
" ToggleBufferDirectories {{{
function! <sid>ToggleBufferDirectories()
    let g:EasyGrepSearchCurrentBufferDir = !g:EasyGrepSearchCurrentBufferDir

    call s:BuildListOfFilesToGrep()
    call s:RefreshAllOptions()

    call s:Echo("Set additional directories included to (".s:OnOrOff(g:EasyGrepSearchCurrentBufferDir).")")
endfunction
" }}}
" ToggleWindow {{{
function! <sid>ToggleWindow()
    let g:EasyGrepWindow = !g:EasyGrepWindow
    call s:RefreshAllOptions()

    call s:Echo("Set window to (".s:GetErrorListName().")")
endfunction
"}}}
" ToggleOpenWindow {{{
function! <sid>ToggleOpenWindow()
    let g:EasyGrepOpenWindowOnMatch = !g:EasyGrepOpenWindowOnMatch
    call s:RefreshAllOptions()

    call s:Echo("Set open window on match to (".s:OnOrOff(g:EasyGrepOpenWindowOnMatch).")")
endfunction
"}}}
" ToggleEveryMatch {{{
function! <sid>ToggleEveryMatch()
    let g:EasyGrepEveryMatch = !g:EasyGrepEveryMatch
    call s:RefreshAllOptions()

    call s:Echo("Set separate multiple matches to (".s:OnOrOff(g:EasyGrepEveryMatch).")")
endfunction
"}}}
" ToggleJumpToMatch {{{
function! <sid>ToggleJumpToMatch()
    let g:EasyGrepJumpToMatch = !g:EasyGrepJumpToMatch
    call s:RefreshAllOptions()

    call s:Echo("Set jump to match to (".s:OnOrOff(g:EasyGrepJumpToMatch).")")
endfunction
"}}}
" ToggleWholeWord {{{
function! <sid>ToggleWholeWord()
    let g:EasyGrepInvertWholeWord = !g:EasyGrepInvertWholeWord
    call s:RefreshAllOptions()

    call s:Echo("Set invert the meaning of whole word to (".s:OnOrOff(g:EasyGrepInvertWholeWord).")")
endfunction
"}}}
" ToggleReplaceWindowMode {{{
function! <sid>ToggleReplaceWindowMode()
    let g:EasyGrepReplaceWindowMode += 1
    if g:EasyGrepReplaceWindowMode == s:NumReplaceModeOptions
        let g:EasyGrepReplaceWindowMode = 0
    endif

    call s:RefreshAllOptions()

    call s:Echo("Set replace window mode to (".s:GetReplaceWindowModeString(g:EasyGrepReplaceWindowMode).")")
endfunction
" }}}
" ToggleOptionsDisplay {{{
function! <sid>ToggleOptionsDisplay()
    let g:EasyGrepAllOptionsInExplorer = !g:EasyGrepAllOptionsInExplorer

    if s:OptionsExplorerOpen
        let oldWindowLines = len(s:Options) + 1
        call s:FillWindow()
        let newWindowLines = len(s:Options) + 1

        let linesDiff = newWindowLines-oldWindowLines
        if linesDiff > 0
            let linesDiff = "+".linesDiff
        endif

        execute "resize ".linesDiff
        normal zb
    endif

    call s:Echo("Showing ". (g:EasyGrepAllOptionsInExplorer ? "more" : "fewer")." options")
endfunction
"}}}
" ToggleFileAssociationsInExplorer {{{
function! <sid>ToggleFileAssociationsInExplorer()
    let g:EasyGrepFileAssociationsInExplorer = !g:EasyGrepFileAssociationsInExplorer

    call s:FillWindow()
    call s:RefreshAllOptions()

    if g:EasyGrepFileAssociationsInExplorer
        execute "resize +".len(s:Dict)
    else
        let newSize = len(s:Options) + s:EasyGrepNumModes + 1
        execute "resize ".newSize
    endif
    normal zb

    call s:Echo("Set file associations in explorer to (".s:OnOrOff(g:EasyGrepFileAssociationsInExplorer).")")
endfunction
"}}}
" Quit {{{
function! <sid>Quit()
    let s:OptionsExplorerOpen = 0
    echo ""
    quit
endfunction
" }}}
"}}}
" ClearActivatedItems {{{
function! s:ClearActivatedItems()
    let i = 0
    let numItems = len(s:Dict)
    while i < numItems
        let s:Dict[i][2] = 0
        let i += 1
    endwhile
endfunction
" }}}
" HasActivatedItem {{{
function! s:HasActivatedItem()
    let i = 0
    let numItems = len(s:Dict)
    while i < numItems
        if s:Dict[i][2] == 1
            return 1
        endif
        let i += 1
    endwhile
    return 0
endfunction
" }}}
" RefreshAllOptions {{{
function! s:RefreshAllOptions()
    if !s:OptionsExplorerOpen
        return
    endif

    call s:CreateOptionsString()

    setlocal modifiable

    let lastLine = len(s:Options)
    let line = 0
    while line < lastLine
        call setline(line+1, s:Options[line])
        let line += 1
    endwhile

    setlocal nomodifiable
endfunction
" }}}
" UpdateAllSelections {{{
function! s:UpdateAllSelections()
    if !s:OptionsExplorerOpen
        return
    endif

    if g:EasyGrepFileAssociationsInExplorer
        let numItems = len(s:Dict)
    else
        let numItems = s:EasyGrepNumModes
    endif
    call s:UpdateSelectionRange(0, numItems)
endfunction
" }}}
" UpdateSelectionLine {{{
function! s:UpdateSelectionLine(choice)
    call s:UpdateSelectionRange(a:choice, a:choice+1)
endfunction
" }}}
" UpdateSelectionRange {{{
function! s:UpdateSelectionRange(first, last)
    if !s:OptionsExplorerOpen
        return
    endif

    setlocal modifiable
    let i = a:first
    while i < a:last
        let indicator = s:Dict[i][2] == 1 ? '>' : ' '
        let str = indicator. s:Dict[i][0] . ': ' . s:Dict[i][1]
        let lineOffset = i >= s:EasyGrepNumModes ? 1 : 0
        call setline(s:firstPatternLine+i+lineOffset, str)
        let i += 1
    endwhile

    setlocal nomodifiable
endfunction
" }}}
" FillWindow {{{
function! s:FillWindow()

    setlocal modifiable

    " Clear the entire window
    execute "silent %delete"

    call s:CreateOptionsString()
    call append(0, s:Options)
    let s:firstPatternLine = len(s:Options) + 1
    call s:RefreshAllOptions()

    setlocal modifiable

    if g:EasyGrepFileAssociationsInExplorer
        let numItems = len(s:Dict)
    else
        let numItems = s:EasyGrepNumModes
    endif

    let i = 0
    while i < numItems
        call append(s:firstPatternLine, "")
        let i += 1
    endwhile
    call s:UpdateAllSelections()
    setlocal nomodifiable

    " place the cursor at the start of the special options
    execute "".len(s:Options)+1
endfunction
" }}}
" CreateOptionMappings {{{
function! s:CreateOptionMappings()
    if empty(g:EasyGrepOptionPrefix)
        return
    endif

    let p = g:EasyGrepOptionPrefix

    exe "nmap <silent> ".p."a  :call <sid>ActivateAll()<cr>"
    exe "nmap <silent> ".p."b  :call <sid>ActivateBuffers()<cr>"
    exe "nmap <silent> ".p."t  :call <sid>ActivateTracked()<cr>"
    exe "nmap <silent> ".p."u  :call <sid>ActivateUser()<cr>"

    exe "nmap <silent> ".p."x  :call <sid>SetFilesToExclude()<cr>"
    exe "nmap <silent> ".p."c  :call <sid>ToggleCommand()<cr>"
    exe "nmap <silent> ".p."r  :call <sid>ToggleRecursion()<cr>"
    exe "nmap <silent> ".p."d  :call <sid>ToggleBufferDirectories()<cr>"
    exe "nmap <silent> ".p."i  :call <sid>ToggleIgnoreCase()<cr>"
    exe "nmap <silent> ".p."h  :call <sid>ToggleHidden()<cr>"
    exe "nmap <silent> ".p."w  :call <sid>ToggleWindow()<cr>"
    exe "nmap <silent> ".p."o  :call <sid>ToggleOpenWindow()<cr>"
    exe "nmap <silent> ".p."g  :call <sid>ToggleEveryMatch()<cr>"
    exe "nmap <silent> ".p."p  :call <sid>ToggleJumpToMatch()<cr>"
    exe "nmap <silent> ".p."!  :call <sid>ToggleWholeWord()<cr>"
    exe "nmap <silent> ".p."e  :call <sid>EchoFilesSearched()<cr>"
    exe "nmap <silent> ".p."s  :call <sid>Sort()<cr>"
    exe "nmap <silent> ".p."m  :call <sid>ToggleReplaceWindowMode()<cr>"
    exe "nmap <silent> ".p."?  :call <sid>ToggleOptionsDisplay()<cr>"
    exe "nmap <silent> ".p."v  :call <sid>EchoGrepCommand()<cr>"
    exe "nmap <silent> ".p."\\|  :call <sid>EchoOptionsSet()<cr>"
    exe "nmap <silent> ".p."*  :call <sid>ToggleFileAssociationsInExplorer()<cr>"
endfunction
"}}}
" GrepOptions {{{
function! <sid>GrepOptions()
    call s:SetGatewayVariables()
    call s:CreateDict()
    call s:OpenOptionsExplorer()
    return s:ClearGatewayVariables()
endfunction
" }}}
" CreateOptionsString {{{
function! s:CreateOptionsString()

    let s:Options = []

    call add(s:Options, "\"q: quit")
    call add(s:Options, "\"r: recursive mode (".s:OnOrOff(g:EasyGrepRecursive).")")
    call add(s:Options, "\"d: additional directories included (".s:OnOrOff(g:EasyGrepSearchCurrentBufferDir).")")
    call add(s:Options, "\"i: ignore case (".s:OnOrOff(g:EasyGrepIgnoreCase).")")
    call add(s:Options, "\"h: hidden files included (".s:OnOrOff(g:EasyGrepHidden).")")
    call add(s:Options, "\"e: echo files that would be searched")
    if g:EasyGrepAllOptionsInExplorer
        call add(s:Options, "\"x: set files to exclude")
        call add(s:Options, "\"c: change grep command (".s:GetGrepCommandNameWithOptions().")")
        call add(s:Options, "\"w: window to use (".s:GetErrorListName().")")
        call add(s:Options, "\"m: replace window mode (".s:GetReplaceWindowModeString(g:EasyGrepReplaceWindowMode).")")
        call add(s:Options, "\"o: open window on match (".s:OnOrOff(g:EasyGrepOpenWindowOnMatch).")")
        call add(s:Options, "\"g: separate multiple matches (".s:OnOrOff(g:EasyGrepEveryMatch).")")
        call add(s:Options, "\"p: jump to match (".s:OnOrOff(g:EasyGrepJumpToMatch).")")
        call add(s:Options, "\"!: invert the meaning of whole word (".s:OnOrOff(g:EasyGrepInvertWholeWord).")")
        call add(s:Options, "\"*: show file associations list (".s:OnOrOff(g:EasyGrepFileAssociationsInExplorer).")")
        if g:EasyGrepFileAssociationsInExplorer
            call add(s:Options, "\"s: change file associations list sorting (".s:SortOptions[s:SortChoice].")")
        endif
        call add(s:Options, "")
        call add(s:Options, "\"a: activate 'All' mode")
        call add(s:Options, "\"b: activate 'Buffers' mode")
        call add(s:Options, "\"t: activate 'TrackExt' mode")
        call add(s:Options, "\"u: activate 'User' mode")
        call add(s:Options, "")
        call add(s:Options, "\"v: echo the grep command")
        call add(s:Options, "\"|: echo options that are set")
    endif
    call add(s:Options, "\"?: show ". (g:EasyGrepAllOptionsInExplorer ? "fewer" : "more")." options")
    call add(s:Options, "")
    call add(s:Options, "\"Current Directory: ".getcwd())
    call add(s:Options, "\"Grep Targets: ".s:FilesToGrep)
    call add(s:Options, "\"Exclusions: ".(!empty(g:EasyGrepFilesToExclude) ? g:EasyGrepFilesToExclude : "none").(empty(g:EasyGrepFilesToExclude) || s:CommandSupportsExclusions() ? "" : " (only supported with grepprg of 'ack' or 'grep')"))
    call add(s:Options, "")

endfunction
"}}}
" MapOptionsKeys {{{
function! s:MapOptionsKeys()

    nnoremap <buffer> <silent> <cr> :call <sid>SelectOptionExplorerLine()<cr>
    nnoremap <buffer> <silent> :    :call <sid>Echo("Type q to quit")<cr>
    nnoremap <buffer> <silent> l    <Nop>

    nnoremap <buffer> <silent> q    :call <sid>Quit()<cr>
    nnoremap <buffer> <silent> r    :call <sid>ToggleRecursion()<cr>
    nnoremap <buffer> <silent> d    :call <sid>ToggleBufferDirectories()<cr>
    nnoremap <buffer> <silent> i    :call <sid>ToggleIgnoreCase()<cr>
    nnoremap <buffer> <silent> h    :call <sid>ToggleHidden()<cr>
    nnoremap <buffer> <silent> e    :call <sid>EchoFilesSearched()<cr>

    nnoremap <buffer> <silent> x    :call <sid>SetFilesToExclude()<cr>
    nnoremap <buffer> <silent> c    :call <sid>ToggleCommand()<cr>
    nnoremap <buffer> <silent> w    :call <sid>ToggleWindow()<cr>
    nnoremap <buffer> <silent> m    :call <sid>ToggleReplaceWindowMode()<cr>
    nnoremap <buffer> <silent> o    :call <sid>ToggleOpenWindow()<cr>
    nnoremap <buffer> <silent> g    :call <sid>ToggleEveryMatch()<cr>
    nnoremap <buffer> <silent> p    :call <sid>ToggleJumpToMatch()<cr>
    nnoremap <buffer> <silent> !    :call <sid>ToggleWholeWord()<cr>
    nnoremap <buffer> <silent> *    :call <sid>ToggleFileAssociationsInExplorer()<cr>
    nnoremap <buffer> <silent> s    :call <sid>Sort()<cr>

    nnoremap <buffer> <silent> a    :call <sid>ActivateAll()<cr>
    nnoremap <buffer> <silent> b    :call <sid>ActivateBuffers()<cr>
    nnoremap <buffer> <silent> t    :call <sid>ActivateTracked()<cr>
    nnoremap <buffer> <silent> u    :call <sid>ActivateUser()<cr>

    nnoremap <buffer> <silent> v    :call <sid>EchoGrepCommand()<cr>
    nnoremap <buffer> <silent> \|   :call <sid>EchoOptionsSet()<cr>
    nnoremap <buffer> <silent> ?    :call <sid>ToggleOptionsDisplay()<cr>

endfunction
"}}}
" GrepSetManual {{{
function! s:GrepSetManual(str)
    call s:SetGatewayVariables()
    let str = a:str
    if s:IsRecursivePattern(str)
        call s:Error("User specified grep pattern may not have a recursive specifier")
        call s:ClearGatewayVariables()
        return -1
    endif
    let pos = s:EasyGrepModeUser

    call s:CreateDict()
    let i = s:FindByPattern(str)
    if i != -1
        let s2 = s:Dict[i][1]
        if str == s2
            let pos = i
        else
            let msg = "Pattern '".s:Dict[i][0]."=".s:Dict[i][1]."' matches your input, use this?"
            let response = confirm(msg, "&Yes\n&No")
            if response == 1
                let pos = i
            endif
        endif
    endif

    call s:ClearGatewayVariables()
    return pos
endfunction
"}}}
" }}}
" EasyGrepFileAssociations {{{
" CreateDict {{{
function! s:CreateDict()
    if exists("s:Dict")
        return
    endif

    let s:Dict = [ ]
    call add(s:Dict, [ "All" , "*", g:EasyGrepMode==s:EasyGrepModeAll ? 1 : 0 ] )
    call add(s:Dict, [ "Buffers" , "*Buffers*", g:EasyGrepMode==s:EasyGrepModeBuffers ? 1 : 0  ] )
    call add(s:Dict, [ "TrackExt" , "*", g:EasyGrepMode==s:EasyGrepModeTracked ? 1 : 0  ] )
    call add(s:Dict, [ "User" , "", g:EasyGrepMode==s:EasyGrepModeUser ? 1 : 0  ] )

    if len(s:Dict) != s:EasyGrepNumModes
        call s:InternalFailure("EasyGrep's default settings are not internally consistent; please reinstall")
    endif

    call s:ParseFileAssociationList()
    let s:NumFileAssociations = len(s:Dict) - s:EasyGrepNumModes

endfunction
" }}}
" BreakDown {{{
function! s:BreakDown(keyList)

    " Indicates which keys have already been parsed to avoid multiple entries
    " and infinite recursion
    let s:traversed = repeat([0], len(s:Dict))

    let str = ""
    for k in a:keyList
        let str .= s:DoBreakDown(k)." "
    endfor
    unlet s:traversed
    let str = s:Trim(str)

    return str
endfunction
"}}}
" DoBreakDown {{{
function! s:DoBreakDown(key)
    if s:traversed[a:key] == 1
        return ""
    endif
    let s:traversed[a:key] = 1

    let str = ""
    let patternList = split(s:Dict[a:key][1])
    for p in patternList
        if s:IsLink(p)
            let k = s:FindByKey(s:GetKeyFromLink(p))
            if k != -1
                let str .= s:DoBreakDown(k)
            endif
        else
            let str .= p
        endif
        let str .= ' '
    endfor
    return str
endfunction
"}}}
" CheckLinks {{{
function! s:CheckLinks()
    let i = s:EasyGrepNumModes
    let end = len(s:Dict)
    while i < end
        let patterns = split(s:Dict[i][1])
        let j = 0
        for p in patterns
            if s:IsLink(p) && s:FindByKey(s:GetKeyFromLink(p)) == -1
                call s:Warning("Key(".p.") links to a nonexistent key")
                call remove(patterns, j)
                let j -= 1
            endif
            let j += 1
        endfor

        if empty(patterns)
            call s:Warning("Key(".s:Dict[i][0].") has no valid patterns or links")
            call remove(s:Dict, i)
        else
            let s:Dict[i][1] = join(patterns)
        endif
        let i += 1
    endwhile
endfunction
"}}}
" FindByKey {{{
function! s:FindByKey(key)
    let i = 0
    let numItems = len(s:Dict)
    while i < numItems
        if s:Dict[i][0] ==# a:key
            return i
        endif
        let i += 1
    endwhile
    return -1
endfunction
" }}}
" IsInDict {{{
function! s:IsInDict(pat)
    let i = 0
    let numItems = len(s:Dict)
    while i < numItems
        if s:Dict[i][0] == a:pat
            return 1
        endif
        let i += 1
    endwhile
    return 0
endfunction
" }}}
" GetKeyFromLink {{{
function! s:GetKeyFromLink(str)
    return strpart(a:str, 1, len(a:str)-2)
endfunction
"}}}
" IsLink {{{
function! s:IsLink(str)
    return a:str[0] == '<' && a:str[len(a:str)-1] == '>'
endfunction
" }}}
" ParseFileAssociationList {{{
function! s:ParseFileAssociationList()
    let lst = s:GetFileAssociationList()

    if empty(lst)
        return
    endif

    if !filereadable(lst)
        call s:Error("Grep Pattern file list can't be read")
        return
    endif

    let fileList = readfile(lst)
    if empty(fileList)
        call s:Error("Grep Pattern file list is empty")
        return
    endif

    let lineCounter = 0
    for line in fileList
        let lineCounter += 1
        let line = s:Trim(line)
        if empty(line) || line[0] == "\""
            continue
        endif

        let keys = split(line, "=")
        if len(keys) != 2
            call s:Warning("Invalid line: ".line)
            continue
        endif

        let keys[0] = s:Trim(keys[0])
        let keys[1] = s:Trim(keys[1])

        if empty(keys[0]) || empty(keys[1])
            call s:Warning("Invalid line: ".line)
            continue
        endif

        " No real need to check that keys[0] is well-formed; just about any key
        " is acceptable

        if s:IsInDict(keys[0])
            call s:Warning("Key already added: ".keys[0])
            continue
        endif

        let pList = split(keys[1])
        for p in pList

            " check for invalid filesystem characters.
            if match(p, "[/\\,;']") != -1
                call s:Warning("Invalid pattern (".p.") in line(".lineCounter.")")
                continue
            endif

            if match(p, '[<>]') != -1
                if    s:countstr(p, '<') > 1
                \  || s:countstr(p, '>') > 1
                \  || p[0] != '<'
                \  || p[len(p)-1] != '>'
                    call s:Warning("Invalid link (".p.") in line(".lineCounter.")")
                    continue
                endif
            endif
        endfor

        call add(s:Dict, [ keys[0], keys[1], 0 ] )
    endfor
    call s:CheckLinks()
endfunction
"}}}
" }}}
" Modes {{{
" IsModeAll {{{
function! s:IsModeAll()
    call s:SanitizeMode()
    return g:EasyGrepMode == s:EasyGrepModeAll
endfunction
" }}}
" IsModeBuffers {{{
function! s:IsModeBuffers()
    call s:SanitizeMode()
    return g:EasyGrepMode == s:EasyGrepModeBuffers
endfunction
" }}}
" IsModeTracked {{{
function! s:IsModeTracked()
    call s:SanitizeMode()
    return g:EasyGrepMode == s:EasyGrepModeTracked
endfunction
" }}}
" IsModeUser {{{
function! s:IsModeUser()
    call s:SanitizeMode()
    return g:EasyGrepMode == s:EasyGrepModeUser
endfunction
" }}}
" IsModeMultipleChoice {{{
function! s:IsModeMultipleChoice()
    call s:SanitizeMode()
    return g:EasyGrepMode == s:EasyGrepModeMultipleChoice
endfunction
" }}}
" GetModeName {{{
function! s:GetModeName(mode)
    if a:mode == s:EasyGrepModeAll
        return "All"
    elseif a:mode == s:EasyGrepModeBuffers
        return "Buffers"
    elseif a:mode == s:EasyGrepModeTracked
        return "TrackExt"
    elseif a:mode == s:EasyGrepModeUser
        return "User"
    else
        return "MultiSelect"
    endif
endfunction
" }}}
" SetGrepMode {{{
function! s:SetGrepMode(mode)
    let g:EasyGrepMode = a:mode
endfunction
" }}}
" ForceGrepMode {{{
function! s:ForceGrepMode(mode)
    call s:ClearActivatedItems()
    call s:SetGrepMode(a:mode)
    let s:Dict[a:mode][2] = 1
endfunction
" }}}
" SanitizeMode {{{
function! s:SanitizeMode()
    if s:SanitizeLock
        return
    endif
    let s:SanitizeLock = 1

    " First check the grep command
    if !s:CheckGrepCommandForChanges()
        let s:SanitizeLock = 0
        return
    endif

    " Next ensure that our mode is sensible
    if g:EasyGrepMode < 0 || g:EasyGrepMode >= s:EasyGrepNumModesWithSpecial
        call s:Error("Invalid value for g:EasyGrepMode; reverting to 'All' mode.")
        call s:ForceGrepMode(s:EasyGrepModeAll)
    elseif g:EasyGrepMode == s:EasyGrepModeMultipleChoice
        " This is OK
    elseif s:Dict[g:EasyGrepMode][2] != 1
        " The user switched the mode by explicitly setting the g:EasyGrepMode
        " global variable; make sure to sync up with it
        call s:ForceGrepMode(g:EasyGrepMode)
    endif

    let s:SanitizeLock = 0
endfunction
" }}}
" ValidateGrepCommand {{{
function! s:ValidateGrepCommand()
    if empty(&grepprg)
        call s:Error("Cannot proceed; the 'grepprg' setting is empty while EasyGrep is configured to use the grep command")
        call s:Info("If you are unsure what to do, revert grepprg to it's default with 'set grepprg&'")
        return 0
    endif
    return 1
endfunction
" }}}
" CheckGrepCommandForChanges {{{
function! s:CheckGrepCommandForChanges()
    if &grepprg != s:LastSeenGrepprg
        if s:IsCommandAck()
            if !s:IsModeAll() && !s:IsModeBuffers()
                call s:Info("==================================================================================")
                call s:Info("The 'grepprg' has changed to '".s:GetGrepCommandName()."' since last inspected")
                call s:Info("Switching to 'All' mode as the '".s:GetModeName(g:EasyGrepMode)."' mode is incompatible with this program")
                if !g:EasyGrepRecursive
                    call s:Info("And setting g:EasyGrepRecusive to 'On', as ".s:GetGrepProgramPair()." is inherently recursive")
                    let g:EasyGrepRecursive = 1
                endif
                call s:Info("==================================================================================")
                call s:ForceGrepMode(s:EasyGrepModeAll)
            endif
        endif
        let s:LastSeenGrepprg = &grepprg
        return 0
    endif
    return 1
endfunction
" }}}
" Extension Tracking {{{
" SetCurrentExtension {{{
function! s:SetCurrentExtension()
    call s:CreateDict()
    if !empty(&buftype)
        return
    endif
    let fname = bufname("%")
    if empty(fname)
        return
    endif
    let ext = fnamemodify(fname, ":e")
    if !empty(ext)
        let ext = "*.".ext
    else
        let ext = fnamemodify(fname, ":p:t")
        if(empty(ext))
            return
        endif
    endif
    if !s:IsModeTracked()
        " Always save the extension when not in tracked mode
        let s:TrackedExt = ext

        " Note: this has a very, very, very, small issue (is it even an
        " issue?) where if you're working with C++ files, and you switch to
        " buffers mode, and then edit a file of another type, like .c (which
        " should be in the C++ list), and then switch back to tracked mode,
        " you will lose the C++ association and have to go back to a C++
        " file before being able to search them.
        " This is so small of an issue that it's almost a non-issue, so I'm
        " not going to bother fixing it
    else
        let tempList = split(s:GetPatternList(" ", 0), ' ')

        " When in tracked mode, change the tracked extension if it isn't
        " already in the list of files to be grepped
        if index(tempList, ext) == -1
            let s:TrackedExt = ext
            let s:Dict[s:EasyGrepModeTracked][1] = ext
        endif
    endif
endfunction
"}}}
" SetWatchExtension {{{
function! s:SetWatchExtension()
    augroup EasyGrepAutocommands
        au!
        autocmd BufEnter * call s:SetCurrentExtension()
    augroup END
endfunction
"}}}
" }}}
" }}}
" Selection Functions {{{
" GrepSelection {{{
function! <sid>GrepSelection(add, whole)
    call s:SetGatewayVariables()
    let currSelection=s:GetCurrentSelection()
    if empty(currSelection)
        call s:Warning("No current selection")
        return s:ClearGatewayVariables()
    endif
    call s:DoGrep(currSelection, a:add, a:whole, "", 1)
    return s:ClearGatewayVariables()
endfunction
" }}}
" GrepCurrentWord {{{
function! <sid>GrepCurrentWord(add, whole)
    call s:SetGatewayVariables()
    let currWord=s:GetCurrentWord()
    if empty(currWord)
        call s:Warning("No current word")
        return s:ClearGatewayVariables()
    endif

    call s:CheckIfCurrentFileIsSearched()
    let r = s:DoGrep(currWord, a:add, a:whole, "", 1)
    return s:ClearGatewayVariables()
endfunction
" }}}
" ReplaceSelection {{{
function! <sid>ReplaceSelection(whole)
    call s:SetGatewayVariables()
    let currSelection=s:GetCurrentSelection()
    if empty(currSelection)
        call s:Warning("No current selection")
        return s:ClearGatewayVariables()
    endif

    call s:ReplaceString(currSelection, a:whole, 1)
    return s:ClearGatewayVariables()
endfunction
"}}}
" GetCurrentWord {{{
function! s:GetCurrentWord()
    return expand("<cword>")
endfunction
" }}}
" GetCurrentSelection {{{
function! s:GetCurrentSelection()
    return s:ClearNewline(@")
endfunction
" }}}
" ReplaceCurrentWord {{{
function! <sid>ReplaceCurrentWord(whole)
    call s:SetGatewayVariables()
    let currWord=s:GetCurrentWord()
    if empty(currWord)
        call s:Warning("No current word")
        return s:ClearGatewayVariables()
    endif

    call s:ReplaceString(currWord, a:whole, 1)
    return s:ClearGatewayVariables()
endfunction
"}}}
" }}}
" Command Line Functions {{{
" GrepCommandLine {{{
function! s:GrepCommandLine(argv, add, bang)
    call s:SetGatewayVariables()
    let opts = s:ParseCommandLine(a:argv)
    if !empty(opts["failedparse"])
        let errorstring="Invalid command: ".opts["failedparse"]
        echo errorstring
    else
        call s:SetCommandLineOptions(opts)
        call s:DoGrep(opts["pattern"], a:add, a:bang == "!" ? 1 : 0, opts["count"]>0 ? opts["count"] : "", 0)
        call s:RestoreCommandLineOptions(opts)
    endif
    return s:ClearGatewayVariables()
endfunction
" }}}
" ParseCommandLine {{{
function! s:ParseCommandLine(argv)
    let opts = {}
    let opts["recursive"] = 0
    let opts["case-insensitive"] = g:EasyGrepIgnoreCase
    let opts["case-sensitive"] = 0
    let opts["count"] = 0
    let opts["pattern"] = ""
    let opts["failedparse"] = ""
    let parseopts = 1

    if empty(a:argv)
        return opts
    endif

    let nextiscount = 0
    let tokens = split(a:argv, ' \zs')
    let numtokens = len(tokens)
    let j = 0
    while j < numtokens
        let tok = tokens[j]
        let tok = s:Trim(tok)
        if tok == "--"
            let parseopts = 0
            let j += 1
            continue
        endif
        if tok[0] == '-' && parseopts
            let tok = s:Trim(tok)
            if tok =~ '-[0-9]\+'
                let opts["count"] = tok[1:]
            else
                let i = 1
                let end = len(tok)
                while i < end
                    let c = tok[i]
                    if c == '-'
                        " ignore
                    elseif c ==# 'R' || c==# 'r'
                        let opts["recursive"] = 1
                    elseif c ==# 'i'
                        let opts["case-insensitive"] = 1
                    elseif c ==# 'I'
                        let opts["case-sensitive"] = 1
                    elseif c ==# 'm'
                        let j += 1
                        if j < numtokens
                            let tok = tokens[j]
                            let opts["count"] = tok
                        else
                            let opts["failedparse"] = "Missing argument to -m"
                        endif
                    else
                        let opts["failedparse"] = "Invalid option (".c.")"
                    endif
                    let i += 1
                endwhile
            endif
        else
            if opts["pattern"] != ""
                let opts["pattern"] .= " "
            endif
            let opts["pattern"] .= tok
        endif
        let j += 1
    endwhile

    if !empty(opts["failedparse"])
        return opts
    endif

    if empty(opts["pattern"])
        let opts["failedparse"] = "missing pattern"
    endif

    return opts
endfunction
" }}}
" SetCommandLineOptions {{{
function! s:SetCommandLineOptions(opts)
    let opts = a:opts
    call s:SaveVariable("g:EasyGrepRecursive")
    let g:EasyGrepRecursive = g:EasyGrepRecursive || opts["recursive"]

    call s:SaveVariable("g:EasyGrepIgnoreCase")
    let g:EasyGrepIgnoreCase = (g:EasyGrepIgnoreCase || opts["case-insensitive"]) && !opts["case-sensitive"]
endfunction
" }}}
" RestoreCommandLineOptions {{{
function! s:RestoreCommandLineOptions(opts)
    let opts = a:opts
    call s:RestoreVariable("g:EasyGrepRecursive")
    call s:RestoreVariable("g:EasyGrepIgnoreCase")
endfunction
" }}}
" Replace {{{
function! s:Replace(whole, argv)
    call s:SetGatewayVariables()

    let l = len(a:argv)
    let invalid = 0

    if l == 0
        let invalid = 1
    elseif l > 3 && a:argv[0] == '/'
        let ph = tempname()
        let ph = substitute(ph, '/', '_', 'g')
        let temp = substitute(a:argv, '\\/', ph, "g")
        let l = len(temp)
        if temp[l-1] != '/'
            call s:Error("Missing trailing /")
            let invalid = 1
        elseif stridx(temp, '/', 1) == l-1
            call s:Error("Missing middle /")
            let invalid = 1
        elseif s:countstr(temp, '/') > 3
            call s:Error("Too many /'s, escape these if necessary")
            let invalid = 1
        else
            let argv = split(temp, '/')
            let i = 0
            while i < len(argv)
                let argv[i] = substitute(argv[i], ph, '\\/', 'g')
                let i += 1
            endwhile
        endif
    else
        let argv = split(a:argv)
        if len(argv) != 2
            call s:Error("Too many arguments")
            let invalid = 1
        endif
    endif

    if invalid
        call s:Echo("usage: Replace /target/replacement/ --or-- Replace target replacement")
        return
    endif

    let target = argv[0]
    let replacement = argv[1]

    call s:DoReplace(target, replacement, a:whole, 0)
    return s:ClearGatewayVariables()
endfunction
"}}}
" ReplaceUndo {{{
function! s:ReplaceUndo(bang)
    call s:SetGatewayVariables()
    if !exists("s:actionList")
        call s:Error("No saved actions to undo")
        return s:ClearGatewayVariables()
    endif

    " If either of these variables exists, that means the last command was
    " interrupted; give it another shot
    if !exists(s:GetSavedName("switchbuf")) && !exists(s:GetSavedName("autowriteall"))

        call s:SaveVariable("switchbuf")
        set switchbuf=useopen
        if g:EasyGrepReplaceWindowMode == 2
            call s:SaveVariable("autowriteall")
            set autowriteall
        else
            if g:EasyGrepReplaceWindowMode == 0
                set switchbuf+=usetab
            else
                set switchbuf+=split
            endif
        endif
    endif

    call s:SetErrorList(s:LastErrorList)
    call s:GotoStartErrorList()

    let bufList = s:GetVisibleBuffers()

    let i = 0
    let numItems = len(s:actionList)
    let lastFile = -1

    let finished = 0
    while !finished
        try
            while i < numItems

                let cc          = s:actionList[i][0]
                let off         = s:actionList[i][1]
                let target      = s:actionList[i][2]
                let replacement = s:actionList[i][3]

                if g:EasyGrepReplaceWindowMode == 0
                    let thisFile = s:LastErrorList[cc].bufnr
                    if thisFile != lastFile
                        " only open a new tab when this window isn't already
                        " open
                        if index(bufList, thisFile) == -1
                            if lastFile != -1
                                tabnew
                            endif
                            if g:EasyGrepWindow == 0
                                execute g:EasyGrepWindowPosition." copen"
                            else
                                execute g:EasyGrepWindowPosition." lopen"
                            endif
                            setlocal nofoldenable
                        endif
                    endif
                    let lastFile = thisFile
                endif

                if g:EasyGrepWindow == 0
                    execute "cc ".(cc+1)
                else
                    execute "ll ".(cc+1)
                endif

                " TODO: increase the granularity of the undo to be per-atom
                " TODO: check that replacement is at off

                let thisLine = getline(".")
                let linebeg = strpart(thisLine, 0, off)
                let lineend = strpart(thisLine, off)
                let lineend = substitute(lineend, replacement, target, "")
                let newLine = linebeg.lineend

                call setline(".", newLine)

                let i += 1
            endwhile
            let finished = 1
        catch /^Vim(\a\+):E36:/
            redraw
            call s:Warning("Ran out of room for more windows")
            let finished = confirm("Do you want to save all windows and continue?", "&Yes\n&No")-1
            if finished == 1
                call s:Warning("To continue, save unsaved windows, make some room (try :only) and run ReplaceUndo again")
                return
            else
                wall
                only
            endif
        catch /^Vim:Interrupt$/
            redraw
            call s:Warning("Undo interrupted by user; state is not guaranteed")
            let finished = confirm("Are you sure you want to stop the undo?", "&Yes\n&No")-1
            let finished = !finished
        catch
            redraw
            echo v:exception
            call s:Warning("Undo interrupted; state is not guaranteed")
            let finished = confirm("Do you want to continue undoing?", "&Yes\n&No")-1
        endtry
    endwhile

    call s:RestoreVariable("switchbuf")
    call s:RestoreVariable("autowriteall")

    unlet s:actionList
    unlet s:LastErrorList
    return s:ClearGatewayVariables()
endfunction
"}}}
" }}}
" Grep Implementation {{{
" SetGrepVariables{{{
function! s:SetGrepVariables(command)
    if s:IsCommandVimgrep()
        call s:SaveVariable("ignorecase")
        let &ignorecase = g:EasyGrepIgnoreCase
    endif
endfunction
"}}}
" RestoreGrepVariables{{{
function! s:RestoreGrepVariables()
    call s:RestoreVariable("ignorecase")
endfunction
"}}}
" CommandSupportsExclusions {{{
function! s:CommandSupportsExclusions()
    return s:IsCommandAck() || s:IsCommandGrep()
endfunction
"}}}
" IsCommandVimgrep {{{
function! s:IsCommandVimgrep()
    return (s:GetGrepCommandName() == "vimgrep")
endfunction
"}}}
" IsCommandAck {{{
function! s:IsCommandAck()
    return !s:IsCommandVimgrep() && (s:GetGrepProgramName() == "ack" || s:GetGrepProgramName() == "ack-grep" || s:GetGrepProgramName() == "ag")
endfunction
"}}}
" IsCommandFindstr {{{
function! s:IsCommandFindstr()
    return !s:IsCommandVimgrep() && (s:GetGrepProgramName() == "findstr")
endfunction
"}}}
" IsCommandGrep {{{
function! s:IsCommandGrep()
    return !s:IsCommandVimgrep() && (s:GetGrepProgramName() == "grep")
endfunction
"}}}
" GetGrepCommandLine{{{
function! s:GetGrepCommandLine(word, add, whole, count, escapeArgs)
    let com = s:GetGrepCommandName()

    let commandIsVimgrep = s:IsCommandVimgrep()
    let commandIsGrep = s:IsCommandGrep()
    let commandIsFindstr = s:IsCommandFindstr()
    let commandIsAck = s:IsCommandAck()

    let s1 = ""
    let s2 = ""
    if commandIsVimgrep
        let s1 = "/"
        let s2 = "/"

        if g:EasyGrepEveryMatch
            let s2 .= "g"
        endif

        if g:EasyGrepJumpToMatch
            let s2 .= "j"
        endif
    else
        if !g:EasyGrepJumpToMatch
            let com .= "!"
        endif
    endif

    let opts = ""

    if g:EasyGrepInvertWholeWord
        let whole = !a:whole
    else
        let whole = a:whole
    endif

    let word = a:escapeArgs ? s:EscapeSpecial(a:word) : a:word
    if commandIsGrep || commandIsAck
        let word = "\"".word."\""
    endif

    if whole
        if commandIsVimgrep
            let word = "\\<".word."\\>"
        elseif commandIsGrep || commandIsAck
            let word = "-w ".word
        elseif commandIsFindstr
            let word = "\"\\<".word."\\>\""
        endif
    endif

    if g:EasyGrepRecursive
        if commandIsGrep
            let opts .= "-R "
        elseif commandIsFindstr
            let opts .= "/S "
        elseif commandIsAck
            " do nothing
        endif
    endif

    if g:EasyGrepIgnoreCase
        if commandIsGrep || commandIsAck
            let opts .= "-i "
        elseif commandIsFindstr
            let opts .= "/I "
        endif
    else
        if commandIsFindstr
            let opts .= "/i "
        endif
    endif

    if commandIsGrep && g:EasyGrepRecursive
        " TODO: clean this up. This is a temporary hack to prevent buffer
        " directories from being added to the filesToGrep string
        call s:SaveVariable("g:EasyGrepSearchCurrentBufferDir")
        let g:EasyGrepSearchCurrentBufferDir = 0
    endif

    let filesToGrep = s:BuildListOfFilesToGrep()
    let filesToExclude = g:EasyGrepFilesToExclude

    " Set extra inclusions and exclusions
    if commandIsGrep
        " Ignore errors
        let opts .= "-s"

        " Specific inclusions are only set in recursive mode
        if g:EasyGrepRecursive
            call s:RestoreVariable("g:EasyGrepSearchCurrentBufferDir")
            " The --include paths will contain the file patterns
            let opts .= " " . join(map(split(filesToGrep, ' '), '"--include=\"" .v:val."\""'), ' ')
            if g:EasyGrepSearchCurrentBufferDir
                let dirs = s:GetRecursiveMinimalSetList()
            else
                let dirs = [ getcwd() ]
            endif
            " the files we specify will be directories
            let filesToGrep = join(dirs, ' ')
        endif

        let opts .= " " . join(map(split(filesToExclude, ','), '"--exclude=\"".v:val."\""." --exclude-dir=\"".v:val."\""'), ' ')
    elseif commandIsAck
        " Patch up the command line in a way that ack understands
        " 1) Replace a leading star with the current directory
        let filesToGrep = substitute(filesToGrep, "^\*", getcwd(), "")
        " 2) Replace all trailing stars with a space
        let filesToGrep = substitute(filesToGrep, '/\*', "", "g")

        " Add exclusions
        let opts .= " " . join(map(split(filesToExclude, ','), '"--ignore-dir=\"".v:val."\""'), ' ')
    endif

    if commandIsAck || commandIsFindstr
        let filesToGrep = s:RemovePatternsWithNoFiles(filesToGrep, ' ')
    endif

    if commandIsFindstr
        let filesToGrep=s:ForwardToBackSlash(filesToGrep)
    endif

    let win = g:EasyGrepWindow != 0 ? "l" : ""
    let grepCommand = a:count.win.com.a:add." ".opts." ".s1.word.s2." ".filesToGrep

    return grepCommand
endfunction
"}}}
" HasTargetsThatMatch {{{
function! s:HasTargetsThatMatch(word)
    call s:CheckIfCurrentFileIsSearched()

    if s:IsModeBuffers() && empty(s:FilesToGrep)
        call s:Warning("No saved buffers to explore")
        return 0
    endif

    if g:EasyGrepExtraWarnings && !g:EasyGrepRecursive
        " Don't evaluate if in recursive mode, this will take too long
        if !s:HasFilesThatMatch()
            call s:WarnNoMatches(a:word)
            return 0
        endif
    endif

    return 1
endfunction

" }}}
" DoGrep {{{
function! s:DoGrep(word, add, whole, count, escapeArgs)
    call s:CreateDict()

    if s:OptionsExplorerOpen == 1
        call s:Error("Error: Can't Grep while options window is open")
        return 0
    endif

    call s:BuildListOfFilesToGrep()
    if !s:HasTargetsThatMatch(a:word)
        return 0
    endif

    let commandName = s:GetGrepCommandName()
    if !s:ValidateGrepCommand()
        return 0
    endif

    call s:SetGrepVariables(commandName)
    let grepCommand = s:GetGrepCommandLine(a:word, a:add, a:whole, a:count, a:escapeArgs)

    let failed = 0
    try
        if g:EasyGrepRecursive
            call s:Info("Running a recursive search, this may take a while")
        endif

        silent execute grepCommand
    catch
        if v:exception != 'E480'
            call s:WarnNoMatches(a:word)
            try
                " go to the last error list on no matches
                if g:EasyGrepWindow == 0
                    silent colder
                else
                    silent lolder
                endif
            catch
            endtry
        else
            call s:Error("FIXME: exception not caught ".v:exception)
        endif
        let failed = 1
    endtry

    call s:RestoreGrepVariables()
    if failed
        return 0
    endif

    if s:HasGrepResults()
        if g:EasyGrepOpenWindowOnMatch
            if g:EasyGrepWindow == 0
                execute g:EasyGrepWindowPosition." copen"
            else
                execute g:EasyGrepWindowPosition." lopen"
            endif
            setlocal nofoldenable
        endif
    else
        call s:WarnNoMatches(a:word)
        return 0
    endif

    return 1
endfunction
" }}}
" HasGrepResults{{{
function! s:HasGrepResults()
    return !empty(s:GetErrorList())
endfunction
"}}}
" HasFilesThatMatch{{{
function! s:HasFilesThatMatch()
    let saveFilesToGrep = s:FilesToGrep

    call s:BuildListOfFilesToGrep("\n")
    let patternList = split(s:FilesToGrep, "\n")
    for p in patternList
        let p = s:Trim(p)
        let fileList = split(glob(p), "\n")
        for f in fileList
            if filereadable(f)
                let s:FilesToGrep = saveFilesToGrep
                return 1
            endif
        endfor
    endfor

    let s:FilesToGrep = saveFilesToGrep
    return 0
endfunction
"}}}
" RemovePatternsWithNoFiles {{{
function! s:RemovePatternsWithNoFiles(files, sep)
    let files = a:files
    let newList = ""

    let patternList = split(files, a:sep)
    for p in patternList
        let p = s:Trim(p)
        let globbedList = glob(p)
        if globbedList != ""
            let newList = newList.a:sep.p
        endif
    endfor

    return newList
endfunction
"}}}
" WarnNoMatches {{{
function! s:WarnNoMatches(pattern)
    if s:IsModeBuffers()
        let fpat = "*Buffers*"
    elseif s:IsModeAll()
        let fpat = "*"
    else
        let fpat = s:GetPatternList(" ", 0)
    endif

    let r = g:EasyGrepRecursive ? " (+Recursive)" : ""
    let h = g:EasyGrepHidden    ? " (+Hidden)"    : ""

    redraw
    call s:Warning("No matches for '".a:pattern."'")
    call s:Warning("File Pattern: ".fpat.r.h)

    let dirs = s:GetDirectorySearchList()
    let s = "Directories:"
    for d in dirs
        call s:Warning(s." ".d)
        let s = "            "
    endfor
    if !empty(g:EasyGrepFilesToExclude) && s:CommandSupportsExclusions()
        call s:Warning("Exclusions:  ".g:EasyGrepFilesToExclude)
    endif
endfunction
" }}}
" }}}
" Replace Implementation {{{
" ReplaceString {{{
function! s:ReplaceString(str, whole, escapeArgs)
    call s:CheckIfCurrentFileIsSearched()
    let r = input("Replace '".a:str."' with: ", a:str)
    if empty(r)
        let confirmed = confirm("Proceed replacing '".a:str."' with an empty pattern, effectively deleting it?", "&Yes\n&No")-1
        if confirmed
            return
        endif
    endif
    if r == a:str
        call s:Echo("No change in pattern")
        return
    endif

    call s:DoReplace(a:str, r, a:whole, a:escapeArgs)
endfunction
"}}}
" DoReplace {{{
function! s:DoReplace(target, replacement, whole, escapeArgs)

    if !s:DoGrep(a:target, "", a:whole, "", a:escapeArgs)
        return
    endif

    let target = a:escapeArgs ? s:EscapeSpecial(a:target) : a:target
    let replacement = a:replacement

    let s:LastErrorList = deepcopy(s:GetErrorList())
    let numMatches = len(s:LastErrorList)

    let s:actionList = []

    call s:SaveVariable("switchbuf")
    set switchbuf=useopen
    if g:EasyGrepReplaceWindowMode == 2
        call s:SaveVariable("autowriteall")
        set autowriteall
    else
        if g:EasyGrepReplaceWindowMode == 0
            set switchbuf+=usetab
        else
            set switchbuf+=split
        endif
    endif

    let bufList = s:GetVisibleBuffers()

    call s:GotoStartErrorList()

    call s:SaveVariable("ignorecase")
    let &ignorecase = g:EasyGrepIgnoreCase

    call s:SaveVariable("cursorline")
    set cursorline
    call s:SaveVariable("hlsearch")
    set hlsearch

    if g:EasyGrepIgnoreCase
        let case = '\c'
    else
        let case = '\C'
    endif

    if g:EasyGrepInvertWholeWord
        let whole = !a:whole
    else
        let whole = a:whole
    endif

    if whole
        let target = "\\<".target."\\>"
    endif

    let finished = 0
    let lastFile = -1
    let doAll = 0
    let i = 0
    while i < numMatches && !finished
        try
            let pendingQuit = 0
            let doit = 1

            let thisFile = s:LastErrorList[i].bufnr
            if thisFile != lastFile
                call s:RestoreVariable("cursorline", "no")
                call s:RestoreVariable("hlsearch", "no")
                if g:EasyGrepReplaceWindowMode == 0
                    " only open a new tab when the window doesn't already exist
                    if index(bufList, thisFile) == -1
                        if lastFile != -1
                            tabnew
                        endif
                        if g:EasyGrepWindow == 0
                            execute g:EasyGrepWindowPosition." copen"
                        else
                            execute g:EasyGrepWindowPosition." lopen"
                        endif
                        setlocal nofoldenable
                    endif
                endif
                if doAll && g:EasyGrepReplaceAllPerFile
                    let doAll = 0
                endif
            endif

            if g:EasyGrepWindow == 0
                execute "cc ".(i+1)
            else
                execute "ll ".(i+1)
            endif

            if thisFile != lastFile
                set cursorline
                set hlsearch
            endif
            let lastFile = thisFile

            if foldclosed(".") != -1
                foldopen!
            endif

            let thisLine = getline(".")
            let off = match(thisLine,case.target, 0)
            while off != -1

                " this highlights the match; it seems to be a simpler solution
                " than matchadd()
                let linebeg = strpart(thisLine, 0, off)
                let m = matchstr(thisLine,case.target, off)
                let lineafterm = strpart(thisLine, off+strlen(m))

                let linebeg = s:EscapeSpecial(linebeg)
                let m = s:EscapeSpecial(m)
                let lineafterm = s:EscapeSpecial(lineafterm)

                silent exe "s/".linebeg."\\zs".case.m."\\ze".lineafterm."//ne"

                if !doAll

                    redraw!
                    echohl Type | echo "replace with ".a:replacement." (y/n/a/q/l/^E/^Y)?"| echohl None
                    let ret = getchar()

                    if ret == 5
                        if winline() > &scrolloff+1
                            normal 
                        endif
                        continue
                    elseif ret == 25
                        if (winheight(0)-winline()) > &scrolloff
                            normal 
                        endif
                        continue
                    elseif ret == 27
                        let doit = 0
                        let pendingQuit = 1
                    else
                        let ret = nr2char(ret)

                        if ret == '<cr>'
                            continue
                        elseif ret == 'y'
                            let doit = 1
                        elseif ret == 'n'
                            let doit = 0
                        elseif ret == 'a'
                            let doit = 1
                            let doAll = 1
                        elseif ret == 'q'
                            let doit = 0
                            let pendingQuit = 1
                        elseif ret == 'l'
                            let doit = 1
                            let pendingQuit = 1
                        else
                            continue
                        endif
                    endif
                endif

                if doit
                    let linebeg = strpart(thisLine, 0, off)
                    let lineend = strpart(thisLine, off)
                    let newend = substitute(lineend, target, replacement, "")
                    let newLine = linebeg.newend
                    call setline(".", newLine)

                    let replacedText = matchstr(lineend, target)
                    let remainder = substitute(lineend, target, "", "")
                    let replacedWith = strpart(newend, 0, strridx(newend, remainder))

                    let action = [i, off, replacedText, replacedWith]
                    call add(s:actionList, action)
                endif

                if pendingQuit
                    break
                endif

                let thisLine = getline(".")
                let m = matchstr(thisLine,target, off)
                let off = match(thisLine,target,off+strlen(m))

                " matching at the end of line should exit here to avoid infinite loops
                if off == len(thisLine)
                    let off = -1
                endif
            endwhile

            if pendingQuit
                break
            endif

        catch /^Vim(\a\+):E36:/
            redraw
            call s:Warning("Ran out of room for more windows")
            let finished = confirm("Do you want to save all windows and continue?", "&Yes\n&No")-1
            if finished == 1
                call s:Warning("To continue, save unsaved windows, make some room (try :only) and run Replace again")
            else
                wall
                only
            endif
        catch /^Vim:Interrupt$/
            redraw
            call s:Warning("Replace interrupted by user")
            let finished = confirm("Are you sure you want to stop the replace?", "&Yes\n&No")-1
            let finished = !finished
        catch
            redraw
            echo "Exception encountered: ".v:exception
            call s:Warning("Replace interrupted")
            let finished = confirm("Do you want to continue replace?", "&Yes\n&No")-1
        endtry

        let i += 1

    endwhile

    call s:RestoreVariable("switchbuf")
    call s:RestoreVariable("autowriteall")
    call s:RestoreVariable("cursorline")
    call s:RestoreVariable("hlsearch")
    call s:RestoreVariable("ignorecase")
endfunction
"}}}
" }}}
" ResultList Functions {{{
" GetErrorList {{{
function! s:GetErrorList()
    if g:EasyGrepWindow == 0
        return getqflist()
    else
        return getloclist(0)
    endif
endfunction
"}}}
" GetErrorListName {{{
function! s:GetErrorListName()
    if g:EasyGrepWindow == 0
        return 'quickfix'
    else
        return 'location list'
    endif
endfunction
"}}}
" SetErrorList {{{
function! s:SetErrorList(lst)
    if g:EasyGrepWindow == 0
        call setqflist(a:lst)
    else
        call setloclist(0,a:lst)
    endif
endfunction
"}}}
" GotoStartErrorList {{{
function! s:GotoStartErrorList()
    if g:EasyGrepWindow == 0
        cfirst
    else
        lfirst
    endif
endfunction
"}}}
" ResultListFilter {{{
function! s:ResultListFilter(...)
    let mode = 'g'

    let filterlist = []
    for s in a:000
        if s[0] == '-'
            if s == '-v'
                let mode = 'v'
            elseif s == '-g'
                if mode == 'v'
                    call s:Error("Multiple -v / -g arguments given")
                    return
                endif
                let mode = 'g'
            else
                call s:Error("Invalid command line switch")
                return
            endif
        else
            call add(filterlist, s)
        endif
    endfor

    if empty(filterlist)
        call s:Error("Missing pattern to filter")
        return
    endif

    let lst = s:GetErrorList()
    if empty(lst)
        call s:Error("Error list is empty")
        return
    endif

    let newlst = []
    for d in lst
        let matched = 0
        for f in filterlist
            let r = match(d.text, f)
            if mode == 'g'
                let matched = (r != -1)
            else
                let matched = (r == -1)
            endif
            if matched == 1
                call add(newlst, d)
                break
            endif
        endfor
    endfor

    call s:SetErrorList(newlst)
endfunction
"}}}
" ResultListOpen {{{
function! s:ResultListOpen(...)
    let lst = s:GetErrorList()

    if empty(lst)
        call s:Error("Error list is empty")
        return
    endif

    let lastbnum = -1
    for item in lst
        if item.bufnr != lastbnum
            exe "tabnew ".bufname(item.bufnr)
            let lastbnum = item.bufnr
        endif
    endfor
endfunction
"}}}
" ResultListDo {{{
function! s:ResultListDo(command)
    let lst = s:GetErrorList()
    if empty(lst)
        call s:Error("Error list is empty")
        return
    endif

    let numMatches = len(lst)

    call s:SaveVariable("switchbuf")
    set switchbuf=useopen
    if g:EasyGrepReplaceWindowMode == 2
        call s:SaveVariable("autowriteall")
        set autowriteall
    else
        if g:EasyGrepReplaceWindowMode == 0
            set switchbuf+=usetab
        else
            set switchbuf+=split
        endif
    endif

    let bufList = s:GetVisibleBuffers()

    call s:GotoStartErrorList()

    call s:SaveVariable("cursorline")
    set cursorline

    let finished = 0
    let lastFile = -1
    let doAll = 0
    let i = 0
    while i < numMatches && !finished
        try
            let pendingQuit = 0
            let doit = 1

            let thisFile = lst[i].bufnr
            if thisFile != lastFile
                call s:RestoreVariable("cursorline", "no")
                if g:EasyGrepReplaceWindowMode == 0
                    " only open a new tab when the window doesn't already exist
                    if index(bufList, thisFile) == -1
                        if lastFile != -1
                            tabnew
                        endif
                        if g:EasyGrepWindow == 0
                            execute g:EasyGrepWindowPosition." copen"
                        else
                            execute g:EasyGrepWindowPosition." lopen"
                        endif
                        setlocal nofoldenable
                    endif
                endif
                if doAll && g:EasyGrepReplaceAllPerFile
                    let doAll = 0
                endif
            endif

            if g:EasyGrepWindow == 0
                execute "cc ".(i+1)
            else
                execute "ll ".(i+1)
            endif

            if thisFile != lastFile
                set cursorline
            endif
            let lastFile = thisFile

            if foldclosed(".") != -1
                foldopen!
            endif

            if !doAll

                redraw!
                echohl Type | echo "run ".a:command." (y/n/a/q/l/^E/^Y)?"| echohl None
                let ret = getchar()

                if ret == 5
                    if winline() > &scrolloff+1
                        normal 
                    endif
                    continue
                elseif ret == 25
                    if (winheight(0)-winline()) > &scrolloff
                        normal 
                    endif
                    continue
                elseif ret == 27
                    let doit = 0
                    let pendingQuit = 1
                else
                    let ret = nr2char(ret)

                    if ret == '<cr>'
                        continue
                    elseif ret == 'y'
                        let doit = 1
                    elseif ret == 'n'
                        let doit = 0
                    elseif ret == 'a'
                        let doit = 1
                        let doAll = 1
                    elseif ret == 'q'
                        let doit = 0
                        let pendingQuit = 1
                    elseif ret == 'l'
                        let doit = 1
                        let pendingQuit = 1
                    else
                        continue
                    endif
                endif
            endif

            if doit
                exe .a:command
            endif

            if pendingQuit
                break
            endif

        catch /^Vim(\a\+):E36:/
            redraw
            call s:Warning("Ran out of room for more windows")
            let finished = confirm("Do you want to save all windows and continue?", "&Yes\n&No")-1
            if finished == 1
                call s:Warning("To continue, save unsaved windows, make some room (try :only) and run Replace again")
            else
                wall
                only
            endif
        catch /^Vim:Interrupt$/
            redraw
            call s:Warning("ResultListDo interrupted by user")
            let finished = confirm("Are you sure you want to stop the ResultListDo?", "&Yes\n&No")-1
            let finished = !finished
        catch
            redraw
            echo "Exception encountered: ".v:exception
            call s:Warning("ResultListDo interrupted")
            let finished = confirm("Do you want to continue ResultListDo?", "&Yes\n&No")-1
        endtry

        let i += 1

    endwhile

    call s:RestoreVariable("switchbuf")
    call s:RestoreVariable("autowriteall")
    call s:RestoreVariable("cursorline")

endfunction
"}}}
" }}}
" }}}

" Commands {{{
command! -bang -nargs=+ Grep :call s:GrepCommandLine( <q-args> , "", "<bang>")
command! -bang -nargs=+ GrepAdd :call s:GrepCommandLine( <q-args>, "add", "<bang>")
command! GrepOptions :call <sid>GrepOptions()

command! -bang -nargs=+ Replace :call s:Replace("<bang>", <q-args>)
command! -bang ReplaceUndo :call s:ReplaceUndo("<bang>")

command! -nargs=0 ResultListOpen :call s:ResultListOpen()
command! -nargs=+ ResultListFilter :call s:ResultListFilter(<f-args>)
command! -nargs=+ ResultListDo :call s:ResultListDo(<q-args>)
"}}}
" Keymaps {{{
if !hasmapto("<plug>EgMapGrepOptions")
    map <silent> <Leader>vo <plug>EgMapGrepOptions
endif
if !hasmapto("<plug>EgMapGrepCurrentWord_v")
    map <silent> <Leader>vv <plug>EgMapGrepCurrentWord_v
endif
if !hasmapto("<plug>EgMapGrepSelection_v")
    vmap <silent> <Leader>vv <plug>EgMapGrepSelection_v
endif
if !hasmapto("<plug>EgMapGrepCurrentWord_V")
    map <silent> <Leader>vV <plug>EgMapGrepCurrentWord_V
endif
if !hasmapto("<plug>EgMapGrepSelection_V")
    vmap <silent> <Leader>vV <plug>EgMapGrepSelection_V
endif
if !hasmapto("<plug>EgMapGrepCurrentWord_a")
    map <silent> <Leader>va <plug>EgMapGrepCurrentWord_a
endif
if !hasmapto("<plug>EgMapGrepSelection_a")
    vmap <silent> <Leader>va <plug>EgMapGrepSelection_a
endif
if !hasmapto("<plug>EgMapGrepCurrentWord_A")
    map <silent> <Leader>vA <plug>EgMapGrepCurrentWord_A
endif
if !hasmapto("<plug>EgMapGrepSelection_A")
    vmap <silent> <Leader>vA <plug>EgMapGrepSelection_A
endif
if !hasmapto("<plug>EgMapReplaceCurrentWord_r")
    map <silent> <Leader>vr <plug>EgMapReplaceCurrentWord_r
endif
if !hasmapto("<plug>EgMapReplaceSelection_r")
    vmap <silent> <Leader>vr <plug>EgMapReplaceSelection_r
endif
if !hasmapto("<plug>EgMapReplaceCurrentWord_R")
    map <silent> <Leader>vR <plug>EgMapReplaceCurrentWord_R
endif
if !hasmapto("<plug>EgMapReplaceSelection_R")
    vmap <silent> <Leader>vR <plug>EgMapReplaceSelection_R
endif

if !exists("g:EasyGrepMappingsSet")
    nmap <silent> <unique> <script> <plug>EgMapGrepOptions          :call <sid>GrepOptions()<CR>
    nmap <silent> <unique> <script> <plug>EgMapGrepCurrentWord_v    :call <sid>GrepCurrentWord("", 0)<CR>
    vmap <silent> <unique> <script> <plug>EgMapGrepSelection_v     y:call <sid>GrepSelection("", 0)<CR>
    nmap <silent> <unique> <script> <plug>EgMapGrepCurrentWord_V    :call <sid>GrepCurrentWord("", 1)<CR>
    vmap <silent> <unique> <script> <plug>EgMapGrepSelection_V     y:call <sid>GrepSelection("", 1)<CR>
    nmap <silent> <unique> <script> <plug>EgMapGrepCurrentWord_a    :call <sid>GrepCurrentWord("add", 0)<CR>
    vmap <silent> <unique> <script> <plug>EgMapGrepSelection_a     y:call <sid>GrepSelection("add", 0)<CR>
    nmap <silent> <unique> <script> <plug>EgMapGrepCurrentWord_A    :call <sid>GrepCurrentWord("add", 1)<CR>
    vmap <silent> <unique> <script> <plug>EgMapGrepSelection_A     y:call <sid>GrepSelection("add", 1)<CR>
    nmap <silent> <unique> <script> <plug>EgMapReplaceCurrentWord_r :call <sid>ReplaceCurrentWord(0)<CR>
    vmap <silent> <unique> <script> <plug>EgMapReplaceSelection_r  y:call <sid>ReplaceSelection(0)<CR>
    nmap <silent> <unique> <script> <plug>EgMapReplaceCurrentWord_R :call <sid>ReplaceCurrentWord(1)<CR>
    vmap <silent> <unique> <script> <plug>EgMapReplaceSelection_R  y:call <sid>ReplaceSelection(1)<CR>

    let g:EasyGrepMappingsSet = 1
endif

"}}}
" User Options {{{
function! s:InitializeMode()
    if !exists("g:EasyGrepMode")
        let g:EasyGrepMode=s:EasyGrepModeAll
        " 0 - All
        " 1 - Buffers
        " 2 - Track
        " 3 - User
    else
        if g:EasyGrepMode < 0 || g:EasyGrepMode >= s:EasyGrepNumModes
            call s:Error("Invalid value for g:EasyGrepMode; reverting to 'All' mode.")
            let g:EasyGrepMode = s:EasyGrepModeAll
        endif
    endif
endfunction

if !exists("g:EasyGrepCommand")
    let g:EasyGrepCommand=0
endif

if !exists("g:EasyGrepRecursive")
    let g:EasyGrepRecursive=0
endif

if !exists("g:EasyGrepIgnoreCase")
    let g:EasyGrepIgnoreCase=&ignorecase
endif

if !exists("g:EasyGrepHidden")
    let g:EasyGrepHidden=0
endif

if !exists("g:EasyGrepAllOptionsInExplorer")
    let g:EasyGrepAllOptionsInExplorer=0
endif

if !exists("g:EasyGrepWindow")
    let g:EasyGrepWindow=0
endif

if !exists("g:EasyGrepOpenWindowOnMatch")
    let g:EasyGrepOpenWindowOnMatch=1
endif

if !exists("g:EasyGrepEveryMatch")
    let g:EasyGrepEveryMatch=0
endif

if !exists("g:EasyGrepJumpToMatch")
    let g:EasyGrepJumpToMatch=1
endif

if !exists("g:EasyGrepSearchCurrentBufferDir")
    let g:EasyGrepSearchCurrentBufferDir=1
endif

if !exists("g:EasyGrepInvertWholeWord")
    let g:EasyGrepInvertWholeWord=0
endif

" EasyGrepFileAssociations {{{
function! s:GetFileAssociationList()
    if exists("g:EasyGrepFileAssociations")
        return g:EasyGrepFileAssociations
    endif

    let VimfilesDirs=split(&runtimepath, ',')
    for v in VimfilesDirs
        let f = s:BackToForwardSlash(v)."/plugin/EasyGrepFileAssociations"
        if filereadable(f)
            let g:EasyGrepFileAssociations=f
            return f
        endif
    endfor

    call s:Error("Grep Pattern file list can't be read")
    let g:EasyGrepFileAssociations=""
    return ""
endfunction
" }}}

if !exists("g:EasyGrepFileAssociationsInExplorer")
    let g:EasyGrepFileAssociationsInExplorer=0
endif

if !exists("g:EasyGrepOptionPrefix")
    let g:EasyGrepOptionPrefix='<leader>vy'
    " Note: I picked a default option prefix of vy because I find it easy to type.
endif

if !exists("g:EasyGrepReplaceWindowMode")
    let g:EasyGrepReplaceWindowMode=0
else
    if g:EasyGrepReplaceWindowMode >= s:NumReplaceModeOptions
        call s:Error("Invalid value for g:EasyGrepReplaceWindowMode")
        let g:EasyGrepReplaceWindowMode = 0
    endif
endif

if !exists("g:EasyGrepReplaceAllPerFile")
    let g:EasyGrepReplaceAllPerFile=0
endif

if !exists("g:EasyGrepExtraWarnings")
    let g:EasyGrepExtraWarnings=1
endif

if !exists("g:EasyGrepWindowPosition")
    let g:EasyGrepWindowPosition=""
else
    let w = g:EasyGrepWindowPosition
    if w != ""
\   && w != "vertical"
\   && w != "leftabove"
\   && w != "aboveleft"
\   && w != "rightbelow"
\   && w != "belowright"
\   && w != "topleft"
\   && w != "botright"
       call s:Error("Invalid position specified in g:EasyGrepWindowPosition")
       let g:EasyGrepWindowPosition=""
   endif
endif

if !exists("g:EasyGrepFilesToExclude")
    let g:EasyGrepFilesToExclude=""
endif

" EasyGrepDefaultUserPattern {{{
function! s:CheckDefaultUserPattern()
    call s:CreateDict()
    let error = ""
    let userModeAndEmpty = (g:EasyGrepMode == s:EasyGrepModeUser) && empty(s:Dict[s:EasyGrepModeUser][1])
    if exists("g:EasyGrepDefaultUserPattern")
        if empty(g:EasyGrepDefaultUserPattern) && userModeAndEmpty
            let error = "Cannot start in 'User' mode when g:EasyGrepDefaultUserPattern is empty"
            call s:ForceGrepMode(s:EasyGrepModeAll)
        elseif s:IsRecursivePattern(g:EasyGrepDefaultUserPattern)
            let error = "User specified grep pattern may not have a recursive specifier"
        else
            let s:Dict[s:EasyGrepModeUser][1] = g:EasyGrepDefaultUserPattern
        endif
    elseif userModeAndEmpty
        let error = "Cannot start in 'User' mode when g:EasyGrepDefaultUserPattern is undefined"
        call s:ForceGrepMode(s:EasyGrepModeAll)
    endif

    if !empty(error)
        let error = error."; switching to 'All' mode"
        call s:Error(error)
        call s:ForceGrepMode(s:EasyGrepModeAll)
    endif
endfunction
"}}}

"}}}
" Script Finalization {{{
call s:InitializeCommandChoice()
call s:InitializeMode()
call s:CreateOptionMappings()
call s:SetWatchExtension()
call s:CheckDefaultUserPattern()
"}}}

