# This suite requires https://github.com/inkarkat/runVimTests to run
TEST_SOURCES="--pure --runtime bundle/vim-easygrep/autoload/EasyGrep.vim --runtime bundle/vim-easygrep/plugin/EasyGrep.vim"
bash ../../runVimTests/bin/runVimTests.sh $TEST_SOURCES vimgrep.suite
