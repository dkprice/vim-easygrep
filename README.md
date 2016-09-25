vim-easygrep
============

Fast and Easy Find and Replace Across Multiple Files

EasyGrep is a plugin for performing search and replace operations through multiple files. Vim already has builtin support for searching through files with its 'vimgrep' and 'grep' commands, but EasyGrep makes using them much, much easier.

## Why EasyGrep?

* Supports multiple Grep programs (vimgrep, grep, ack, ag, pt, git grep, csearch).
* Mapping-based or command-based searches.
* Allows searching all files, just buffers, or a user-specified pattern. Allows
excluding unwanted files.
* Searches from a configurable location, like a project root (.git,.hg,.svn), current
directory, or arbitrary directory.
* Automatically escapes patterns to avoid regex confusion (so that you can
search text like '->data()[x][y][z]')
* Offers an interactive options explorer.
* And much more...

## Using Easygrep

Keymappings:

    <Leader>vv  - Grep for the word under the cursor, match all occurences,
                  like |gstar|
    <Leader>vV  - Grep for the word under the cursor, match whole word, like
                  |star|
    <Leader>va  - Like vv, but add to existing list
    <Leader>vA  - Like vV, but add to existing list
    <Leader>vr  - Perform a global search on the word under the cursor
                  and prompt for a pattern with which to replace it.
    <Leader>vo  - Select the files to search in and set grep options
    <Leader>vy* - Invoke any option from the options explorer, where * is the
                  shortcut for that option.
                  e.g. <Leader>vyr - toggles recursion
                       <Leader>vyb - sets buffer grepping mode
                       etc.


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

    :ResultListOpen
        Open all files in the result list

    :ResultListFilter [+arg]
        Filter the result list according to a user pattern, matching either file
        or the result list text.

    :ResultListDo [+arg]
        Perform an action on all entries in the quickfix list

## Using Easygrep with perl style regexp

you may use perl style regexp while using Easygrep, simply:

1. have https://github.com/othree/eregex.vim installed
1. have `let g:EasyGrepCommand=1` and `grepprg` been set properly
1. have `let g:EasyGrepPerlStyle=1`
1. also make sure you have GNU grep greater than 2.5.3


## Screencast

![Alt text](https://cloud.githubusercontent.com/assets/2375604/9804914/d0c39ff0-5800-11e5-8e7d-b77543bf2dcf.gif "EasyGrep demo")

