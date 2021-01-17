let s:Do = { -> {} }

let g:___VS_Vim_Buffer_id = get(g:, '___VS_Vim_Buffer_id', 0)

"
" get_line_count
"
if exists('*nvim_buf_line_count')
  function! s:get_line_count(bufnr) abort
    return nvim_buf_line_count(a:bufnr)
  endfunction
elseif has('patch-8.2.0019')
  function! s:get_line_count(bufnr) abort
    return getbufinfo(a:bufnr)[0].linecount
  endfunction
else
  function! s:get_line_count(bufnr) abort
    if bufnr('%') == bufnr(a:bufnr)
      return line('$')
    endif
    return len(getbufline(a:bufnr, '^', '$'))
  endfunction
endif

"
" create
"
function! s:create(...) abort
  let g:___VS_Vim_Buffer_id += 1
  let l:bufnr = bufnr(printf('VS.Vim.Buffer: %s: %s',
  \   g:___VS_Vim_Buffer_id,
  \   get(a:000, 0, 'VS.Vim.Buffer.Default')
  \ ), v:true)
  call s:load(l:bufnr)
  return l:bufnr
endfunction

"
" load
"
if exists('*bufload')
  function! s:load(bufnr_or_path) abort
    call bufload(bufnr(a:bufnr_or_path, v:true))
  endfunction
else
  function! s:load(bufnr_or_path) abort
    call s:do(bufnr(a:bufnr_or_path, v:true), { -> {} })
  endfunction
endif

"
" do
"
function! s:do(bufnr, func) abort
  let l:curr_bufnr = bufnr('%')
  if l:curr_bufnr == a:bufnr
    call a:func()
    return
  endif

  try
    execute printf('noautocmd keepalt keepjumps %sbuffer', a:bufnr)
    call a:func()
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  finally
    execute printf('noautocmd keepalt keepjumps %sbuffer', l:curr_bufnr)
  endtry
endfunction

