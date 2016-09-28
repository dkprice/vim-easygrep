
" TODO: ensure that the configuration is already set

" We set recursive to 0 despite this not having any effect on some
" grep programs.
" This is to isolate a problem seen in other grep programs.
let g:EasyGrepMode=2
let g:EasyGrepRecursive=0

edit alphabet.in

ResultListTag EasyGrepTest GrepAdd a
GrepAdd a

cclose
ResultListSanitize
exe "ResultListSave ".testname.".out"
quit!


