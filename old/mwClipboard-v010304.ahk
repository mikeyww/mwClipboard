version := '1.3.5'

/* mwClipboard ---------------------------------------------------------------------------------------------
This program provides a simple clipboard manager.
A hotkey displays a list of clips. The user can then select one or more to paste.
For additional details, see the helpTextArr.
Key features:
• Fast and easy to use
• Multiple clips can be selected and pasted
• Selected clips are pasted in reverse order, reflecting the order of clipping
• Full text of all selected clips is displayed in an edit control, shown as the clips will be pasted
• Clips selected to be pasted will populate the clipboard
• The first or second clip can be sent (optionally) without affecting the clipboard
• Clips are saved in a plain text file
• A sound is played when the clipboard changes
• The GUI of clips can be resized
• A ListView control for clips enables using the keyboard to jump directly to a clip
• The ListView can be reset (cleared) without affecting the text file of clips
• For repeated pasting, the main GUI can be set to be redisplayed after pasting clips
• Clips can be added manually via an input box
• Right-clicking an item in the list will copy it to the clipboard
• A menu option will open the text file of clips for editing, viewing, or searching
• A simple notepad is included as a temporary editing area for working with text
• The entire program consists of one portable file of less than 1 MB
By mikeyww in U.S.A. • For AutoHotkey version 2.0.16
20 Feb 2026 (v1.3.5) : Updated: AutoHotkey to version 2.0.20
18 Dec 2025 (v1.3.4) : Added:   Tray menu option to reload the script
                       Changed: Increased delay for setting on top the window to add a clip manually
                       Changed: Sound will not play if clipboard is cleared
                       Changed: Send mode is now Event rather than Input
27 Jan 2025 (v1.3.3) : Added:   Notepad option to replace notepad contents with clipboard contents
25 Jan 2025 (v1.3.2) : Changed: Adding a clip manually will not display the clips list
                       Updated: AutoHotkey to version 2.0.19
10 Nov 2024 (v1.3.1) : Added  : For duplicate clips: Try, and DllCall('GetOpenClipboardWindow') before checking
                       Changed: Copy non-text as well as text
                       Changed: Notepad's CutD shortcut key from backtick to F6
15 Jul 2024 (v1.2) :   Added  : GUI title adds "Administrator" suffix when the script is running as admin
                       Added  : Flag for restoring the original clip to the clipboard after pasting
                       Fixed  : F12 does not activate notepad when it is minimized
                       Changed: Increased sleep before and after pasting if mwClipboard is set to "top"
                       Changed: Updated icon; added separate icon for notepad GUI
02 Jul 2024 (v1.1) :   Updated: documentation
09 Jun 2024 (v1.0) :   Initial release
https://github.com/mikeyww/mwClipboard/
https://www.autohotkey.com/boards/viewtopic.php?f=83&t=131119
AHK 2.0.18 fixed A_Clipboard silently exiting when GetClipboardData returns NULL.
AHK 2.0.19 fixed certain issues with modifiers, dialogs, key-up suppression, and loading of icons.
------------------------------------------------------------------------------------------------------------
WINDOWS CLIPBOARD HISTORY FEATURE:
Disabling the Windows clipboard history may be desirable (but is not required).
To disable clipboard history for all users:
 [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System]
 "AllowClipboardHistory"=dword:00000000
To disable clipboard history for the current user:
 [HKEY_CURRENT_USER\Software\Microsoft\Clipboard]
 "EnableClipboardHistory"=dword:00000000
To enable clipboard history for all users:
 [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System]
 "AllowClipboardHistory"=-
To enable clipboard history for the current user:
 [HKEY_CURRENT_USER\Software\Microsoft\Clipboard]
 "EnableClipboardHistory"=dword:00000001
------------------------------------------------------------------------------------------------------------
*/
#Requires AutoHotkey 2
#SingleInstance Ignore                                    ; Running a modification may first require manually
                                                          ;  exiting the running script
; Constants
T            := ' `t'                                     ; Used in defining the menu bar
CRLF         := '`r`n'
ISGUI        := ' ahk_class AutoHotkeyGUI'                ; Used to detect whether a GUI is visible
URL          := 'https://github.com/mikeyww/mwClipboard/' ; mwClipboard Web site

; ==========================================================================================================
; Variables for user to configure

; Tray icon
; https://github.com/free-icons/free-icons
; Updated fill colors
icon := Map(
   'program', 'clipboard-list-check.ico'
 , 'notepad', 'notebook.ico'
)

; Global hotkeys
showHK       := '^!0'                                     ; Hotkey to show main GUI
addClipHK    := '^!+0'                                    ; Hotkey to add clip manually
plainHK      := '^!9'                                     ; Hotkey to send clipboard as plain text
secondHK     := '^+9'                                     ; Hotkey to send the second clip as plain text
notepadHK    := '^+F12'                                   ; Hotkey for simple notepad to work with text
notePasteHK  := '^!+F12'                                  ; Hotkey to set clipboard and populate notepad

; Paths for clips files
clipsDir     := 'd:\noBackup'                             ; Directory for the clips files;
                                                          ;  if not found, MyDocuments will be used
clips        := 'clips.txt'                               ; All text clips are saved in this file
clipsOld     := 'clips-old.txt'                           ; Backup file saved upon exiting the program

; Sounds
soundDir      := 'd:\mwsounds'                               ; Directory of audio files
question      := soundDir '\UtopiaQuestion.wav'              ; Sound to play before confirmation dialog
useQuestion   := FileExist(question)                         ; Play sound when confirming ListView reset
If !useAudio  := FileExist(audio := soundDir '\TYPEKEY.wav') ; Play sound when clipboard changes
 If !useAudio := FileExist(audio := 'TYPEKEY.wav')
  useAudio    := FileExist(audio := A_WinDir '\Media\Windows Pop-up Blocked.wav')

; Colors
bkg          := 'F0F0F0'                                  ; ListView background color
back         := ['FFFF9E', 'FFAD99']                      ; Color of main GUI margins [Not on top, On top]

; Sizing
width        := A_ScreenWidth / 3                         ; ListView width for main GUI
rows         := 20                                        ; ListView number of rows for main GUI
editRows     := 7                                         ; Number of rows for the main GUI's edit control
offset       := 10                                        ; GUI's distance from right screen edge
fontSize     := 10                                        ; Font size for ListView of main GUI
between      := 15                                  ; Space between ListView and edit control with full text

; Text
GUItitle     := 'mwClipboard'                             ; Title of the main GUI
              . (A_IsAdmin ? ' - Administrator' : '')     ; Add suffix when script is running as admin
resetItem    := '&Reset' T 'F5'                           ; Menu item name for resetting the ListView
showItem     := 'Show clips'                              ; Caption (menu item name) for tray menu item

restoreClip  := False                                     ; Restore original clip to clipboard after pasting
; restoreClip  := True

; Notepad
note         := {x: 25, y: 100, w: 350, h: 670}           ; Notepad's initial position & dimensions
noteColor    := 'FFFF9E'                                  ; Notepad's color

; ==========================================================================================================
; Other variables

goHome       := True                                      ; Whether HOME key will be sent after GUI is shown
top          := False                                     ; Whether GUI is redisplayed after pasting selected clips
aboutStr     := 'mwClipboard'                                                        '`n`n'
              . 'Version ' version                                                   '`n`n'
              . 'AutoHotkey version: ' A_AhkVersion                                  '`n`n'
              . 'Process: '            A_AhkPath                                     '`n`n'
              . 'Icons with updated fill:`nhttps://github.com/free-icons/free-icons' '`n`n'
              . 'Copyright 2024-2026 mikeyww (from AutoHotkey forum)'                '`n`n'
              . 'https://github.com/mikeyww/mwClipboard/'
(!DirExist(clipsDir)) && clipsDir := A_MyDocuments        ; Use My Documents directory if this directory is missing
clips        := clipsDir '\' clips                        ; Text file of clips
clipsOld     := clipsDir '\' clipsOld                     ; Older backup file of clips
helpText     := Map()                                     ; Used to set the help GUI's edit control
notehelpText := Map()                                     ; Used to set the help GUI's edit control

; One-line (fat-arrow) functions
setBackColor := (top) => g.BackColor := back[top + 1]     ; Set color for GUI margins
show         := (*)   => (showGUI(g), homey(goHome))      ; Show GUI; called by hotkey and tray icon
setIcon      := (type) => (FileExist(icon[type]) && TraySetIcon(icon[type]))

; Text for the help GUI
helpTextArr := [
   ['Introduction'
    , 'mwClipboard is a simple clipboard manager.'                                       '`n`n'
    . 'Each text clip will be added to the top of a list of clips that can be displayed'
    . ' via hotkey.'                                                                     '`n`n'
    . 'Full text of selected clips is displayed in an edit control at the bottom'
    . ' of the main window.'                                                             '`n`n'
    . 'One or more clips can be selected. Right-clicking an item in the list will'
    . ' copy it to the clipboard.'                                                       '`n`n'
    . 'The user can press ENTER to paste all selected clips. '
    . 'The user can double-click on one clip to select and paste it.'                    '`n`n'
    . 'Upon ENTER or double-click, the selection will populate the clipboard,'
    . ' which is then pasted.'                                                           '`n`n'
    . 'If multiple clips are selected, they will be pasted in reverse order,'
    . ' reflecting the actual order of clipping.'                                        '`n`n'
    . 'Additional hotkeys can be used to send the first or second clip as plain text,'
    . ' without altering the clipboard.'                                                 '`n`n'
    . 'A simple notepad enables working with text. '
    . 'All text clips are saved in a plain text file. Exiting mwClipboard recycles'
    . ' a clips backup file if present, and moves current clips to the backup file'
    . ' by renaming the clips file.'                                                     '`n`n'
    . 'A sound is played whenever the clipboard changes.'
   ]
 , ['Ex'   , 'EXit this program']
 , ['Add'  , 'Prompt the user to enter text that will then populate'
           . ' the clipboard and the display.`n`n'
           . 'This menu option can be selected by a local or global hotkey.'
   ]
 , ['Ed'   , 'Open the clips file for EDiting, viewing, or searching in the default text editor.']
 , ['Reset', 'Clear all clips from the display. The clips file will not be altered.']
 , ['Top'  , 'Make the clips window reappear after pasting a selection,'
           . ' so that additional clips can be pasted quickly. This is a toggle.']
 , ['Keys' , 'Display a listing of the global hotkeys.']
 , ['Pad'  , 'Populate the notepad with the selected clips.']
 , ['About', aboutStr]
]
For arr in helpTextArr
 helpText[arr[1]] := arr[2]                               ; Help text, by topic

notehelpTextArr := [
   ['Introduction', 'The notepad is a simple editing area for working with text.']
 , ['Reset'       , 'Clear the notepad.']
 , ['LB'          , 'Add a line break to each line break.']
 , ['Cut'         , 'Cut the notepad`'s current line as seen in the GUI.']
 , ['Replace'     , 'Replace notepad contents with clipboard contents.']
 , ['CutD'        , 'Cut the notepad`'s current line as seen in the GUI, and deactivate the notepad.']
]
For arr in notehelpTextArr
 notehelpText[arr[1]] := arr[2]                           ; Help text, by topic

; ==========================================================================================================
; Set send mode
SendMode('Event'), SetKeyDelay(-1, 0)
; ==========================================================================================================
; GUIs and menus

; Menu bar for the main GUI
m := MenuBar()                                                        ; Create a menu for the GUI
m.Add 'E&x'             , (*) => ExitApp()                            ; Exit the script
m.Add '&Add'     T 'F2' , addManual                                   ; F2  = Manually add item to clipboard
m.Add '&Ed'      T 'F4' , edit                                        ; F4  = Edit the text file of clips
m.Add resetItem         , reset                                       ; F5  = Clear all clips
m.Disable resetItem
m.Add '&Top'     T 'F10', topper                                      ; F10 = "On top" toggle
m.Add '&Keys'    T 'F11', (*) => (keys_LV.Modify(0, '-Focus -Select') ; F11 = Show list of hotkeys
                                , keys.Show())
m.Add '&Pad'     T 'F12', (*) => notepadSet(getRevText())             ; F12 = Selected clips => Notepad
m.Add '&Help'    T 'F1' , helpShow                                    ; F1  = Show the help GUI
m.Add 'A&b'             , about

; Main GUI of clips; includes ListView and an edit control showing full text of selected clips
setIcon('program')
g  := Gui('+AlwaysOnTop +Resize -DPIScale', GUItitle)
g.SetFont('s' fontSize), setBackColor(top)                                ; Color for GUI margins
LV := g.AddListView('Background' bkg ' -Hdr w' width ' r' rows, ['Clip']) ; Add the ListView
g.SetFont 's9'
ed := g.AddEdit('wp r' editRows ' y+' between)                            ; Add the edit control
g.AddButton('x0 y0 Hidden Default', 'OK')                                 ; Add hidden button for ENTER
 .OnEvent('Click', (btn, info) => (btn.Gui.FocusedCtrl = LV && LV.GetCount('S')) && paste(ed.Text))
g.MenuBar := m                                                            ; Attach the menu to the GUI

; Additional events
g.OnEvent  'Escape'     , (gui) => gui.Submit()                                  ; User pressed ESC
g.OnEvent  'Size'       , gui_Size                                               ; GUI was resized
LV.OnEvent 'DoubleClick', (LV, item) => paste(LV.GetText(item))                  ; A clip was double-clicked
LV.OnEvent 'ItemFocus'  , (LV, item) => ed.Text := getRevText()                  ; Update GUI's edit control
LV.OnEvent 'ContextMenu', (LV, item, isRightClick, x, y) => (item) && A_Clipboard := LV.GetText(item) ; Copy

; Tray icon & menu
A_IconTip := GUItitle '`nClick to see clips'
A_TrayMenu.Add                       ; Add a separator
A_TrayMenu.Add '&Reload', restart    ; Add item to tray menu
A_TrayMenu.Add showItem , show       ; Add item to tray menu
A_TrayMenu.Add 'A&bout' , about      ; Show the "about" dialog
A_TrayMenu.ClickCount := 1           ; Activate icon on one click
A_TrayMenu.Default    := showItem    ; Show GUI when tray icon is activated

; GUI for help
help := Gui('+AlwaysOnTop +Resize -DPIScale', 'Help for mwClipboard')
help.OnEvent 'Size', help_Size              ; When the help GUI is resized
help.SetFont 's10'
help.BackColor := 'AAFF99'
help.OnEvent 'Escape', (gui) => gui.Hide()
help_LV  := help.AddListView('NoSort -Multi w150 r10 Background' bkg, ['Topic'])
help_LV.OnEvent 'ItemFocus', help_ItemFocus ; When a ListView item is newly focused
For arr in helpTextArr
 help_LV.Add , arr[1]                       ; Add the help topic to the ListView
help_ed := help.AddEdit('ym r30 BackgroundWhite ReadOnly')

; GUI for displaying list of global hotkeys
keys := Gui('+AlwaysOnTop', 'Global hotkeys')
keys.SetFont 's12 Bold', 'Courier New'
keys.BackColor := '9ECBFF'
keys.OnEvent 'Escape', (gui) => gui.Hide()
keys_LV := keys.AddListView('w700 r6 Background' bkg, ['Hotkey', 'Description'])
keys_LV.Add , showHK     , 'Show main GUI'
keys_LV.Add , addClipHK  , 'Add clip manually'
keys_LV.Add , plainHK    , 'Send clipboard as plain text'
keys_LV.Add , secondHK   , 'Send second clip as plain text (does not change clipboard)'
keys_LV.Add , notepadHK  , 'Show simple notepad to work with text'
keys_LV.Add , notePasteHK, 'Populate notepad with text selection'
keys_LV.ModifyCol(1, '80 Center'), keys_LV.ModifyCol(2, 610)

; Menu bar for the notepad GUI
pad_m := MenuBar()
pad_m.Add '&Reset'   T 'F1', notepadReset
pad_m.Add '&LB'      T 'F2', notepadAddLineBreaks
pad_m.Add '&Cut'     T 'F3', cutLine
pad_m.Add 'R&eplace' T 'F4', notepadReplace
pad_m.Add 'Cut&D'    T 'F6', notepadCutLineAndDeactivate
pad_m.Add '&Help'          , notehelpShow

; GUI for displaying notepad to work with text
setIcon 'notepad'
pad := Gui('+AlwaysOnTop +Resize -DPIScale', 'Notepad')
pad.SetFont 's10'
pad.BackColor := 'C1C1C1'
pad_ed        := pad.AddEdit('w' note.w ' h' note.h ' Background' noteColor)
pad.MenuBar   := pad_m
pad.OnEvent 'Escape', (gui) => gui.Hide()
pad.OnEvent 'Size'  , notepad_Size ; When the notepad GUI is resized

; GUI for notepad help
notehelp := Gui('+AlwaysOnTop +Resize -DPIScale', 'Notepad help')
notehelp.OnEvent 'Size', notehelp_Size          ; When the notepad help GUI is resized
notehelp.SetFont 's10'
notehelp.BackColor := 'DFC9FF'
notehelp.OnEvent 'Escape', (gui) => gui.Hide()
notehelp_LV  := notehelp.AddListView('NoSort -Multi w150 r10 Background' bkg, ['Topic'])
notehelp_LV.OnEvent 'ItemFocus', notehelp_ItemFocus ; When a ListView item is newly focused
For arr in notehelpTextArr
 notehelp_LV.Add , arr[1]                           ; Add the help topic to the ListView
notehelp_ed := notehelp.AddEdit('w300 ym r15 BackgroundWhite ReadOnly')
setIcon('program')

; ==========================================================================================================
; Create global hotkeys

Hotkey showHK     , show
Hotkey addClipHK  , addManual
Hotkey notepadHK  , notepadShow
Hotkey notePasteHK, notePaste
Hotkey plainHK    , (ThisHotkey) =>  LV.GetCount()      && SendText(LV.GetText(1)) ; Send 1st item
Hotkey secondHK   , (ThisHotkey) => (LV.GetCount() > 1) && SendText(LV.GetText(2)) ; Send 2nd item
OnClipboardChange(clipChanged), OnExit(done)

; ==========================================================================================================
; Functions

clipChanged(dataType) {                           ; Clipboard was changed; add textclips to top of ListView
 static TEXT := 1
 ; If dataType != TEXT ; Text copied from Microsoft Excel does not have a text data type.
 If A_Clipboard != '' {
  (useAudio) && SoundPlay(audio)
  LV.Modify 0, '-Select'                          ; Deselect all rows
  LV.Insert 1, 'Focus Select', A_Clipboard        ; Insert clip as first row in the ListView
  m.Enable resetItem
  Global goHome := True                           ; Send HOME key when GUI is next displayed
  ed.Text := A_Clipboard                          ; Update the edit control with the clip's full text
  dupe    := False
  While DllCall('GetOpenClipboardWindow')
   Sleep 10
  Loop LV.GetCount()
   Try (A_Index > 1) && (LV.GetText(A_Index) = A_Clipboard) && LV.Delete(dupe := A_Index) ; Delete dupe if present
  Until dupe
  (dupe) || FileAppend(A_Clipboard CRLF, clips)   ; Save unique clips in a text file
 }
}

addManual(*) {                                                   ; Manually add an item to the clipboard
 static boxTitle := 'Copy to clipboard'
 static w := 500                                                 ; Width of input box
 g.GetPos &x                                                     ; Get GUI's x-position
 WinExist('Help for mwClipboard' ISGUI) && help.Hide()
 SetTimer () => (WinExist(boxTitle ' ahk_class #32770') && WinSetAlwaysOnTop()), -900
 ib := InputBox('Enter the text to copy.', boxTitle, 'h100 w' w)
 If ib.Result = 'OK' && ib.Value != ''
  A_Clipboard := ib.Value                                        ; Set the clipboard (triggers "clipChanged")
}

homey(trueFalse := True) {  ; Send HOME key to ListView
 ; If trueFalse {
 If trueFalse && WinExist(GUItitle ISGUI) {
  Sleep 50
  LV.Focus(), Send('{Home}')
 }
 Global goHome := False
}

showGUI(gui) {                              ; Called by "show" and "paste"
 gui.Show('Hide'), gui.GetPos(,, &w, &h)    ; Get GUI width
 gui.Show  'x'  A_ScreenWidth  - w - offset ; Right side of the screen
        . ' y' (A_ScreenHeight - h) / 2     ; Vertically centered
}

gui_Size(gui, minMax, w, h) {                                             ; Main GUI was resized
 w -= 2 * gui.MarginX                                                     ; New width of controls
 gui.GetClientPos(,,, &ch), ed.GetPos(,,, &eh)                            ; Get height of client & edit control
 ed.Move gui.MarginX, ch - gui.MarginY - eh, w                            ; Move the edit control
 LV.Move gui.MarginX, gui.MarginY, w, h -  2 * gui.MarginY - eh - between ; Adjust ListView's dimensions
 LV.ModifyCol 1, w - 5                                                    ; Adjust ListView's column width
}

getRevText() {                                      ; Get the text of selected clips in reverse order
 row := 0
 str := ''
 While row := LV.GetNext(row)                       ; Loop through selected rows
  str := LV.GetText(row) (str = '' ? '' : CRLF) str ; Reverse the order of clips
 Return str
}

paste(str) {                                        ; Populate and paste the clipboard
 g.Submit
 OnClipboardChange clipChanged, False               ; Temporarily disable the capture trigger
 If restoreClip
  clipSaved := ClipboardAll()
 (str != A_Clipboard) && A_Clipboard := str         ; Set clipboard to the output
 Sleep top ? 50 : 40
 Send '^v'                                          ; Paste the clip
 If restoreClip {
  Sleep 300
  A_Clipboard := clipSaved
  clipSaved   := ''
 }
 OnClipboardChange clipChanged
 If top
  Sleep(30), showGUI(g)                             ; If "on top", then show the GUI again
}

edit(itemName, itemPos, m) {    ; Open clips file for editing, viewing, or searching
 ; If clips file is not found, then use old clips file if it exists
 If fPath := FileExist(clips) ? clips : FileExist(clipsOld) ? clipsOld : ''
  Run fPath
}

topper(itemName, itemPos, m) {  ; F10 = Toggle "on-top" status to enable repeated pasting
 Global top ^= True
 setBackColor top
}

reset(itemName, itemPos, m) {   ; F5  = Clear all clips (does not alter clips file)
 (useQuestion) && SoundPlay(question)
 If 'OK' = MsgBox('All clips will be cleared.', 'Confirm', 'Icon? OC Default2') {
  LV.Delete                     ; Delete all clips from the ListView
  ed.Text := ''                 ; Reset the edit control
  m.Disable resetItem
 }
}

cutLine(*) {  ; Cut the current text line as seen in the GUI (not by CRLF)
 OnClipboardChange clipChanged, False     ; Temporarily disable the capture trigger
 A_Clipboard := ''
 Send '{Home}{Shift down}{End}{Right}{Shift up}^x'
 OnClipboardChange clipChanged
 If ClipWait(1)
  A_Clipboard := RTrim(A_Clipboard, CRLF) ; Strip the trailing CRLF
 Else MsgBox 'An error occurred while waiting for the clipboard.', 'Error', 'Icon!'
}

notepadAddLineBreaks(itemName, itemPos, m) {  ; Add a line break to each line break
 pad_ed.Text := RegExReplace(pad_ed.Text, '(\R)', '$1`r`n')
}

notepadShow(*) {         ; Show a simple notepad
 Static shown := False
 pad.Show shown ? '' : 'x' note.x ' y' note.y
 shown := True
}

notePaste(ThisHotkey) {  ; Populate the notepad with selected text
 A_Clipboard := ''
 Send '^c'                                                   ; Copy text to clipboard
 If ClipWait(1)
  notepadSet(RegExReplace(A_Clipboard, '[^\r]\K\n', CRLF)) ; Populate notepad with clipboard
 Else MsgBox 'An error occurred while waiting for the clipboard.', 'Error', 'Icon!'
}

notepadSet(str) {                               ; Populate & show the notepad
 If str != ''
  pad_ed.Text .= pad_ed.Text = '' ? str : CRLF str
 If WinExist('Notepad' ISGUI)
  WinActivate
 Else notepadShow
 pad_ed.Focus(), Send('^{End}')
}

notepadCutLineAndDeactivate(itemName, itemPos, m) {
 cutline
 pad.Hide(), pad.Show('NoActivate')
}

notepadReset(itemName, itemPos, m) {              ; Clear the notepad after copying its text to the clipboard
 A_Clipboard := pad_ed.Text
 pad_ed.Text := ''
}

notepadReplace(itemName, itemPos, m) {            ; Replace notepad contents with clipboard contents
 (pad_ed.Text = '') || A_Clipboard := pad_ed.Text
 Sleep 50
 If LV.GetCount() > 1
  A_Clipboard := pad_ed.Text := LV.GetText(2)
 pad_ed.Focus(), Send('^{End}')
}

notepad_Size(gui, minMax, w, h) {                          ; The notepad GUI was resized
 pad_ed.Move ,, w - 2 * gui.MarginX , h - 2 * gui.MarginY  ; Adjust edit control's dimensions
}

helpShow(itemName, itemPos, m) {                           ; Show the help GUI
 help_LV.Modify 1, 'Focus Select'                          ; Select the first topic
 help_ItemFocus help_LV, 1                                 ; Display corresponding text in edit control
 g.GetPos(, &y), g.GetClientPos(,,, &h)                    ; Get main GUI's y-position & client height
 help.Show 'x20 y' y ' w' 0.4 * A_ScreenWidth ' h' h + 30  ; Help GUI's height will match main GUI's height
 help_LV.Focus
}

help_ItemFocus(LV, item) {  ; Set the edit control's contents based on the newly selected item
 topic := LV.GetText(item)
 help_ed.Text := StrUpper(topic) StrReplace('`n`n' helpText[topic], '`n', CRLF)
}

help_Size(gui, minMax, w, h) {                            ; The help GUI was resized
 h -= 2 * gui.MarginY                                     ; New height of controls
 help_LV.GetPos ,, &LVwidth                               ; Get width of ListView
 help_ed.Move   ,, w - 2 * gui.MarginX - LVwidth - 15, h  ; Adjust edit control's dimensions
 help_ed.Redraw                                           ; Redraw edit control to account for GUI's new size
 help_LV.Move  ,,, h                                      ; Adjust ListView's height
}

notehelpShow(itemName, itemPos, m) {                      ; Show the help GUI
 Static shown := False
 notehelp_LV.Modify 1, 'Focus Select'                     ; Select the first topic
 notehelp_ItemFocus notehelp_LV, 1                        ; Display corresponding text in edit control
 notehelp.Show shown ? '' : 'x460'
 notehelp_LV.Focus
 shown := True
}

notehelp_ItemFocus(LV, item) {  ; Set the edit control's contents based on the newly selected item
 topic := LV.GetText(item)
 notehelp_ed.Text := StrUpper(topic) StrReplace('`n`n' notehelpText[topic], '`n', CRLF)
}

notehelp_Size(gui, minMax, w, h) {                           ; The help GUI was resized
 h -= 2 * gui.MarginY                                        ; New height of controls
 notehelp_LV.GetPos ,, &LVwidth                              ; Get width of ListView
 notehelp_ed.Move   ,, w - 2 * gui.MarginX - LVwidth - 15, h ; Adjust edit control's dimensions
 notehelp_ed.Redraw                                          ; Redraw edit control to account for GUI's new size
 notehelp_LV.Move  ,,, h                                     ; Adjust ListView's height
}

about(itemName, itemPos, m) { 
 If 'Yes' = MsgBox(aboutStr '`n`nVisit the Web site?', 'About mwClipboard', 'Iconi 262144 YNC Default2')
  Run url
}

restart(itemName, itemPos, m) {
 If 'Yes' = MsgBox('Reloading will lose current clips.`n`nContinue?', 'Confirm', 'YNC Default2 Icon?') {
  SoundBeep 1500
  g := Gui(, 'Status')
  g.SetFont 's20'
  g.BackColor := 'FFFF9E'
  g.AddText 'w230 Center', 'Reloading....'
  g.Show(), Sleep(1000), g.Destroy()
  Reload
 }
}

done(exitReason, exitCode) {                   ; Script is exiting, so rename the clips file (as backup)
 Static WS_EX_TOPMOST := 262144
 If FileExist(clips) {
  FileExist(clipsOld) && FileRecycle(clipsOld) ; Delete old clips file (might be permanent for network files)
  FileMove clips, clipsOld                     ; Rename clips file to old clips file
 }
 If exitReason = 'Close'                       ; Script was sent a WM_CLOSE or WM_QUIT message, had a critical error,
                                               ;  or is being closed in some other way
  MsgBox 'Exiting mwClipboard.', 'mwClipboard', 'Icon! ' WS_EX_TOPMOST
}