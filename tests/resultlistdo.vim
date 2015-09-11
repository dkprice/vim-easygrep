
let testname="resultlistdo"
let g:EasyGrepDefaultUserPattern="__resultlistdo.in"
let g:EasyGrepMode=3

" Search
ResultListTag GrepAdd resultlist
GrepAdd resultlist

" Exercise
ResultListDo s/resultlistdo/resultlistfroo/e
wa

" Search
ResultListTag GrepAdd resultlistfroo
GrepAdd resultlistfroo

" Restore the input
ResultListDo s/resultlistfroo/resultlistdo/e
wa

" Search again
ResultListTag GrepAdd resultlist
GrepAdd resultlist

" Save results
exe "ResultListSave ".testname.".out"

cclose
quitall!
