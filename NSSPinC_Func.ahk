; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: NSSPinC_Func.ahk - GUI and helper functions.
; ----------------------------------------------------------------------------------------------------------------------

; Rearrange Tray Menu dinamically when minized/maximized.
AHK_NOTIFYICON(wParam, lParam)
{
    Global bIsMinimized
    
    If ( lParam == 0x0205 ) ; WM_RBUTTONUP = 0x0205
    {
        Menu, Tray, DeleteAll
        Menu, Tray, Add, % (bIsMinimized) ? "Restore" : "Minimize", GUIMINTOGGLE
        Menu, Tray, Add
        Menu, Tray, Add, Reload, GUIRELOAD
        Menu, Tray, Add, Quit,   GUICLOSEREALLY
        Menu, Tray, Default, % (bIsMinimized) ? "Restore" : "Minimize"
        Menu, Tray, Click, 2
    }
}

; Callback for database updating and caching. Update statusbar
; content using a timer to create a minimal progress animation.
CbSetInfo(sText:="", bAnimate:=0)
{
    Static sProgressText, nIdx := 0
         , aCharAni  := ["|", "/", "—", "\"]
         , szCharAni := aCharAni.MaxIndex()
    
    ( sText != "" ) ? SB_SetText(sProgressText := sText)
    SetTimer, INFOTIMER, % ( bAnimate ) ? "500" : "Off"
    Return
    
    INFOTIMER:
        SB_SetText(sProgressText "  " aCharAni[++nIdx])
        (nIdx == szCharAni) ? nIdx := 0
        Return
    ;INFOTIMER
}

; Ask to the user the provided message (YES - NO).
; Remove the Tray menu during the MsgBox presence.
CheckMsgBox(sTitle, sMsg)
{
    Gui, +OwnDialogs
    Menu, Tray, DeleteAll               ; Delete Tray menu items.
    OnMessage(0x0404, "")               ; Stop monitoring of Tray message.
    MsgBox, 0x24, %sTitle%, %sMsg%
    OnMessage(0x0404, "AHK_NOTIFYICON") ; Restore monitoring of Tray message.
    IfMsgBox, No
        Return 0
    Return 1
}

; Check if the debug is enabled and write a message.
DebugMessage(sMsg, bTime:=0)
{
    Global DEBUG_ENABLED, DEBUG_FILENAME
    
    If ( DEBUG_ENABLED )
        FileAppend, % (( bTime ) ? A_Now " :: " : "") sMsg, %DEBUG_FILENAME%
}

; Open a popup message and quit.
ExitMessage(nType, sTitle, sMsg)
{
    MsgBox, % nType, %sTitle%, %sMsg%
    ExitApp
}

; Return the index of the selected item.
; The index is the relative value of the hidden Index column.
GetSelected()
{
    LV_GetText(nIdx, LV_GetNext(0), 3)
    Return nIdx
}

; Get a full path from a relative one.
GetFullPath(sPath)
{
    Return StrGet(DllCall( "msvcrt.dll\" (A_IsUnicode ? "_w" : "_") "fullpath", Ptr,0, Str,sPath ))
}

; Update the listview with or without a filter.
ListViewUpdate(ByRef objPinDb, bRestore:=0, sStrSearch:="")
{
    Global CACHE_DIR
    
    LV_Delete()
    If ( bRestore )
        Loop % objPinDb.length
            LV_Add( (objPinDb[A_Index-1].shared != "no")
            ? (InStr(FileExist(CACHE_DIR "\" objPinDb[A_Index-1].hash), "D")) ? "Icon5" : "Icon4"
            : (InStr(FileExist(CACHE_DIR "\" objPinDb[A_Index-1].hash), "D")) ? "Icon7" : "Icon6"
            , objPinDb[A_Index-1].description, objPinDb[A_Index-1].tag, A_Index-1 )
    Else
        Loop % objPinDb.length
            If ( RegExMatch( objPinDb[A_Index-1].description . " "
                           . objPinDb[A_Index-1].href        . " "
                           . objPinDb[A_Index-1].tag         . " "
                           . objPinDb[A_Index-1].extended    . " "
                           . objPinDb[A_Index-1].hash, "iS)" sStrSearch ) )
                LV_Add( (objPinDb[A_Index-1].shared != "no")
                ? (InStr(FileExist(CACHE_DIR "\" objPinDb[A_Index-1].hash), "D")) ? "Icon5" : "Icon4"
                : (InStr(FileExist(CACHE_DIR "\" objPinDb[A_Index-1].hash), "D")) ? "Icon7" : "Icon6"
                , objPinDb[A_Index-1].description, objPinDb[A_Index-1].tag, A_Index-1 )

    DebugMessage("ListViewUpdate -> " (( bRestore ) ? "Updated ListView." : "Searched for: [" sStrSearch "]") "`n", 1)
}

ListViewUpdateItem(ByRef objSelected, nSelected)
{
    nIdx := 0
    Loop % LV_GetCount()
    {
        If ( LV_GetText(nVal, A_Index, 3) && nVal == nSelected )
        {
            LV_Modify(A_Index, (objSelected.shared != "no") ? "Icon5" : "Icon7") ; Update icon
            Break
        }
    }
    DebugMessage("ListViewUpdateItem -> Updated ListView item: [" objSelected.hash "]`n", 1)
}

; Open the html main cache file. It tries to load an eventual index.htm(l) first
; then it tries to find the best match between the present htm(l) files and the
; name of the bookmark using trigrams.
OpenCache(ByRef objSelected)
{
    Global CACHE_DIR, BROWSER_CMDLINE
    
    If ( !InStr(FileExist(CACHE_DIR "\" objSelected.hash), "D") )
        Return 0
      , DebugMessage("OpenCache -> Error opening cache item: [" objSelected.hash "]`n", 1)
    
    arrHtml := [] ; Build array of html filenames.
    Loop, % CACHE_DIR "\" objSelected.hash "\*.htm*", 0, 1
    {
        If ( InStr("index.html", A_LoopFileName) )
        {
            FileRead, sTmp, *m1024 %A_LoopFileLongPath%
            If ( RegexMatch(sTmp, "S)<[\s\S]*>") )
            {   ; Trivial check to determine if it's html.
                Run, % (BROWSER_CMDLINE) ? BROWSER_CMDLINE " " A_LoopFileLongPath : A_LoopFileLongPath
                Return 1
            }
        }
        Else arrHtml.Insert(A_LoopFileName)
    }
    
    VarSetCapacity(MATCHLIST, arrHtml.MaxIndex()*4,0), pIdx := &MATCHLIST
    Loop % arrHtml.MaxIndex() ; Fill the matchlist structure.
        pIdx := NumPut(arrHtml.GetAddress(A_Index), pIdx+0)
    
    ; Match the best html filename to the item URL.
    nWinIdx := MatchItemFromList(&MATCHLIST, arrHtml.MaxIndex(), objSelected.href)
    sFile   := CACHE_DIR "\" objSelected.hash "\" arrHtml[nWinIdx & 0xFFFF]
    Run, % ( BROWSER_CMDLINE ) ? BROWSER_CMDLINE " " sFile : sFile
    
    Return 1
  , DebugMessage("OpenCache -> Opened cache item: [" objSelected.hash "]`n", 1)
}

; Rebuild menu from scratch when updating/caching.
RebuildMenu(bUpdating:=0)
{
    Menu, FileMenu, ToggleEnable, &Update Database
    Menu, FileMenu, ToggleEnable, Cache &New Bookmarks
    Menu, FileMenu, ToggleEnable, Cache &All Bookmarks
    Menu, FileMenu, ToggleEnable, Cache &Maintenance
  If ( !bUpdating )
    Menu, FileMenu, ToggleEnable, &Stop Caching
}

; Show a dialog to save a pdf or jpg file.
SaveAsWkhtml(ByRef objSelected, sType:="pdf")
{
    Global WKHTML_PATH, WKHTML_PDF_PARAM, WKHTML_IMG_PARAM
    
    FileSelectFile, sFile, S18, % objSelected.hash,, *.%sType%
    If ( sFile )
    {
        sFile := (SubStr(sFile, -2) == sType) ? sFile : sFile "." sType
        sCmd  := (( sType == "pdf" ) ? """" WKHTML_PATH "\wkhtmltopdf.exe"" "   WKHTML_PDF_PARAM 
                                     : """" WKHTML_PATH "\wkhtmltoimage.exe"" " WKHTML_IMG_PARAM )
                                     . " """ objSelected.href """ """ sFile """"
        Run, %sCmd%
    }
    
    DebugMessage( "SaveAsWkhtml -> Saved bookmark as " sType ":`n" 
                . "URL:    [" objSelected.href "]`n"
                . "FILE:   [" sFile            "]`n"
                . "WKHTML: [" sCmd             "]`n", 1 )
}
