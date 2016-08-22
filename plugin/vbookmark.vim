" Name: Vim bookmark
" Author: Name5566 <name5566@gmail.com>
" Version: 0.3.0

if exists('loaded_vbookmark')
	finish
endif
let loaded_vbookmark = 1

let s:savedCpo = &cpo
set cpo&vim


"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sign
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
highlight SignColor ctermfg=white ctermbg=blue guifg=white guibg=RoyalBlue3


"exec 'sign define vbookmark_sign text=>> texthl=Visual'
exec 'sign define vbookmark_sign text=>> texthl=SignColor'
" exec 'sign define vbookmark_sign linehl=SignColor texthl=SignColor text=>>'

function! s:Vbookmark_placeSign(id, file, lineNo)
	exec 'sign place ' . a:id
		\ . ' line=' . a:lineNo
		\ . ' name=vbookmark_sign'
		\ . ' file=' . a:file
endfunction

function! s:Vbookmark_unplaceSign(id, file)
	exec 'sign unplace ' . a:id
		\ . ' file=' . a:file
endfunction

function! s:Vbookmark_jumpSign(id, file)
	exec 'sign jump ' . a:id
		\ . ' file=' . a:file
endfunction

" I don't like this implementation
function! s:Vbookmark_getSignId(line)
	let savedZ = @z
	redir @z
	silent! exec 'sign place buffer=' . winbufnr(0)
	redir END
	let output = @z
	let @z = savedZ

	let match = matchlist(output, '    \S\+=' . a:line . '  id=\(\d\+\)')
	if empty(match)
		return -1
	else
		return match[1]
	endif
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Bookmark
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Vbookmark_initVariables()
	let s:vbookmark_groups = []
	let s:vbookmark_curGroupIndex = s:Vbookmark_addGroup('default')
	let s:listBufNr = -1
endfunction

function! s:Vbookmark_isSignIdExist(id)
	let group = s:vbookmark_groups[s:vbookmark_curGroupIndex]
	for mark in group.marks
		if mark.id == a:id
			return 1
		endif
	endfor
	return 0
endfunction

function! s:Vbookmark_generateSignId()
	if !exists('s:vbookmark_signSeed')
		"let s:vbookmark_signSeed = 201210
		let s:vbookmark_signSeed = 1
	endif
	while s:Vbookmark_isSignIdExist(s:vbookmark_signSeed)
		let s:vbookmark_signSeed += 1
	endwhile
	return s:vbookmark_signSeed
endfunction

function! s:Vbookmark_adjustCurGroupIndex()
	let size = len(s:vbookmark_groups)
	let s:vbookmark_curGroupIndex = s:vbookmark_curGroupIndex % size
	if s:vbookmark_curGroupIndex < 0
		let s:vbookmark_curGroupIndex += size
	endif
endfunction

function! s:Vbookmark_adjustCurMarkIndex()
	let group = s:vbookmark_groups[s:vbookmark_curGroupIndex]
	let size = len(group.marks)
	let group.index = group.index % size
	if group.index < 0
		let group.index += size
	endif
endfunction

function! s:Vbookmark_setBookmark(line)
	let id = s:Vbookmark_generateSignId()
	let file = expand("%:p")
	if file == ''
		echo "No valid file name"
		return
	endif
	call s:Vbookmark_placeSign(id, file, a:line)
	let group = s:vbookmark_groups[s:vbookmark_curGroupIndex]
"	call add(group.marks, {'id': id, 'file': file, 'line': a:line})
"	call add(group.marks, {'id': id, 'file': file, 'line': a:line, 'text': getline("."), 'tabpage': tabpagenr(), 'winnr': tabpagewinnr(tabpagenr())})
	call add(group.marks, {'file': file, 'id': id, 'line': a:line, 'text': getline("."), 'tabpage': tabpagenr()})

    let CompareFunc = function("s:Vbookmark_sortBookmark")
    call sort(group.marks, CompareFunc)
endfunction

function! s:Vbookmark_sortBookmark(first, second)
	if a:first.file < a:second.file
		return -1
	elseif a:first.file > a:second.file
		return 1
	else
		if a:first.line < a:second.line
			return -1
		elseif a:first.line > a:second.line
			return 1
		else
			return 0
		endif
	endif
endfunction

function! s:Vbookmark_unsetBookmark(id)
	let marks = s:vbookmark_groups[s:vbookmark_curGroupIndex].marks
	let i = 0
	let size = len(marks)
	while i < size
		let mark = marks[i]
		if mark.id == a:id
			call s:Vbookmark_unplaceSign(mark.id, mark.file)
			call remove(marks, i)
			call s:Vbookmark_adjustCurMarkIndex()
			break
		endif
		let i += 1
	endwhile
endfunction

function! s:Vbookmark_refreshSign(file)
	let marks = s:vbookmark_groups[s:vbookmark_curGroupIndex].marks
	for mark in marks
		if mark.file == a:file
			call s:Vbookmark_placeSign(mark.id, mark.file, mark.line)
		endif
	endfor
endfunction

function! s:Vbookmark_jumpBookmark(method)
	let group = s:vbookmark_groups[s:vbookmark_curGroupIndex]
	if empty(group.marks)
        echo "No bookmarks found"
		return
	endif

	call s:Vbookmark_adjustCurMarkIndex()

	if a:method == 'fileprev' || a:method == 'filenext'
		if a:method == 'filenext'
			let group.index += 1
		elseif a:method == 'fileprev'
			let group.index -= 1
		endif
		call s:Vbookmark_adjustCurMarkIndex()
		let mark = group.marks[group.index]
    else 	
		let file = expand("%:p")
		let i = 0
		let tempIndex = group.index
		let size = len(group.marks)
		while i < size
			if a:method == 'next'
				let tempIndex += 1
				if tempIndex >= size 
					let tempIndex = 0
				endif
			elseif a:method == 'prev'
				let tempIndex -= 1
				if tempIndex < 0
					let tempIndex = size - 1
				endif
			endif
			let mark = group.marks[tempIndex]
			if mark.file == file
				break
			endif
			let i += 1
		endwhile
		if mark.file != file
			echo "No bookmarks found in current file"
			return
		endif
		let group.index = tempIndex
    endif

	try
		exec 'b ' . mark.file
		call s:Vbookmark_jumpSign(mark.id, mark.file)
	catch
		if !filereadable(mark.file)
			call remove(group.marks, group.index)
			call s:Vbookmark_adjustCurMarkIndex()
			call s:Vbookmark_jumpBookmark(a:method)
			return
		endif
		exec 'e ' . mark.file
		call s:Vbookmark_refreshSign(mark.file)
		call s:Vbookmark_jumpSign(mark.id, mark.file)
	endtry
endfunction

function! s:Vbookmark_placeAllSign()
	let marks = s:vbookmark_groups[s:vbookmark_curGroupIndex].marks
	for mark in marks
		try
			call s:Vbookmark_placeSign(mark.id, mark.file, mark.line)
		catch
		endtry
	endfor
endfunction

function! s:Vbookmark_unplaceAllSign()
	let marks = s:vbookmark_groups[s:vbookmark_curGroupIndex].marks
	for mark in marks
		try
			call s:Vbookmark_unplaceSign(mark.id, mark.file)
		catch
		endtry
	endfor
endfunction

function! s:Vbookmark_listAllBookmark()

	let group = s:vbookmark_groups[s:vbookmark_curGroupIndex]
	if empty(group.marks)
        echo "No bookmarks found"
		return
	endif

    if s:listBufNr < 0 || !bufexists(s:listBufNr)
		let s:listBufNr = bufnr("Bookmarks", 1)
	endif

	let l:bfwn = bufwinnr(s:listBufNr)
	if l:bfwn == winnr()
		" viewport wth buffer already active and current
		return
	"elseif gettabwinvar(s:listTabNr,1,"is_bklistwin") == 1
	else
		let haslistTabpage = 0
		for i in range(tabpagenr('$'))
			if gettabwinvar(i+1,1,"is_bklistwin") == 1
				let haslistTabpage = 1
				execute "normal!"  i+1 . "gt"
				break
			endif
		endfor
		
		if haslistTabpage == 0
			execute("tabedit")
			execute("b " . s:listBufNr)
			call s:Vbookmark_setupListWin()
		endif
	endif
	
	call s:Vbookmark_cleanListWin()
	call s:Vbookmark_renderListWin()

endfunction

function! s:Vbookmark_setupListWin()

	call setwinvar(1, "is_bklistwin", 1)

	setlocal buftype=nofile
	setlocal noswapfile
	setlocal nowrap
	set bufhidden=hide
	setlocal nobuflisted
	setlocal nolist
	setlocal noinsertmode
	setlocal nonumber
	setlocal cursorline
	setlocal nospell
	setlocal matchpairs=""

	for key in [".", "p", "P", "C", "x", "X", "r", "R", "i", "I", "a", "A", "D", "S", "U"]
		try
			execute "nnoremap <buffer> " . key . " <NOP>"
		catch //
		endtry
	endfor

	noremap <buffer> <silent> <CR>        :<C-U>call Vbookmark_jumpto()<CR>

	call s:Vbookmark_setListWinSyntax()

	"setlocal statusline=%{}
endfunction

"hi TabNum ctermfg=White ctermbg=2
"hi TabLineSel term=bold cterm=bold ctermbg=Red ctermfg=yellow
"hi TabLine ctermfg=yellow ctermbg=DarkGray

hi FileNameHL cterm=bold ctermfg=yellow
"hi LineNumHL cterm=none ctermfg=yellow
hi LineNumHL ctermbg=none ctermfg=Green

function! s:Vbookmark_setListWinSyntax()
	syn match FileName '^<\d\+> .*'
	highlight! link FileName FileNameHL
	syn match LineNum '^ \+\d\+  '
	highlight! link LineNum LineNumHL
endfunction

function! s:Vbookmark_cleanListWin()
	call cursor(1, 1)
	exec 'silent! normal! "_dG'
endfunction

function! s:Vbookmark_renderListWin()
	let marks = s:vbookmark_groups[s:vbookmark_curGroupIndex].marks
	let prefile = " "
	let fileIndex = 0
	let bookmarkIndex = 0
	let s:listwinJumpMap = []
	for mark in marks
		if mark.file != prefile
			let fileIndex = fileIndex + 1
			let l:markpath =  "<" . string(fileIndex) . "> " 
			let l:markpath .= fnamemodify(mark.file, ":.")
			let prefile = mark.file
			call append(line("$")-1, l:markpath) 
			call add(s:listwinJumpMap,bookmarkIndex)
		endif

		let l:markline = "    " . string(mark.line)
		let l:markline = s:_format_align_left(l:markline,8,' ')
		let l:markline .= mark.text
		"let l:markline = string(mark.line)
		"let l:markline = s:_format_align_right(l:markline,6,' ') . "  "
		"let l:markline .= mark.text
		call append(line("$")-1, l:markline)
		call add(s:listwinJumpMap,bookmarkIndex)
		let bookmarkIndex = bookmarkIndex + 1
	endfor

	try
		" remove extra last line
		execute('normal! GV"_X')
	catch //
	endtry

	call cursor(1, 1)
endfunction


function! s:_format_align_left(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return a:text . l:fill
endfunction

function! s:_format_align_right(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return l:fill . a:text
endfunction


function! Vbookmark_jumpto()

	let group = s:vbookmark_groups[s:vbookmark_curGroupIndex]
	if empty(group.marks)
        echo "No bookmarks found"
		return
	endif

	let line = line(".") - 1
	let group.index = s:listwinJumpMap[line]

	let mark = group.marks[group.index]
	let find = 0
	call s:Vbookmark_adjustCurMarkIndex()
	try
		if (bufname(tabpagebuflist(mark.tabpage)[0]) == fnamemodify(mark.file, ":."))
			let find  = 1
			execute "normal!"  mark.tabpage . "gt"
			call s:Vbookmark_jumpSign(mark.id, mark.file)
		else 
			for i in range(tabpagenr('$'))
				if (bufname(tabpagebuflist(i+1)[0]) == fnamemodify(mark.file, ":."))
					let find  = 1
					execute "normal!"  i+1 . "gt"
					call s:Vbookmark_jumpSign(mark.id, mark.file)
					break
				endif
			endfor
		endif
		if find == 0
			execute("tabedit " .  mark.file)
			call s:Vbookmark_refreshSign(mark.file)
			call s:Vbookmark_jumpSign(mark.id, mark.file)
		endif
	catch
		if !filereadable(mark.file)
			call remove(group.marks, group.index)
			call s:Vbookmark_adjustCurMarkIndex()
			call s:Vbookmark_jumpBookmark(a:method)
			return
		endif
		execute("tabedit " .  mark.file)
		call s:Vbookmark_refreshSign(mark.file)
		call s:Vbookmark_jumpSign(mark.id, mark.file)
	endtry
endfunction

function! s:Vbookmark_clearAllBookmark()
	call s:Vbookmark_unplaceAllSign()
	call s:Vbookmark_initVariables()
endfunction

function! s:Vbookmark_addGroup(name)
	call add(s:vbookmark_groups, {'name': a:name, 'marks': [], 'index': -1})
	return len(s:vbookmark_groups) - 1
endfunction

function! s:Vbookmark_removeGroup(name)
	if len(s:vbookmark_groups) <= 1
        echo "Cann't remove the last bookmark group"
		return
	endif

	let curGroupName = s:vbookmark_groups[s:vbookmark_curGroupIndex].name
	if curGroupName =~ '^' . a:name
		call s:Vbookmark_unplaceAllSign()
		call remove(s:vbookmark_groups, s:vbookmark_curGroupIndex)
		call s:Vbookmark_adjustCurGroupIndex()
		call s:Vbookmark_placeAllSign()
		echo 'Remove the current bookmark group ' . curGroupName
			\ . '. Open the bookmark group ' . s:vbookmark_groups[s:vbookmark_curGroupIndex].name
		return
	endif

	let i = 0
	let size = len(s:vbookmark_groups)
	while i < size
		let group = s:vbookmark_groups[i]
		if group.name =~ '^' . a:name
			call remove(s:vbookmark_groups, i)
			if i < s:vbookmark_curGroupIndex
				let s:vbookmark_curGroupIndex -= 1
			endif
			echo 'Remove the bookmark group ' . group.name
			return
		endif
		let i += 1
	endwhile

	echo 'No bookmark group ' . a:name . ' found'
endfunction

function! s:Vbookmark_openGroup(name)
	if s:vbookmark_groups[s:vbookmark_curGroupIndex].name =~ '^' . a:name
		return 1
	endif

	let i = 0
	let size = len(s:vbookmark_groups)
	while i < size
		let group = s:vbookmark_groups[i]
		if group.name =~ '^' . a:name
			call s:Vbookmark_unplaceAllSign()
			let s:vbookmark_curGroupIndex = i
			call s:Vbookmark_placeAllSign()
			echo 'Open the bookmark group ' . group.name
			return 1
		endif
		let i += 1
	endwhile
	return 0
endfunction

function! s:Vbookmark_listGroup()
	let i = 0
	let size = len(s:vbookmark_groups)
	while i < size
		let output = '  '
		if i == s:vbookmark_curGroupIndex
			let output = '* '
		endif
		let output .= s:vbookmark_groups[i].name
		echo output
		let i += 1
	endwhile
endfunction

function! s:Vbookmark_saveAllBookmark()
	if !exists('g:vbookmark_bookmarkSaveFile')
		return
	end
	let outputGroups = 'let g:__vbookmark_groups__ = ['
	for group in s:vbookmark_groups
		let outputGroups .= '{"name": "' . group.name . '", "index": ' . group.index . ', "marks": ['
		for mark in group.marks
			let outputGroups .= '{"id": ' . mark.id . ', "file": "' . escape(mark.file, ' \') . '", "line": ' . mark.line . ', "text": "' . mark.text . '", "tabpage": ' . mark.tabpage . '},'
		endfor
		let outputGroups .= ']},'
	endfor
	let outputGroups .= ']'
	let outputCurGroupIndex = "let g:__vbookmark_curGroupIndex__ = " . s:vbookmark_curGroupIndex
	call writefile([outputGroups, outputCurGroupIndex], g:vbookmark_bookmarkSaveFile)
endfunction
autocmd VimLeave * call s:Vbookmark_saveAllBookmark()

function! s:Vbookmark_loadAllBookmark()
	if !exists('g:vbookmark_bookmarkSaveFile') || !filereadable(g:vbookmark_bookmarkSaveFile)
		return
	end
	try
		exec 'source ' . g:vbookmark_bookmarkSaveFile
	catch
        echo "Bookmark save file is broken"
		return
	endtry
	if !exists('g:__vbookmark_groups__') || type(g:__vbookmark_groups__) != 3
		\ || !exists('g:__vbookmark_curGroupIndex__') || type(g:__vbookmark_curGroupIndex__) != 0
		echo "Bookmark save file is invalid"
		return
	end

	let s:vbookmark_groups = deepcopy(g:__vbookmark_groups__)
	let s:vbookmark_curGroupIndex = g:__vbookmark_curGroupIndex__
	call s:Vbookmark_placeAllSign()
	unlet g:__vbookmark_groups__
	unlet g:__vbookmark_curGroupIndex__
endfunction
autocmd VimEnter * call s:Vbookmark_loadAllBookmark()

call s:Vbookmark_initVariables()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:VbookmarkToggle()
	let line = line('.')
	let id = s:Vbookmark_getSignId(line)
	if id == -1
		call s:Vbookmark_setBookmark(line)
	else
		call s:Vbookmark_unsetBookmark(id)
	endif
endfunction

function! s:VbookmarkNext()
	call s:Vbookmark_jumpBookmark('next')
endfunction

function! s:VbookmarkPrevious()
	call s:Vbookmark_jumpBookmark('prev')
endfunction

function! s:VbookmarkNextInFile()
	call s:Vbookmark_jumpBookmark('filenext')
endfunction

function! s:VbookmarkPreviousInFile()
	call s:Vbookmark_jumpBookmark('fileprev')
endfunction

function! s:VbookmarkClearAll()
	call s:Vbookmark_clearAllBookmark()
endfunction

function! s:VbookmarkListAll()
	call s:Vbookmark_listAllBookmark()
endfunction

function! s:VbookmarkGroup(name)
	if a:name == ''
		call s:Vbookmark_listGroup()
	elseif !s:Vbookmark_openGroup(a:name)
		call s:Vbookmark_unplaceAllSign()
		let s:vbookmark_curGroupIndex = s:Vbookmark_addGroup(a:name)
		echo 'Add a new bookmark group ' . a:name
	endif
endfunction

function! s:VbookmarkGroupRemove(name)
	let name = a:name
	if name == ''
		let name = s:vbookmark_groups[s:vbookmark_curGroupIndex].name
	endif
	call s:Vbookmark_removeGroup(name)
endfunction

if !exists(':VbookmarkToggle')
	command -nargs=0 VbookmarkToggle :call s:VbookmarkToggle()
endif

if !exists(':VbookmarkNext')
	command -nargs=0 VbookmarkNext :call s:VbookmarkNext()
endif

if !exists(':VbookmarkPrevious')
	command -nargs=0 VbookmarkPrevious :call s:VbookmarkPrevious()
endif

if !exists(':VbookmarkNextInFile')
	command -nargs=0 VbookmarkNextInFile :call s:VbookmarkNextInFile()
endif

if !exists(':VbookmarkPreviousInFile')
	command -nargs=0 VbookmarkPreviousInFile :call s:VbookmarkPreviousInFile()
endif

if !exists(':VbookmarkClearAll')
	command -nargs=0 VbookmarkClearAll :call s:VbookmarkClearAll()
endif

if !exists(':VbookmarkListAll')
	command -nargs=0 VbookmarkListAll :call s:VbookmarkListAll()
endif

if !exists(':VbookmarkGroup')
	command -nargs=? VbookmarkGroup :call s:VbookmarkGroup(<q-args>)
endif

if !exists(':VbookmarkGroupRemove')
	command -nargs=? VbookmarkGroupRemove :call s:VbookmarkGroupRemove(<q-args>)
endif

if !exists('g:vbookmark_disableMapping')
	nnoremap <silent> mm :VbookmarkToggle<CR>
	nnoremap <silent> mn :VbookmarkNext<CR>
	nnoremap <silent> mp :VbookmarkPrevious<CR>
	nnoremap <silent> mfn :VbookmarkNextInFile<CR>
	nnoremap <silent> mfp :VbookmarkPreviousInFile<CR>
	nnoremap <silent> ma :VbookmarkClearAll<CR>
endif

let &cpo = s:savedCpo
