vim-easygrep
============

Fast and Easy Find and Replace Across Multiple Files

EasyGrep is a plugin for performing search and replace operations through multiple files. Vim already has builtin support for searching through files with its 'vimgrep' and 'grep' commands, but EasyGrep makes using them much, much easier. It also provides a powerful "Replace in Files" operation, something that is not very easy to do in Vim by default. With EasyGrep, you can specify with high-precision exactly the type of files you want to search, whether it be all files, only open buffers, only files matching a pattern, etc. Additionally, you can easily specify searching through hidden files, case-sensitivity, performing a recursive search, and many more options that make searching more easy. 

EasyGrep provides both key mappings and commands to make search and replace easy. When using EasyGrep, searching for a word is as easy as typing <leader>vv (v v, not double-u) over the word for which you want to search.  This search can also be accomplished with the :Grep command and a user-specified pattern. Performing a "replace in files" is similar; type <leader>vr or use the :Replace command. Setting options is easy, simply type <leader>vo or :GrepOptions.  EasyGrep provides a great set of defaults but can also be configured to start up just how you like it; see the script for these options.  Most vimgrep (and grepprg) options are supported.   

For a screencast of the script in action go here: http://downloads.veryspeedy.net/vim/EasyGrep.gif 

Keymappings: 

    <Leader>vv  - Grep for the word under the cursor, match all occurences, 
                  like |gstar| 
    <Leader>vV  - Grep for the word under the cursor, match whole word, like 
                  |star| 
    <Leader>va  - Like vv, but add to existing list 
    <Leader>vA  - Like vV, but add to existing list 
    <Leader>vr  - Perform a global search search on the word under the cursor 
                  and prompt for a pattern with which to replace it. 
    <Leader>vo  - Select the files to search in and set grep options 

Commands: 

    :Grep [arg] 
        Search for the specified arg, like <Leader>vv.  When an ! is added, 
        search like <Leader>vV 

    :GrepAdd [arg] 
        Search for the specified arg, add to existing file list, as in 
        <Leader>va.  When an ! is added, search like <Leader>vA 

    :Replace [target] [replacement] 
        Perform a global search and replace.  The function searches 
        the same set of files a grep for the desired target and opens a dialog to 
        confirm replacement. 
     
    :ReplaceUndo 
        Undoes the last :Replace operation.  Does not stack successive 
        searches; only the last replace may be undone.  This function may not 
        work well when edits are made between a call to Replace and a call to 
        ReplaceUndo. 

    :GrepOptions
        Open a window to set grep options.

    :GrepProgram [+arg] 
        Select a grep program from a list of programs found on your system. An
        optional argument may be provided to switch to the program without user
        interaction.

    :GrepRoot [+arg] 
        Configure the location that EasyGrep searches from. An optional argument
        may be provided to switch to the program without user interaction.
        Roots:
          1. The current directory. As the current directory changes, the search
             location changes automatically.
          2. A dynamic directory that easygrep searches for. This is useful for
             finding the root of a project with a marker like ".git".
          3. A user specified directory. The search location is fixed and does 
             not change.
        
        

