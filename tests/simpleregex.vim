
let g:EasyGrepDefaultUserPattern="__simpleregex.in"
let g:EasyGrepMode=3

" Search
ResultListTag EasyGrepTest GrepAdd -E [a-c]
GrepAdd -E [a-c]

ResultListTag EasyGrepTest GrepAdd -E [A-C]
GrepAdd -E [A-C]

ResultListTag EasyGrepTest GrepAdd -F [a-c]
GrepAdd -F [a-c]

ResultListTag EasyGrepTest GrepAdd -F [A-C]
GrepAdd -F [A-C]

ResultListTag EasyGrepTest GrepAdd -F !
GrepAdd -F !

"ResultListTag EasyGrepTest GrepAdd -F "
"GrepAdd -F "

ResultListTag EasyGrepTest GrepAdd -F #
GrepAdd -F #

ResultListTag EasyGrepTest GrepAdd -F $
GrepAdd -F $

"ResultListTag EasyGrepTest GrepAdd -F %
"GrepAdd -F %

"ResultListTag EasyGrepTest GrepAdd -F &
"GrepAdd -F &

"ResultListTag EasyGrepTest GrepAdd -F '
"GrepAdd -F '

ResultListTag EasyGrepTest GrepAdd -F (
GrepAdd -F (

"ResultListTag EasyGrepTest GrepAdd -F )
"GrepAdd -F )

ResultListTag EasyGrepTest GrepAdd -F *
GrepAdd -F *

ResultListTag EasyGrepTest GrepAdd -F +
GrepAdd -F +

ResultListTag EasyGrepTest GrepAdd -F ,
GrepAdd -F ,

ResultListTag EasyGrepTest GrepAdd -F -
GrepAdd -F -

ResultListTag EasyGrepTest GrepAdd -F .
GrepAdd -F .

ResultListTag EasyGrepTest GrepAdd -F /
GrepAdd -F /

ResultListTag EasyGrepTest GrepAdd -F :
GrepAdd -F :

ResultListTag EasyGrepTest GrepAdd -F ;
GrepAdd -F ;

"ResultListTag EasyGrepTest GrepAdd -F <
"GrepAdd -F <

ResultListTag EasyGrepTest GrepAdd -F =
GrepAdd -F =

"ResultListTag EasyGrepTest GrepAdd -F >
"GrepAdd -F >

ResultListTag EasyGrepTest GrepAdd -F ?
GrepAdd -F ?

ResultListTag EasyGrepTest GrepAdd -F @
GrepAdd -F @

ResultListTag EasyGrepTest GrepAdd -F [
GrepAdd -F [

"ResultListTag EasyGrepTest GrepAdd -F \
"GrepAdd -F \

ResultListTag EasyGrepTest GrepAdd -F ]
GrepAdd -F ]

ResultListTag EasyGrepTest GrepAdd -F ^
GrepAdd -F ^

ResultListTag EasyGrepTest GrepAdd -F _
GrepAdd -F _

"ResultListTag EasyGrepTest GrepAdd -F `
"GrepAdd -F `

ResultListTag EasyGrepTest GrepAdd -F {
GrepAdd -F {

"ResultListTag EasyGrepTest GrepAdd -F |
"GrepAdd -F |

ResultListTag EasyGrepTest GrepAdd -F }
GrepAdd -F }

ResultListTag EasyGrepTest GrepAdd -F ~
GrepAdd -F ~

cclose
exe "ResultListSave ".testname.".out"
quit!


