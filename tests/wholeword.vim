

let g:EasyGrepDefaultUserPattern="__wholeword.in"
let g:EasyGrepMode=3

" Load the test data. 
edit __wholeword.in

" Search no whole word
Grep whole
GrepAdd word
GrepAdd wholeword

" Explicit whole word
GrepAdd -w whole
GrepAdd -w word
GrepAdd -w wholeword

cclose
exe "ResultListSave ".testname.".out"
quit!


