
" Purpose:      This Vim script adds a kind of `tabs' to the Vim.
" Maintainer:   Andrey Tarantsov <andreyvit@gmail.com>
" Copyright:    Free Software Foundation
" Version:      1.0    (released on 21.05.2005)
" 
" License:
"    this file should be considered in public domain; it is provided "AS IS",
"    without warranty of any kind
"
" Usage:
"    type \T to turn the tabs on or off
"    type \t to toggle whether the current buffer gets its own tab
"    type \1, \2, ..., \9 to switch between buffer tabs
"    type \0 to switch to the "other" tab
"    type \- to unload the current buffer and delete its tab
"    type :qa<CR> to exit from Vim (simple :q<CR> only closes current tab)
"
"    If you run Vim with a list of files on the command line and then type \T,
"    all those files will be loaded as tabs automatically.
"
" Installation:
"    Just put this file in your "Plugin" directory or load it manually via
"    "source" Vim command.
"
" Status:
"    This script is usable, but has lots of issues as I don't have time to
"    maintain it;
"
"    It works under Linux console and Win32 GUI; not tested under X GUI;
"    somewhy color does not work when using PuTTY SSH client.
"
"    It should be rather slow, but I did not notice it personally.
"
" Developers:
"    If there is someone wishing to maintain this script, just let me know :)
"
"    Some kind of `special tabs' is also implemented, activated by \\1, \\2
"    etc. It was included to use my "diary" script to write a local blog in
"    Vim, but was made general enough to support many kinds of special tabs.
"    I don't quite remember the details, just don't be suprised with the code.
"
"    Note that "Tabs line" is really an ordinary Vim window. So I have all
"    sorts of headache to keep it one line high and not to allow the user to
"    switch into it.
"    
" Ideas:
"    * make presentation more customizable, especially allow hiding the clock
"    * fix tabs coloring (highlighting) bugs
"    * make other features deactivatable
"               
" Changes:
"    2005-05-21      1st public release (after ab. half a year of private usage)


let s:tabs = -1

fun! <SID>ActivateTabs()
  let s:ignore = s:ignore + 1
  let s:lastwin = winnr()
  wincmd p
  let s:altwin = winnr()
  let tabs = bufnr("file-tabs")
  if tabs != -1
    wincmd b
    if bufnr("%") != tabs
      exec "bwipeout " . tabs
      let tabs = -1
    endif
  endif
  if tabs == -1
    set laststatus=0
    bot new
    set noswapfile
    file file-tabs
    set buftype=nofile
    let tabs = bufnr("%")
    syn match FileTabsAll /./
    syn match FileTabsActive /\[[^]]\+\]/
    syn match FileTabsNo / \d\+:/
    syn match FileTabsTime / \d\+:\d\+$/
  endif
  " check to see if it's the only window
  if bufwinnr(tabs) == 1 && winbufnr(2) == -1
  else
    resize 1 "just in case...
  endif
  let s:tabwin = tabs
  let s:ignore = s:ignore - 1
endfun

fun! <SID>DeactivateTabs()
  if s:lastwin == 0
    echo "OOPS"
  endif
  exec s:altwin . "wincmd w"
  exec s:lastwin . "wincmd w"
  "unlet s:altwin
  "unlet s:lastwin
endfun

fun! <SID>GetTabName(buf, try)
  let s = bufname(a:buf)
  if s == ""
    let s = "*new*"
  else
    let s = fnamemodify(s, ":~:.")
    if a:try == 2 && strlen(s) > 15
      let s1 = s
      while strlen(s1) >= 10
        let s1 = fnamemodify(s1, ":h")
      endwhile
      if s1 != ""
        let s2 = fnamemodify(s, ":h:t") . "/" .                 fnamemodify(s, ":t")
        if strlen(s2) >= 10
          let s2 = fnamemodify(s, ":t")
        endif

        let s = s1 . "/*/" . s2
      endif
    elseif a:try >= 3 && strlen(s) > 10
      let s1 = s
      while strlen(s1) >= 7
        let s1 = fnamemodify(s1, ":h")
      endwhile
      if s1 != ""
        let s2 = fnamemodify(s, ":h:t") . "/" .                 fnamemodify(s, ":t")
        if strlen(s2) >= 7
          let s2 = fnamemodify(s, ":t")
        endif

        let s = s1 . "/*/" . s2
      endif
    endif
    if a:try >= 4 && s[0] == "/"
      let s = "/" . fnamemodify(s, ":t")
    elseif a:try >= 5 && s[0] == "~"
      let s = "~" . fnamemodify(s, ":t")
    elseif a:try >= 6
      let s = fnamemodify(s, ":t")
    endif
  endif
  return s
endfun

fun! <SID>DecorateTabName(name, buf)
  if a:buf == s:curbuf
    return "[" . a:name . "]"
  else
    return " " . a:name . " "
  endif
endfun

fun! <SID>UpdateTabs()
  if s:ignore > 0
    return
  endif
  let s:curbuf = bufnr("%")
  let s:tabwin = bufnr("file-tabs")
  
  " load the previous meaning of <<other tab>>, in case
  " it should be discarded when a real tab pointing to the
  " same buffer appears
  let tab0 = getbufvar(s:tabwin, "thetab-0")

  " <<special tabs>>
  " FIXME: add more
  let tab1 = getbufvar(s:tabwin, "thetab-s1")
  let tab2 = getbufvar(s:tabwin, "thetab-s2")
   
  " check if some of the tabs do not exist any more
  " FIXME: add more
  if bufexists(tab1) == 0
    let tab1 = 0
    call setbufvar(s:tabwin, "thetab-s1", 0)
  endif
  if bufexists(tab2) == 0
    let tab2 = 0
    call setbufvar(s:tabwin, "thetab-s2", 0)
  endif

  " format time
  let time = "  " . strftime("%H:%M")
  
  " find out which tabs we are to display
  let last = bufnr("$")
  let i = 1
  let c = 0
  let s:curtab = 0
  while i <= last
    if (bufloaded(i) || getbufvar(i,"&bufhidden") == "delete") && getbufvar(i, "tab-on") == 1 
      let skiptab = 0
      " special tabs should never display as ordinary ones
      " FIXME: add more
      if i == tab1
        let skiptab = 1
      elseif i == tab2
        let skiptab = 1
      endif
      if skiptab == 0
        let c = c + 1
        if i == s:curbuf
          let s:curtab = c
        endif
        if i == tab0
          let tab0 = 0
        endif
        call setbufvar(s:tabwin, "thetab-" . c, i)
      endif "skiptab
    endif "bufloaded
    let i = i + 1
  endwhile "i
  call setbufvar(s:tabwin, "thetab-n", c)

  " find out if the current tab is one of the special ones
  if s:curbuf == tab1
    let s:curtab = -1
  elseif s:curbuf == tab2
    let s:curtab = -2
  endif

  " special tabs are never displayed as <<other>> tab
  " FIXME: add more
  if tab0 == tab1 || tab0 == tab2
    let tab0 = 0
  endif

  if bufname(s:curbuf) == "file-tabs"
    " this is not a usual case, but we try to prevent endless loops
    " in case of disaster
    let s:curbuf = 0
  endif
  
  " set <<other>> tab to the current buffer if no real tab 
  " is active
  if s:curtab == 0 && s:curbuf != 0
    let tab0 = s:curbuf
    call setbufvar(s:tabwin, "thetab-0", tab0)
  elseif tab0 == 0
    call setbufvar(s:tabwin, "thetab-0", 0)
  endif

  if s:ignore > 0
    return
  endif

  call <SID>ActivateTabs()

  " format names of <<special tabs>>
  " FIXME: add more
  if tab1 != 0
    let tab1n = getbufvar(tab1, "tab-name")
    let tab1s = getbufvar(tab1, "tab-sname")
  endif
  if tab2 != 0
    let tab2n = getbufvar(tab2, "tab-name")
    let tab2s = getbufvar(tab2, "tab-sname")
  endif
  
  " now format the tab line
  let try = 1
  let wr = winwidth(0)
  let w = wr - strlen(time)
  while try != 0
    let ln = ""
    if try == 3
      let w = wr
      let time = ""
    endif
    " regular tabs
    let i = 1
    while i <= c
      let buf = getbufvar(s:tabwin, "thetab-" . i)
      let ln = ln . <SID>DecorateTabName((try > 5 ? "" : i . ":") . <SID>GetTabName(buf, try), buf)
      let i = i + 1
    endwhile
    " <<other>> tab
    if tab0 != 0
      let ln = ln . <SID>DecorateTabName(try > 2 ? "*o*" : "*other*", tab0)
    endif
    " FIXME: add more
    if tab1 != 0
      let ln = ln . <SID>DecorateTabName(try > 2 ? tab1s : tab1n, tab1)
    endif
    if tab2 != 0
      let ln = ln . <SID>DecorateTabName(try > 2 ? tab2s : tab2n, tab2)
    endif

    if strlen(ln) <= w || try > 10
      let try = 0
    else
      let try = try + 1
    endif
  endwhile

  while strlen(ln) < w
    let ln = ln . " "
  endwhile
  let ln = ln . time
  
  " let ln = ln . "  " . strftime("%H:%M:%S")
  call setline(1,ln)
  
  call <SID>DeactivateTabs()
  let s:ignore = 0
endfun

fun! <SID>ToggleTab()
  if s:tabons == 0
    call TabsOn ()
  endif
  if getbufvar("%", "tab-on") != 1
    call setbufvar("%", "tab-on", 1)
  else
    call setbufvar("%", "tab-on", 0)
  endif
  call <SID>UpdateTabs()
endfun

fun! <SID>CancelTabs()
  if bufnr("file-tabs") != -1
    bwipeout file-tabs
  endif
  augroup filetabs
    au!
  augroup END
endfun

fun! <SID>SwitchToBuf(buf)
  if bufwinnr(a:buf) == -1
    if winbufnr(2) != -1 || winbufnr(1) != -1 && bufname(winbufnr(1)) != "file-tabs"
      exec "buffer " . a:buf
    else
      exec "sbuffer " . a:buf
    endif
  else
    exec bufwinnr(a:buf) . "wincmd w"
  endif
endfun

fun! <SID>RemoveTab()
  call setbufvar("%", "tab-on", 0)
  quit
  " if this was the last window on the screen (besides TABS window),
  " WinEnter logic will automatically switch to another tab
endfun

fun! <SID>AddTab()
  let s:ignore = s:ignore + 1
  enew
  call setbufvar("%", "tab-on", 1)
  let s:ignore = s:ignore - 1
  call <SID>UpdateTabs()
endfun

" should switch to some other tab in case the current one became
" unavailable
fun! <SID>AnotherTab()
  " fetch the new tab list
  call <SID>UpdateTabs()
  let c = getbufvar("file-tabs", "thetab-n")
  let b = 0
  if c != 0
    let b = getbufvar("file-tabs", "thetab-1")
  endif
  echo "b = " . b
  if b == 0
    resize
    new
  else
    call <SID>SwitchToBuf(b)
  endif
endfunc

fun! <SID>OnWinLeave()
  if s:ignore > 0
    return
  endif
  let s:prevwin = winnr()
  let s:prevbuf = bufnr("%")
endfun

fun! <SID>OnWinEnter()
  if s:ignore > 0
    return
  endif
  let s:ignore = s:ignore + 1
  if bufname("%") == "file-tabs"
    " first, check to see if <<file-tabs>> is the only window left
    if winnr() == 1 && winbufnr(2) == -1
      " the last non-tabs window was closed
      " 
      " this is treated specially: if the user manually closed the last
      " window of a tab, he probably wants to remove that tab
      if bufloaded(s:prevbuf) && getbufvar(s:prevbuf,"tab-on") == 1
        call setbufvar(s:prevbuf,"tab-on",0)
      endif
      " need to switch to another tab
      call <SID>AnotherTab()
    else
      if s:prevwin == 1
        wincmd W
      else
        wincmd w
      endif
    endif
  endif
  let s:ignore = s:ignore - 1
  call <SID>UpdateTabs()
endfun

" once i've tried to introduce "tab-special" variable of the *tab*'s buffer,
" but it was of no use -- once the buffer is unloaded (like directory buffer
" does), the setting gets lost
fun! <SID>AddSpecialTab(buf)
  " FIXME: add more
  let tab1 = getbufvar(s:tabwin, "thetab-s1")
  let tab2 = getbufvar(s:tabwin, "thetab-s2")
  if a:buf == tab1 || a:buf == tab2
  elseif tab1 == 0
    call setbufvar(s:tabwin, "thetab-s1", a:buf)
  elseif tab2 == 0
  else
    echo "Cannot add special tab to " . bufname(buf) . " -- no more free tabs"
  endif
endfun

command! -nargs=1 AddSpecialTab call <SID>AddSpecialTab(<f-args>)

fun! <SID>GoDiary()
  let expr = system("diary -vi")
  exec expr
  call setbufvar("%", "tab-name", "*diary*")
  call setbufvar("%", "tab-sname", "*d*")
  call setbufvar("%", "tab-special", 1)
  call <SID>AddSpecialTab(bufnr("%"))
endfun

fun! <SID>GoDir()
endfun

fun! s:GoTab(i)
  let c = getbufvar(s:tabwin, "thetab-n")
  if a:i == 1000
    let b = getbufvar(s:tabwin, "thetab-0")
  elseif a:i > 1000
    let b = getbufvar(s:tabwin, "thetab-s" . (a:i-1000))
  elseif a:i > c
    return
  else
    let b = getbufvar(s:tabwin, "thetab-" . a:i)
  endif
  if b == 0
    return
  endif
  cal <SID>SwitchToBuf(b)
endfun

noremap <Plug>GoDiary :<C-U>call <SID>GoDiary()<CR>
noremap <Plug>GoTabOther :<C-U>call <SID>GoTab(1000)<CR>
noremap <Plug>GoTabS1 :<C-U>call <SID>GoTab(1001)<CR>
noremap <Plug>GoTabS2 :<C-U>call <SID>GoTab(1002)<CR>
noremap <Plug>GoTab1 :<C-U>call <SID>GoTab(1)<CR>
noremap <Plug>GoTab2 :<C-U>call <SID>GoTab(2)<CR>
noremap <Plug>GoTab3 :<C-U>call <SID>GoTab(3)<CR>
noremap <Plug>GoTab4 :<C-U>call <SID>GoTab(4)<CR>
noremap <Plug>GoTab5 :<C-U>call <SID>GoTab(5)<CR>
noremap <Plug>GoTab6 :<C-U>call <SID>GoTab(6)<CR>
noremap <Plug>GoTab7 :<C-U>call <SID>GoTab(7)<CR>
noremap <Plug>GoTab8 :<C-U>call <SID>GoTab(8)<CR>
noremap <Plug>GoTab9 :<C-U>call <SID>GoTab(9)<CR>
noremap <Plug>ToggleTab :<C-U>call <SID>ToggleTab()<CR>
noremap <Plug>RemoveTab :<C-U>call <SID>RemoveTab()<CR>
noremap <Plug>NewTab :<C-U>call <SID>AddTab()<CR>

map <Leader>D <Plug>GoDiary

let s:ignore = 0

command! -count=1 GoTab call <SID>GoTab(<count>)
command! SwitchTab call <SID>Tabify()

map <Leader>1 <Plug>GoTab1
map <Leader>2 <Plug>GoTab2
map <Leader>3 <Plug>GoTab3
map <Leader>4 <Plug>GoTab4
map <Leader>5 <Plug>GoTab5
map <Leader>6 <Plug>GoTab6
map <Leader>7 <Plug>GoTab7
map <Leader>8 <Plug>GoTab8
map <Leader>9 <Plug>GoTab9
map <Leader>0 <Plug>GoTabOther
map <Leader>t <Plug>ToggleTab
map <Leader>- <Plug>RemoveTab
map <Leader>\1 <Plug>GoTabS1
map <Leader>\2 <Plug>GoTabS2
map <Leader>n <Plug>NewTab

if bufnr("file-tabs") != -1
  bwipeout file-tabs
endif

let s:tabons = 0

fun! TabsOn()
  let s:tabons = s:tabons + 1
  augroup filetabs
    au!
    au CursorHold * call <SID>UpdateTabs()
    au WinEnter * call <SID>OnWinEnter()
    au WinLeave * call <SID>OnWinLeave()
    au BufEnter * call <SID>OnWinEnter()
    au BufFilePost * call <SID>UpdateTabs()
    "au BufLeave * call <SID>OnWinLeave()
  augroup END
  call <SID>UpdateTabs()
  let s:tabson = 1
  if s:tabons == 1 && argc() > 0
    let i = 0
    while i < argc()
      let b = argv(i)
      exec "edit " . b
      call setbufvar(b, "tab-on", 1)
      let i = i + 1
    endwhile
    exec "edit " . argv(0)

    hi FileTabsActive ctermfg=red ctermbg=yellow cterm=bold guifg=red guibg=yellow gui=bold
    hi FileTabsAll ctermbg=blue guibg=blue
    hi FileTabsNo ctermbg=blue ctermfg=red guibg=blue guifg=red
    hi FileTabsTime ctermbg=blue ctermfg=cyan cterm=NONE guibg=blue guifg=cyan gui=NONE
  endif
endfun

fun! TabsOff()
  augroup filetabs
    au!
  augroup END
  bwipeout file-tabs
  let s:tabson = 0
endfun

fun! <SID>TabsToggle()
  if s:tabson == 0
    call TabsOn()
  else
    call TabsOff()
  endif
endfun

let s:tabson = 0

noremap <Plug>TabsToggle :<C-U>call <SID>TabsToggle()<CR>

map <Leader>T <Plug>TabsToggle
