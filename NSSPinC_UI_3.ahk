; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: NSSPinC_UI_3.ahk - Chache GUI management.
; ----------------------------------------------------------------------------------------------------------------------

3GUISHOW:
    Gui, 3: Destroy
    Gui, 3:+Owner1 -SysMenu
    Gui, 3: Margin, 5, 5
    
    Gui, 3: Add, Text,     x5 y+5, Wget Parameters:
    Gui, 3: Add, Edit,     w600 r5 y+5 v3EDIT_A Disabled, % objPinCacheMngr.GetCacheParameters(objSelected)
    Gui, 3: Add, Checkbox, w60 h22 x+-230 y+5 v3CBOX_A g3OVERRIDE, Override
    Gui, 3: Add, Button,   w80 h22 x+5 v3BTN_A g3STARTCACHING, Start
    Gui, 3: Add, Button,   w80 h22 x+5 g3GUICLOSE, Close
    
    Gui, 3: Show, AutoSize, % SCRIPTNAME " - " objSelected.hash
    Gui, 1:+Disabled
    Return
;3GUISHOW

3GUICLOSE:
    Gui, 1:-Disabled
    Gui, 3: Destroy
    Return
;3GUICLOSE

3OVERRIDE:
    GuiControlGet, bOverride,, 3CBOX_A
    GuiControl, % (bOverride) ? "Enable" : "Disable", 3EDIT_A ; *** TO DO - CHECK STRING ***
    Return
;3OVERRIDE

3STARTCACHING:
    Gui, 1:-Disabled
    Gui, 3: Submit
    Gui, 3: Destroy
    Gui, 1: Default
    RebuildMenu(), nSelected := GetSelected()
    sParam := ( 3CBOX_A && 3EDIT_A != objPinCacheMngr.GetCacheParameters(objSelected) ) ? 3EDIT_A : ""
    nExitCode := objPinCacheMngr.CacheSingleBookmark(objSelected, sParam)
    If ( !InStr("1234567-1-2", nExitCode) )
        ListViewUpdateItem(objSelected, nSelected)
    RebuildMenu()
    Return
;3STARTCACHING
