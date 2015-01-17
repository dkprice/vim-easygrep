
let g:EasyGrepDefaultUserPattern="__simpleregex.in"
let g:EasyGrepMode=3

" Search
ResultListTag GrepAdd -E [a-c]
GrepAdd -E [a-c]

ResultListTag GrepAdd -E [A-C]
GrepAdd -E [A-C]

ResultListTag GrepAdd -F [a-c]
GrepAdd -F [a-c]

ResultListTag GrepAdd -F [A-C]
GrepAdd -F [A-C]


cclose
exe "ResultListSave ".testname.".out"
quit!


