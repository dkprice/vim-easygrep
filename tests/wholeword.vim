

let g:EasyGrepDefaultUserPattern="__wholeword.in"
let g:EasyGrepMode=3

" Load the test data. 
edit __wholeword.in

" Search no whole word
ResultListTag GrepAdd whole
GrepAdd whole
ResultListTag GrepAdd word
GrepAdd word
ResultListTag GrepAdd wholeword
GrepAdd wholeword

" Explicit whole word
ResultListTag GrepAdd -w whole
GrepAdd -w whole
ResultListTag GrepAdd -w word
GrepAdd -w word
ResultListTag GrepAdd -w wholeword
GrepAdd -w wholeword

cclose
exe "ResultListSave ".testname.".out"
quit!


