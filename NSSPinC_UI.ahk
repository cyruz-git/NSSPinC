; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: NSSPinC_UI.ahk - Main GUI and program logic.
; ----------------------------------------------------------------------------------------------------------------------

; ======================================================================================================================
; ===[ MENUS CREATION ]=================================================================================================
; ======================================================================================================================

; * TRAY MENU CREATION 
; * Tray menu is managed dinamically by the AHK_NOTIFYICON function to change 
; * menu items on the fly. Only the "Minimize" entry is added on start to 
; * allow the "double-click on tray icon to minimize" feature to work.

    OnMessage(0x0404, "AHK_NOTIFYICON") ; WM_USER + 4 = 0x0404
    Menu, Tray, NoStandard
    Menu, Tray, Add, Minimize, GUIMINTOGGLE
    Menu, Tray, Default, Minimize
    Menu, Tray, Click, 2
    Menu, Tray, Tip, %SCRIPTLINE%
If ( !A_IsCompiled)
    Menu, Tray, Icon, % RESOURCES_DIR "\icon_1.ico"

; * GUI MENU CREATION
; * Actually AutoHotkey doesn't provide a way to update Gui menu dinamically.

    Menu, FileMenu, Add, &Update Database, UPDATEDB
If ( CACHE_ENABLED )
{
    Menu, FileMenu, Add
    Menu, FileMenu, Add, Cache &New Bookmarks, CACHEDB
    Menu, FileMenu, Add, Cache &All Bookmarks, CACHEDB
    Menu, FileMenu, Add, &Stop Caching, CACHESTOP
    Menu, FileMenu, Disable, &Stop Caching
    Menu, FileMenu, Add
    Menu, FileMenu, Add, Cache &Maintenance, CACHEMAINT
}   
    Menu, FileMenu, Add
    Menu, FileMenu, Add, &Reload, GUIRELOAD
    Menu, FileMenu, Add, &Quit, GUICLOSEREALLY
    Menu, HelpMenu, Add, &Help, HELP
    Menu, HelpMenu, Add
    Menu, HelpMenu, Add, &About, ABOUT
    Menu, MenuBar,  Add, &File, :FileMenu
    Menu, MenuBar,  Add, &Help, :HelpMenu

; * CONTEXT MENU CREATION
; * Context menu doesn't need to be changed dinamically.
    
    Menu, Context, Add, View Item, VIEW
    Menu, Context, Add
    Menu, Context, Add, Open URL, OPENURL
    Menu, Context, Add, Copy URL, COPYURL
    Menu, Context, Add
    Menu, Context, Add, Check Web Archive, CHECKWEBARCHIVE
If ( WKHTML_PDF_ENABLED || WKHTML_IMG_ENABLED )
    Menu, Context, Add
If ( WKHTML_PDF_ENABLED )
    Menu, Context, Add, Save as PDF, SAVEAS
If ( WKHTML_IMG_ENABLED )
    Menu, Context, Add, Save as JPG, SAVEAS
If ( CACHE_ENABLED )
{
    Menu, Context, Add
    Menu, Context, Add, Open Cache, OPENCACHE
    Menu, Context, Add, Open Cache Dir, OPENCACHEDIR
    Menu, Context, Add
    Menu, Context, Add, Cache Selected, CACHESELECTED
}

; ======================================================================================================================
; ===[ MAIN UI CREATION ]===============================================================================================
; ======================================================================================================================

; Main GUI creation.
Gui, +LastFound +Resize +OwnDialogs +Hwnd1GUI_HWND
Gui, Margin, 5, 5
Gui, Add, ListView, w%WIDTH% h%HEIGHT% v1LIST_A gLISTEVENT hwnd1LIST_A_HND -Multi -LV0x10 Sort AltSubmit
                  , Description|Taglist|Index
Gui, Add, Edit,     % "w" (WIDTH - 170) " h22 x5 y+5 v1EDIT_A"
Gui, Add, Button,   w80 h22 x+5 v1BTN_B gSEARCHEDIT, &Search
Gui, Add, Button,   w80 h22 x+5 v1BTN_A gCLEAREDIT, Cl&ear
Gui, Add, Button,   gCATCHENTER Hidden Default, Open
Gui, Add, StatusBar
Gui, Menu, MenuBar
GuiControl, Focus, 1LIST_A
SB_SetParts(150)

; ImageList creation.
hImageList := IL_Create(RESOURCES_TOTAL)
Loop, %RESOURCES_TOTAL%
{
    If ( A_IsCompiled )
        adrBuf := UpdRes_LockResource(0, "RES\ICON_" A_Index ".ICO", 10, 0)
      , DllCall( "Comctl32.dll\ImageList_ReplaceIcon", Ptr,hImageList, Int,-1, Ptr,hIcon:=BinGet_Icon(adrBuf,16) )
      , DllCall( "CloseHandle", Ptr,hIcon )
    Else
        IL_Add(hImageList, RESOURCES_DIR "\icon_" A_Index ".ico")
}
LV_SetImageList(hImageList)

; Hide the Index column and set the width of the others.
LV_ModifyCol(3, 0)
If ( !AUTOHDR && COL1 != "" && COL2 != "" )
    LV_ModifyCol(1, COL1), LV_ModifyCol(2, COL2)

; Populate the ListView.
If ( IsObject(objPinDb) )
    SB_SetText(" Loading...")
  , ListViewUpdate(objPinDb, 1)
  , SB_SetText(" Done.")

bIsMinimized := 0
Gui, Show, AutoSize x%POSX% y%POSY%, %SCRIPTLINE%
WinSet, Redraw,, ahk_id %1GUI_HWND%

If ( FULLSCREEN )
    WinMaximize, ahk_id %1GUI_HWND%

If ( UPDATE_ON_START )
    SetTimer, UPDATEDBFORCE, -1000
Return

; ======================================================================================================================
; ===[ MAIN UI LABELS (ALPHABETICAL ORDER) ]============================================================================
; ======================================================================================================================

ABOUT:
    Gui, +OwnDialogs
    MsgBox, 0x40, %SCRIPTNAME%,
    ( LTrim
        %SCRIPTLINE% - %SCRIPTVERSION%
                
        Project:`thttps://github.com/cyruz-git/NSSPinC
        Forum:`thttp://ahkscript.org/boards/viewtopic.php?f=6&t=
        
        Copyright ©2015 - Ciro Principe (http://ciroprincipe.info)
    )
    Return
;ABOUT

CACHEDB:
    If ( !CheckMsgBox( SCRIPTNAME, "Are you sure you want to cache "
       . (( A_ThisMenuItem == "Cache &New Bookmarks" ) ? "NEW" : "ALL") " bookmarks?") )
        Return
CACHEDBFORCE:
    RebuildMenu()
    nRetVal := objPinCacheMngr.CacheDb(( A_ThisMenuItem == "Cache &All Bookmarks" ) ? 1 : 0)
    ListViewUpdate(objPinDb, 1)
    RebuildMenu()
    Return
;CACHEDBFORCE
;CACHEDB

CACHEMAINT:
    If ( !CheckMsgBox(SCRIPTNAME, "Are you sure you want to delete old cached files?") )
        Return
    RebuildMenu(), objPinCacheMngr.CacheMaintenance(), RebuildMenu()
    Return
;CACHEMAINT

CACHESELECTED:
    objSelected := objPinDb[GetSelected()]
    GoSub, 3GUISHOW
    Return
;CACHESELECTED

CACHESTOP:
    objPinCacheMngr.CacheStop()
    Return
;CACHESTOP

CATCHENTER:
    GuiControlGet, FocusedControl, FocusV
    If ( FocusedControl == "1LIST_A" && LV_GetNext(0) )
        GoSub, VIEW
    Else If ( FocusedControl == "1EDIT_A" )
        GoSub, SEARCHEDIT
    Return
;CATCHENTER

CHECKWEBARCHIVE:
    objSelected := objPinDb[GetSelected()]
    Run, % (BROWSER_CMDLINE) ? BROWSER_CMDLINE " " WEB_ARCHIVE_PFX objSelected.href 
                             : WEB_ARCHIVE_PFX objSelected.href
    Return
;CHECKWEBARCHIVE

CLEAREDIT:
    GuiControl,, 1EDIT_A
    ListViewUpdate(objPinDb, 1)
    Return
;CLEAREDIT

COPYURL:
    Clipboard := objPinDb[GetSelected()].href
    SB_SetText(" Copied.")
    Return
;COPYURL

DUMMY:
    FileInstall, res\icon_1.ico, DUMMY
    FileInstall, res\icon_2.ico, DUMMY
    FileInstall, res\icon_3.ico, DUMMY
    FileInstall, res\icon_4.ico, DUMMY
    FileInstall, res\icon_5.ico, DUMMY
    FileInstall, res\icon_6.ico, DUMMY
    FileInstall, res\icon_7.ico, DUMMY
    FileInstall, res\icon_8.ico, DUMMY
    Return
;DUMMY

GUICLOSE:
    IfEqual, MIN_ON_CLOSE, 1, GoSub, GUIMINTOGGLE
    Else GoSub, GUICLOSEREALLY
    Return
;GUICLOSE

GUICLOSEREALLY:
    ; Check if updating/caching before closing the program.
    If ( objPinDbHandler.UPDATE_RUNNING || objPinCacheMngr.CACHE_RUNNING )
        If ( !CheckMsgBox(SCRIPTNAME, "The program is updating/caching, are you sure you want to close?") )
            Return
    DetectHiddenWindows, On
    If ( SAVE_ON_CLOSE )
    {
        WinGet, FULLSCREEN, MinMax, ahk_id %1GUI_HWND%
        If ( FULLSCREEN )
            IniWrite, 1, %INI_FILENAME%, SETTINGS, FULLSCREEN
        Else
        {
            ControlGetPos,,, WIDTH, HEIGHT,, ahk_id %1LIST_A_HND%
            WinGetPos, POSX, POSY,,, ahk_id %1GUI_HWND%
            IniWrite, %WIDTH%,  %INI_FILENAME%, SETTINGS, WIDTH
            IniWrite, %HEIGHT%, %INI_FILENAME%, SETTINGS, HEIGHT
            IniWrite, %POSX%,   %INI_FILENAME%, SETTINGS, POSX
            IniWrite, %POSY%,   %INI_FILENAME%, SETTINGS, POSY
            IniWrite, 0,        %INI_FILENAME%, SETTINGS, FULLSCREEN
        }
        SendMessage, 0x1000+29, 0, 0, SysListView321, ahk_id %1GUI_HWND%
        IniWrite, % (ErrorLevel != "FAIL") ? ErrorLevel : "", %INI_FILENAME%, SETTINGS, COL1
        SendMessage, 0x1000+29, 1, 0, SysListView321, ahk_id %1GUI_HWND%
        IniWrite, % (ErrorLevel != "FAIL") ? ErrorLevel : "", %INI_FILENAME%, SETTINGS, COL2
    }
    If ( SAVE_ON_CLOSE_2 ) {
        IniWrite, %WIDTH_2%,  %INI_FILENAME%, SETTINGS, WIDTH_2
        IniWrite, %HEIGHT_2%, %INI_FILENAME%, SETTINGS, HEIGHT_2
        IniWrite, %POSX_2%,   %INI_FILENAME%, SETTINGS, POSX_2
        IniWrite, %POSY_2%,   %INI_FILENAME%, SETTINGS, POSY_2
    }
    ExitApp
;GUICLOSEREALLY

GUICONTEXTMENU:
    If ( A_GuiControl != "1LIST_A" || !LV_GetNext(0) )
        Return
    If ( CACHE_ENABLED )
    {
        objSelected := objPinDb[GetSelected()]
        Menu, Context, % ( InStr(FileExist(CACHE_DIR "\" objSelected.hash), "D") ) 
                       ? "Enable" : "Disable", Open Cache
        Menu, Context, % ( InStr(FileExist(CACHE_DIR "\" objSelected.hash), "D") )
                       ? "Enable" : "Disable", Open Cache Dir
        Menu, Context, % ( !objPinCacheMngr.CACHE_RUNNING                        ) 
                       ? "Enable" : "Disable", Cache Selected
    }
    Menu, Context, Show, %A_GuiX%, %A_GuiY%
    Return
;GUICONTEXTMENU

GUIMINTOGGLE:
    If ( bIsMinimized )
    {
        Gui, Show, Minimize
        WinRestore, ahk_id %1GUI_HWND%
        bIsMinimized := 0
    }
    Else
    {
        WinMinimize, ahk_id %1GUI_HWND%
        Gui, Cancel
        bIsMinimized := 1
    }
    Return
;GUITOGGLE

GUIRELOAD:
    ; Check if updating/caching before reloading the program.
    If ( objPinDbHandler.UPDATE_RUNNING || objPinCacheMngr.CACHE_RUNNING )
        If ( !CheckMsgBox(SCRIPTNAME, "The program is updating/caching, are you sure you want to reload?") )
            Return
    PostMessage, 0x111, 65400,,, ahk_id %1GUI_HWND%
    Return
;GUIRELOAD

GUISIZE:
    AnchorL( "1LIST_A", "w h"       ), AnchorL( "1BTN_A",  "x y", true )
  , AnchorL( "1BTN_B",  "x y", true ), AnchorL( "1EDIT_A", "w y", true )
    If ( AUTOHDR )
        LV_ModifyCol(2, "AutoHdr"), LV_ModifyCol(3, "AutoHdr")
    Return
;GUISIZE

HELP:
    If ( !FileExist(HELP_FILENAME) )
        ExitMessage(0x40, SCRIPTNAME, "Help file not present.")
    Run, %HELP_FILENAME%
    Return
;HELP

LISTEVENT:
    objSelected := objPinDb[GetSelected()]
    If ( A_GuiEvent == "I" || A_GuiEvent = "Normal" ) ; Item changed || Left click
        SB_SetText(" " objSelected.href, 2)
    Else If ( A_GuiEvent == "A" )                     ; Row double-clicked
        GoSub, 2GUISHOW
    Return
;LISTEVENT

OPENCACHE:
    objSelected := objPinDb[GetSelected()]
    OpenCache(objSelected)
    Return
;OPENCACHE

OPENCACHEDIR:
    objSelected := objPinDb[GetSelected()]
    Run, % "open " CACHE_DIR "\" objSelected.hash
    Return
;OPENCACHE

OPENURL:
    objSelected := objPinDb[GetSelected()]
    Run, % (BROWSER_CMDLINE) ? BROWSER_CMDLINE " " objSelected.href : objSelected.href
    Return
;OPENURL

SAVEAS:
    Gui, +OwnDialogs
    objSelected := objPinDb[GetSelected()]
    SaveAsWkhtml(objSelected, ( A_ThisMenuItem == "Save as PDF" ) ? "pdf" : "jpg")
;SAVEAS

SEARCHEDIT:
    GuiControlGet, sStrSearch,, 1EDIT_A
    If ( sStrSearch )
        ListViewUpdate(objPinDb, 0, sStrSearch)
    Return
;SEARCHEDIT

UPDATEDB:
    If ( !CheckMsgBox(SCRIPTNAME, "Are you sure you want to update the DB?") )
        Return
UPDATEDBFORCE:
    RebuildMenu(1), nRetVal := objPinDbHandler.UpdateDb(), RebuildMenu(1)
    If ( nRetVal == 1 )
    {   ; If the update was successful, init the DB and get the new object,
        ; then pass it to the cache manager and update the listview.
        objPinDbHandler.InitDb()
        objPinDb := Object(objPinDbHandler.GetDbObject())
        objPinCacheMngr.SetDbObject(objPinDb)
        ListViewUpdate(objPinDb, 1)
        If ( CACHE_ON_UPDATE )
            GoSub, CACHEDBFORCE
    }
    Return
;UPDATEDBFORCE
;UPDATEDB

VIEW:
    If ( !IsObject(objSelected := objPinDb[GetSelected()]) )
         MsgBox, 0x30, %SCRIPTNAME%, No item selected.
    Else GoSub, 2GUISHOW
    Return
;VIEW
