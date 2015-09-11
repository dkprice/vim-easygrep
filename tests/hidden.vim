
let g:EasyGrepMode=0
GrepRoot hidden

" no hidden files
let g:EasyGrepHidden=0
ResultListTag GrepAdd c g:EasyGrepHidden=0
GrepAdd c
ResultListTag GrepAdd C g:EasyGrepHidden=0
GrepAdd C

" hidden files
let g:EasyGrepHidden=1
ResultListTag GrepAdd c g:EasyGrepHidden=1
GrepAdd c
ResultListTag GrepAdd C g:EasyGrepHidden=1
GrepAdd C

cclose
exe "ResultListSave ".testname.".out"
quit!


