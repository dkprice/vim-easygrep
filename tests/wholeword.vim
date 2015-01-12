

let g:EasyGrepDefaultUserPattern="__wholeword.in"
let g:EasyGrepMode=3

" Load the test data. 
edit __wholeword.in

Grep whole
GrepAdd word
GrepAdd wholeword

" Invert whole word
GrepAdd! whole
GrepAdd! word
GrepAdd! wholeword

cclose
exe "ResultListSave ".testname.".out"
quit!


