let s:keepcpo = &cpo
set cpo&vim

if !exists('g:istanbul#test') || g:istanbul#test == 0
  finish
endif
unlet! g:istanbul#version
unlet! g:istanbul#jsonPath " reset by default
for f in split(glob('autoload/**/*.vim'), "\n")
  execute printf('source %s', f)
endfor
source plugin/istanbul.vim

let s:nest = 0
let s:indent = repeat("\u0020", 2)
function! s:passing(it, time)
  echohl Statement
  echomsg printf("%s\u2713 %s (%ssec)", repeat(s:indent, s:nest),
     \ a:it, substitute(reltimestr(a:time), '^\s*', '', ''))
  echohl None
endfunction
function! s:failing(it, actual, expect)
  echohl WarningMsg
  echomsg printf('%sx %s', repeat(s:indent, s:nest), a:it)
  echomsg printf('%s  expect: %s', repeat(s:indent, s:nest), string(a:expect))
  echomsg printf('%s  actual: %s', repeat(s:indent, s:nest), string(a:actual))
  echohl None
endfunction
function! s:shouldeql(it, actual, expect, time)
  if a:actual == a:expect
    call s:passing(a:it, a:time)
  else
    call s:failing(a:it, a:actual, a:expect)
  endif
endfunction
function! s:itshouldeql(it, input, expect)
  let start = reltime()
  call s:shouldeql(a:it, a:input, a:expect, reltime(start))
endfunction
function! s:describe(desc)
  echomsg repeat(s:indent, s:nest) a:desc
  let s:nest += 1
endfunction
function! s:enddescribe()
  let s:nest -= 1
endfunction

let s:windows = has('win64') || has('win32') || has('win16') || has('win95')

function! s:rmdir(path)
  let rel = fnamemodify(a:path, ':.')
  if isdirectory(rel)
    if s:windows
      let cmd = printf('rmdir /S /Q %s', rel)
    else
      let cmd = printf('rm -rf %s', rel)
    endif
    echo system(cmd)
  endif
endfunction

call s:rmdir('test/_')
call mkdir('test/_/foo/bar/baz/coverage', 'p')
call mkdir('test/_/foo/coverage', 'p')
call writefile([], 'test/_/foo/bar/baz/coverage/coverage.json')
call writefile([], 'test/_/foo/coverage/coverage.json')

call s:describe('autoload/istanbul.vim')
  call s:describe('istanbul#findjson')
    call s:itshouldeql('should detect coverage.json that is placed on the same directory',
      \ fnamemodify(istanbul#findjson('test/_/foo/bar/baz/index.js'), ':.'),
      \ !s:windows
        \ ? 'test/_/foo/bar/baz/coverage/coverage.json'
        \ : 'test\_\foo\bar\baz\coverage\coverage.json')
    call s:itshouldeql('should detect coverage.json that is placed on upper directory',
      \ fnamemodify(istanbul#findjson('test/_/foo/bar/index.js'), ':.'),
      \ !s:windows
        \ ? 'test/_/foo/coverage/coverage.json'
        \ : 'test\_\foo\coverage\coverage.json')
  call s:enddescribe()
call s:enddescribe()

call s:describe('autoload/istanbul/error.vim')
  call s:describe('istanbul#error#spreadcall')
    call s:itshouldeql('should execute multiple arguments function by list (like ES2015 spread syntax)',
      \ istanbul#error#spreadcall('printf', ['%s %s %s %.4f', 'foo', 'bar', 'baz', 12.345]),
      \ 'foo bar baz 12.3450')
  call s:enddescribe()
call s:enddescribe()

call s:describe('autoload/istanbul/path.vim')
  call s:describe('istanbul#path#sep')
    call s:itshouldeql('should detect backslash (\) from Windows path format',
      \ istanbul#path#sep('C:\Foo\Bar'), '\')
    call s:itshouldeql('should detect slash (/) from UNIX path format',
      \ istanbul#path#sep('/foo/bar'), '/')
    call s:itshouldeql('should return first separator (\) from mixed-path format',
      \ istanbul#path#sep('C:\Foo/Bar'), '\')
    call s:itshouldeql('should return first separator (/) from mixed-path format',
      \ istanbul#path#sep('/foo\bar'), '/')
    call s:itshouldeql('should return OS specific separator from non-separator partial',
      \ istanbul#path#sep('foo'), s:windows ? '\' : '/')
    call s:itshouldeql('should return OS specific separator from empty string',
      \ istanbul#path#sep(''), s:windows ? '\' : '/')
  call s:enddescribe()
  call s:describe('istanbul#path#ancestors')
    call s:itshouldeql('should return partial ancestors for partial path',
      \ istanbul#path#ancestors('foo\bar\baz'),
      \ ['foo\bar\baz', 'foo\bar', 'foo' ] )
    call s:itshouldeql('should return ancestors for UNIX path format',
      \ istanbul#path#ancestors('\foo\bar\baz'),
      \ ['\foo\bar\baz', '\foo\bar', '\foo' ] )
    call s:itshouldeql('should return ancestors for Windows path format',
      \ istanbul#path#ancestors('C:\foo\bar\baz'),
      \ ['C:\foo\bar\baz', 'C:\foo\bar', 'C:\foo', 'C:'] )
    call s:itshouldeql('should return ancestors for UNC path format',
      \ istanbul#path#ancestors('//foo/bar/baz'),
      \ ['//foo/bar/baz', '//foo/bar', '//foo' ] )
  call s:enddescribe()
  call s:describe('istanbul#path#join')
    call s:itshouldeql('should join (foo, bar) to ''foo\bar'' (unix) or ''foo/bar'' (win)',
      \ istanbul#path#join('foo', 'bar'), s:windows ? 'foo\bar' : 'foo/bar')
    call s:itshouldeql('should join (foo, bar\) to ''foo\bar'' (unix) or ''foo/bar'' (win)',
      \ istanbul#path#join('foo', 'bar\'), s:windows ? 'foo\bar' : 'foo/bar')
    call s:itshouldeql('should join (foo/, bar\) to ''foo/bar'' on any OS',
      \ istanbul#path#join('foo/', 'bar\'), 'foo/bar')
    call s:itshouldeql('should join (foo\, bar/) to ''foo\bar'' on any OS',
      \ istanbul#path#join('foo\', 'bar/'), 'foo\bar')
    call s:itshouldeql('should join (foo\, bar, baz) to ''foo\bar\baz'' on any OS',
      \ istanbul#path#join('foo\', 'bar', 'baz'), 'foo\bar\baz')
  call s:enddescribe()
  call s:describe('istanbul#path#similaliry')
    call s:itshouldeql('should similarity is 0 for ''foo/bar'' and ''bar/foo''',
      \ istanbul#path#similarity('foo/bar', 'bar/foo'), 0)
    call s:itshouldeql('should similarity is 2 for ''foo/bar'' and ''foo/bar''',
      \ istanbul#path#similarity('foo/bar', 'foo/bar'), 2)
    call s:itshouldeql('should similarity is 2 for ''foo/bar/baz'' and ''bar/baz''',
      \ istanbul#path#similarity('foo/bar/baz', 'bar/baz'), 2)
  call s:enddescribe()
  call s:describe('istanbul#path#sort')
    call s:itshouldeql('should sort by length and alphabetical order',
      \ istanbul#path#sort([
        \ 'x',
        \ 'd\e\f',
        \ 'b\a',
        \ 'a\b',
        \ 'b\c\d',
        \ 'a\b\c\d',
        \ 'b\c\d\e\f',
      \ ]), [
        \ 'x',
        \ 'a\b',
        \ 'b\a',
        \ 'b\c\d',
        \ 'd\e\f',
        \ 'a\b\c\d',
        \ 'b\c\d\e\f',
      \ ])
  call s:enddescribe()
  call s:describe('istanbul#path#mostsimilar')
    call s:itshouldeql('should return foo/bar from [./foo/bar/baz, ./foo/bar, ./foo ]',
      \ istanbul#path#mostsimilar(['./foo/bar/baz', './foo/bar', './foo'], 'foo/bar'),
      \ './foo/bar')
    call s:itshouldeql('should return c/d from [ c/d, b/c/d/, a/b/c/d/ ]',
      \ istanbul#path#mostsimilar(['c/d', 'b/c/d/', 'a/b/c/d'], 'c/d'),
      \ 'c/d')
    call s:itshouldeql('should return c/d from [ a/b/c/d, b/c/d/, c/d ]',
      \ istanbul#path#mostsimilar(['a/b/c/d', 'b/c/d', 'c/d'], 'c/d'),
      \ 'c/d')
  call s:enddescribe()
call s:enddescribe()
call s:describe('autoload/istanbul/numlist.vim')
  call s:describe('istanbul#numlist#swap')
    call s:itshouldeql('should swap [1, 2] to [2, 1] by indexes (0, 1)',
      \ istanbul#numlist#swap([1, 2], 0, 1), [2, 1])
    call s:itshouldeql('should swap [1, 2] to [2, 1] by indexes (1, 0)',
      \ istanbul#numlist#swap([1, 2], 0, 1), [2, 1])
    call s:itshouldeql('should swap [3, 2, 1, 4] to [1, 2, 3, 4] by indexes (0, 2)',
      \ istanbul#numlist#swap([3, 2, 1, 4], 0, 2), [1, 2, 3, 4])
  call s:enddescribe()
  call s:describe('istanbul#numlist#sort')
    call s:itshouldeql('should sort [5,4,3] to [3,4,5]',
      \ istanbul#numlist#sort([5,4,3]), [3,4,5])
    call s:itshouldeql('should sort [100, 2, 30] to [2, 30, 100]',
      \ istanbul#numlist#sort([100, 2, 30]), [2, 30, 100])
  call s:enddescribe()
  call s:describe('istanbul#numlist#uniq')
    call s:itshouldeql('should filter [1,1,1] to [1]',
      \ istanbul#numlist#uniq([1,1,1]), [1])
    call s:itshouldeql('should filter [1,1,2,2,2,3,3] to [1,2,3]',
      \ istanbul#numlist#uniq([1,1,2,2,2,3,3]), [1,2,3])
  call s:enddescribe()
  call s:describe('istanbul#numlist#mkrange')
      call s:itshouldeql('should convert [1, 2, 4, 5] to [[1, 2], [4, 5]]',
        \ istanbul#numlist#mkrange([1, 2, 4, 5]), [[1, 2], [4, 5]])
      call s:itshouldeql('should convert [1, 3, 5, 7] to [[1, 1], [3, 3], [5, 5], [7, 7]]',
        \ istanbul#numlist#mkrange([1, 3, 5, 7]), [[1, 1], [3, 3], [5, 5], [7, 7]])
  call s:enddescribe()
call s:enddescribe()

call s:rmdir('test/_')

let &cpo = s:keepcpo
unlet s:keepcpo
