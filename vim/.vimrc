" Enable modern Vim defaults
syntax on
filetype plugin indent on

" Set SPACE as leader key
let mapleader=" "

" Use system clipboard
set clipboard=unnamedplus

" ---- vim-plug ----
call plug#begin('~/.vim/plugged')

Plug 'preservim/nerdtree'
Plug 'tpope/vim-fugitive'
Plug 'mhinz/vim-signify', { 'tag': 'legacy' }
Plug 'arcticicestudio/nord-vim'

" To be loaded last
Plug 'ryanoasis/vim-devicons'

call plug#end()

" Colorscheme
colorscheme nord

" Keybinds
"" Open Tree
nnoremap <leader>e :NERDTreeToggle<CR>:wincmd p<CR>

"" Close current buffer
nnoremap <leader>bd :bd<CR>
