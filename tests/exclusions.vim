

" TODO: ensure that the configuration is already set

let g:EasyGrepMode=0

" Load the test data. 
cd allext/
edit alphabet.a

let EasyGrepFilesToExclude="*.b,*.c"
ResultListTag EasyGrepTest GrepAdd a (exclude b c)
GrepAdd a
ResultListTag EasyGrepTest GrepAdd A (exclude b c)
GrepAdd A
let EasyGrepFilesToExclude="*.a,*.c"
ResultListTag EasyGrepTest GrepAdd b (exclude a c)
GrepAdd b
ResultListTag EasyGrepTest GrepAdd B (exclude a c)
GrepAdd B
let EasyGrepFilesToExclude="*.a,*.b"
ResultListTag EasyGrepTest GrepAdd c (exclude a b)
GrepAdd c
ResultListTag EasyGrepTest GrepAdd C (exclude a b)
GrepAdd C

cclose
cd ../
exe "ResultListSave ".testname.".out"
quit!


