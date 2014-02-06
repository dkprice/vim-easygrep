
let testname="casesensitivity"
let g:EasyGrepDefaultUserPattern="alphabet.in"
let g:EasyGrepMode=3

" Load the test data. 
edit alphabet.in

let g:EasyGrepIgnoreCase=0
Grep c
GrepAdd C
let g:EasyGrepIgnoreCase=1
GrepAdd c
GrepAdd C
cclose

exe "ResultListSave ".testname.".out"
quit!


