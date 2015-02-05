; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: NSSPinC_UI_2.ahk - Bookmark GUI management.
; ----------------------------------------------------------------------------------------------------------------------

2GUISHOW:
    Gui, 2: Destroy
    Gui, 2:+LastFound +Resize -0x10000 +Hwnd2GUI_HWND
    Gui, 2: Margin, 5, 5

    Gui, 2: Add, Text,   w60, Title:
    Gui, 2: Add, Edit,   w%WIDTH_2% r1 x+5 v2EDIT_A, % objSelected.description
    Gui, 2: Add, Text,   w60 x5 y+5, URL:
    Gui, 2: Add, Edit,   w%WIDTH_2% r1 x+5 v2EDIT_B, % objSelected.href
    Gui, 2: Add, Text,   w60 x5 y+5, Tags:
    Gui, 2: Add, Edit,   w%WIDTH_2% r1 x+5 v2EDIT_C, % objSelected.tag
    Gui, 2: Add, Text,   w60 x5 y+5, Description:
    Gui, 2: Add, Edit,   w%WIDTH_2% h%HEIGHT_2% x+5 v2EDIT_D hwnd2EDIT_D_HND, % objSelected.extended
    Gui, 2: Add, Button, w80 h22 x+-80 y+5 v2BTN_A g2GUICLOSE Default, &Close
    Gui, 2: Font, s6

    nIcon  := (objSelected.shared != "no")
           ?  (FileExist(CACHE_DIR "\" objSelected.hash)) ? 5 : 4
           :  (FileExist(CACHE_DIR "\" objSelected.hash)) ? 7 : 6
    sLabel := ((objSelected.shared != "no") ? "Public - " : "Private - ")
           .  ((FileExist(CACHE_DIR "\" objSelected.hash)) ? "Cached" : "Not Cached")

    Gui, 2: Add, Picture, w16 h-1 x5 y+-16 v2PIC_A AltSubmit, %RESOURCES_DIR%\icon_%nIcon%.ico
    Gui, 2: Add, Text,    x+2 y+-12 v2TEXT_A, %sLabel%

    Gui, 2: Font
    Gui, 2: Show, AutoSize x%POSX_2% y%POSY_2%, % SCRIPTNAME " - " objSelected.hash
    Postmessage, 0x00B1, 0, 0, 2EDIT_A, ahk_id %2GUI_HWND% ; Remove selection from edit field (put cursor on 1st char).
    GuiControl, 2: Focus, 2BTN_A
    Return
;2GUISHOW

2GUICLOSE:
    ControlGetPos,,, WIDTH_2, HEIGHT_2,, ahk_id %2EDIT_D_HND%
    WinGetPos, POSX_2, POSY_2,,, ahk_id %2GUI_HWND%
    Gui, 2: Destroy
    Return
;2GUICLOSE

2GUISIZE:
    AnchorL("2EDIT_A", "w",   true), AnchorL("2EDIT_B", "w", true), AnchorL("2EDIT_C", "w", true)
  , AnchorL("2EDIT_D", "w h", true), AnchorL("2PIC_A",  "y", true), AnchorL("2TEXT_A", "y", true)
  , AnchorL("2BTN_A",  "x y", true)
    Return
;2GUISIZE
