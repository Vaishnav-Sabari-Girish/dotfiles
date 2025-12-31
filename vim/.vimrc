" Enable modern Vim defaults
syntax on
filetype plugin indent on

" Hide ~ at end of buffer
set fillchars=eob:\ 

" Set SPACE as leader key
let mapleader=" "

" Use system clipboard
set clipboard=unnamedplus

" Recommended basic settings for completion menu
set completeopt=menuone,noinsert,noselect

" ---- vim-plug ----
call plug#begin('~/.vim/plugged')

Plug 'rust-lang/rust.vim'
Plug 'preservim/nerdtree'
Plug 'tpope/vim-fugitive'
Plug 'mhinz/vim-signify', { 'tag': 'legacy' }
Plug 'arcticicestudio/nord-vim'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" Completion
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" To be loaded last
Plug 'ryanoasis/vim-devicons'

call plug#end()

" Colorscheme
colorscheme nord

" CoC.nvim completion mappings
" Use <Tab>/<S-Tab> to navigate completion menu
inoremap <silent><expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Use <CR> (Enter) to confirm completion when menu is open, otherwise newline
if exists('*complete_info')
  inoremap <silent><expr> <CR> complete_info()['selected'] !=# -1
        \ ? "\<C-y>"
        \ : "\<C-g>u\<CR>"
else
  inoremap <silent><expr> <CR> pumvisible()
        \ ? "\<C-y>"
        \ : "\<C-g>u\<CR>"
endif

" Keybinds
"" Open Tree
nnoremap <leader>e :NERDTreeToggle<CR>

"" Close only the open file buffer and not NERDTree and also keep the focus on
"" NERDTree
function! DeleteFileBuffer()
  " Save current window
  let l:cur_win = winnr()

  " Find a non-NERDTree window
  for w in range(1, winnr('$'))
    if getbufvar(winbufnr(w), '&filetype') !=# 'nerdtree'
      execute w . 'wincmd w'
      bd
      break
    endif
  endfor

  " Restore focus
  if winnr('$') >= l:cur_win
    execute l:cur_win . 'wincmd w'
  endif
endfunction

nnoremap <leader>bd :call DeleteFileBuffer()<CR>
