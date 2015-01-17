

" TODO: ensure that the configuration is already set

let g:EasyGrepMode=0

" Load the test data. 
cd allext/
edit alphabet.a

let EasyGrepFilesToExclude="*.b,*.c"
ResultListTag GrepAdd a (exclude b c)
GrepAdd a
ResultListTag GrepAdd A (exclude b c)
GrepAdd A
let EasyGrepFilesToExclude="*.a,*.c"
ResultListTag GrepAdd b (exclude a c)
GrepAdd b
ResultListTag GrepAdd B (exclude a c)
GrepAdd B
let EasyGrepFilesToExclude="*.a,*.b"
ResultListTag GrepAdd c (exclude a b)
GrepAdd c
ResultListTag GrepAdd C (exclude a b)
GrepAdd C

cclose
cd ../
exe "ResultListSave ".testname.".out"
quit!


