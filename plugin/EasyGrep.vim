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
" Version:       2.0 -- Programs can inspect g:EasyGrepVersion

" Initialization {{{
if exists("g:EasyGrepVersion") || &cp || !has("quickfix")
    finish
endif
let g:EasyGrepVersion = "2.0"
" Check for Vim version 700 or greater {{{
if v:version < 700
    echo "Sorry, EasyGrep ".g:EasyGrepVersion." ONLY runs with Vim 7.0 and greater."
    finish
endif
" }}}
" }}}

" Internals {{{
" Script Variables {{{
let s:EasyGrepSourceFile=expand("<sfile>")
let s:EasyGrepModeAll=0
let s:EasyGrepModeBuffers=1
let s:EasyGrepModeTracked=2
let s:EasyGrepModeUser=3
let s:EasyGrepNumModes=4
let s:EasyGrepRepositoryList="search:.git,.hg,.svn"

" This is a special mode
let s:EasyGrepModeMultipleChoice=4
let s:EasyGrepNumModesWithSpecial = 5

let s:NumReplaceModeOptions = 3

let s:OptionsExplorerOpen = 0

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
let s:LastSeenGrepprg = &grepprg
function! s:InitializeCommandChoice()
    let result = s:SetGrepCommand(g:EasyGrepCommand)
    if !result
        call EasyGrep#Error("Invalid option to g:EasyGrepCommand")
    endif
endfunction
let s:CurrentFileCurrentDirChecked = 0
let s:SanitizeModeLock = 0

" SetGatewayVariables {{{
function! s:SetGatewayVariables()
    echo
    call EasyGrep#SaveVariable("lazyredraw")
    set lazyredraw
endfunction
" }}}
" ClearGatewayVariables {{{
function! s:ClearGatewayVariables()
    let s:CurrentFileCurrentDirChecked = 0
    call EasyGrep#RestoreVariable("lazyredraw")
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
" EchoNewline {{{
function! <sid>EchoNewline()
    echo " "
endfunction
"}}}
" EscapeDirIfSpace {{{
function! s:EscapeDirIfSpace(dir)
    return match(a:dir, ' ') == -1 ? a:dir : EasyGrep#ShellEscape(a:dir)
endfunction
"}}}
" DoEscapeSpecialCharacters {{{
function! s:DoEscapeSpecialCharacters(str, escapeonce, escapetwice)
    let str = a:str

    let i = 0
    let len = strlen(a:escapeonce)
    while i < len
        let str = escape(str, a:escapeonce[i])
        let i += 1
    endwhile

    let i = 0
    let len = strlen(a:escapetwice)
    while i < len
        let str = escape(str, a:escapetwice[i])
        let str = escape(str, a:escapetwice[i])
        let i += 1
    endwhile

    return str
endfunction
"}}}
" EscapeSpecialCharacters {{{
function! s:EscapeSpecialCharacters(str)
    if s:IsCommandVimgrep()
        return s:EscapeSpecialCharactersForVim(a:str)
    endif

    let commandParams = s:GetGrepCommandParameters()
    let escapeonce = s:CommandParameter(commandParams, "req_str_escapespecialcharacters")
    let escapetwice = s:CommandParameterOr(commandParams, "opt_str_escapespecialcharacterstwice", "")
    return s:DoEscapeSpecialCharacters(a:str, escapeonce, escapetwice)
endfunction
"}}}
" EscapeSpecialCharactersForVim {{{
function! s:EscapeSpecialCharactersForVim(str)
    let escapeonce = "\\/^$#"
    if &magic
        let escapeonce .= "*.~[]"
    endif
    return s:DoEscapeSpecialCharacters(a:str, escapeonce, "")
endfunction
"}}}
" SetGrepRoot {{{
function! s:SetGrepRoot(...)
    if a:0 > 0
        let grepRootChoice = a:1
    else
        let lst = [ "Select grep root: " ]
        call extend(lst, [ "1. 'cwd' (search from the current directory)" ])
        call extend(lst, [ "2. 'search' (search from a dynamic root)" ])
        call extend(lst, [ "3. 'repository' (alias for '".s:EasyGrepRepositoryList."')" ])
        call extend(lst, [ "4. 'directory' (search from a specific directory)" ])

        let numFixedItems = 4
        let upperLimit = numFixedItems + 1
        if exists("s:EasyGrepRootHistory")
            let numAdditional = len(s:EasyGrepRootHistory)
            for dir in s:EasyGrepRootHistory
                call extend(lst, [ upperLimit.". Recent: ".dir ])
                let upperLimit += 1
            endfor
        endif

        let grepRootNumChoice = inputlist(lst)

        if grepRootNumChoice == 0
            return
        elseif grepRootNumChoice == 1
            let grepRootChoice = "cwd"
        elseif grepRootNumChoice == 2
            let grepRootChoice = input("Enter a pattern for the dynamic root (comma separated): ", "")
            if empty(grepRootChoice)
                return
            endif
            let grepRootChoice = "search:".grepRootChoice
        elseif grepRootNumChoice == 3
            let grepRootChoice = "repository"
        elseif grepRootNumChoice == 4
            let grepRootChoice = input("Enter a directory to set the root to: ", "", "dir")
            if empty(grepRootChoice)
                return
            endif
        elseif grepRootNumChoice < upperLimit
            let grepRootChoice = s:EasyGrepRootHistory[grepRootNumChoice - (numFixedItems + 1)]
        else
            echo " "
            call EasyGrep#Error("Invalid GrepRoot choice")
            return
        endif
    endif

    if exists("s:GrepRootCache")
        unlet s:GrepRootCache
    endif
    let oldRoot = g:EasyGrepRoot
    let g:EasyGrepRoot = grepRootChoice
    let [newRoot, success, type] = s:GetGrepRootEx()
    if !success
        let g:EasyGrepRoot = oldRoot
        call EasyGrep#Error("Setting GrepRoot failed; root remains as '".g:EasyGrepRoot."'")
    else
        if type == "directory"
            if !exists("s:EasyGrepRootHistory")
                let s:EasyGrepRootHistory = []
            else
                let existingIndex = -1
                let i = 0
                for entry in s:EasyGrepRootHistory
                    if entry == g:EasyGrepRoot
                        let existingIndex = i
                        break
                    endif
                    let i += 1
                endfor
                if existingIndex != -1
                    call remove(s:EasyGrepRootHistory, existingIndex)
                endif
            endif
            call insert(s:EasyGrepRootHistory, g:EasyGrepRoot, 0)
        endif

        if a:0 == 0
            call s:EchoNewline()
        endif
        call EasyGrep#Info("Set GrepRoot to '".g:EasyGrepRoot."'")
    endif
endfunction
" }}}
" GetGrepRootEx {{{
function! s:GetGrepRootEx()
    let errorstring = ""

    if g:EasyGrepRoot == "repository"
        let g:EasyGrepRoot=s:EasyGrepRepositoryList
    elseif g:EasyGrepRoot == "."
        let g:EasyGrepRoot=EasyGrep#GetCwdEscaped()
    endif

    let type = "builtin"
    let pathtoreturn = "."
    if !exists("g:EasyGrepRoot")
        " this is ok; act as if we are specified as "cwd"
    elseif g:EasyGrepRoot == "cwd"
        " also ok; return the current directory
    elseif match(g:EasyGrepRoot, "search:") != -1
        " search for a directory matching the specified pattern
        let searchlst = split(g:EasyGrepRoot, "search:")
        if empty(searchlst)
            let errorstring = "Bad pattern"
        else
            if exists("s:GrepRootCache") && isdirectory(s:GrepRootCache)
                let pathtoreturn = s:GrepRootCache
            else
                let foundit = 0
                let searchlst = split(searchlst[0], ",")
                for searchkey in searchlst
                    let dirIterator = getcwd()
                    let foundit = 1
                    while !isdirectory(dirIterator."/".searchkey) && !filereadable(dirIterator."/".searchkey)
                        let oldIterator = dirIterator
                        let dirIterator = fnamemodify(dirIterator, ":h")
                        if dirIterator == oldIterator
                            let foundit = 0
                            break
                        endif
                    endwhile
                    if foundit
                        break
                    endif
                endfor
                if foundit
                    let pathtoreturn = substitute(dirIterator, escape(searchkey, "."), "", "")
                    let s:GrepRootCache = pathtoreturn
                endif
            endif
        endif
    elseif isdirectory(g:EasyGrepRoot)
        " Trim a trailing slash
        let g:EasyGrepRoot = substitute(g:EasyGrepRoot, "/$", "", "")
        let fullRootPath = substitute(fnamemodify(g:EasyGrepRoot, ":p"), "/$", "", "")
        if g:EasyGrepRoot[0] == '/' && g:EasyGrepRoot != fullRootPath
            let g:EasyGrepRoot = fullRootPath
        elseif match(g:EasyGrepRoot, "\\./", 0) != 0 && g:EasyGrepRoot != fullRootPath
            let g:EasyGrepRoot = "./".g:EasyGrepRoot
        endif
        let pathtoreturn = g:EasyGrepRoot
        let type = "directory"
    else
        let errorstring = "Unknown option or bad path"
    endif

    if !empty(errorstring)
        call EasyGrep#Error(errorstring." for g:EasyGrepRoot '".g:EasyGrepRoot."'; acting as if cwd")
    endif
    call EasyGrep#Log("GetGrepRootEx returned ".pathtoreturn)
    return [pathtoreturn, empty(errorstring), type]

endfunction
" }}}
" GetGrepRoot {{{
function! s:GetGrepRoot()
    return s:GetGrepRootEx()[0]
endfunction
" }}}
" GetCurrentWord {{{
function! s:GetCurrentWord()
    return expand("<cword>")
endfunction
" }}}
" GetCurrentSelection {{{
function! s:GetCurrentSelection()
    return EasyGrep#ClearNewline(@")
endfunction
" }}}
" IsBufferDirSearchAllowed {{{
function! s:IsBufferDirSearchAllowed()
    if s:IsModeBuffers()
        return 0
    endif

    let commandParams = s:GetGrepCommandParameters()
    if !has_key(commandParams, "opt_bool_bufferdirsearchallowed")
        return 1
    endif

    let bufferdirsearchallowed = commandParams["opt_bool_bufferdirsearchallowed"]
    if bufferdirsearchallowed ==# "1"
        return 1
    elseif bufferdirsearchallowed ==# "0"
        return 0
    elseif bufferdirsearchallowed ==# "!recursive"
        return !s:IsRecursiveSearch()
    else
        return 1
    endif
endfunction
" }}}
" IsRecursivePattern {{{
function! s:IsRecursivePattern(pattern)
    return stridx(a:pattern, "\*\*\/") == 0 ? 1 : 0
endfunction
" }}}
" IsRecursiveSearch {{{
function! s:IsRecursiveSearch()
    if g:EasyGrepRecursive
        return !s:IsModeBuffers()
    endif
    return s:CommandHas("opt_bool_isinherentlyrecursive")
endfunction
" }}}
" ChangeDirectoryToGrepRoot {{{
function! s:ChangeDirectoryToGrepRoot()
    if g:EasyGrepRoot != "cwd" && !s:IsCommandVimgrep()
        exe "lcd ".s:GetGrepRoot()
    endif
endfunction
" }}}
" ChangeDirectoryToPrevious {{{
function! s:ChangeDirectoryToPrevious()
    if g:EasyGrepRoot != "cwd" && !s:IsCommandVimgrep()
        lcd -
    endif
endfunction
" }}}
" GetFileTargetList_Tracked {{{
function! s:GetFileTargetList_Tracked()
    let lst = [s:TrackedExt]
    let i = s:FindFileTarget(s:TrackedExt)
    if i != -1
        let keyList = [ i ]
        let lst = s:CollectEnabledFileTargets(keyList)
    endif
    return lst
endfunction
" }}}
" GetFileTargetList {{{
function! s:GetFileTargetList(addAdditionalLocations)
    let addAdditionalLocations = a:addAdditionalLocations
    let fileTargetList = []
    if s:IsModeBuffers()
        let fileTargetList = EasyGrep#EscapeList(EasyGrep#GetBufferNamesList(), " ")
        let addAdditionalLocations = 0
    elseif s:IsModeTracked()
        let fileTargetList = s:GetFileTargetList_Tracked()
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
            let fileTargetList = s:CollectEnabledFileTargets(keyList)
        else
            call EasyGrep#InternalFailure("Keylist should not be empty")
            let fileTargetList = [ "*" ]
        endif
    endif

    if addAdditionalLocations
        let fileTargetList = s:AddAdditionalLocationsToFileTargetList(fileTargetList)
    endif

    return fileTargetList
endfunction
" }}}
" AddAdditionalLocationsToFileTargetList {{{
function! s:AddAdditionalLocationsToFileTargetList(fileTargetList)
    let fileTargetList = a:fileTargetList
    if empty(fileTargetList) || s:IsModeBuffers()
        return fileTargetList
    endif

    if g:EasyGrepSearchCurrentBufferDir && s:IsBufferDirSearchAllowed() && !s:CommandHasLen("opt_str_mapinclusionsexpression")
        let fileTargetList = s:ApplySearchDirectoriesToFileTargetList(fileTargetList)
    endif

    if g:EasyGrepHidden && !s:CommandHasLen("opt_str_hiddenswitch")
        let i = 0
        let size = len(fileTargetList)
        while i < size
            let item = fileTargetList[i]
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
                call insert(fileTargetList, newItem, i)
            endif
            let i += 1
        endwhile
    endif

    let newlst = []
    for item in fileTargetList
        if s:IsRecursiveSearch() && s:IsCommandVimgrep()
            " Insert a recursive specifier into the command
            let item = substitute(item, '\([^/]\+\)$', '**/\1', "")
            let item = substitute(item, '/\*\*/\*$', '/**', "")
            let item = substitute(item, '^\*$', '**', "")
        endif
        call add(newlst, item)
    endfor

    return newlst
endfunction
"}}}
" ApplySearchDirectoriesToFileTargetList {{{
function! s:ApplySearchDirectoriesToFileTargetList(fileTargets)
    let fileTargets = a:fileTargets

    " Build a list of the directories in buffers
    let dirs = s:GetDirectorySearchList()

    let newlst = []
    for dir in dirs
        for target in fileTargets
            let newTarget = dir == "." ? target : dir."/".target
            call add(newlst, newTarget)
        endfor
    endfor

    return newlst
endfunction
"}}}
" FindFileTarget {{{
function! s:FindFileTarget(target)
    let target = a:target
    let i = 0
    let numItems = len(s:Dict)
    while i < numItems
        if i != s:EasyGrepModeTracked
            let patterns = split(s:Dict[i][1])
            for p in patterns
                if target ==# p
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
    let fromthisdir = a:fromthisdir == "." ? EasyGrep#GetCwdEscaped() : a:fromthisdir

    if match(directoryTarget, fromthisdir) != 0
        return 0
    endif

    return 1
endfunction
" }}}
" GetDirectorySearchList {{{
function! s:GetDirectorySearchList()
    if !g:EasyGrepSearchCurrentBufferDir
        return [ s:GetGrepRoot() ]
    endif

    let root = s:GetGrepRoot()
    let currDir = EasyGrep#GetCwdEscaped()
    let bufferDirs = EasyGrep#GetBufferDirsList()

    call add(bufferDirs, root)
    let bufferDirsWithRoot = sort(bufferDirs)

    let bufferSetList = []

    let i = 0
    let end = len(bufferDirsWithRoot)
    while i < end
        let dir = bufferDirsWithRoot[i]
        let addToList = 1
        if (i > 0) && (dir == bufferDirsWithRoot[i-1])
            let addToList = 0
        elseif s:IsRecursiveSearch()
            for d in bufferSetList
                if s:IsRecursivelyReachable(d, dir)
                    let addToList = 0
                    break
                endif
            endfor
        endif
        if addToList
            let escapedDir = EasyGrep#FileEscape(dir)
            call add(bufferSetList, escapedDir)
        endif
        let i += 1
    endwhile

    " Place the root as the first item if possible
    let i = 0
    let end = len(bufferSetList)
    while i < end
        if bufferSetList[i] == root
            call remove(bufferSetList, i)
            call insert(bufferSetList, root, 0)
            break
        endif
        let i += 1
    endwhile

    return bufferSetList
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
            call EasyGrep#Warning("cannot search the current buffer because it is unnamed")
            return 0
        endif
        let fileDir = fnamemodify(currFile, ":p:h")
        if !empty(fileDir) && !g:EasyGrepSearchCurrentBufferDir
            let root = s:GetGrepRoot()
            let willmatch = 1
            if s:IsRecursiveSearch()
                if match(fileDir, root) != 0
                    let willmatch = 0
                endif
            else
                if fileDir != cwd
                    let willmatch = 0
                endif
            endif
            if !willmatch
                call EasyGrep#Warning("current file not searched, its directory [".fileDir."] doesn't match the working directory [".cwd."]")
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

    call s:MapOptionsExplorerKeys()

    call s:FillWindow()
endfunction
" }}}
" Mapped Functions {{{
" EchoFilesSearched {{{
function! <sid>EchoFilesSearched()
    let str = ""
    let fileTargetList = s:GetFileTargetList(1)
    call s:ChangeDirectoryToGrepRoot()
    for f in fileTargetList
        if s:IsModeBuffers()
            let str .= "    ".f."\n"
        else
            let globList = glob(f, 0, 1)
            for g in globList
                if filereadable(g)
                    let str .= "    ".g."\n"
                endif
            endfor
        endif
    endfor
    call s:ChangeDirectoryToPrevious()

    if !empty(str)
        call s:Echo("Files that will be searched:")
        echo str
    else
        call s:Echo("No files match the current options")
    endif
endfunction
"}}}
" SetFilesToInclude {{{
function! <sid>SetFilesToInclude()
    let filesToInclude = input("Enter patterns to include, seperated by a comma: ", g:EasyGrepFilesToInclude)
    let g:EasyGrepFilesToInclude = EasyGrep#Trim(filesToInclude)

    call s:RefreshAllOptions()

    if !empty(g:EasyGrepFilesToInclude)
        call s:Echo("Set files to include to (".g:EasyGrepFilesToInclude.")")
    else
        call s:Echo("Clearing files to include")
    endif
endfunction
"}}}
" SetFilesToExclude {{{
function! <sid>SetFilesToExclude()
    let filesToExclude = input("Enter patterns to exclude, seperated by a comma: ", g:EasyGrepFilesToExclude)
    let g:EasyGrepFilesToExclude = EasyGrep#Trim(filesToExclude)

    call s:RefreshAllOptions()

    if !empty(g:EasyGrepFilesToExclude)
        call s:Echo("Set files to exclude to (".g:EasyGrepFilesToExclude.")")
        if !s:CommandSupportsExclusions()
            call s:Echo("But note that your command, ".s:GetGrepCommandName().", does not support them. See the docs for supported programs.")
        endif
    else
        call s:Echo("Clearing files to exclude")
    endif
endfunction
"}}}
" ChooseGrepProgram {{{
function! <sid>ChooseGrepProgram(...)

    let programNames = sort(keys(g:EasyGrep_commandParamsDict))

    if a:0 > 0
        let grepChoiceStr = a:1
    else
        let lst = [ "Select grep program: " ]
        let numPrograms = len(programNames)
        let programRemap = {}

        let i = 0
        let validProgramCounter = 0
        while i < numPrograms
            let program = programNames[i]
            if executable(program)
                let validProgramCounter += 1
                call extend(lst, [ validProgramCounter.". ". programNames[i] ])
                let programRemap[validProgramCounter] = i
            endif
            let i += 1
        endwhile

        let grepChoice = inputlist(lst)

        if grepChoice == 0
            return
        elseif grepChoice > validProgramCounter
            echo " "
            call EasyGrep#Error("Invalid GrepProgram choice")
            return
        endif

        let grepChoiceStr = programNames[programRemap[grepChoice]]
    endif
    let result = s:SetGrepCommand(grepChoiceStr)

    if result
        if a:0 == 0
            echo " "
            echo " "
        endif
        call s:Echo("-- Grep configuration changed --")
        call s:EchoGrepCommand()
    else
        call EasyGrep#Error("Unknown program '".a:1."'")
    endif
endfunction
"}}}
" SetGrepCommand {{{
function! s:SetGrepCommand(grepChoice)
    if a:grepChoice ==# "1"
        let g:EasyGrepCommand = 1
    elseif a:grepChoice ==# "0" || a:grepChoice ==# "vimgrep"
        let g:EasyGrepCommand = 0
    else
        let g:EasyGrepCommand = 1

        if !has_key(g:EasyGrep_commandParamsDict, a:grepChoice)
            return 0
        endif

        let args = ""
        if len(g:EasyGrep_commandParamsDict[a:grepChoice]["req_str_programargs"])
            let args = '\ '.escape(g:EasyGrep_commandParamsDict[a:grepChoice]["req_str_programargs"], ' ')
        endif
        exe "set grepprg=".a:grepChoice.args
    endif
    let s:LastSeenGrepprg = &grepprg

    return 1
endfunction
"}}}
" EchoGrepCommand {{{
function! <sid>EchoGrepCommand()
    if !s:ValidateGrepCommand()
        return 0
    endif

    let recursiveTag = s:IsRecursiveSearch() ? " (Recursive)" : ""
    call s:Echo("Search Mode:           ".s:GetModeName(g:EasyGrepMode).recursiveTag)

    if !s:CommandHas("opt_bool_nofiletargets")
        if g:EasyGrepSearchCurrentBufferDir && s:IsBufferDirSearchAllowed()
            let dirs = s:GetDirectorySearchList()
            let dirAnnotation = "Search Directory:      "
            for d in dirs
                let d = (d == ".") ? d." --> ".EasyGrep#GetCwdEscaped()."" : d
                call s:Echo(dirAnnotation.d)
                let dirAnnotation = "Additional Directory:  "
            endfor
        else
            let dirAnnotation = "Search Directory:      "
            let d = s:GetGrepRoot()
            let d = (d == ".") ? d." --> ".EasyGrep#GetCwdEscaped()."" : d
            call s:Echo(dirAnnotation.d)
        endif
    endif

    let placeholder = "<pattern>"
    let grepCommand = s:GetGrepCommandLine(placeholder, "", 0, "", 1, 0, "")
    call s:Echo("VIM command:           ".grepCommand)

    if s:GetGrepCommandName() == "grep"
        let shellCommand = substitute(grepCommand, "grep", &grepprg, "")
        call s:Echo("Shell command:         ".shellCommand)
        let @* = shellCommand
    endif

    if s:GetGrepCommandChoice(0) != s:GetGrepCommandChoice(1)
        call s:Echo("Note:                  "."Overriding '".substitute(s:GetGrepCommandName(0), "grep", &grepprg, "")."' with '".s:GetGrepCommandName(1)."' due to 'Buffers' mode")
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
            \ "g:EasyGrepFilesToInclude",
            \ "g:EasyGrepFilesToExclude",
            \ "g:EasyGrepAllOptionsInExplorer",
            \ "g:EasyGrepWindow",
            \ "g:EasyGrepReplaceWindowMode",
            \ "g:EasyGrepOpenWindowOnMatch",
            \ "g:EasyGrepEveryMatch",
            \ "g:EasyGrepJumpToMatch",
            \ "g:EasyGrepInvertWholeWord",
            \ "g:EasyGrepPatternType",
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

    call EasyGrep#Warning("The following options will be saved in the e register; type \"ep to paste into your .vimrc")
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

    if s:CommandHas("opt_bool_isselffiltering")
        if selectedMode != s:EasyGrepModeAll && selectedMode != s:EasyGrepModeBuffers
            call EasyGrep#Error("Cannot activate '".s:GetModeName(selectedMode)."' mode when ".s:GetGrepProgramVarAndName().", as this grepprg implements its own filtering")
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
            let choice = s:SetUserGrepPattern(userStr)
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
" GetGrepCommandChoice {{{
function! s:GetGrepCommandChoice(overrideForBuffersMode)
    if !exists("g:EasyGrepCommand") || g:EasyGrepCommand > len(s:Commands)
        let g:EasyGrepCommand=0
    endif
    return a:overrideForBuffersMode && s:IsModeBuffers() ? 0 : g:EasyGrepCommand
endfunction
" }}}
" GetGrepCommandName {{{
function! s:GetGrepCommandName(...)
    let overrideForBuffersMode = 1
    if a:0 > 0
        let overrideForBuffersMode = a:1
    endif
    return s:Commands[s:GetGrepCommandChoice(overrideForBuffersMode)]
endfunction
" }}}
" GetGrepCommandNameWithOptions {{{
function! s:GetGrepCommandNameWithOptions()
    let name = s:GetGrepCommandName(0)
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
" GetGrepProgramVarAndName {{{
function! s:GetGrepProgramVarAndName()
    return "(grepprg='".s:GetGrepProgramName()."')"
endfunction
" }}}
" GetGrepPatternType {{{
function! s:GetGrepPatternType()
    if !exists("g:EasyGrepPatternType") || (g:EasyGrepPatternType != "regex" && g:EasyGrepPatternType != "fixed")
        let g:EasyGrepPatternType="regex"
    elseif (g:EasyGrepPatternType != "regex" && g:EasyGrepPatternType != "fixed")
        call EasyGrep#Error("Invalid option for g:EasyGrepPatternType; switching to \"regex\"")
        let g:EasyGrepPatternType="regex"
    endif
    return g:EasyGrepPatternType
endfunction
" }}}
" ToggleCommand {{{
function! <sid>ToggleCommand()
    let commandChoice = s:GetGrepCommandChoice(0)
    let commandChoice += 1
    if commandChoice == len(s:Commands)
        let commandChoice = 0
    endif
    let g:EasyGrepCommand = commandChoice

    call s:RefreshAllOptions()

    call s:Echo("Set command to (".s:GetGrepCommandNameWithOptions().")")
    call s:CheckCommandRequirements()
endfunction
" }}}
" ToggleRecursion {{{
function! <sid>ToggleRecursion()
    if s:IsModeBuffers()
        call EasyGrep#Warning("Recursive mode cant' be set when *Buffers* is activated")
        return
    endif

    let g:EasyGrepRecursive = !g:EasyGrepRecursive

    call s:RefreshAllOptions()

    call s:Echo("Set recursive mode to (".EasyGrep#OnOrOff(g:EasyGrepRecursive).")")
endfunction
" }}}
" ToggleIgnoreCase {{{
function! <sid>ToggleIgnoreCase()
    let g:EasyGrepIgnoreCase = !g:EasyGrepIgnoreCase
    call s:RefreshAllOptions()
    call s:Echo("Set ignore case to (".EasyGrep#OnOrOff(g:EasyGrepIgnoreCase).")")
endfunction
" }}}
" ToggleHidden {{{
function! <sid>ToggleHidden()
    let g:EasyGrepHidden = !g:EasyGrepHidden

    call s:RefreshAllOptions()

    call s:Echo("Set hidden files included to (".EasyGrep#OnOrOff(g:EasyGrepHidden).")")
endfunction
" }}}
" ToggleBufferDirectories {{{
function! <sid>ToggleBufferDirectories()
    let g:EasyGrepSearchCurrentBufferDir = !g:EasyGrepSearchCurrentBufferDir

    call s:RefreshAllOptions()

    call s:Echo("Set 'include all buffer directories' to (".EasyGrep#OnOrOff(g:EasyGrepSearchCurrentBufferDir).")")
endfunction
" }}}
" ToggleWindow {{{
function! <sid>ToggleWindow()
    let g:EasyGrepWindow = !g:EasyGrepWindow
    call s:RefreshAllOptions()

    call s:Echo("Set window to (".EasyGrep#GetErrorListName().")")
endfunction
"}}}
" ToggleOpenWindow {{{
function! <sid>ToggleOpenWindow()
    let g:EasyGrepOpenWindowOnMatch = !g:EasyGrepOpenWindowOnMatch
    call s:RefreshAllOptions()

    call s:Echo("Set open window on match to (".EasyGrep#OnOrOff(g:EasyGrepOpenWindowOnMatch).")")
endfunction
"}}}
" ToggleEveryMatch {{{
function! <sid>ToggleEveryMatch()
    let g:EasyGrepEveryMatch = !g:EasyGrepEveryMatch
    call s:RefreshAllOptions()

    call s:Echo("Set separate multiple matches to (".EasyGrep#OnOrOff(g:EasyGrepEveryMatch).")")
endfunction
"}}}
" ToggleJumpToMatch {{{
function! <sid>ToggleJumpToMatch()
    let g:EasyGrepJumpToMatch = !g:EasyGrepJumpToMatch
    call s:RefreshAllOptions()

    call s:Echo("Set jump to match to (".EasyGrep#OnOrOff(g:EasyGrepJumpToMatch).")")
endfunction
"}}}
" ToggleWholeWord {{{
function! <sid>ToggleWholeWord()
    let g:EasyGrepInvertWholeWord = !g:EasyGrepInvertWholeWord
    call s:RefreshAllOptions()

    call s:Echo("Set invert the meaning of whole word to (".EasyGrep#OnOrOff(g:EasyGrepInvertWholeWord).")")
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
" TogglePatternType {{{
function! <sid>TogglePatternType()
    call s:GetGrepPatternType()
    if g:EasyGrepPatternType == "regex"
        let g:EasyGrepPatternType = "fixed"
    else
        let g:EasyGrepPatternType = "regex"
    endif
    call s:RefreshAllOptions()

    call s:Echo("Set pattern type to (".s:GetGrepPatternType().")")
endfunction
"}}}
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

    call s:Echo("Set file associations in explorer to (".EasyGrep#OnOrOff(g:EasyGrepFileAssociationsInExplorer).")")
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

    exe "nmap <silent> ".p."I  :call <sid>SetFilesToInclude()<cr>"
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
    exe "nmap <silent> ".p."~  :call <sid>TogglePatternType()<cr>"
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
    call s:CreateGrepDictionary()
    call s:OpenOptionsExplorer()
    return s:ClearGatewayVariables()
endfunction
" }}}
" CreateOptionsString {{{
function! s:CreateOptionsString()

    let s:Options = []

    call add(s:Options, "\"q: quit")
    call add(s:Options, "\"r: recursive mode (".EasyGrep#OnOrOff(g:EasyGrepRecursive).")")
    call add(s:Options, "\"d: include all buffer directories (".EasyGrep#OnOrOff(g:EasyGrepSearchCurrentBufferDir).")")
    call add(s:Options, "\"i: ignore case (".EasyGrep#OnOrOff(g:EasyGrepIgnoreCase).")")
    call add(s:Options, "\"h: hidden files included (".EasyGrep#OnOrOff(g:EasyGrepHidden).")")
    call add(s:Options, "\"e: echo files that would be searched")
    if g:EasyGrepAllOptionsInExplorer
        call add(s:Options, "\"x: set files to exclude")
        call add(s:Options, "\"c: change grep command (".s:GetGrepCommandNameWithOptions().")")
        call add(s:Options, "\"w: window to use (".EasyGrep#GetErrorListName().")")
        call add(s:Options, "\"m: replace window mode (".s:GetReplaceWindowModeString(g:EasyGrepReplaceWindowMode).")")
        call add(s:Options, "\"o: open window on match (".EasyGrep#OnOrOff(g:EasyGrepOpenWindowOnMatch).")")
        call add(s:Options, "\"g: separate multiple matches (".EasyGrep#OnOrOff(g:EasyGrepEveryMatch).")")
        call add(s:Options, "\"p: jump to match (".EasyGrep#OnOrOff(g:EasyGrepJumpToMatch).")")
        call add(s:Options, "\"!: invert the meaning of whole word (".EasyGrep#OnOrOff(g:EasyGrepInvertWholeWord).")")
        call add(s:Options, "\"~: pattern type (".s:GetGrepPatternType().")")
        call add(s:Options, "\"*: show file associations list (".EasyGrep#OnOrOff(g:EasyGrepFileAssociationsInExplorer).")")
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
    call add(s:Options, "\"Grep Targets: ".join(s:GetFileTargetList(0), ' '))
    call add(s:Options, "\"Inclusions: ".(!empty(g:EasyGrepFilesToInclude) ? g:EasyGrepFilesToInclude : "none"))
    call add(s:Options, "\"Exclusions: ".(!empty(g:EasyGrepFilesToExclude) ? g:EasyGrepFilesToExclude : "none").(empty(g:EasyGrepFilesToExclude) || s:CommandSupportsExclusions() ? "" : " (not supported with grepprg='".s:GetGrepProgramName()."')"))
    call add(s:Options, "")

endfunction
"}}}
" MapOptionsExplorerKeys {{{
function! s:MapOptionsExplorerKeys()

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
    nnoremap <buffer> <silent> ~    :call <sid>TogglePatternType()<cr>
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
" SetUserGrepPattern {{{
function! s:SetUserGrepPattern(str)
    call s:SetGatewayVariables()
    let str = a:str
    if s:IsRecursivePattern(str)
        call EasyGrep#Error("User specified grep pattern may not have a recursive specifier")
        call s:ClearGatewayVariables()
        return -1
    endif
    let pos = s:EasyGrepModeUser

    call s:CreateGrepDictionary()
    let i = s:FindFileTarget(str)
    if i != -1
        let s2 = s:Dict[i][1]
        if str == s2
            let pos = i
        else
            let msg = "File target '".s:Dict[i][0]."=".s:Dict[i][1]."' matches your input, use this?"
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
" CreateGrepDictionary {{{
function! s:CreateGrepDictionary()
    if exists("s:Dict")
        call s:CheckDefaultUserPattern()
        return
    endif

    let s:Dict = [ ]
    call add(s:Dict, [ "All" , "*", g:EasyGrepMode==s:EasyGrepModeAll ? 1 : 0 ] )
    call add(s:Dict, [ "Buffers" , "*Buffers*", g:EasyGrepMode==s:EasyGrepModeBuffers ? 1 : 0  ] )
    call add(s:Dict, [ "TrackExt" , "*", g:EasyGrepMode==s:EasyGrepModeTracked ? 1 : 0  ] )
    call add(s:Dict, [ "User" , "", g:EasyGrepMode==s:EasyGrepModeUser ? 1 : 0  ] )

    if len(s:Dict) != s:EasyGrepNumModes
        call EasyGrep#InternalFailure("EasyGrep's default settings are not internally consistent; please reinstall")
    endif

    call s:ParseFileAssociationList()
    let s:NumFileAssociations = len(s:Dict) - s:EasyGrepNumModes

endfunction
" }}}
" CollectEnabledFileTargets {{{
function! s:CollectEnabledFileTargets(keyList)

    " Indicates which keys have already been parsed to avoid multiple entries
    " and infinite recursion
    let s:traversed = repeat([0], len(s:Dict))

    let lst = []
    for k in a:keyList
        call extend(lst, s:DoCollectEnabledFileTargets(k))
    endfor
    unlet s:traversed

    return lst
endfunction
"}}}
" DoCollectEnabledFileTargets {{{
function! s:DoCollectEnabledFileTargets(key)
    if s:traversed[a:key] == 1
        return []
    endif
    let s:traversed[a:key] = 1

    let lst = []
    let fileTargetList = split(s:Dict[a:key][1])
    for p in fileTargetList
        if s:IsLink(p)
            let k = s:FindTargetByKey(s:GetKeyFromLink(p))
            if k != -1
                call extend(lst, s:DoCollectEnabledFileTargets(k))
            endif
        else
            call add(lst, p)
        endif
    endfor
    return lst
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
            if s:IsLink(p) && s:FindTargetByKey(s:GetKeyFromLink(p)) == -1
                call EasyGrep#Warning("Key(".p.") links to a nonexistent key")
                call remove(patterns, j)
                let j -= 1
            endif
            let j += 1
        endfor

        if empty(patterns)
            call EasyGrep#Warning("Key(".s:Dict[i][0].") has no valid patterns or links")
            call remove(s:Dict, i)
        else
            let s:Dict[i][1] = join(patterns)
        endif
        let i += 1
    endwhile
endfunction
"}}}
" FindTargetByKey {{{
function! s:FindTargetByKey(key)
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
        call EasyGrep#Error("Grep Pattern file list can't be read")
        return
    endif

    if !filereadable(lst)
        call EasyGrep#Error("Grep Pattern file list can't be read")
        return
    endif

    let fileList = readfile(lst)
    if empty(fileList)
        call EasyGrep#Error("Grep Pattern file list is empty")
        return
    endif

    let lineCounter = 0
    for line in fileList
        let lineCounter += 1
        let line = EasyGrep#Trim(line)
        if empty(line) || line[0] == "\""
            continue
        endif

        let keys = split(line, "=")
        if len(keys) != 2
            call EasyGrep#Warning("Invalid line: ".line)
            continue
        endif

        let keys[0] = EasyGrep#Trim(keys[0])
        let keys[1] = EasyGrep#Trim(keys[1])

        if empty(keys[0]) || empty(keys[1])
            call EasyGrep#Warning("Invalid line: ".line)
            continue
        endif

        " No real need to check that keys[0] is well-formed; just about any key
        " is acceptable

        if s:IsInDict(keys[0])
            call EasyGrep#Warning("Key already added: ".keys[0])
            continue
        endif

        let pList = split(keys[1])
        for p in pList

            " check for invalid filesystem characters.
            if match(p, "[/\\,;']") != -1
                call EasyGrep#Warning("Invalid pattern (".p.") in line(".lineCounter.")")
                continue
            endif

            if match(p, '[<>]') != -1
                if    EasyGrep#countstr(p, '<') > 1
                \  || EasyGrep#countstr(p, '>') > 1
                \  || p[0] != '<'
                \  || p[len(p)-1] != '>'
                    call EasyGrep#Warning("Invalid link (".p.") in line(".lineCounter.")")
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
" IsModeFiltered {{{
function! s:IsModeFiltered()
    call s:SanitizeMode()
    return s:IsModeTracked() || s:IsModeUser()
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
    call s:SetGrepMode(a:mode)
    if exists("s:Dict")
        call s:ClearActivatedItems()
        let s:Dict[a:mode][2] = 1
    endif
endfunction
" }}}
" SanitizeMode {{{
function! s:SanitizeMode()
    if s:SanitizeModeLock
        return
    endif
    let s:SanitizeModeLock = 1

    " First check the grep command
    if !s:CheckGrepCommandForChanges()
        let s:SanitizeModeLock = 0
        return
    endif

    " Next ensure that our mode is sensible
    if g:EasyGrepMode < 0 || g:EasyGrepMode >= s:EasyGrepNumModesWithSpecial
        call EasyGrep#Error("Invalid value for g:EasyGrepMode (".g:EasyGrepMode."); reverting to 'All' mode.")
        call s:ForceGrepMode(s:EasyGrepModeAll)
    elseif g:EasyGrepMode == s:EasyGrepModeMultipleChoice
        " This is OK
    elseif s:Dict[g:EasyGrepMode][2] != 1
        " The user switched the mode by explicitly setting the g:EasyGrepMode
        " global variable; make sure to sync up with it
        call s:ForceGrepMode(g:EasyGrepMode)
    endif

    let s:SanitizeModeLock = 0
endfunction
" }}}
" ValidateGrepCommand {{{
function! s:ValidateGrepCommand()
    if !s:IsCommandVimgrep() && empty(&grepprg)
        call EasyGrep#Error("Cannot proceed; the 'grepprg' setting is empty while EasyGrep is configured to use the grep command")
        call EasyGrep#Info("If you are unsure what to do, revert grepprg to it's default with 'set grepprg&'")
        return 0
    endif

    let commandParams = s:GetGrepCommandParameters()
    if empty(commandParams)
        call EasyGrep#Error("Cannot proceed; the configured 'grepprg' setting is not a known program")
        call EasyGrep#Error("Select a supported program with :GrepProgram")
        return 0
    endif

    return 1
endfunction
" }}}
" CheckGrepCommandForChanges {{{
function! s:CheckGrepCommandForChanges()
    if &grepprg != s:LastSeenGrepprg
        if s:CommandHas("opt_bool_isselffiltering")
            if s:IsModeFiltered()
                call EasyGrep#Info("==================================================================================")
                call EasyGrep#Info("The 'grepprg' has changed to '".s:GetGrepProgramName()."' since last inspected")
                call EasyGrep#Info("Switching to 'All' mode as the '".s:GetModeName(g:EasyGrepMode)."' mode is incompatible with this program")
                call EasyGrep#Info("==================================================================================")
                call s:ForceGrepMode(s:EasyGrepModeAll)
            endif
        endif
        let s:LastSeenGrepprg = &grepprg
        return 0
    endif
    return 1
endfunction
" }}}
" CheckCommandRequirements {{{
function! s:CheckCommandRequirements()
    call s:SanitizeMode()
    if s:CommandHasLen("opt_str_warnonuse")
        let commandParams = s:GetGrepCommandParameters()
        call EasyGrep#Warning(commandParams["opt_str_warnonuse"])
    endif
endfunction
" }}}
" Extension Tracking {{{
" SetCurrentExtension {{{
function! s:SetCurrentExtension()
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

    call s:CreateGrepDictionary()
    let tempList = s:GetFileTargetList_Tracked()

    " When in tracked mode, change the tracked extension if it isn't
    " already in the list of files to be grepped
    if index(tempList, ext) == -1
        let s:TrackedExt = ext
        let s:Dict[s:EasyGrepModeTracked][1] = ext
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
function! <sid>GrepSelection(add, wholeword)
    call s:SetGatewayVariables()
    let currSelection=s:GetCurrentSelection()
    if empty(currSelection)
        call EasyGrep#Warning("No current selection")
        return s:ClearGatewayVariables()
    endif
    call s:DoGrep(currSelection, a:add, a:wholeword, "", 1, "")
    return s:ClearGatewayVariables()
endfunction
" }}}
" GrepCurrentWord {{{
function! <sid>GrepCurrentWord(add, wholeword)
    call s:SetGatewayVariables()
    let currWord=s:GetCurrentWord()
    if empty(currWord)
        call EasyGrep#Warning("No current word")
        return s:ClearGatewayVariables()
    endif

    call s:CheckIfCurrentFileIsSearched()
    let r = s:DoGrep(currWord, a:add, a:wholeword, "", 1, "")
    return s:ClearGatewayVariables()
endfunction
" }}}
" ReplaceSelection {{{
function! <sid>ReplaceSelection(wholeword)
    call s:SetGatewayVariables()
    let currSelection=s:GetCurrentSelection()
    if empty(currSelection)
        call EasyGrep#Warning("No current selection")
        return s:ClearGatewayVariables()
    endif

    call s:ReplaceString(currSelection, a:wholeword, 1)
    return s:ClearGatewayVariables()
endfunction
"}}}
" ReplaceCurrentWord {{{
function! <sid>ReplaceCurrentWord(wholeword)
    call s:SetGatewayVariables()
    let currWord=s:GetCurrentWord()
    if empty(currWord)
        call EasyGrep#Warning("No current word")
        return s:ClearGatewayVariables()
    endif

    call s:ReplaceString(currWord, a:wholeword, 1)
    return s:ClearGatewayVariables()
endfunction
"}}}
" }}}
" Command Line Functions {{{
" GrepCommandLine {{{
function! s:GrepCommandLine(argv, add)
    call s:SetGatewayVariables()
    let opts = s:ParseCommandLine(a:argv)
    if !empty(opts["failedparse"])
        call EasyGrep#Error(opts["failedparse"])
    else
        call s:SetCommandLineOptions(opts)
        call s:DoGrep(opts["pattern"], a:add, opts["whole-word"], opts["count"]>0 ? opts["count"] : "", opts["regex"] == "fixed" ? 1 : 0, opts["xgrep"])
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
    let opts["whole-word"] = 0
    let opts["count"] = 0
    let opts["regex"] = s:GetGrepPatternType()
    let opts["pattern"] = ""
    let opts["xgrep"] = ""
    let opts["failedparse"] = ""
    let parseopts = 1

    if empty(a:argv)
        return opts
    endif

    let tokens = split(a:argv, ' \zs')
    let numtokens = len(tokens)
    let j = 0
    while j < numtokens
        let tok = tokens[j]
        let tok = EasyGrep#Trim(tok)
        if tok == "--"
            let parseopts = 0
            let j += 1
            continue
        endif
        if tok != "-" && tok[0] == '-' && parseopts
            let tok = EasyGrep#Trim(tok)
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
                    elseif c ==# 'w'
                        let opts["whole-word"] = 1
                    elseif c ==# 'E'
                        let opts["regex"] = "regex"
                    elseif c ==# 'F'
                        let opts["regex"] = "fixed"
                    elseif c ==# 'm'
                        let j += 1
                        if j < numtokens
                            let tok = tokens[j]
                            let opts["count"] = tok
                        else
                            let opts["failedparse"] = "Missing argument to -m"
                        endif
                    elseif c ==# 'X'
                        let j += 1
                        if j < numtokens
                            let tok = tokens[j]
                            let opts["xgrep"] .= " ".tok
                        else
                            let opts["failedparse"] = "Missing argument to -X"
                        endif
                    else
                        let opts["failedparse"] = "Invalid option (-".c.")"
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
    call EasyGrep#SaveVariable("g:EasyGrepRecursive")
    let g:EasyGrepRecursive = g:EasyGrepRecursive || opts["recursive"]

    call EasyGrep#SaveVariable("g:EasyGrepIgnoreCase")
    let g:EasyGrepIgnoreCase = (g:EasyGrepIgnoreCase || opts["case-insensitive"]) && !opts["case-sensitive"]
endfunction
" }}}
" RestoreCommandLineOptions {{{
function! s:RestoreCommandLineOptions(opts)
    let opts = a:opts
    call EasyGrep#RestoreVariable("g:EasyGrepRecursive")
    call EasyGrep#RestoreVariable("g:EasyGrepIgnoreCase")
endfunction
" }}}
" Replace {{{
function! s:Replace(bang, argv)
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
            call EasyGrep#Error("Missing trailing /")
            let invalid = 1
        elseif stridx(temp, '/', 1) == l-1
            call EasyGrep#Error("Missing middle /")
            let invalid = 1
        elseif EasyGrep#countstr(temp, '/') > 3
            call EasyGrep#Error("Too many /'s, escape these if necessary")
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
            call EasyGrep#Error("Too many arguments")
            let invalid = 1
        endif
    endif

    if invalid
        call s:Echo("usage: Replace /target/replacement/ --or-- Replace target replacement")
        return
    endif

    let target = argv[0]
    let replacement = argv[1]

    call s:DoReplace(target, replacement, a:bang == "!" ? 1 : 0, 0)
    return s:ClearGatewayVariables()
endfunction
"}}}
" ReplaceUndo {{{
function! s:ReplaceUndo()
    call s:SetGatewayVariables()
    if !exists("s:actionList")
        call EasyGrep#Error("No saved actions to undo")
        return s:ClearGatewayVariables()
    endif

    " If either of these variables exists, that means the last command was
    " interrupted; give it another shot
    if !exists(EasyGrep#GetSavedVariableName("switchbuf")) && !exists(EasyGrep#GetSavedVariableName("autowriteall"))

        call EasyGrep#SaveVariable("switchbuf")
        set switchbuf=useopen
        if g:EasyGrepReplaceWindowMode == 2
            call EasyGrep#SaveVariable("autowriteall")
            set autowriteall
        else
            if g:EasyGrepReplaceWindowMode == 0
                set switchbuf+=usetab
            else
                set switchbuf+=split
            endif
        endif
    endif

    call EasyGrep#SetErrorList(s:LastErrorList)
    call EasyGrep#GotoStartErrorList()

    let bufList = EasyGrep#GetVisibleBuffers()

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
            call EasyGrep#Warning("Ran out of room for more windows")
            let finished = confirm("Do you want to save all windows and continue?", "&Yes\n&No")-1
            if finished == 1
                call EasyGrep#Warning("To continue, save unsaved windows, make some room (try :only) and run ReplaceUndo again")
                return
            else
                wall
                only
            endif
        catch /^Vim:Interrupt$/
            redraw
            call EasyGrep#Warning("Undo interrupted by user; state is not guaranteed")
            let finished = confirm("Are you sure you want to stop the undo?", "&Yes\n&No")-1
            let finished = !finished
        catch
            redraw
            echo v:exception
            call EasyGrep#Warning("Undo interrupted; state is not guaranteed")
            let finished = confirm("Do you want to continue undoing?", "&Yes\n&No")-1
        endtry
    endwhile

    call EasyGrep#RestoreVariable("switchbuf")
    call EasyGrep#RestoreVariable("autowriteall")

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
        call EasyGrep#SaveVariable("ignorecase")
        let &ignorecase = g:EasyGrepIgnoreCase

        call EasyGrep#SaveVariable("wildignore")
        silent exe "set wildignore+=".g:EasyGrepFilesToExclude
    endif
endfunction
"}}}
" RestoreGrepVariables{{{
function! s:RestoreGrepVariables()
    call EasyGrep#RestoreVariable("ignorecase")
    call EasyGrep#RestoreVariable("wildignore")
endfunction
"}}}
" CommandSupportsExclusions {{{
function! s:CommandSupportsExclusions()
    return s:CommandHas("req_bool_supportsexclusions")
endfunction
"}}}
" IsCommandVimgrep {{{
function! s:IsCommandVimgrep()
    return (s:GetGrepCommandName() == "vimgrep")
endfunction
"}}}
" CommandParameterMatches {{{
function! s:CommandParameterMatches(parameter, value)
    let commandParams = s:GetGrepCommandParameters()
    return has_key(commandParams, a:parameter) && (commandParams[a:parameter] == a:value)
endfunction
"}}}
" CommandParameter {{{
function! s:CommandParameter(commandParams, parameter)
    return a:commandParams[a:parameter]
endfunction
"}}}
" CommandParameterOr {{{
function! s:CommandParameterOr(commandParams, parameter, value)
    if has_key(a:commandParams, a:parameter)
        return a:commandParams[a:parameter]
    else
        return a:value
    endif
endfunction
"}}}
" CommandHas {{{
function! s:CommandHas(parameter)
    return s:CommandParameterMatches(a:parameter, '1')
endfunction
"}}}
" CommandHasLen {{{
function! s:CommandHasLen(parameter)
    let commandParams = s:GetGrepCommandParameters()
    return has_key(commandParams, a:parameter) && len(commandParams[a:parameter])
endfunction
"}}}
" RegisterGrepProgram {{{
function! s:RegisterGrepProgram(programName, programSettingsDict)
    if !exists("g:EasyGrep_commandParamsDict")
        let g:EasyGrep_commandParamsDict = {}
    endif

    if has_key(g:EasyGrep_commandParamsDict, a:programName)
        call EasyGrep#Error("Cannot register '".a:programName."' because it is already registered")
        return
    endif

    let g:EasyGrep_commandParamsDict[a:programName] = a:programSettingsDict
endfunction
" }}}
" ConfigureGrepCommandParameters {{{
function! s:ConfigureGrepCommandParameters()
    if exists("g:EasyGrep_commandParamsDict")
        return
    endif

    call s:RegisterGrepProgram("vimgrep", {
                \ 'req_str_programargs': '',
                \ 'req_bool_supportsexclusions': '1',
                \ 'req_str_recurse': '',
                \ 'req_str_caseignore': '',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '/',
                \ 'opt_str_patternpostfix': '/',
                \ 'opt_str_wholewordprefix': '\<',
                \ 'opt_str_wholewordpostfix': '\>',
                \ 'opt_str_wholewordoption': '',
                \ 'req_str_escapespecialcharacters': "configured@runtime",
                \ 'opt_str_escapespecialcharacterstwice': "",
                \ 'opt_str_mapexclusionsexpression': '',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '1',
                \ 'opt_str_suppresserrormessages': '',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '0',
                \ 'opt_bool_isselffiltering': '0',
                \ 'opt_bool_nofiletargets': '0',
                \ })

    call s:RegisterGrepProgram("grep", {
                \ 'req_str_programargs': '-n',
                \ 'req_bool_supportsexclusions': '1',
                \ 'req_str_recurse': '-R',
                \ 'req_str_caseignore': '-i',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '"',
                \ 'opt_str_patternpostfix': '"',
                \ 'opt_str_wholewordprefix': '',
                \ 'opt_str_wholewordpostfix': '',
                \ 'opt_str_wholewordoption': '-w ',
                \ 'req_str_escapespecialcharacters': "-\^$#.*[]",
                \ 'opt_str_escapespecialcharacterstwice': "",
                \ 'opt_str_mapexclusionsexpression': '"--exclude=\"".v:val."\""." --exclude-dir=\"".v:val."\""',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '!recursive',
                \ 'opt_str_suppresserrormessages': '-s',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '0',
                \ 'opt_bool_isselffiltering': '0',
                \ 'opt_bool_nofiletargets': '0',
                \ 'opt_str_mapinclusionsexpression': '"--include=\"" .v:val."\""',
                \ })

    call s:RegisterGrepProgram("git", {
                \ 'req_str_programargs': 'grep -n',
                \ 'req_bool_supportsexclusions': '0',
                \ 'req_str_recurse': '-R',
                \ 'req_str_caseignore': '-i',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '"',
                \ 'opt_str_patternpostfix': '"',
                \ 'opt_str_wholewordprefix': '',
                \ 'opt_str_wholewordpostfix': '',
                \ 'opt_str_wholewordoption': '-w ',
                \ 'req_str_escapespecialcharacters': "-\^$#.*",
                \ 'opt_str_escapespecialcharacterstwice': "",
                \ 'opt_str_mapexclusionsexpression': '',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '0',
                \ 'opt_str_suppresserrormessages': '',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '0',
                \ 'opt_bool_isselffiltering': '0',
                \ 'opt_bool_nofiletargets': '0',
                \ })

    call s:RegisterGrepProgram("ack", {
                \ 'req_str_programargs': '-s --nogroup --nocolor --column --with-filename',
                \ 'req_bool_supportsexclusions': '1',
                \ 'req_str_recurse': '',
                \ 'req_str_caseignore': '-i',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '"',
                \ 'opt_str_patternpostfix': '"',
                \ 'opt_str_wholewordprefix': '',
                \ 'opt_str_wholewordpostfix': '',
                \ 'opt_str_wholewordoption': '-w ',
                \ 'req_str_escapespecialcharacters': "-\^$#.*+?()[]{}",
                \ 'opt_str_escapespecialcharacterstwice': "|",
                \ 'opt_str_mapexclusionsexpression': '"--ignore-dir=\"".v:val."\" --ignore-file=ext:\"".substitute(v:val, "\\*\\.", "", "")."\""',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '1',
                \ 'opt_str_suppresserrormessages': '',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '1',
                \ 'opt_bool_isselffiltering': '0',
                \ 'opt_bool_nofiletargets': '0',
                \ 'opt_str_mapinclusionsexpression': 'substitute(v:val, "^\\*\\.", "", "")',
                \ 'opt_str_mapinclusionsexpressionseparator': ',',
                \ 'opt_str_mapinclusionsprefix': '--type-set="easygrep:ext:',
                \ 'opt_str_mapinclusionspostfix': '" --type=easygrep',
                \ })

    call s:RegisterGrepProgram("ack-grep", g:EasyGrep_commandParamsDict["ack"])

    call s:RegisterGrepProgram("ag", {
                \ 'req_str_programargs': '--nogroup --nocolor --column',
                \ 'req_bool_supportsexclusions': '1',
                \ 'req_str_recurse': '',
                \ 'req_str_caseignore': '-i',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '"',
                \ 'opt_str_patternpostfix': '"',
                \ 'opt_str_wholewordprefix': '',
                \ 'opt_str_wholewordpostfix': '',
                \ 'opt_str_wholewordoption': '-w ',
                \ 'req_str_escapespecialcharacters': "-\^$#.*+?()[]{}",
                \ 'opt_str_escapespecialcharacterstwice': "|",
                \ 'opt_str_mapexclusionsexpression': '"--ignore=\"".v:val."\""',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '1',
                \ 'opt_str_suppresserrormessages': '',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '1',
                \ 'opt_bool_isselffiltering': '0',
                \ 'opt_bool_nofiletargets': '0',
                \ 'opt_str_mapinclusionsexpression': '"--file-search-regex=\"" .substitute(v:val, "^\\*\\.", "\\\\.", "")."\""',
                \ 'opt_str_hiddenswitch': '--hidden',
                \ })

    call s:RegisterGrepProgram("pt", {
                \ 'req_str_programargs': '-e --nogroup --nocolor',
                \ 'req_bool_supportsexclusions': '0',
                \ 'req_str_recurse': '',
                \ 'req_str_caseignore': '-i',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '"',
                \ 'opt_str_patternpostfix': '"',
                \ 'opt_str_wholewordprefix': '',
                \ 'opt_str_wholewordpostfix': '',
                \ 'opt_str_wholewordoption': '-w ',
                \ 'req_str_escapespecialcharacters': "-\^$#.*+?()[]{}",
                \ 'opt_str_escapespecialcharacterstwice': "",
                \ 'opt_str_mapexclusionsexpression': '"--ignore=\"".v:val."\""',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '1',
                \ 'opt_str_suppresserrormessages': '',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '1',
                \ 'opt_bool_isselffiltering': '0',
                \ 'opt_bool_nofiletargets': '0',
                \ 'opt_str_mapinclusionsexpression': '"--file-search-regexp=\"" .substitute(v:val, "^\\*\\.", "\\\\.", "")."\""',
                \ 'opt_str_hiddenswitch': '--hidden',
                \ })

    call s:RegisterGrepProgram("csearch", {
                \ 'req_str_programargs': '-n',
                \ 'req_bool_supportsexclusions': '0',
                \ 'req_str_recurse': '',
                \ 'req_str_caseignore': '-i',
                \ 'req_str_casematch': '',
                \ 'opt_str_patternprefix': '"',
                \ 'opt_str_patternpostfix': '"',
                \ 'opt_str_wholewordprefix': '\b',
                \ 'opt_str_wholewordpostfix': '\b',
                \ 'opt_str_wholewordoption': '',
                \ 'req_str_escapespecialcharacters': "\^$#.*+?()[]{}",
                \ 'opt_str_escapespecialcharacterstwice': "",
                \ 'opt_str_mapexclusionsexpression': '',
                \ 'opt_bool_filtertargetswithnofiles': '0',
                \ 'opt_bool_bufferdirsearchallowed': '0',
                \ 'opt_str_suppresserrormessages': '',
                \ 'opt_bool_directoryneedsbackslash': '0',
                \ 'opt_bool_isinherentlyrecursive': '1',
                \ 'opt_bool_isselffiltering': '1',
                \ 'opt_bool_nofiletargets': '1',
                \ })

    "call s:RegisterGrepProgram("findstr", {
                "\ 'req_str_programargs': '/n',
                "\ 'req_bool_supportsexclusions': '0',
                "\ 'req_str_recurse': '/S',
                "\ 'req_str_caseignore': '/I',
                "\ 'req_str_casematch': '',
                "\ 'opt_str_warnonuse': 'The findstr program is buggy and not-recommended for use',
                "\ 'opt_str_patternprefix': '',
                "\ 'opt_str_patternpostfix': '',
                "\ 'opt_str_wholewordprefix': '"\<',
                "\ 'opt_str_wholewordpostfix': '\>"',
                "\ 'opt_str_wholewordoption': '',
                "\ 'req_str_escapespecialcharacters': "\^$#.*",
                "\ 'opt_str_escapespecialcharacterstwice': "",
                "\ 'opt_str_mapexclusionsexpression': '',
                "\ 'opt_bool_filtertargetswithnofiles': '1',
                "\ 'opt_bool_bufferdirsearchallowed': '1',
                "\ 'opt_str_suppresserrormessages': '',
                "\ 'opt_bool_directoryneedsbackslash': '1',
                "\ 'opt_bool_isinherentlyrecursive': '0',
                "\ 'opt_bool_isselffiltering': '0',
                "\ })
endfunction
" }}}
" GetGrepCommandParameters {{{
function! s:GetGrepCommandParameters()
    call s:ConfigureGrepCommandParameters()
    if s:IsCommandVimgrep()
        return g:EasyGrep_commandParamsDict["vimgrep"]
    endif

    let programName = s:GetGrepProgramName()
    if !has_key(g:EasyGrep_commandParamsDict, programName)
        return {}
    endif

    return g:EasyGrep_commandParamsDict[programName]
endfunction
" }}}
" GetGrepCommandLine {{{
function! s:GetGrepCommandLine(pattern, add, wholeword, count, escapeArgs, filterTargetsWithNoFiles, xgrep)

    call s:CheckCommandRequirements()

    let com = s:GetGrepCommandName()

    let bang = ""
    let aux_pattern_postfix = ""
    if s:IsCommandVimgrep()
        if g:EasyGrepEveryMatch
            let aux_pattern_postfix .= "g"
        endif

        if !g:EasyGrepJumpToMatch
            let aux_pattern_postfix .= "j"
        endif
    else
        if !g:EasyGrepJumpToMatch
            let bang = "!"
        endif
    endif

    if g:EasyGrepInvertWholeWord
        let wholeword = !a:wholeword
    else
        let wholeword = a:wholeword
    endif

    let commandParams = s:GetGrepCommandParameters()

    let pattern = a:escapeArgs ? s:EscapeSpecialCharacters(a:pattern) : a:pattern

    " Enclose the pattern if needed; build from inner to outer
    if wholeword
        let pattern = commandParams["opt_str_wholewordprefix"].pattern.commandParams["opt_str_wholewordpostfix"]
    endif
    let pattern = commandParams["opt_str_patternprefix"].pattern.commandParams["opt_str_patternpostfix"]

    let opts = a:xgrep
    if wholeword
        let opts .= s:CommandParameterOr(commandParams, "opt_str_wholewordoption", "")
    endif

    if s:IsRecursiveSearch()
        if s:CommandHasLen("req_str_recurse")
            let opts .= commandParams["req_str_recurse"]." "
        endif
    endif

    if g:EasyGrepIgnoreCase
        if s:CommandHasLen("req_str_caseignore")
            let opts .= commandParams["req_str_caseignore"]." "
        endif
    else
        if s:CommandHasLen("req_str_casematch")
            let opts .= commandParams["req_str_casematch"]." "
        endif
    endif

    if g:EasyGrepHidden && s:CommandHasLen("opt_str_hiddenswitch")
        let opts .= commandParams["opt_str_hiddenswitch"]." "
    endif

    " Suppress errors
    if s:CommandHasLen("opt_str_suppresserrormessages")
        let opts .= commandParams["opt_str_suppresserrormessages"]." "
    endif

    let fileTargetList = s:CommandHas("opt_bool_nofiletargets") ? [] : s:GetFileTargetList(1)
    let filesToExclude = g:EasyGrepFilesToExclude

    if a:filterTargetsWithNoFiles && s:CommandHas("opt_bool_filtertargetswithnofiles")
        call s:FilterTargetsWithNoFiles(fileTargetList)
    endif

    if s:CommandHas("opt_bool_directoryneedsbackslash")
        call map(fileTargetList, 'EasyGrep#ForwardToBackSlash(v:val)')
    endif

    " Set extra inclusions and exclusions
    if s:IsModeFiltered() && s:CommandHasLen("opt_str_mapinclusionsexpression") && match(fileTargetList, "*", 0) != -1
        " Explicitly specify the file types as arguments according to the configured expression
        let opts .= " "
            \ . s:CommandParameterOr(commandParams, "opt_str_mapinclusionsprefix", "")
            \ . join(map(fileTargetList, commandParams["opt_str_mapinclusionsexpression"]), s:CommandParameterOr(commandParams, "opt_str_mapinclusionsexpressionseparator", ' '))
            \ . s:CommandParameterOr(commandParams, "opt_str_mapinclusionspostfix", "")
            \ . " "
        " while the files we specify will be directories
        let fileTargetList = s:GetDirectorySearchList()
    endif

    " Add exclusions
    if s:CommandHasLen("opt_str_mapexclusionsexpression")
        let opts .= " " . join(map(split(filesToExclude, ','), commandParams["opt_str_mapexclusionsexpression"]), ' ') . " "
    endif

    if s:CommandHas("opt_bool_isinherentlyrecursive")
        " Eliminate a trailing star
        call map(fileTargetList, 'substitute(v:val, "/\\*$", "/", "")')
        " Replace an individual star with a dot
        call map(fileTargetList, 'substitute(v:val, "^\\*$", s:GetGrepRoot(), "")')
    endif

    " Finally, ensure that the paths we pass to the external grep command are
    " absolute paths. This command may be invoked from any location.
    if !s:IsCommandVimgrep()
        call map(fileTargetList, 'substitute(v:val, "^\\.\\/", EasyGrep#GetCwdEscaped()."/", "")')
        call map(fileTargetList, 'substitute(v:val, "^\\.$", EasyGrep#GetCwdEscaped(), "")')
    endif

    let filesToGrep = join(fileTargetList, ' ')

    let win = g:EasyGrepWindow != 0 ? "l" : ""
    let grepCommand = a:count.win.com.a:add.bang." ".opts.pattern.aux_pattern_postfix." ".filesToGrep

    return grepCommand
endfunction
"}}}
" HasTargetsThatMatch {{{
function! s:HasTargetsThatMatch(pattern)
    call s:CheckIfCurrentFileIsSearched()

    if s:IsModeBuffers() && empty(s:GetFileTargetList(1))
        call EasyGrep#Warning("No saved buffers to explore")
        return 0
    endif

    if g:EasyGrepExtraWarnings && !s:IsRecursiveSearch()
        " Don't evaluate if in recursive mode, this will take too long
        if !s:HasFilesThatMatch()
            call s:WarnNoMatches(a:pattern)
            return 0
        endif
    endif

    return 1
endfunction

" }}}
" DoGrep {{{
function! s:DoGrep(pattern, add, wholeword, count, escapeArgs, xgrep)
    call s:CreateGrepDictionary()

    if s:OptionsExplorerOpen == 1
        call EasyGrep#Error("Error: Can't Grep while options window is open")
        return 0
    endif

    if !s:HasTargetsThatMatch(a:pattern)
        return 0
    endif

    let commandName = s:GetGrepCommandName()
    if !s:ValidateGrepCommand()
        return 0
    endif

    call s:SetGrepVariables(commandName)
    let grepCommand = s:GetGrepCommandLine(a:pattern, a:add, a:wholeword, a:count, a:escapeArgs, 1, a:xgrep)

    " change directory to the grep root before executing
    call s:ChangeDirectoryToGrepRoot()

    let failed = 0
    try
        if s:IsRecursiveSearch()
            call EasyGrep#Info("Running a recursive search, this may take a while")
        endif

        call EasyGrep#Log(grepCommand)
        silent execute grepCommand
    catch /.*E303.*/
        " This error reports that a swap file could not be opened; this is not a critical error
        let failed = 0
    catch
        if v:exception != 'E480'
            call s:WarnNoMatches(a:pattern)
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
            call EasyGrep#Error("FIXME: exception not caught ".v:exception)
        endif
        let failed = 1
    endtry

    " Return to the previous directory
    call s:ChangeDirectoryToPrevious()

    call s:RestoreGrepVariables()
    if failed
        return 0
    endif

    if s:HasGrepResults()
        " In some cases the colors of vim's layout might be borked, so force vim to redraw:
        redraw!
        if g:EasyGrepOpenWindowOnMatch
            if g:EasyGrepWindow == 0
                if !EasyGrep#IsQuickfixListOpen()
                    execute g:EasyGrepWindowPosition." copen"
                endif
            else
                if !EasyGrep#IsLocationListOpen()
                    execute g:EasyGrepWindowPosition." lopen"
                endif
            endif
            setlocal nofoldenable
        endif
    else
        call s:WarnNoMatches(a:pattern)
        return 0
    endif

    return 1
endfunction
" }}}
" HasGrepResults{{{
function! s:HasGrepResults()
    return !empty(EasyGrep#GetErrorList())
endfunction
"}}}
" HasFilesThatMatch{{{
function! s:HasFilesThatMatch()
    let fileTargetList = s:GetFileTargetList(1)
    for p in fileTargetList
        let p = EasyGrep#Trim(p)
        let fileList = glob(p, 0, 1)
        for f in fileList
            if filereadable(f)
                return 1
            endif
        endfor
    endfor

    return 0
endfunction
"}}}
" FilterTargetsWithNoFiles {{{
function! s:FilterTargetsWithNoFiles(fileTargetList)
    call filter(a:fileTargetList, 'glob(EasyGrep#Trim(v:val)) != ""')
endfunction
"}}}
" WarnNoMatches {{{
function! s:WarnNoMatches(pattern)
    if s:IsModeBuffers()
        let fpat = "*Buffers*"
    elseif s:IsModeAll()
        let fpat = "*"
    else
        let fpat = join(s:GetFileTargetList(0), ', ')
    endif

    let r = s:IsRecursiveSearch() ? " (+Recursive)" : ""
    let h = g:EasyGrepHidden    ? " (+Hidden)"    : ""

    redraw
    call EasyGrep#Warning("No matches for '".a:pattern."'")
    call EasyGrep#Warning("File Pattern: ".fpat.r.h)

    let dirs = s:GetDirectorySearchList()
    let s = "Directories:"
    for d in dirs
        call EasyGrep#Warning(s." ".d)
        let s = "            "
    endfor
    if !empty(g:EasyGrepFilesToExclude) && s:CommandSupportsExclusions()
        call EasyGrep#Warning("Exclusions:  ".g:EasyGrepFilesToExclude)
    endif
endfunction
" }}}
" }}}
" Replace Implementation {{{
" ReplaceString {{{
function! s:ReplaceString(str, wholeword, escapeArgs)
    call s:CheckIfCurrentFileIsSearched()
    let r = input("Replace '".a:str."' with: ", a:str)
    if empty(r)
        let confirmed = confirm("Proceed replacing '".a:str."' with an empty pattern, effectively deleting it?", "&Yes\n&No")-1
        if confirmed
            return
        endif
    endif
    if r ==# a:str
        call s:EchoNewline()
        call EasyGrep#Warning("No change in pattern, ignoring")
        return
    endif

    call s:DoReplace(a:str, r, a:wholeword, a:escapeArgs)
endfunction
"}}}
" DoReplace {{{
function! s:DoReplace(target, replacement, wholeword, escapeArgs)

    if !s:DoGrep(a:target, "", a:wholeword, "", a:escapeArgs, "")
        return
    endif

    let target = a:escapeArgs ? s:EscapeSpecialCharacters(a:target) : a:target
    let replacement = a:replacement

    let s:LastErrorList = deepcopy(EasyGrep#GetErrorList())
    let numMatches = len(s:LastErrorList)

    let s:actionList = []

    call EasyGrep#SaveVariable("switchbuf")
    set switchbuf=useopen
    if g:EasyGrepReplaceWindowMode == 2
        call EasyGrep#SaveVariable("autowriteall")
        set autowriteall
    else
        if g:EasyGrepReplaceWindowMode == 0
            set switchbuf+=usetab
        else
            set switchbuf+=split
        endif
    endif

    let bufList = EasyGrep#GetVisibleBuffers()

    call EasyGrep#GotoStartErrorList()

    call EasyGrep#SaveVariable("ignorecase")
    let &ignorecase = g:EasyGrepIgnoreCase

    call EasyGrep#SaveVariable("cursorline")
    set cursorline
    call EasyGrep#SaveVariable("hlsearch")
    set hlsearch

    if g:EasyGrepIgnoreCase
        let case = '\c'
    else
        let case = '\C'
    endif

    if g:EasyGrepInvertWholeWord
        let wholeword = !a:wholeword
    else
        let wholeword = a:wholeword
    endif

    if wholeword
        let target = "\\<".target."\\>"
    endif

    let finished = 0
    let lastFile = -1
    let doAll = exists("g:EasyGrepAutomatedTest")
    let i = 0
    while i < numMatches && !finished
        try
            let pendingQuit = 0
            let doit = 1

            let thisFile = s:LastErrorList[i].bufnr
            if thisFile != lastFile
                call EasyGrep#RestoreVariable("cursorline", "no")
                call EasyGrep#RestoreVariable("hlsearch", "no")
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

                let linebeg = s:EscapeSpecialCharactersForVim(linebeg)
                let m = s:EscapeSpecialCharactersForVim(m)
                let lineafterm = s:EscapeSpecialCharactersForVim(lineafterm)

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
            call EasyGrep#Warning("Ran out of room for more windows")
            let finished = confirm("Do you want to save all windows and continue?", "&Yes\n&No")-1
            if finished == 1
                call EasyGrep#Warning("To continue, save unsaved windows, make some room (try :only) and run Replace again")
            else
                wall
                only
            endif
        catch /^Vim:Interrupt$/
            redraw
            call EasyGrep#Warning("Replace interrupted by user")
            let finished = confirm("Are you sure you want to stop the replace?", "&Yes\n&No")-1
            let finished = !finished
        catch
            redraw
            echo "Exception encountered: ".v:exception
            call EasyGrep#Warning("Replace interrupted")
            let finished = confirm("Do you want to continue replace?", "&Yes\n&No")-1
        endtry

        let i += 1

    endwhile

    call EasyGrep#RestoreVariable("switchbuf")
    call EasyGrep#RestoreVariable("autowriteall")
    call EasyGrep#RestoreVariable("cursorline")
    call EasyGrep#RestoreVariable("hlsearch")
    call EasyGrep#RestoreVariable("ignorecase")
endfunction
"}}}
" }}}
" ResultList Functions {{{
" ResultListFilter {{{
function! s:ResultListFilter(...)
    let mode = 'g'
    let entry = 'd.text'

    let filterlist = []
    for s in a:000
        if s[0] == '-'
            if s == '-v'
                let mode = 'v'
            elseif s == '-g'
                if mode == 'v'
                    call EasyGrep#Error("Multiple -v / -g arguments given")
                    return
                endif
                let mode = 'g'
            elseif s == '-f'
                let entry = 'bufname(d.bufnr)'
            else
                call EasyGrep#Error("Invalid command line switch")
                return
            endif
        else
            call add(filterlist, s)
        endif
    endfor

    if empty(filterlist)
        call EasyGrep#Error("Missing pattern to filter")
        return
    endif

    let lst = EasyGrep#GetErrorList()
    if empty(lst)
        call EasyGrep#Error("Error list is empty")
        return
    endif

    let newlst = []
    for d in lst
        let matched = 0
        for f in filterlist
            exe "let r = match(".entry.", f)"
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

    call EasyGrep#SetErrorList(newlst)
endfunction
"}}}
" ResultListOpen {{{
function! s:ResultListOpen(...)
    let lst = EasyGrep#GetErrorList()

    if empty(lst)
        call EasyGrep#Error("Error list is empty")
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
    let lst = EasyGrep#GetErrorList()
    if empty(lst)
        call EasyGrep#Error("Error list is empty")
        return
    endif

    let numMatches = len(lst)

    call EasyGrep#SaveVariable("switchbuf")
    set switchbuf=useopen
    if g:EasyGrepReplaceWindowMode == 2
        call EasyGrep#SaveVariable("autowriteall")
        set autowriteall
    else
        if g:EasyGrepReplaceWindowMode == 0
            set switchbuf+=usetab
        else
            set switchbuf+=split
        endif
    endif

    let bufList = EasyGrep#GetVisibleBuffers()

    call EasyGrep#GotoStartErrorList()

    call EasyGrep#SaveVariable("cursorline")
    set cursorline

    let finished = 0
    let lastFile = -1
    let doAll = exists("g:EasyGrepAutomatedTest")
    let i = 0
    while i < numMatches && !finished
        try
            let pendingQuit = 0
            let doit = 1

            let thisFile = lst[i].bufnr
            if thisFile != lastFile
                call EasyGrep#RestoreVariable("cursorline", "no")
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
                exe a:command
            endif

            if pendingQuit
                break
            endif

        catch /^Vim(\a\+):E36:/
            redraw
            call EasyGrep#Warning("Ran out of room for more windows")
            let finished = confirm("Do you want to save all windows and continue?", "&Yes\n&No")-1
            if finished == 1
                call EasyGrep#Warning("To continue, save unsaved windows, make some room (try :only) and run Replace again")
            else
                wall
                only
            endif
        catch /^Vim:Interrupt$/
            redraw
            call EasyGrep#Warning("ResultListDo interrupted by user")
            let finished = confirm("Are you sure you want to stop the ResultListDo?", "&Yes\n&No")-1
            let finished = !finished
        catch
            redraw
            echo "Exception encountered: ".v:exception
            call EasyGrep#Warning("ResultListDo interrupted")
            let finished = confirm("Do you want to continue ResultListDo?", "&Yes\n&No")-1
        endtry

        let i += 1

    endwhile

    call EasyGrep#RestoreVariable("switchbuf")
    call EasyGrep#RestoreVariable("autowriteall")
    call EasyGrep#RestoreVariable("cursorline")

endfunction
"}}}
" ResultListSave {{{
function! s:ResultListSave(f)
    if filereadable(a:f)
        let confirmed = confirm("File '".a:f."' exists; overwrite it?", "&Yes\n&No")-1
        if confirmed
            return
        endif
        call s:Echo("Proceeding to overwrite '".a:f."'")
    endif

    let lst = EasyGrep#GetErrorList()

    if empty(lst)
        call EasyGrep#Error("No result list to save")
        return
    endif

    try
        let contents = []
        for e in lst
            let line = bufname(e.bufnr)."|".e.lnum." col ".e.col."| ".e.text
            call insert(contents, line, len(contents))
        endfor

        call writefile(contents, a:f)
    catch
        call EasyGrep#Error("Error saving result list to '".a:f."'")
        return
    endtry

    call s:Echo("Result list was saved to '".a:f."' successfully")
endfunction
"}}}
" ResultListTag {{{
function! s:ResultListTag(tag)
    let lst = EasyGrep#GetErrorList()

    let entry = {
                \ 'bufnr' : bufnr('%'),
                \ 'lnum' : 1,
                \ 'col' : 1,
                \ 'vcol' : 0,
                \ 'nr' : 0,
                \ 'pattern' : '',
                \ 'text' : a:tag,
                \ 'type' : '1',
                \ 'valid' : 0,
                \ }

    call add(lst, entry)

    call EasyGrep#SetErrorList(lst)
endfunction
"}}}
" }}}
" }}}

" Commands {{{
command! -nargs=+ Grep :call s:GrepCommandLine( <q-args> , "")
command! -nargs=+ GrepAdd :call s:GrepCommandLine( <q-args>, "add")
command! GrepOptions :call <sid>GrepOptions()
command! -nargs=? GrepProgram :call <sid>ChooseGrepProgram(<f-args>)
command! -nargs=? -complete=dir GrepRoot :call <sid>SetGrepRoot(<f-args>)

command! -bang -nargs=+ Replace :call s:Replace("<bang>", <q-args>)
command! ReplaceUndo :call s:ReplaceUndo()

command! -nargs=0 ResultListOpen :call s:ResultListOpen()
command! -nargs=+ ResultListFilter :call s:ResultListFilter(<f-args>)
command! -nargs=+ ResultListDo :call s:ResultListDo(<q-args>)
command! -nargs=1 ResultListSave :call s:ResultListSave(<q-args>)
command! -nargs=1 ResultListTag :call s:ResultListTag(<q-args>)
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
    let s:SanitizeModeLock = 1
    if !exists("g:EasyGrepMode")
        let g:EasyGrepMode=s:EasyGrepModeAll
        " 0 - All
        " 1 - Buffers
        " 2 - Track
        " 3 - User
    else
        if g:EasyGrepMode < 0 || g:EasyGrepMode >= s:EasyGrepNumModesWithSpecial
            call EasyGrep#Error("Invalid value for g:EasyGrepMode (".g:EasyGrepMode."); reverting to 'All' mode.")
            let g:EasyGrepMode = s:EasyGrepModeAll
        endif
        call s:CheckCommandRequirements()
    endif
    let s:SanitizeModeLock = 0
endfunction

if !exists("g:EasyGrepRoot")
    let g:EasyGrepRoot="cwd"
endif

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
    let sawError = 0
    if exists("g:EasyGrepFileAssociations")
        if filereadable(g:EasyGrepFileAssociations)
            return g:EasyGrepFileAssociations
        endif
        let sawError = 1
        call EasyGrep#Error("The file specified by g:EasyGrepFileAssociations=".g:EasyGrepFileAssociations." cannot be read")
        call EasyGrep#Error("    Attempting to look for 'EasyGrepFileAssociations' in other locations")
    endif

    let nextToSource=fnamemodify(s:EasyGrepSourceFile, ":h")."/EasyGrepFileAssociations"
    if filereadable(nextToSource)
        let g:EasyGrepFileAssociations = nextToSource
    else
        let VimfilesDirs=split(&runtimepath, ',')
        for v in VimfilesDirs
            let f = EasyGrep#BackToForwardSlash(v)."/plugin/EasyGrepFileAssociations"
            if filereadable(f)
                let g:EasyGrepFileAssociations=f
            endif
        endfor
    endif

    if empty(g:EasyGrepFileAssociations)
        let g:EasyGrepFileAssociations=""
    elseif sawError
        call EasyGrep#Error("    Found at: ".g:EasyGrepFileAssociations)
        call EasyGrep#Error("    Please fix your configuration to suppress these messages")
    endif
    return g:EasyGrepFileAssociations
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
        call EasyGrep#Error("Invalid value for g:EasyGrepReplaceWindowMode")
        let g:EasyGrepReplaceWindowMode = 0
    endif
endif

if !exists("g:EasyGrepReplaceAllPerFile")
    let g:EasyGrepReplaceAllPerFile=0
endif

if !exists("g:EasyGrepExtraWarnings")
    let g:EasyGrepExtraWarnings=0
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
       call EasyGrep#Error("Invalid position specified in g:EasyGrepWindowPosition")
       let g:EasyGrepWindowPosition=""
   endif
endif

if !exists("g:EasyGrepFilesToInclude")
    let g:EasyGrepFilesToInclude=""
endif

if !exists("g:EasyGrepFilesToExclude")
    let g:EasyGrepFilesToExclude="*.swp,*~"
endif

if !exists("g:EasyGrepPatternType")
    let g:EasyGrepPatternType="regex"
endif

" CheckDefaultUserPattern {{{
function! s:CheckDefaultUserPattern()
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
        call EasyGrep#Error(error)
        call s:ForceGrepMode(s:EasyGrepModeAll)
    endif
endfunction
"}}}

"}}}
" Script Finalization {{{
call s:ConfigureGrepCommandParameters()
call s:InitializeMode()
call s:CreateGrepDictionary()
call s:InitializeCommandChoice()
call s:CreateOptionMappings()
call s:SetWatchExtension()
call s:CheckDefaultUserPattern()
"}}}

