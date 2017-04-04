let s:keepcpo = &cpo
set cpo&vim

if !exists('g:istanbul#quickfix#prefix')
  let g:istanbul#quickfix#prefix = 'ISTANBUL:'
endif

function! istanbul#quickfix#getlist()
  if g:istanbul#store =~ '^l'
    return getloclist(0)
  else
    return getqflist()
  endif
endfunction

function! istanbul#quickfix#setlist(entries)
  if g:istanbul#store =~ '^l'
    call setloclist(0, a:entries)
  else
    call setqflist(a:entries)
  endif
endfunction

let g:istanbul#quickfix#errjumpdesc = -1
let g:istanbul#quickfix#errjumpasc = -2
let g:istanbul#quickfix#errjumpempty = -3

function! istanbul#quickfix#format(range, modestr)
  if a:range[0] == a:range[1]
    return printf('%s Uncovered %s #%d',
      \ g:istanbul#quickfix#prefix,
      \ a:modestr[0],
      \ a:range[0])
  else
    return printf('%s Uncovered %s #%d-%d',
      \ g:istanbul#quickfix#prefix,
      \ a:modestr[1],
      \ a:range[0], a:range[1])
  endif
endfunction
function! istanbul#quickfix#update(bufnr, ranges, modestr)
  if g:istanbul#quickfix#prefix !~ '\v^[-a-zA-Z0-9:_]+$'
    throw g:istanbul#error#format("InvalidPrefix", g:istanbul#quickfix#prefix)
  endif
  let entries = filter(istanbul#quickfix#getlist(),
    \ printf('v:val.text !~ "^%s" || v:val.bufnr != %d', g:istanbul#quickfix#prefix, a:bufnr))
  for r in a:ranges
    call add(entries, {
      \ 'bufnr': a:bufnr,
      \ 'lnum': r[0],
      \ 'text': istanbul#quickfix#format(r, a:modestr),
      \ })
  endfor
  call istanbul#quickfix#setlist(entries)
endfunction
function! istanbul#quickfix#jumpnr(cyclic, switchbuf, curbufnr, curline, pattern, offset)
  let reverse = a:offset < 0
  let filtered = []
  let nr = 0
  for entry in istanbul#quickfix#getlist()
    let nr += 1
    let bufnr = get(entry, 'bufnr', -1)
    if !a:switchbuf && bufnr != a:curbufnr
      continue
    endif
    let line = get(entry, 'lnum', 0)
    if line == 0
      continue
    endif
    if get(entry, 'text', '') !~ a:pattern
      continue
    endif
    call add(filtered, { 'nr': nr, 'line': line, 'bufnr': bufnr })
  endfor
  let len = len(filtered)
  if len == 0
    return g:istanbul#quickfix#errjumpempty
  endif
  let buffound = 0
  let curindex = reverse ? len : -1
  for item in reverse ? reverse(copy(filtered)) : filtered
    if item.bufnr == a:curbufnr
      let buffound += 1
      if reverse ? item.line < a:curline : item.line > a:curline
        break
      endif
    elseif buffound > 0
      break
    endif
    let curindex += reverse ? -1 : 1
  endfor
  let curindex += a:offset
  if a:cyclic
    let curindex = curindex % len
    if curindex < 0
      let curindex += len
    endif
    return filtered[curindex].nr
  else
    if curindex < 0
      return g:istanbul#quickfix#errjumpdesc
    elseif curindex > len - 1
      return g:istanbul#quickfix#errjumpasc
    else
      return filtered[curindex].nr
    endif
  endif
endfunction
function! istanbul#quickfix#clear(bufnr)
  let filtered = []
  for q in istanbul#quickfix#getlist()
    let bufnr = get(q, 'bufnr', 0)
    let text = get(q, 'text', '')
    if bufnr != a:bufnr || text !~ '^'.g:istanbul#quickfix#prefix
      call add(filtered, q)
    endif
  endfor
  call istanbul#quickfix#setlist(filtered)
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo
