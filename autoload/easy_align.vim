" Copyright (c) 2014 Junegunn Choi
"
" MIT License
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software"), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
"
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

if exists("g:loaded_easy_align")
  finish
endif
let g:loaded_easy_align = 1

let s:cpo_save = &cpo
set cpo&vim

let s:easy_align_delimiters_default = {
\  ' ': { 'pattern': ' ',  'left_margin': 0, 'right_margin': 0, 'stick_to_left': 0 },
\  '=': { 'pattern': '===\|<=>\|\(&&\|||\|<<\|>>\)=\|=\~[#?]\?\|=>\|[:+/*!%^=><&|.?-]\?=[#?]\?',
\                          'left_margin': 1, 'right_margin': 1, 'stick_to_left': 0 },
\  ':': { 'pattern': ':',  'left_margin': 0, 'right_margin': 1, 'stick_to_left': 1 },
\  ',': { 'pattern': ',',  'left_margin': 0, 'right_margin': 1, 'stick_to_left': 1 },
\  '|': { 'pattern': '|',  'left_margin': 1, 'right_margin': 1, 'stick_to_left': 0 },
\  '.': { 'pattern': '\.', 'left_margin': 0, 'right_margin': 0, 'stick_to_left': 0 },
\  '#': { 'pattern': '#\+', 'delimiter_align': 'l', 'ignore_groups': ['!Comment']  },
\  '"': { 'pattern': '"\+', 'delimiter_align': 'l', 'ignore_groups': ['!Comment']  },
\  '&': { 'pattern': '\\\@<!&\|\\\\',
\                          'left_margin': 1, 'right_margin': 1, 'stick_to_left': 0 },
\  '{': { 'pattern': '(\@<!{',
\                          'left_margin': 1, 'right_margin': 1, 'stick_to_left': 0 },
\  '}': { 'pattern': '}',  'left_margin': 1, 'right_margin': 0, 'stick_to_left': 0 }
\ }

let s:mode_labels = { 'l': '', 'r': '[R]', 'c': '[C]' }

let s:help_split_option = 'easy_align_auto_open_help_in_unfocused_split'
let s:help_buffer_name = '[EasyAlign Help] - Interactive Mode'

let s:known_options = {
\ 'margin_left':   [0, 1], 'margin_right':     [0, 1], 'stick_to_left':   [0],
\ 'left_margin':   [0, 1], 'right_margin':     [0, 1], 'indentation':     [1],
\ 'ignore_groups': [3   ], 'ignore_unmatched': [0   ], 'delimiter_align': [1],
\ 'mode_sequence': [1   ], 'ignores':          [3],    'filter':          [1],
\ 'align':         [1   ], 'justify':           [1]
\ }

let s:option_values = {
\ 'indentation':      ['shallow', 'deep', 'none', 'keep', -1],
\ 'delimiter_align':  ['left', 'center', 'right', -1],
\ 'ignore_unmatched': [0, 1, -1],
\ 'ignore_groups':    [[], ['String'], ['Comment'], ['String', 'Comment'], -1],
\ 'justify':          ['between', 'cells', -1]
\ }

let s:shorthand = {
\ 'margin_left':   'lm', 'margin_right':     'rm', 'stick_to_left':   'stl',
\ 'left_margin':   'lm', 'right_margin':     'rm', 'indentation':     'idt',
\ 'ignore_groups': 'ig', 'ignore_unmatched': 'iu', 'delimiter_align': 'da',
\ 'mode_sequence': 'a',  'ignores':          'ig', 'filter':          'f',
\ 'align':         'a',  'justify':           'j'
\ }

if exists("*strdisplaywidth")
  function! s:strwidth(str)
    return strdisplaywidth(a:str)
  endfunction
else
  function! s:strwidth(str)
    return len(split(a:str, '\zs')) + len(matchstr(a:str, '^\t*')) * (&tabstop - 1)
  endfunction
endif

function! s:ceil2(v)
  return a:v % 2 == 0 ? a:v : a:v + 1
endfunction

function! s:floor2(v)
  return a:v % 2 == 0 ? a:v : a:v - 1
endfunction

function! s:get_highlight_group_name(line, col)
  let hl = synIDattr(synID(a:line, a:col, 0), 'name')

  if hl == '' && has('nvim-0.9.0')
    let insp = luaeval('vim.inspect_pos and vim.inspect_pos( nil, ' .. (a:line-1) .. ', ' .. (a:col-1) .. ' ) or { treesitter = {} }')
    if !empty(insp.treesitter)
      let hl = insp.treesitter[0].hl_group_link
    endif
  endif

  " and, finally
  return hl
endfunction

function! easy_align#get_highlight_group_name(...)
  let l  = get(a:, 1, line('.'))
  let c  = get(a:, 2, col('.'))
  let hl = s:get_highlight_group_name(l, c)
  return { 'line': l, 'column': c, 'group': hl }
endfunction

function! s:highlighted_as(line, col, groups)
  if empty(a:groups) | return 0 | endif
  let hl = s:get_highlight_group_name(a:line, a:col)
  for grp in a:groups
    if grp[0] == '!'
      if hl !~# grp[1:-1]
        return 1
      endif
    elseif hl =~# grp
      return 1
    endif
  endfor
  return 0
endfunction

function! s:ignored_syntax()
  if has('syntax') && exists('g:syntax_on')
    " Backward-compatibility
    return get(g:, 'easy_align_ignore_groups',
          \ get(g:, 'easy_align_ignores',
            \ (get(g:, 'easy_align_ignore_comment', 1) == 0) ?
              \ ['String'] : ['String', 'Comment']))
  else
    return []
  endif
endfunction

function! s:echon_(tokens)
  " http://vim.wikia.com/wiki/How_to_print_full_screen_width_messages
  let xy = [&ruler, &showcmd]
  try
    set noruler noshowcmd

    let winlen = winwidth(winnr()) - 2
    let len = len(join(map(copy(a:tokens), 'v:val[1]'), ''))
    let ellipsis = len > winlen ? '..' : ''

    echon "\r"
    let yet = 0
    for [hl, msg] in a:tokens
      if empty(msg) | continue | endif
      execute "echohl ". hl
      let yet += len(msg)
      if yet > winlen - len(ellipsis)
        echon msg[ 0 : (winlen - len(ellipsis) - yet - 1) ] . ellipsis
        break
      else
        echon msg
      endif
    endfor
  finally
    echohl None
    let [&ruler, &showcmd] = xy
  endtry
endfunction

function! s:echon(l, n, r, d, o, warn)
  let tokens = [
  \ ['Function', s:live ? ':LiveEasyAlign' : ':EasyAlign'],
  \ ['ModeMsg', get(s:mode_labels, a:l, a:l)],
  \ ['None', ' ']]

  if a:r == -1 | call add(tokens, ['Comment', '(']) | endif
  call add(tokens, [a:n =~ '*' ? 'Repeat' : 'Number', a:n])
  call extend(tokens, a:r == 1 ?
  \ [['Delimiter', '/'], ['String', a:d], ['Delimiter', '/']] :
  \ [['Identifier', a:d == ' ' ? '\ ' : (a:d == '\' ? '\\' : a:d)]])
  if a:r == -1 | call extend(tokens, [['Normal', '_'], ['Comment', ')']]) | endif
  call add(tokens, ['Statement', empty(a:o) ? '' : ' '.string(a:o)])
  if !empty(a:warn)
    call add(tokens, ['WarningMsg', ' ('.a:warn.')'])
  endif

  call s:echon_(tokens)
  return join(map(tokens, 'v:val[1]'), '')
endfunction

function! s:exit(msg)
  call s:echon_([['ErrorMsg', a:msg]])
  throw 'exit'
endfunction

function! s:ltrim(str)
  return substitute(a:str, '^\s\+', '', '')
endfunction

function! s:rtrim(str)
  return substitute(a:str, '\s\+$', '', '')
endfunction

function! s:trim(str)
  return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! s:sum(values)
  let total = 0
  for value in a:values
    let total += value
  endfor
  return total
endfunction

function! s:fuzzy_lu(key)
  if has_key(s:known_options, a:key)
    return a:key
  endif
  let key = tolower(a:key)

  " stl -> ^s.*_t.*_l.*
  let regexp1 = '^' .key[0]. '.*' .substitute(key[1 : -1], '\(.\)', '_\1.*', 'g')
  let matches = filter(keys(s:known_options), 'v:val =~ regexp1')
  if len(matches) == 1
    return matches[0]
  endif

  " stl -> ^s.*t.*l.*
  let regexp2 = '^' . substitute(substitute(key, '-', '_', 'g'), '\(.\)', '\1.*', 'g')
  let matches = filter(keys(s:known_options), 'v:val =~ regexp2')

  if empty(matches)
    call s:exit("Unknown option key: ". a:key)
  elseif len(matches) == 1
    return matches[0]
  else
    " Avoid ambiguity introduced by deprecated margin_left and margin_right
    if sort(matches) == ['margin_left', 'margin_right', 'mode_sequence']
      return 'mode_sequence'
    endif
    if sort(matches) == ['ignore_groups', 'ignores']
      return 'ignore_groups'
    endif
    call s:exit("Ambiguous option key: ". a:key ." (" .join(matches, ', '). ")")
  endif
endfunction

function! s:shift(modes, cycle)
  let item = remove(a:modes, 0)
  if a:cycle || empty(a:modes)
    call add(a:modes, item)
  endif
  return item
endfunction

function! s:normalize_options(opts)
  let ret = {}
  for k in keys(a:opts)
    let v = a:opts[k]
    let k = s:fuzzy_lu(k)
    " Backward-compatibility
    if k == 'margin_left'   | let k = 'left_margin'    | endif
    if k == 'margin_right'  | let k = 'right_margin'   | endif
    if k == 'mode_sequence' | let k = 'align'          | endif
    let ret[k] = v
    unlet v
  endfor
  return s:validate_options(ret)
endfunction

function! s:compact_options(opts)
  let ret = {}
  for k in keys(a:opts)
    let ret[s:shorthand[k]] = a:opts[k]
  endfor
  return ret
endfunction

function! s:validate_options(opts)
  for k in keys(a:opts)
    let v = a:opts[k]
    if index(s:known_options[k], type(v)) == -1
      call s:exit("Invalid type for option: ". k)
    endif
    unlet v
  endfor
  return a:opts
endfunction

function! s:split_line(line, nth, modes, cycle, fc, lc, pattern,
      \ stick_to_left, ignore_unmatched, ignore_groups, edge)
  let mode = ''

  let string = a:lc ?
    \ strpart(getline(a:line), a:fc - 1, a:lc - a:fc + 1) :
    \ strpart(getline(a:line), a:fc - 1)
  let idx     = 0
  let nomagic = match(a:pattern, '\\v') > match(a:pattern, '\C\\[mMV]')
  let pattern = '^.\{-}\s*\zs\('.a:pattern.(nomagic ? ')' : '\)')
  let tokens  = []
  let delims  = []

  " Phase 1: split
  let ignorable = 0
  let token = ''
  let phantom = 0
  let edge_col = 0
  while 1
    let matchidx = match(string, pattern, idx)
    " No match
    if matchidx < 0 | break | endif
    let matchend = matchend(string, pattern, idx)
    let spaces = matchstr(string, '\s'.(a:stick_to_left ? '*' : '\{-}'), matchend + (matchidx == matchend))

    " Match, but empty
    if len(spaces) + matchend - idx == 0
      let char = strpart(string, idx, 1)
      if empty(char) | break | endif
      let [match, part, delim] = [char, char, '']
    " Match
    else
      let match = strpart(string, idx, matchend - idx + len(spaces))
      let part  = strpart(string, idx, matchidx - idx)
      let delim = strpart(string, matchidx, matchend - matchidx)
    endif

    let at_edge = 1
    if a:edge
      let edge_start = matchidx
      let edge_end = matchend
      if delim =~# '^\s\+$'
        let edge_start -= len(matchstr(strpart(string, 0, matchidx), '\s*$'))
        let edge_end += len(matchstr(strpart(string, matchend), '^\s*'))
      endif
      let edge_start_vcol = s:strwidth(strpart(string, 0, edge_start)) + 1
      let edge_end_vcol = s:strwidth(strpart(string, 0, edge_end))
      let at_edge = edge_start_vcol <= a:edge && a:edge <= edge_end_vcol
    endif

    let ignorable = !at_edge ||
          \ s:highlighted_as(a:line, idx + len(part) + a:fc, a:ignore_groups)
    if ignorable
      let token .= match
    else
      let [pmode, mode] = [mode, s:shift(a:modes, a:cycle)]
      call add(tokens, token . match)
      call add(delims, delim)
      let token = ''
    endif

    let idx += len(match)

    if a:edge && at_edge && !ignorable
      let edge_col = s:strwidth(strpart(string, 0, idx)) + 1
      break
    endif

    " If the string is non-empty and ends with the delimiter,
    " append an empty token to the list
    if idx == len(string)
      let phantom = 1
      break
    endif
  endwhile

  let leftover = token . strpart(string, idx)
  if !empty(leftover)
    let ignorable = s:highlighted_as(a:line, len(string) + a:fc - 1, a:ignore_groups)
    call add(tokens, leftover)
    call add(delims, '')
  elseif phantom
    call add(tokens, '')
    call add(delims, '')
  endif
  let [pmode, mode] = [mode, s:shift(a:modes, a:cycle)]

  " Preserve indentation - merge first two tokens
  if len(tokens) > 1 && empty(s:rtrim(tokens[0]))
    let tokens[1] = tokens[0] . tokens[1]
    call remove(tokens, 0)
    call remove(delims, 0)
    let mode = pmode
  endif

  " Skip comment line
  if ignorable && len(tokens) == 1 && a:ignore_unmatched
    let tokens = []
    let delims = []
  " Append an empty item to enable right/center alignment of the last token
  " - if the last token is not ignorable or ignorable but not the only token
  elseif a:ignore_unmatched != 1          &&
        \ (mode ==? 'r' || mode ==? 'c')  &&
        \ (!ignorable || len(tokens) > 1) &&
        \ a:nth >= 0 " includes -0
    call add(tokens, '')
    call add(delims, '')
  endif

  return [tokens, delims, edge_col]
endfunction

function! s:do_align(todo, modes, all_tokens, all_delims, all_edge_cols,
      \ fl, ll, fc, lc, nth, recur, dict, edge)
  let mode       = a:modes[0]
  let lines      = {}
  let min_indent = -1
  let max = { 'pivot_len2': 0, 'token_len': 0, 'just_len': 0, 'delim_len': 0,
        \ 'edge_col': -1, 'indent': 0, 'tokens': 0, 'strip_len': 0 }
  let d = a:dict
  let [f, fx] = s:parse_filter(d.filter)

  " Phase 1
  for line in range(a:fl, a:ll)
    let snip = a:lc > 0 ? getline(line)[a:fc-1 : a:lc-1] : getline(line)
    if f == 1 && snip !~ fx
      continue
    elseif f == -1 && snip =~ fx
      continue
    endif

    if !has_key(a:all_tokens, line)
      " Split line into the tokens by the delimiters
      let [tokens, delims, edge_col] = s:split_line(
            \ line, a:nth, copy(a:modes), a:recur == 2,
            \ a:fc, a:lc, d.pattern,
            \ d.stick_to_left, d.ignore_unmatched, d.ignore_groups, a:edge)

      " Remember tokens for subsequent recursive calls
      let a:all_tokens[line] = tokens
      let a:all_delims[line] = delims
      let a:all_edge_cols[line] = edge_col
    else
      let tokens = a:all_tokens[line]
      let delims = a:all_delims[line]
      let edge_col = a:all_edge_cols[line]
    endif

    " Skip empty lines
    if empty(tokens) || (a:edge && edge_col <= 0)
      continue
    endif

    if a:edge && (max.edge_col < 0 || edge_col < max.edge_col)
      let max.edge_col = edge_col
    endif

    " Calculate the maximum number of tokens for a line within the range
    let max.tokens = max([max.tokens, len(tokens)])

    if a:nth > 0 " Positive N-th
      if len(tokens) < a:nth
        continue
      endif
      let nth = a:nth - 1 " make it 0-based
    else " -0 or Negative N-th
      if a:nth == 0 && mode !=? 'l'
        let nth = len(tokens) - 1
      else
        let nth = len(tokens) + a:nth
      endif
      if empty(delims[len(delims) - 1])
        let nth -= 1
      endif

      if nth < 0 || nth == len(tokens)
        continue
      endif
    endif

    let prefix = nth > 0 ? join(tokens[0 : nth - 1], '') : ''
    let delim  = delims[nth]
    let token  = s:rtrim( tokens[nth] )
    let token  = s:rtrim( strpart(token, 0, len(token) - len(s:rtrim(delim))) )
    if empty(delim) && !exists('tokens[nth + 1]') && d.ignore_unmatched
      continue
    endif

    let indent = s:strwidth(matchstr(tokens[0], '^\s*'))
    if min_indent < 0 || indent < min_indent
      let min_indent  = indent
    endif
    if mode ==? 'c'
      let token .= substitute(matchstr(token, '^\s*'), '\t', repeat(' ', &tabstop), 'g')
    endif
    let [pw, tw] = [s:strwidth(prefix), s:strwidth(token)]
    let max.indent    = max([max.indent,    indent])
    let max.token_len = max([max.token_len, tw])
    let max.just_len  = max([max.just_len,  pw + tw])
    let max.delim_len = max([max.delim_len, s:strwidth(delim)])

    if mode ==? 'c'
      let pivot_len2 = pw * 2 + tw
      if max.pivot_len2 < pivot_len2
        let max.pivot_len2 = pivot_len2
      endif
      let max.strip_len = max([max.strip_len, s:strwidth(s:trim(token))])
    endif
    let lines[line]   = [nth, prefix, token, delim]
  endfor

  " Phase 1-5: indentation handling (only on a:nth == 1)
  if a:nth == 1
    let idt = d.indentation
    if idt ==? 'd'
      let indent = max.indent
    elseif idt ==? 's'
      let indent = min_indent
    elseif idt ==? 'n'
      let indent = 0
    elseif idt !=? 'k'
      call s:exit('Invalid indentation: ' . idt)
    end

    if idt !=? 'k'
      let max.just_len   = 0
      let max.token_len  = 0
      let max.pivot_len2 = 0

      for [line, elems] in items(lines)
        let [nth, prefix, token, delim] = elems

        let tindent = matchstr(token, '^\s*')
        while 1
          let len = s:strwidth(tindent)
          if len < indent
            let tindent .= repeat(' ', indent - len)
            break
          elseif len > indent
            let tindent = tindent[0 : -2]
          else
            break
          endif
        endwhile

        let token = tindent . s:ltrim(token)
        if mode ==? 'c'
          let token = substitute(token, '\s*$', repeat(' ', indent), '')
        endif
        let [pw, tw] = [s:strwidth(prefix), s:strwidth(token)]
        let max.token_len = max([max.token_len, tw])
        let max.just_len  = max([max.just_len,  pw + tw])
        if mode ==? 'c'
          let pivot_len2 = pw * 2 + tw
          if max.pivot_len2 < pivot_len2
            let max.pivot_len2 = pivot_len2
          endif
        endif

        let lines[line][2] = token
      endfor
    endif
  endif

  let edge_pad = 0
  if a:edge && max.edge_col > 0
    let aligned_width = max.just_len + s:strwidth(d.ml) +
          \ max.delim_len + s:strwidth(d.mr)
    let edge_pad = max([0, max.edge_col - 1 - aligned_width])
  endif

  " Phase 2
  for [line, elems] in items(lines)
    let tokens = a:all_tokens[line]
    let delims = a:all_delims[line]
    let [nth, prefix, token, delim] = elems

    " Remove the leading whitespaces of the next token
    if len(tokens) > nth + 1
      let tokens[nth + 1] = s:ltrim(tokens[nth + 1])
    endif

    " Pad the token with spaces
    let [pw, tw] = [s:strwidth(prefix), s:strwidth(token)]
    let rpad = ''
    if mode ==? 'l'
      let pad = repeat(' ', max.just_len - pw - tw)
      if d.stick_to_left
        let rpad = pad
      else
        let token = token . pad
      endif
    elseif mode ==? 'r'
      let pad = repeat(' ', max.just_len - pw - tw)
      let indent = matchstr(token, '^\s*')
      let token = indent . pad . s:ltrim(token)
    elseif mode ==? 'c'
      let p1  = max.pivot_len2 - (pw * 2 + tw)
      let p2  = max.token_len - tw
      let pf1 = s:floor2(p1)
      if pf1 < p1 | let p2 = s:ceil2(p2)
      else        | let p2 = s:floor2(p2)
      endif
      let strip = s:ceil2(max.token_len - max.strip_len) / 2
      let indent = matchstr(token, '^\s*')
      let token = indent. repeat(' ', pf1 / 2) .s:ltrim(token). repeat(' ', p2 / 2)
      let token = substitute(token, repeat(' ', strip) . '$', '', '')

      if d.stick_to_left
        if empty(s:rtrim(token))
          let center = len(token) / 2
          let [token, rpad] = [strpart(token, 0, center), strpart(token, center)]
        else
          let [token, rpad] = [s:rtrim(token), matchstr(token, '\s*$')]
        endif
      endif
    endif
    let tokens[nth] = token

    " Pad the delimiter
    let dpadl = max.delim_len - s:strwidth(delim)
    let da = d.delimiter_align
    if da ==? 'l'
      let [dl, dr] = ['', repeat(' ', dpadl)]
    elseif da ==? 'c'
      let dl = repeat(' ', dpadl / 2)
      let dr = repeat(' ', dpadl - dpadl / 2)
    elseif da ==? 'r'
      let [dl, dr] = [repeat(' ', dpadl), '']
    else
      call s:exit('Invalid delimiter_align: ' . da)
    endif

    " Before and after the range (for blockwise visual mode)
    let cline  = getline(line)
    let before = strpart(cline, 0, a:fc - 1)
    let after  = a:lc ? strpart(cline, a:lc) : ''

    " Determine the left and right margin around the delimiter
    let rest   = join(tokens[nth + 1 : -1], '')
    let nomore = empty(rest.after)
    let ml     = (empty(prefix . token) || empty(delim) && nomore) ? '' : d.ml
    let mr     = nomore ? '' : d.mr . repeat(' ', edge_pad)

    " Adjust indentation of the lines starting with a delimiter
    let lpad = ''
    if nth == 0
      let ipad = repeat(' ', min_indent - s:strwidth(token.ml))
      if mode ==? 'l'
        let token = ipad . token
      else
        let lpad = ipad
      endif
    endif

    " Align the token
    let aligned = join([lpad, token, ml, dl, delim, dr, mr, rpad], '')
    let tokens[nth] = aligned

    " Update the line
    let a:todo[line] = before.join(tokens, '').after
  endfor

  if !a:edge && a:nth < max.tokens && (a:recur || len(a:modes) > 1)
    call s:shift(a:modes, a:recur == 2)
    return [a:todo, a:modes, a:all_tokens, a:all_delims, a:all_edge_cols,
          \ a:fl, a:ll, a:fc, a:lc, a:nth + 1, a:recur, a:dict, a:edge]
  endif
  return [a:todo]
endfunction

function! s:input(str, default, vis)
  if a:vis
    normal! gv
    redraw
    execute "normal! \<esc>"
  else
    " EasyAlign command can be called without visual selection
    redraw
  endif
  let got = input(a:str, a:default)
  return got
endfunction

function! s:atoi(str)
  return (a:str =~ '^[0-9]\+$') ? str2nr(a:str) : a:str
endfunction

function! s:shift_opts(opts, key, vals)
  let val = s:shift(a:vals, 1)
  if type(val) == 0 && val == -1
    call remove(a:opts, a:key)
  else
    let a:opts[a:key] = val
  endif
endfunction

function! s:help_lines(layout, live)
  if a:layout ==# 'vertical'
    let lines = [
    \ 'Occurrence',
    \ '  `0` block-edge delimiter',
    \ '    line-start ` `: leading indent',
    \ '  `1` first (default)',
    \ '  `2`...`N` nth',
    \ '  `-` last; `-2` second-to-last',
    \ '  `*` all; `**` alternating',
    \ '',
    \ 'Delimiter',
    \ '  ` ` whitespace',
    \ '  `=` operators; `:` JSON/YAML',
    \ '  `,` arguments; `.` chains',
    \ '  `|` tables; `&` LaTeX',
    \ '  `#` comments; `"` Vim comments',
    \ '  `{` and `}` braces',
    \ '',
    \ 'Alignment',
    \ '  <Enter> left/right/center',
    \ '  <C-A>/<C-O> per-occurrence sequence',
    \ '    (e.g. `lrc`, `rl*`)',
    \ '',
    \ 'Layout',
    \ '  <C-J> columns / space-between',
    \ '    / equal cells',
    \ '',
    \ 'Margins',
    \ '  <Left>/<Right> stick/margin',
    \ '  <Down> no margins; <Up> defaults',
    \ '  <C-L>/<C-R> margins',
    \ '',
    \ 'Options',
    \ '  <C-D> delimiter alignment',
    \ '  <C-I> indentation',
    \ '  <C-U> unmatched lines',
    \ '  <C-G> ignored syntax groups',
    \ '  <C-F> line filter',
    \ '  <C-X> regular expression',
    \ '',
    \ 'Operation',
    \ '  Cancel: <Esc> or <C-C>',
    \ '  Toggle live preview: <C-P>',
    \ '',
    \ 'Finish'
    \ ]
    return lines + (a:live
          \ ? ['  <C-P> or delimiter again',
          \    '    accept the preview',
          \    '  Finish regex: <C-X> again']
          \ : ['  EasyAlign: enter a delimiter once',
          \    '    align and finish immediately'])
  endif

  let lines = [
  \ 'Occurrence  `0` block edge; line-start ` `: leading indentation',
  \ '            `1` first  `2`...`N` nth  `-` last  `-2` second-to-last  `*` all  `**` alternating',
  \ 'Delimiter   ` ` whitespace  `=` operators  `:` JSON/YAML  `,` arguments        `.` chains',
  \ '            `|` tables      `&` LaTeX      `#` comments   `"` Vim comments     `{` and `}` braces',
  \ '',
  \ 'Alignment   <Enter> cycle left/right/center',
  \ '            <C-A>/<C-O> set per-occurrence sequence (e.g. `lrc`, `rl*`)',
  \ 'Layout      <C-J> columns / space-between / equal cells',
  \ 'Margins     <Left>/<Right> stick/margin  <Down> no margins  <Up> defaults  <C-L>/<C-R> margins',
  \ 'Options     <C-D> delimiter alignment    <C-I> indentation  <C-U> unmatched lines',
  \ '            <C-G> ignored syntax groups  <C-F> line filter  <C-X> regular expression',
  \ '',
  \ 'Operation   Cancel: <Esc> or <C-C>',
  \ '            Toggle live preview: <C-P>',
  \ '',
  \ ]
  return lines + (a:live
        \ ? ['Finish      <C-P> or delimiter again to accept the preview',
        \    '            Finish regex: <C-X> again']
        \ : ['Finish      EasyAlign: enter a delimiter once to align and finish'])
endfunction

function! s:exact_bufnr(name)
  for nr in range(1, bufnr('$'))
    if bufexists(nr) && bufname(nr) ==# a:name
      return nr
    endif
  endfor
  return -1
endfunction

function! s:update_help_split(help)
  if empty(a:help) || !bufexists(a:help.bufnr)
    return
  endif

  let target_view = win_getid() == a:help.target_winid ? winsaveview() : {}
  let old_line_count = len(getbufline(a:help.bufnr, 1, '$'))
  let lines = s:help_lines(a:help.layout, s:live)
  call setbufvar(a:help.bufnr, '&modifiable', 1)
  call setbufline(a:help.bufnr, 1, lines)
  if old_line_count > len(lines) && exists('*deletebufline')
    call deletebufline(a:help.bufnr, len(lines) + 1, old_line_count)
  endif
  call setbufvar(a:help.bufnr, '&modified', 0)
  call setbufvar(a:help.bufnr, '&modifiable', 0)
  if a:help.layout ==# 'horizontal' && exists('*win_execute') &&
        \ win_id2win(a:help.winid) > 0
    call win_execute(a:help.winid,
          \ 'resize '.min([len(lines), a:help.max_size]))
  endif
  if !empty(target_view) && win_getid() == a:help.target_winid
    call winrestview(target_view)
  endif
  redraw
endfunction

function! s:help_split_layout()
  let layout = get(g:, s:help_split_option, '')
  if type(layout) != type('') || index(['', 'horizontal', 'vertical'], layout) < 0
    call s:exit('Invalid g:'.s:help_split_option.
          \ ': expected '''', ''horizontal'', or ''vertical''')
  endif
  return layout
endfunction

function! s:max_line_width(lines)
  return max(map(copy(a:lines), 's:strwidth(v:val)'))
endfunction

function! s:configure_help_syntax()
  syntax match EasyAlignHelpHeading /^\%(Occurrence\|Delimiter\|Alignment\|Layout\|Margins\|Options\|Operation\|Finish\)\>/
  syntax match EasyAlignHelpKey /`[^`]*`/
  syntax match EasyAlignHelpKey /<[^>]*>/
  highlight default link EasyAlignHelpHeading Identifier
  highlight default link EasyAlignHelpKey Special
  let b:current_syntax = 'easy_align_help'
endfunction

function! s:open_help_split()
  let layout = s:help_split_layout()
  if empty(layout)
    return {}
  endif
  if !exists('*win_getid') || !exists('*win_gotoid') || !exists('*win_id2win')
    call s:exit('g:'.s:help_split_option.' requires window-ID support')
  endif

  let target_winid = win_getid()
  let target_view = winsaveview()
  let lines = s:help_lines(layout, s:live)
  if layout ==# 'horizontal'
    let max_size = max([1, winheight(0) / 2])
    let size = min([len(lines), max_size])
    execute 'keepalt botright '.size.'new'
  else
    let max_size = 0
    let width = winwidth(0)
    let help_width = max([
          \ s:max_line_width(s:help_lines(layout, 0)),
          \ s:max_line_width(s:help_lines(layout, 1))])
    let size = min([help_width + 2,
          \ max([20, width / 2]), max([1, width - 2])])
    execute 'keepalt botright '.size.'vnew'
  endif

  let help_winid = win_getid()
  let help_bufnr = bufnr('')
  let help_name = s:help_buffer_name
  let suffix = 2
  while s:exact_bufnr(help_name) >= 0
    let help_name = printf('[EasyAlign Help %d] - Interactive Mode', suffix)
    let suffix += 1
  endwhile
  execute 'silent file '.fnameescape(help_name)
  call setline(1, lines)
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  setlocal nowrap nonumber norelativenumber nospell
  setlocal foldcolumn=0 signcolumn=no
  setlocal nomodified nomodifiable
  if layout ==# 'horizontal'
    setlocal winfixheight
  else
    setlocal winfixwidth
  endif
  let b:easy_align_help = 1
  call s:configure_help_syntax()

  if !win_gotoid(target_winid)
    silent! close
    call s:exit('EasyAlign target window disappeared')
  endif
  call winrestview(target_view)
  redraw
  return {
  \ 'bufnr': help_bufnr,
  \ 'layout': layout,
  \ 'max_size': max_size,
  \ 'target_winid': target_winid,
  \ 'winid': help_winid
  \ }
endfunction

function! s:close_help_split(help)
  if empty(a:help)
    return
  endif

  let target_winid = a:help.target_winid
  let target_view = win_getid() == target_winid ? winsaveview() : {}
  if win_id2win(a:help.winid) > 0 && win_gotoid(a:help.winid)
    silent! close
  endif
  if win_id2win(target_winid) > 0 && win_gotoid(target_winid) && !empty(target_view)
    call winrestview(target_view)
  endif
  redraw
endfunction

function! s:interactive(range, modes, n, d, opts, rules, vis, bvis, help)
  let mode = s:shift(a:modes, 1)
  let n    = a:n
  let d    = a:d
  let ch   = ''
  let opts = s:compact_options(a:opts)
  let vals = deepcopy(s:option_values)
  let regx = 0
  let warn = ''
  let undo = 0

  while 1
    " Live preview
    let rdrw = 0
    if undo
      silent! undo
      let undo = 0
      let rdrw = 1
    endif
    if s:live && !empty(d)
      let output = s:process(a:range, mode, n, d, s:normalize_options(opts), regx, a:rules, a:bvis)
      let &undolevels = &undolevels " Break undo block
      call s:update_lines(output.todo)
      let undo = !empty(output.todo)
      let rdrw = 1
    endif
    if rdrw
      if a:vis
        normal! gv
      endif
      redraw
      if a:vis | execute "normal! \<esc>" | endif
    endif
    call s:echon(mode, n, -1, regx ? '/'.d.'/' : d, opts, warn)

    let check = 0
    let warn = ''

    try
      let c = getchar()
    catch /^Vim:Interrupt$/
      let c = 27
    endtry
    let ch = nr2char(c)
    if c == 3 || c == 27 " CTRL-C / ESC
      if undo
        silent! undo
      endif
      throw 'exit'
    elseif c == "\<bs>"
      if !empty(d)
        let d = ''
        let regx = 0
      elseif len(n) > 0
        let n = strpart(n, 0, len(n) - 1)
      endif
    elseif c == 10 " CTRL-J
      call s:shift_opts(opts, 'j', vals['justify'])
    elseif c == 13 " Enter key
      let mode = s:shift(a:modes, 1)
      if has_key(opts, 'a')
        let opts.a = mode . strpart(opts.a, 1)
      endif
    elseif ch == '-'
      if empty(n)      | let n = '-'
      elseif n == '-'  | let n = ''
      else             | let check = 1
      endif
    elseif ch == '*'
      if empty(n)      | let n = '*'
      elseif n == '*'  | let n = '**'
      elseif n == '**' | let n = ''
      else             | let check = 1
      endif
    elseif empty(d) && c >= 48 && c <= 57 " Numbers
      if n[0] == '*' || n ==# '0' | let check = 1
      else             | let n = n . ch
      end
    elseif ch == "\<C-D>"
      call s:shift_opts(opts, 'da', vals['delimiter_align'])
    elseif ch == "\<C-I>"
      call s:shift_opts(opts, 'idt', vals['indentation'])
    elseif ch == "\<C-L>"
      let lm = s:input("Left margin: ", get(opts, 'lm', ''), a:vis)
      if empty(lm)
        let warn = 'Set to default. Input 0 to remove it'
        silent! call remove(opts, 'lm')
      else
        let opts['lm'] = s:atoi(lm)
      endif
    elseif ch == "\<C-R>"
      let rm = s:input("Right margin: ", get(opts, 'rm', ''), a:vis)
      if empty(rm)
        let warn = 'Set to default. Input 0 to remove it'
        silent! call remove(opts, 'rm')
      else
        let opts['rm'] = s:atoi(rm)
      endif
    elseif ch == "\<C-U>"
      call s:shift_opts(opts, 'iu', vals['ignore_unmatched'])
    elseif ch == "\<C-G>"
      call s:shift_opts(opts, 'ig', vals['ignore_groups'])
    elseif ch == "\<C-P>"
      if s:live
        if !empty(d)
          let ch = d
          break
        else
          let s:live = 0
        endif
      else
        let s:live = 1
      endif
      call s:update_help_split(a:help)
    elseif c == "\<Left>"
      let opts['stl'] = 1
      let opts['lm']  = 0
    elseif c == "\<Right>"
      let opts['stl'] = 0
      let opts['lm']  = 1
    elseif c == "\<Down>"
      let opts['lm']  = 0
      let opts['rm']  = 0
    elseif c == "\<Up>"
      silent! call remove(opts, 'stl')
      silent! call remove(opts, 'lm')
      silent! call remove(opts, 'rm')
    elseif ch == "\<C-A>" || ch == "\<C-O>"
      let modes = tolower(s:input("Alignment ([lrc...][[*]*]): ", get(opts, 'a', mode), a:vis))
      if match(modes, '^[lrc]\+\*\{0,2}$') != -1
        let opts['a'] = modes
        let mode      = modes[0]
        while mode != s:shift(a:modes, 1)
        endwhile
      else
        silent! call remove(opts, 'a')
      endif
    elseif ch == "\<C-_>" || ch == "\<C-X>"
      if s:live && regx && !empty(d)
        break
      endif

      let prompt = 'Regular expression: '
      let ch = s:input(prompt, '', a:vis)
      if !empty(ch) && s:valid_regexp(ch)
        let regx = 1
        let d = ch
        if !s:live | break | endif
      else
        let warn = 'Invalid regular expression: '.ch
      endif
    elseif ch == "\<C-F>"
      let f = s:input("Filter (g/../ or v/../): ", get(opts, 'f', ''), a:vis)
      let m = matchlist(f, '^[gv]/\(.\{-}\)/\?$')
      if empty(f)
        silent! call remove(opts, 'f')
      elseif !empty(m) && s:valid_regexp(m[1])
        let opts['f'] = f
      else
        let warn = 'Invalid filter expression'
      endif
    elseif ch =~ '[[:print:]]'
      let check = 1
    else
      let warn = 'Invalid character'
    endif

    if check
      if empty(d)
        if has_key(a:rules, ch)
          let d = ch
          if !s:live
            if a:vis
              execute "normal! gv\<esc>"
            endif
            break
          endif
        else
          let warn = 'Unknown delimiter key: '.ch
        endif
      else
        if regx
          let warn = 'Press <CTRL-X> to finish'
        else
          if d == ch
            break
          else
            let warn = 'Press '''.d.''' again to finish'
          endif
        end
      endif
    endif
  endwhile
  if s:live
    let copts = call('s:summarize', output.summarize)
    let s:live = 0
    let g:easy_align_last_command = s:echon('', n, regx, d, copts, '')
    let s:live = 1
  end
  return [mode, n, ch, opts, regx]
endfunction

function! s:interactive_with_help(range, modes, n, d, opts, rules, vis, bvis)
  let help = {}
  try
    let help = s:open_help_split()
    return s:interactive(a:range, a:modes, a:n, a:d, a:opts, a:rules, a:vis, a:bvis, help)
  finally
    call s:close_help_split(help)
  endtry
endfunction

function! s:valid_regexp(regexp)
  try
    call matchlist('', a:regexp)
  catch
    return 0
  endtry
  return 1
endfunction

function! s:test_regexp(regexp)
  let regexp = empty(a:regexp) ? @/ : a:regexp
  if !s:valid_regexp(regexp)
    call s:exit('Invalid regular expression: '. regexp)
  endif
  return regexp
endfunction

let s:shorthand_regex =
  \ '\s*\%('
  \   .'\(lm\?[0-9]\+\)\|\(rm\?[0-9]\+\)\|\(iu[01]\)\|\(\%(s\%(tl\)\?[01]\)\|[<>]\)\|'
  \   .'\(da\?[clr]\)\|\(\%(ms\?\|a\)[lrc*]\+\)\|\(i\%(dt\)\?[kdsn]\)\|\([gv]/.*/\)\|\(\%(ig\[.*\]\|j[bc]\)\)'
  \ .'\)\+\s*$'

function! s:parse_shorthand_opts(expr)
  let opts = {}
  let expr = substitute(a:expr, '\s', '', 'g')
  let regex = '^'. s:shorthand_regex

  if empty(expr)
    return opts
  elseif expr !~ regex
    call s:exit("Invalid expression: ". a:expr)
  else
    let match = matchlist(expr, regex)
    for m in filter(match[ 1 : -1 ], '!empty(v:val)')
      for key in ['lm', 'rm', 'l', 'r', 'stl', 's', '<', '>', 'iu', 'da', 'd', 'ms', 'm', 'ig', 'i', 'g', 'v', 'a', 'j']
        if stridx(tolower(m), key) == 0
          let rest = strpart(m, len(key))
          if key == 'i' | let key = 'idt' | endif
          if key == 'g' || key == 'v'
            let rest = key.rest
            let key = 'f'
          endif

          if key == 'idt' || index(['d', 'f', 'm', 'a', 'j'], key[0]) >= 0
            let opts[key] = rest
          elseif key == 'ig'
            try
              let arr = eval(rest)
              if type(arr) == 3
                let opts[key] = arr
              else
                throw 'Not an array'
              endif
            catch
              call s:exit("Invalid ignore_groups: ". a:expr)
            endtry
          elseif key =~ '[<>]'
            let opts['stl'] = key == '<'
          else
            let opts[key] = str2nr(rest)
          endif
          break
        endif
      endfor
    endfor
  endif
  return s:normalize_options(opts)
endfunction

function! s:parse_args(args)
  if empty(a:args)
    return ['', '', {}, 0]
  endif
  let n    = ''
  let ch   = ''
  let args = a:args
  let cand = ''
  let opts = {}

  " Poor man's option parser
  let idx = 0
  while 1
    let midx = match(args, '\s*{.*}\s*$', idx)
    if midx == -1 | break | endif

    let cand = strpart(args, midx)
    try
      let [l, r, c, k, s, d, n] = ['l', 'r', 'c', 'k', 's', 'd', 'n']
      let [L, R, C, K, S, D, N] = ['l', 'r', 'c', 'k', 's', 'd', 'n']
      let o = eval(cand)
      if type(o) == 4
        let opts = o
        if args[midx - 1 : midx] == '\ '
          let midx += 1
        endif
        let args = strpart(args, 0, midx)
        break
      endif
    catch
      " Ignore
    endtry
    let idx = midx + 1
  endwhile

  " Invalid option dictionary
  if len(substitute(cand, '\s', '', 'g')) > 2 && empty(opts)
    call s:exit("Invalid option: ". cand)
  else
    let opts = s:normalize_options(opts)
  endif

  " Shorthand option notation
  let sopts = matchstr(args, s:shorthand_regex)
  if !empty(sopts)
    let args = strpart(args, 0, len(args) - len(sopts))
    let opts = extend(s:parse_shorthand_opts(sopts), opts)
  endif

  " Has /Regexp/?
  let matches = matchlist(args, '^\(.\{-}\)\s*/\(.*\)/\s*$')

  " Found regexp
  if !empty(matches)
    return [matches[1], s:test_regexp(matches[2]), opts, 1]
  else
    let tokens = matchlist(args, '^\(0\|[1-9][0-9]*\|-[0-9]*\|\*\*\?\)\?\s*\(.\{-}\)\?$')
    " Try swapping n and ch
    let [n, ch] = empty(tokens[2]) ? reverse(tokens[1:2]) : tokens[1:2]

    " Resolving command-line ambiguity
    " '\ ' => ' '
    " '\'  => ' '
    if ch =~ '^\\\s*$'
      let ch = ' '
    " '\\' => '\'
    elseif ch =~ '^\\\\\s*$'
      let ch = '\'
    endif

    return [n, ch, opts, 0]
  endif
endfunction

function! s:parse_filter(f)
  let m = matchlist(a:f, '^\([gv]\)/\(.\{-}\)/\?$')
  if empty(m)
    return [0, '']
  else
    return [m[1] == 'g' ? 1 : -1, m[2]]
  endif
endfunction

function! s:interactive_modes(bang)
  return get(g:,
    \ (a:bang ? 'easy_align_bang_interactive_modes' : 'easy_align_interactive_modes'),
    \ (a:bang ? ['r', 'l', 'c'] : ['l', 'r', 'c']))
endfunction

function! s:alternating_modes(mode)
  return a:mode ==? 'r' ? 'rl' : 'lr'
endfunction

function! s:update_lines(todo)
  for [line, content] in items(a:todo)
    call setline(line, s:rtrim(content))
  endfor
endfunction

function! s:align_leading_whitespace(range, dict)
  let todo = {}
  let [f, fx] = s:parse_filter(a:dict.filter)
  for line in range(a:range[0], a:range[1])
    let text = getline(line)
    if f == 1 && text !~ fx
      continue
    elseif f == -1 && text =~ fx
      continue
    endif
    if text =~# '^\s\+\S'
      let todo[line] = a:dict.mr . s:ltrim(text)
    endif
  endfor
  return todo
endfunction

function! s:justify_split(line, string, fc, pattern, ignore_groups)
  let cells = []
  let delims = []
  let cell_start = 0
  let scan = 0
  while scan < len(a:string)
    let matchidx = match(a:string, a:pattern, scan)
    if matchidx < 0
      break
    endif
    let matchend = matchend(a:string, a:pattern, scan)
    if matchend == matchidx
      call s:exit('justify requires non-empty delimiter matches')
    endif

    if s:highlighted_as(a:line, a:fc + matchidx, a:ignore_groups)
      let scan = matchend
      continue
    endif

    call add(cells, strpart(a:string, cell_start, matchend - cell_start))
    call add(delims, strpart(a:string, matchidx, matchend - matchidx))
    let cell_start = matchend
    let scan = matchend
  endwhile
  return [cells, delims, strpart(a:string, cell_start)]
endfunction

function! s:justify_line(line, dict)
  let string = s:rtrim(getline(a:line))
  let [raw_cells, delims, tail] = s:justify_split(
        \ a:line, string, 1, a:dict.pattern, a:dict.ignore_groups)
  let tail = s:rtrim(tail)
  let indent = ''
  let cells = []

  if !empty(raw_cells)
    for idx in range(0, len(raw_cells) - 1)
      let delim = delims[idx]
      let body = strpart(raw_cells[idx], 0, len(raw_cells[idx]) - len(delim))
      if idx == 0
        let indent = matchstr(body, '^\s*')
        let body = strpart(body, len(indent))
      else
        let body = s:ltrim(body)
      endif

      let compact = s:rtrim(body) . delim
      let opener = get({']': '[', ')': '(', '}': '{', '>': '<'}, delim, '')
      if !empty(opener) && stridx(body, opener) == 0
        let body = strpart(body, len(opener))
      else
        let opener = ''
      endif
      call add(cells, {
            \ 'compact': compact,
            \ 'opener': opener,
            \ 'content': s:trim(body),
            \ 'closer': delim })
    endfor
  endif

  return {
        \ 'original': string,
        \ 'width': s:strwidth(string),
        \ 'indent': indent,
        \ 'cells': cells,
        \ 'tail': tail }
endfunction

function! s:justify_allocate_widths(total, minimums)
  let widths = copy(a:minimums)
  let slack = a:total - s:sum(widths)
  while slack > 0
    let smallest = min(widths)
    let lowest = []
    let next = -1
    for idx in range(0, len(widths) - 1)
      if widths[idx] == smallest
        call add(lowest, idx)
      elseif next < 0 || widths[idx] < next
        let next = widths[idx]
      endif
    endfor

    let step = next < 0 ? -1 : next - smallest
    let needed = step * len(lowest)
    if step > 0 && slack >= needed
      for idx in lowest
        let widths[idx] += step
      endfor
      let slack -= needed
    else
      let each = slack / len(lowest)
      let extra = slack % len(lowest)
      for pos in range(0, len(lowest) - 1)
        let widths[lowest[pos]] += each +
              \ (pos >= len(lowest) - extra ? 1 : 0)
      endfor
      let slack = 0
    endif
  endwhile
  return widths
endfunction

function! s:justify_between(info, target)
  let cell_count = len(a:info.cells)
  let compact_width = s:strwidth(a:info.indent .
        \ join(map(copy(a:info.cells), 'v:val.compact'), '') . a:info.tail)
  let slack = a:target - compact_width
  if slack < 0 || cell_count < 2
    return a:info.original
  endif

  let gaps = cell_count - 1
  let each = slack / gaps
  let extra = slack % gaps
  let output = a:info.indent
  for idx in range(0, cell_count - 1)
    let output .= a:info.cells[idx].compact
    if idx < gaps
      let output .= repeat(' ', each + (idx < extra ? 1 : 0))
    endif
  endfor
  return output . a:info.tail
endfunction

function! s:justify_cells(info, target, mode_sequence, recur)
  let cell_count = len(a:info.cells)
  if cell_count < 1
    return a:info.original
  endif

  let available = a:target - s:strwidth(a:info.indent . a:info.tail)
  let minimums = map(copy(a:info.cells),
        \ 's:strwidth(v:val.opener . v:val.content . v:val.closer)')
  if available < s:sum(minimums)
    return a:info.original
  endif
  let widths = s:justify_allocate_widths(available, minimums)
  let modes = split(a:mode_sequence, '\zs')
  if empty(modes)
    let modes = ['l']
  endif

  let output = a:info.indent
  for idx in range(0, cell_count - 1)
    let cell = a:info.cells[idx]
    let mode = s:shift(modes, a:recur == 2)
    let padding = widths[idx] - minimums[idx]
    if mode ==? 'l'
      let [left, right] = [0, padding]
    elseif mode ==? 'r'
      let [left, right] = [padding, 0]
    elseif mode ==? 'c'
      let left = padding / 2
      let right = padding - left
    else
      call s:exit('Invalid alignment mode for justify: ' . mode)
    endif
    let output .= cell.opener . repeat(' ', left) . cell.content .
          \ repeat(' ', right) . cell.closer
  endfor
  return output . a:info.tail
endfunction

function! s:do_justify(range, dict, mode_sequence, recur)
  let lines = {}
  let target = 0
  let [f, fx] = s:parse_filter(a:dict.filter)
  let required = a:dict.justify ==# 'between' ? 2 : 1

  for line in range(a:range[0], a:range[1])
    let text = getline(line)
    if f == 1 && text !~ fx
      continue
    elseif f == -1 && text =~ fx
      continue
    endif
    let info = s:justify_line(line, a:dict)
    if len(info.cells) < required
      continue
    endif
    let lines[line] = info
    let target = max([target, info.width])
  endfor

  let todo = {}
  for [line, info] in items(lines)
    if info.width == target
      continue
    elseif a:dict.justify ==# 'between'
      let todo[line] = s:justify_between(info, target)
    else
      let todo[line] = s:justify_cells(info, target, a:mode_sequence, a:recur)
    endif
  endfor
  return todo
endfunction

function! s:parse_nth(n)
  let n = a:n
  let recur = 0
  if n == '*'      | let [nth, recur] = [1, 1]
  elseif n == '**' | let [nth, recur] = [1, 2]
  elseif n == '-'  | let nth = -1
  elseif empty(n)  | let nth = 1
  elseif n == '0' || ( n != '-0' && n != string(str2nr(n)) )
    call s:exit('Invalid N-th parameter: '. n)
  else
    let nth = n
  endif
  return [nth, recur]
endfunction

function! s:is_zero_nth(n)
  return type(a:n) == type(0) ? a:n == 0 : a:n ==# '0'
endfunction

function! s:build_dict(delimiters, ch, regexp, opts)
  if a:regexp
    let dict = { 'pattern': a:ch }
  else
    if !has_key(a:delimiters, a:ch)
      call s:exit('Unknown delimiter key: '. a:ch)
    endif
    let dict = copy(a:delimiters[a:ch])
  endif
  call extend(dict, a:opts)

  let ml = get(dict, 'left_margin', ' ')
  let mr = get(dict, 'right_margin', ' ')
  if type(ml) == 0 | let ml = repeat(' ', ml) | endif
  if type(mr) == 0 | let mr = repeat(' ', mr) | endif
  call extend(dict, { 'ml': ml, 'mr': mr })

  let dict.pattern = get(dict, 'pattern', a:ch)
  let dict.delimiter_align =
    \ get(dict, 'delimiter_align', get(g:, 'easy_align_delimiter_align', 'r'))[0]
  let dict.indentation =
    \ get(dict, 'indentation', get(g:, 'easy_align_indentation', 'k'))[0]
  let dict.stick_to_left =
    \ get(dict, 'stick_to_left', 0)
  let dict.ignore_unmatched =
    \ get(dict, 'ignore_unmatched', get(g:, 'easy_align_ignore_unmatched', 2))
  let dict.ignore_groups =
    \ get(dict, 'ignore_groups', get(dict, 'ignores', s:ignored_syntax()))
  let dict.filter =
    \ get(dict, 'filter', '')
  let dict.justify =
    \ get(dict, 'justify', '')
  if dict.justify ==# 'b'
    let dict.justify = 'between'
  elseif dict.justify ==# 'c'
    let dict.justify = 'cells'
  elseif !empty(dict.justify) && index(['between', 'cells'], dict.justify) < 0
    call s:exit('Invalid justify: ' . dict.justify)
  endif
  return dict
endfunction

function! s:build_mode_sequence(expr, recur)
  let [expr, recur] = [a:expr, a:recur]
  let suffix = matchstr(a:expr, '\*\+$')
  if suffix == '*'
    let expr = expr[0 : -2]
    let recur = 1
  elseif suffix == '**'
    let expr = expr[0 : -3]
    let recur = 2
  endif
  return [tolower(expr), recur]
endfunction

function! s:process(range, mode, n, ch, opts, regexp, rules, bvis)
  let requested_nth = (empty(a:n) && exists('g:easy_align_nth'))
        \ ? g:easy_align_nth : a:n
  let edge_nth = s:is_zero_nth(requested_nth)
  let edge = edge_nth && a:bvis ? min([virtcol("'<"), virtcol("'>")]) : 0
  let leading_nth = edge_nth && !a:regexp && a:ch ==# ' ' &&
        \ (!a:bvis || edge == 1)
  if edge_nth && !a:bvis && !leading_nth
    call s:exit('N-th parameter 0 outside blockwise mode requires the whitespace delimiter')
  endif
  let [nth, recur] = edge_nth ? [1, 0] : s:parse_nth(requested_nth)
  let dict = s:build_dict(a:rules, a:ch, a:regexp, a:opts)
  let [mode_sequence, recur] = s:build_mode_sequence(
    \ get(dict, 'align', recur == 2 ? s:alternating_modes(a:mode) : a:mode),
    \ recur)

  if !empty(dict.justify)
    if a:bvis
      call s:exit('justify does not support blockwise visual mode')
    endif
    return { 'todo': s:do_justify(a:range, dict, mode_sequence, recur),
          \ 'summarize': [ a:opts, recur, mode_sequence ] }
  endif

  if leading_nth
    return { 'todo': s:align_leading_whitespace(a:range, dict),
          \ 'summarize': [ a:opts, recur, mode_sequence ] }
  endif

  let ve = &virtualedit
  set ve=all
  let args = [
    \ {}, split(mode_sequence, '\zs'),
    \ {}, {}, {}, a:range[0], a:range[1],
    \ edge_nth ? 1 : (a:bvis ? min([virtcol("'<"), virtcol("'>")]) : 1),
    \ edge_nth ? 0 : ((!recur && a:bvis) ? max([virtcol("'<"), virtcol("'>")]) : 0),
    \ nth, recur, dict,
    \ edge ]
  let &ve = ve
  while len(args) > 1
    let args = call('s:do_align', args)
  endwhile

  " todo: lines to update
  " summarize: arguments to s:summarize
  return { 'todo': args[0], 'summarize': [ a:opts, recur, mode_sequence ] }
endfunction

function s:summarize(opts, recur, mode_sequence)
  let copts = s:compact_options(a:opts)
  let nbmode = s:interactive_modes(0)[0]
  if !has_key(copts, 'a') && (
    \  (a:recur == 2 && s:alternating_modes(nbmode) != a:mode_sequence) ||
    \  (a:recur != 2 && (a:mode_sequence[0] != nbmode || len(a:mode_sequence) > 1))
    \ )
    call extend(copts, { 'a': a:mode_sequence })
  endif
  return copts
endfunction

function! s:align(bang, live, visualmode, first_line, last_line, expr)
  " Heuristically determine if the user was in visual mode
  if a:visualmode == 'command'
    let vis  = a:first_line == line("'<") && a:last_line == line("'>")
    let bvis = vis && visualmode() == "\<C-V>"
  elseif empty(a:visualmode)
    let vis  = 0
    let bvis = 0
  else
    let vis  = 1
    let bvis = a:visualmode == "\<C-V>"
  end
  let range = [a:first_line, a:last_line]
  let modes = s:interactive_modes(a:bang)
  let mode  = modes[0]
  let s:live = a:live

  let rules = s:easy_align_delimiters_default
  if exists('g:easy_align_delimiters')
    let rules = extend(copy(rules), g:easy_align_delimiters)
  endif

  let [n, ch, opts, regexp] = s:parse_args(a:expr)

  let bypass_fold = get(g:, 'easy_align_bypass_fold', 0)
  let ofm = &l:foldmethod
  try
    if bypass_fold | let &l:foldmethod = 'manual' | endif

    if empty(n) && empty(ch) || s:live
      let [mode, n, ch, opts, regexp] =
            \ s:interactive_with_help(range, copy(modes), n, ch, opts, rules, vis, bvis)
    endif

    if !s:live
      let output = s:process(range, mode, n, ch, s:normalize_options(opts), regexp, rules, bvis)
      call s:update_lines(output.todo)
      let copts = call('s:summarize', output.summarize)
      let g:easy_align_last_command = s:echon('', n, regexp, ch, copts, '')
    endif
  finally
    if bypass_fold | let &l:foldmethod = ofm | endif
  endtry
endfunction

function! easy_align#align(bang, live, visualmode, expr) range
  try
    call s:align(a:bang, a:live, a:visualmode, a:firstline, a:lastline, a:expr)
  catch /^\%(Vim:Interrupt\|exit\)$/
    if empty(a:visualmode)
      echon "\r"
      echon "\r"
    else
      normal! gv
    endif
  endtry
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set et sw=2 :
