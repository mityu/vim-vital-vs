let s:Do = { -> {} }

"
" do
"
function! s:do(winid, func) abort
  let l:curr_winid = win_getid()
  if l:curr_winid == a:winid
    call a:func()
    return
  endif

  if exists('*win_execute')
    let s:Do = a:func
    try
      noautocmd keepalt keepjumps call win_execute(a:winid, 'call s:Do()')
    catch /.*/
      echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    endtry
    unlet s:Do
    return
  endif

  noautocmd keepalt keepjumps call win_gotoid(a:winid)
  try
    call a:func()
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
  noautocmd keepalt keepjumps call win_gotoid(l:curr_winid)
endfunction

"
" info
"
if has('nvim')
  function! s:info(winid) abort
    let l:info = getwininfo(a:winid)[0]
    return {
    \   'width': l:info.width,
    \   'height': l:info.height,
    \   'topline': l:info.topline,
    \ }
  endfunction
else
  function! s:info(winid) abort
    if s:is_floating(a:winid)
      let l:info = popup_getpos(a:winid)
      return {
      \   'width': l:info.width,
      \   'height': l:info.height,
      \   'topline': l:info.firstline
      \ }
    endif

    let l:ctx = {}
    let l:ctx.info = {}
    function! l:ctx.callback() abort
      let self.info.width = winwidth(0)
      let self.info.height = winheight(0)
      let self.info.topline = line('w0')
    endfunction
    call s:do(a:winid, { -> l:ctx.callback() })
    return l:ctx.info
  endfunction
endif

"
" find
"
function! s:find(callback) abort
  let l:winids = []
  let l:winids += map(range(1, tabpagewinnr(tabpagenr(), '$')), 'win_getid(v:val)')
  let l:winids += s:_get_visible_popup_winids()
  return filter(l:winids, 'a:callback(v:val)')
endfunction

"
" is_floating
"
if has('nvim')
  function! s:is_floating(winid) abort
    let l:config = nvim_win_get_config(a:winid)
    return empty(l:config) || !empty(get(l:config, 'relative', ''))
  endfunction
else
  function! s:is_floating(winid) abort
    return winheight(a:winid) != -1 && win_id2win(a:winid) == 0
  endfunction
endif

"
" scroll
"
function! s:scroll(winid, topline) abort
  let l:ctx = {}
  function! l:ctx.callback(winid, topline) abort
    let l:wininfo = s:info(a:winid)
    let l:topline = a:topline
    let l:topline = min([l:topline, line('$') - l:wininfo.height + 1])
    let l:topline = max([l:topline, 1])

    if l:topline == l:wininfo.topline
      return
    endif

    if !has('nvim') && s:is_floating(a:winid)
      call popup_setoptions(a:winid, {
      \   'firstline': l:topline,
      \ })
    else
      let l:delta = l:topline - l:wininfo.topline
      let l:key = l:delta > 0 ? "\<C-e>" : "\<C-y>"
      execute printf('noautocmd silent normal! %s', repeat(l:key, abs(l:delta)))
    endif
  endfunction
  call s:do(a:winid, { -> l:ctx.callback(a:winid, a:topline) })
endfunction

"
" screenpos
"
" @param {[number, number]} pos - position on the current buffer.
"
function! s:screenpos(pos) abort
  let l:y = a:pos[0]
  let l:x = a:pos[1] + get(a:pos, 2, 0)

  let l:view = winsaveview()
  let l:scroll_x = l:view.leftcol
  let l:scroll_y = l:view.topline

  let l:winpos = win_screenpos(win_getid())
  let l:y = l:winpos[0] + l:y - l:scroll_y
  let l:x = l:winpos[1] + l:x - l:scroll_x
  return [l:y, l:x + (wincol() - virtcol('.')) - 1]
endfunction

"
" _get_visible_popup_winids
"
function! s:_get_visible_popup_winids() abort
  if !exists('*popup_list')
    return []
  endif
  return filter(popup_list(), 'popup_getpos(v:val).visible')
endfunction

