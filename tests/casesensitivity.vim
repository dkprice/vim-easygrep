

" TODO: ensure that the configuration is already set

let g:EasyGrepDefaultUserPattern="alphabet.in"
let g:EasyGrepMode=3

" Load the test data. 
edit alphabet.in

" case-sensitive
let g:EasyGrepIgnoreCase=0
ResultListTag EasyGrepTest GrepAdd c g:EasyGrepIgnoreCase=0
GrepAdd c
ResultListTag EasyGrepTest GrepAdd C g:EasyGrepIgnoreCase=0
GrepAdd C
ResultListTag EasyGrepTest GrepAdd -I c
GrepAdd -I c
ResultListTag EasyGrepTest GrepAdd -I C
GrepAdd -I C

" case-insensitive
let g:EasyGrepIgnoreCase=1
ResultListTag EasyGrepTest GrepAdd c g:EasyGrepIgnoreCase=1
GrepAdd c
ResultListTag EasyGrepTest GrepAdd C g:EasyGrepIgnoreCase=1
GrepAdd C
ResultListTag EasyGrepTest GrepAdd -i c
GrepAdd -i c
ResultListTag EasyGrepTest GrepAdd -i C
GrepAdd -i C

cclose
exe "ResultListSave ".testname.".out"
quit!


