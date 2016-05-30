# This suite requires https://github.com/inkarkat/runVimTests to run
if [[ $(uname -s) == "Linux" ]]; then
    sed -i ':a; s,^\([^|]*\)\\,\1/,g; ta' *.ok
fi
TEST_SOURCES="--pure --runtime bundle/vim-easygrep/autoload/EasyGrep.vim --runtime bundle/vim-easygrep/plugin/EasyGrep.vim"
bash ../../runVimTests/bin/runVimTests.sh $TEST_SOURCES vimgrep.suite
if [[ $(uname -s) == "Linux" ]]; then
    sed -i ':a; s,^\([^|]*\)/,\1\\,g; ta' *.ok
fi
