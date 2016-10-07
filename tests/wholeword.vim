

let g:EasyGrepDefaultUserPattern="__wholeword.in"
let g:EasyGrepMode=3

" Load the test data. 
edit __wholeword.in

" Search no whole word
ResultListTag EasyGrepTest GrepAdd whole
GrepAdd whole
ResultListTag EasyGrepTest GrepAdd word
GrepAdd word
ResultListTag EasyGrepTest GrepAdd wholeword
GrepAdd wholeword

" Explicit whole word
ResultListTag EasyGrepTest GrepAdd -w whole
GrepAdd -w whole
ResultListTag EasyGrepTest GrepAdd -w word
GrepAdd -w word
ResultListTag EasyGrepTest GrepAdd -w wholeword
GrepAdd -w wholeword

cclose
ResultListSanitize
exe "ResultListSave ".testname.".out"
quit!


