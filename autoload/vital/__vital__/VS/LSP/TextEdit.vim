"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Text = a:V.import('VS.LSP.Text')
  let s:Position = a:V.import('VS.LSP.Position')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['VS.LSP.Text']
endfunction

"
" apply
"
function! s:apply(path, text_edits) abort
  let l:current_bufname = bufname('%')
  let l:target_bufname = a:path
  let l:cursor_position = s:Position.cursor()

  call s:_switch(l:target_bufname)
  for l:text_edit in s:_normalize(a:text_edits)
    call s:_apply(bufnr(l:target_bufname), l:text_edit, l:cursor_position)
  endfor
  call s:_switch(l:current_bufname)

  if bufnr(l:current_bufname) == bufnr(l:target_bufname)
    try
      call cursor(s:Position.lsp_to_vim('%', l:cursor_position))
    catch /.*/
      echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    endtry
  endif
endfunction

"
" _apply
"
function! s:_apply(bufnr, text_edit, cursor_position) abort
  " create before/after line.
  let l:start_line = getline(a:text_edit.range.start.line + 1)
  let l:end_line = getline(a:text_edit.range.end.line + 1)
  let l:before_line = strcharpart(l:start_line, 0, a:text_edit.range.start.character)
  let l:after_line = strcharpart(l:end_line, a:text_edit.range.end.character, strchars(l:end_line) - a:text_edit.range.end.character)

  " create new lines.
  let l:new_lines = s:Text.split_by_eol(a:text_edit.newText)
  let l:new_lines[0] = l:before_line . l:new_lines[0]
  let l:new_lines[-1] = l:new_lines[-1] . l:after_line
  let l:new_lines_len = len(l:new_lines)

  let l:range_len = (a:text_edit.range.end.line - a:text_edit.range.start.line) + 1

  " fix cursor
  if a:text_edit.range.end.line <= a:cursor_position.line && a:text_edit.range.end.character <= a:cursor_position.character
    " fix cursor col
    if a:text_edit.range.end.line == a:cursor_position.line
      let l:end_character = strchars(l:new_lines[-1]) - strchars(l:after_line)
      let l:end_offset = a:cursor_position.character - a:text_edit.range.end.character
      let a:cursor_position.character = l:end_character + l:end_offset
    endif

    " fix cursor line
    let a:cursor_position.line += l:new_lines_len - l:range_len
  endif

  " append or delete lines.
  if l:new_lines_len > l:range_len
    call append(a:text_edit.range.start.line, repeat([''], l:new_lines_len - l:range_len))
  elseif l:new_lines_len < l:range_len
    let l:offset = l:range_len - l:new_lines_len
    execute printf('%s,%sdelete _', a:text_edit.range.start.line + 1, a:text_edit.range.start.line + l:offset)
  endif

  " set lines.
  call setline(a:text_edit.range.start.line + 1, l:new_lines)
endfunction

"
" _normalize
"
function! s:_normalize(text_edits) abort
  let l:text_edits = type(a:text_edits) == type([]) ? a:text_edits : [a:text_edits]
  let l:text_edits = s:_range(l:text_edits)
  let l:text_edits = sort(copy(l:text_edits), function('s:_compare', [], {}))
  let l:text_edits = s:_check(l:text_edits)
  return reverse(l:text_edits)
endfunction

"
" _range
"
function! s:_range(text_edits) abort
  for l:text_edit in a:text_edits
    if l:text_edit.range.start.line > l:text_edit.range.end.line || (
          \   l:text_edit.range.start.line == l:text_edit.range.end.line &&
          \   l:text_edit.range.start.character > l:text_edit.range.end.character
          \ )
      let l:text_edit.range = { 'start': l:text_edit.range.end, 'end': l:text_edit.range.start }
    endif
  endfor
  return a:text_edits
endfunction

"
" _check
"
function! s:_check(text_edits) abort
  if len(a:text_edits) > 1
    let l:range = a:text_edits[0].range
    for l:text_edit in a:text_edits[1 : -1]
      if l:range.end.line > l:text_edit.range.start.line || (
      \   l:range.end.line == l:text_edit.range.start.line &&
      \   l:range.end.character > l:text_edit.range.start.character
      \ )
        throw 'VS.LSP.TextEdit: range overlapped.'
      endif
      let l:range = l:text_edit.range
    endfor
  endif
  return a:text_edits
endfunction

"
" _compare
"
function! s:_compare(text_edit1, text_edit2) abort
  let l:diff = a:text_edit1.range.start.line - a:text_edit2.range.start.line
  if l:diff == 0
    return a:text_edit1.range.start.character - a:text_edit2.range.start.character
  endif
  return l:diff
endfunction

"
" _switch
"
function! s:_switch(path) abort
  if bufnr(a:path) >= 0
    execute printf('keepalt keepjumps %sbuffer!', bufnr(a:path))
  else
    execute printf('keepalt keepjumps edit! %s', fnameescape(a:path))
  endif
endfunction

