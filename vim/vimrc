" Don't try to be vi compatible
set nocompatible

" Helps force plugins to load correctly when it is turned back on
filetype on

" turn off auto comment insertion
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

" Statusbar customization
set statusline=%f%=%{&filetype}

" Turn on syntax highlighting
syntax on

" Fold Method
set foldmethod=marker

" Security
set modelines=0

" Show line numbers
set number

" Show file stats
set ruler

" Encoding
set encoding=utf-8

" Whitespace
"set wrap
"set textwidth=80
set formatoptions=tcqrn1
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set noshiftround

" Cursor motion
set scrolloff=3
set backspace=indent,eol,start
set matchpairs+=<:> " use % to jump between pairs
runtime! macros/matchit.vim

" Move up/down editor lines
nnoremap j gj
nnoremap k gk

" Allow hidden buffers
set hidden

" Rendering
set ttyfast

" Status bar
set laststatus=2

" Last line
set showmode
set showcmd

" Searching
nnoremap / /\v
vnoremap / /\v
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
map <leader><space> :let @/=''<cr> " clear search

" Remap help key.
inoremap <F1> <ESC>:set invfullscreen<CR>a
nnoremap <F1> :set invfullscreen<CR>
vnoremap <F1> :set invfullscreen<CR>

" Textmate holdouts

" Formatting
map <leader>q gqip

" Visualize tabs and newlines
set listchars=tab:▸\ ,eol:¬
" Uncomment this to enable by default:
" set list " To enable by default
" Or use your leader key + l to toggle on/off
map <leader>l :set list!<CR> " Toggle tabs and EOL

" Color scheme (terminal)
set t_Co=256
set background=dark
let g:solarized_termcolors=256
let g:solarized_termtrans=1
" put https://raw.github.com/altercation/vim-colors-solarized/master/colors/solarized.vim
" in ~/.vim/colors/ and uncomment:
" colorscheme solarized

" Custom File Types
" autocmd BufNewFile,BufRead *.EXTENSION set filetype=FT
autocmd BufRead,BufNewFile *.vimrc.bak set ft vim

" {{{ VISUAL MODE MAPPINGS
" Search and replace
vmap \sr :s/\%V{s}/{r}/g <bar> :noh

" ! True/False switch
vmap \tf :s/\%Vtrue/false/g <bar> :noh
vmap \ft :s/\%Vfalse/true/g <bar> :noh

" Auto indent
vmap \i :ggVG= <bar> :noh

" default commenting is #
vmap \c :s/^/# / <bar> :noh
vmap \u :s/# \?// <bar> :noh

" Line Commenting
au FileType sh vmap \c :s/^/# / <bar> :noh
au FileType sh vmap \u :s/# \?// <bar> :noh

au FileType perl vmap \c :s/^/# / <bar> :noh
au FileType perl vmap \u :s/# \?// <bar> :noh

au FileType vim vmap \c :s/^/" / <bar> :noh
au FileType vim vmap \u :s/" \?// <bar> :noh

au FileType go vmap \c :s/^/\/\/ / <bar> :noh
au FileType go vmap \u :s/\/\/ \?// <bar> :noh

au FileType tmux vmap \c :s/^/# / <bar> :noh
au FileType tmux vmap \u :s/# \?// <bar> :noh

au FileType conf vmap \c :s/^/# / <bar> :noh
au FileType conf vmap \u :s/# \?// <bar> :noh

au FileType scss vmap \c :s/^/\/\/ / <bar> :noh
au FileType scss vmap \u :s/\/\/ \?// <bar> :noh

au FileType json vmap \c :s/^/\/\/ / <bar> :noh
au FileType json vmap \u :s/\/\/ \?// <bar> :noh

" }}}

" Templates
autocmd BufNewFile  *_test.go 0r ~/.vim/templates/skel.test.go
autocmd BufNewFile *\(test\)\@<!.go 0r ~/.vim/templates/skel.go
autocmd BufNewFile  *.sh 0r ~/.vim/templates/skel.sh
autocmd BufNewFile  *.pl 0r ~/.vim/templates/skel.pl

" Turn off annoyances
map Q <Nop>
set visualbell
set t_vb=

" Disable Arrow keys in normal mode
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>

" Disable Arrow keys in insert mode
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

" Disable Arrow keys in visual mode
vmap <up> <nop>
vmap <down> <nop>
vmap <left> <nop>
vmap <right> <nop>
