" ================================
" Core editor settings
" ================================

" Enable modern Vim defaults
syntax on
filetype plugin indent on

set ttimeout
set ttimeoutlen=1
set ttyfast

" Set cursor shapes for different modes
" 1 or 2 = block, 3 or 4 = underline, 5 or 6 = bar
" (Odd numbers blink, even numbers are steady)
let &t_EI = "\<Esc>[1 q"   " Normal mode: Blinking block
let &t_SI = "\<Esc>[5 q"   " Insert mode: Blinking bar
let &t_SR = "\<Esc>[3 q"   " Replace mode: Blinking underline

" FIX: Force terminal to show block cursor immediately on startup
augroup force_startup_cursor
  autocmd!
  autocmd VimEnter * silent !echo -ne "\<Esc>[1 q"
augroup END

" Hide ~ at end of buffer
set fillchars=eob:\ 

" Set SPACE as leader key
let mapleader=" "

" Use system clipboard
set clipboard=unnamedplus

" Recommended basic settings for completion menu
set completeopt=menuone,noinsert,noselect

" Line numbers (hybrid: absolute + relative)
set number
set relativenumber

" Smart line numbers: disable relative numbers in Insert mode
augroup numbertoggle
  autocmd!
  autocmd InsertEnter * set norelativenumber
  autocmd InsertLeave * set relativenumber
augroup END


" ================================
" Plugin management (vim-plug)
" ================================

call plug#begin('~/.vim/plugged')

" Language / syntax
Plug 'rust-lang/rust.vim'
Plug 'mracos/mermaid.vim'

" File tree
Plug 'preservim/nerdtree'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" Git
Plug 'tpope/vim-fugitive'
Plug 'mhinz/vim-signify', { 'tag': 'legacy' }

" Completion / LSP
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Auto close brackets
Plug 'jiangmiao/auto-pairs'

" UI / theme
Plug 'arcticicestudio/nord-vim'
Plug 'ryanoasis/vim-devicons'

call plug#end()


" ================================
" Appearance
" ================================

colorscheme nord
" Fix invisible text in Visual mode
set termguicolors
highlight Visual guibg=#4c566a guifg=NONE ctermbg=8 ctermfg=NONE


" ================================
" CoC.nvim completion mappings
" ================================

" Use <Tab>/<S-Tab> to navigate completion menu
inoremap <silent><expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Use <CR> (Enter) to confirm completion when menu is open, otherwise newline
inoremap <silent><expr> <CR> pumvisible() ? "\<C-y>" : "\<CR>"


" ================================
" Keybindings
" ================================

" Toggle NERDTree
nnoremap <leader>e :NERDTreeToggle<CR>

" Close only the file buffer, keep NERDTree open and focused
function! DeleteFileBuffer()
  " Save current window
  let l:cur_win = winnr()

  " Find a non-NERDTree window and close its buffer
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

" Remove the ugly default header (filename, page number)
set printoptions=header:0

" Set margins (left:right:top:bottom)
set printoptions+=left:10pc,right:5pc,top:5pc,bottom:5pc

" Optional: Set a specific font (syntax varies by system, but 'Courier' is standard)
set printfont=Courier:h11
