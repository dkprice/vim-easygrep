
let g:EasyGrepMode=0
GrepRoot hidden

" no hidden files
let g:EasyGrepHidden=0
ResultListTag EasyGrepTest GrepAdd c g:EasyGrepHidden=0
GrepAdd c
ResultListTag EasyGrepTest GrepAdd C g:EasyGrepHidden=0
GrepAdd C

" hidden files
let g:EasyGrepHidden=1
ResultListTag EasyGrepTest GrepAdd c g:EasyGrepHidden=1
GrepAdd c
ResultListTag EasyGrepTest GrepAdd C g:EasyGrepHidden=1
GrepAdd C

cclose
ResultListSanitize
exe "ResultListSave ".testname.".out"
quit!


