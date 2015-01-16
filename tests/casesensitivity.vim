

" TODO: ensure that the configuration is already set

let g:EasyGrepDefaultUserPattern="alphabet.in"
let g:EasyGrepMode=3

" Load the test data. 
edit alphabet.in

" case-sensitive
let g:EasyGrepIgnoreCase=0
Grep c
GrepAdd C
GrepAdd -I c
GrepAdd -I C

" case-insensitive
let g:EasyGrepIgnoreCase=1
GrepAdd c
GrepAdd C
GrepAdd -i c
GrepAdd -i C

cclose
exe "ResultListSave ".testname.".out"
quit!


