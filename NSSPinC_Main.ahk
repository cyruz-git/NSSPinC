; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; Description ..: Minimalistic Pinboard client with caching support.
; File .........: NSSPinC_Main.ahk - Main file, manage configuration.
; AHK Version ..: AHK_L 1.1.19.01 x32/64 Unicode
; Author .......: Cyruz - http://ciroprincipe.info
; Changelog ....: Nov. 27, 2013 - v0.1 - First revision.
; ..............: Feb. 05, 2015 - v0.2 - Code refactoring, including resources, revised caching system. Added Gui menu.
; License ......: GNU Lesser General Public License
; ..............: This program is free software: you can redistribute it and/or modify it under the terms of the GNU
; ..............: Lesser General Public License as published by the Free Software Foundation, either version 3 of the
; ..............: License, or (at your option) any later version.
; ..............: This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
; ..............: the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser 
; ..............: General Public License for more details.
; ..............: You should have received a copy of the GNU Lesser General Public License along with this program. If 
; ..............: not, see <http://www.gnu.org/licenses/>.
; ----------------------------------------------------------------------------------------------------------------------

#SingleInstance force
#Persistent
#NoEnv
#Include <AnchorL>
#Include <BinGet>
#Include <MatchItemFromList>
#Include <UpdRes>

; ======================================================================================================================
; ===[ INITIALIZATIONS AND CONFIGURATION CHECK ]========================================================================
; ======================================================================================================================

SCRIPTNAME      := "NSSPinC"
SCRIPTLINE      := SCRIPTNAME " - Not So Sucky Pinboard Client"
SCRIPTVERSION   := "0.2.0"
RESOURCES_DIR   := A_ScriptDir "\Resources"
RESOURCES_TOTAL := 8
HELP_FILENAME   := A_ScriptDir "\Readme.html"
INI_FILENAME    := A_ScriptDir "\" SCRIPTNAME ".ini"
DB_FILENAME     := A_ScriptDir "\db.xml"
BINVAR_FILENAME := A_ScriptDir "\dbhelper.dat"
DEBUG_FILENAME  := A_ScriptDir "\debug.txt"

; If the configuration file doesn't exists regenerate it, otherwise, read it.
If ( !FileExist(INI_FILENAME) )
{
    IniWrite, % "", %INI_FILENAME%, SETTINGS, API_TOKEN
    IniWrite, 1,    %INI_FILENAME%, SETTINGS, SAVE_ON_CLOSE
    IniWrite, 1,    %INI_FILENAME%, SETTINGS, SAVE_ON_CLOSE_2
    ExitMessage( 0x30, SCRIPTNAME, "Configuration file not present. It will be regenerated`, please write your API "
                                 . "TOKEN into it." )
}

; ======================================================================================================================
; ===[ GENERAL SETTINGS VARIABLES]======================================================================================
; ======================================================================================================================

IniRead, API_TOKEN,       %INI_FILENAME%, SETTINGS, API_TOKEN,       0
IniRead, BROWSER_CMDLINE, %INI_FILENAME%, SETTINGS, BROWSER_CMDLINE, 0
IniRead, DEBUG_ENABLED,   %INI_FILENAME%, SETTINGS, DEBUG_ENABLED,   0
IniRead, MIN_ON_CLOSE,    %INI_FILENAME%, SETTINGS, MIN_ON_CLOSE,    0
IniRead, UPDATE_ON_START, %INI_FILENAME%, SETTINGS, UPDATE_ON_START, 0
IniRead, WEB_ARCHIVE_PFX, %INI_FILENAME%, SETTINGS, WEB_ARCHIVE_PFX, 0

If ( !API_TOKEN )
    ExitMessage(0x40, SCRIPTNAME, "Please write the API TOKEN into the configuration file!")

If ( (DEBUG_ENABLED   != 0 && DEBUG_ENABLED   != 1)
||   (MIN_ON_CLOSE    != 0 && MIN_ON_CLOSE    != 1)
||   (UPDATE_ON_START != 0 && UPDATE_ON_START != 1) )
    ExitMessage( 0x40, SCRIPTNAME, "Some settings intended to be boolean (0 or 1) are wrong, please check the "
                                 . "configuration." )

WEB_ARCHIVE_PFX := ( WEB_ARCHIVE_PFX ) ? WEB_ARCHIVE_PFX : "http://web.archive.org/web/*/"

; ======================================================================================================================
; ===[ CACHE SYSTEM VARIABLES ]=========================================================================================
; ======================================================================================================================

IniRead, CACHE_DIR,       %INI_FILENAME%, SETTINGS, CACHE_DIR,       0
IniRead, CACHE_ENABLED,   %INI_FILENAME%, SETTINGS, CACHE_ENABLED,   1
IniRead, CACHE_EXE_DIR,   %INI_FILENAME%, SETTINGS, CACHE_EXE_DIR,   0
IniRead, CACHE_ON_UPDATE, %INI_FILENAME%, SETTINGS, CACHE_ON_UPDATE, 0
IniRead, CACHE_PARAM,     %INI_FILENAME%, SETTINGS, CACHE_PARAM,     0

If ( (CACHE_ENABLED   != 0 && CACHE_ENABLED   != 1)
||   (CACHE_ON_UPDATE != 0 && CACHE_ON_UPDATE != 1) )
    ExitMessage( 0x40, SCRIPTNAME, "Some settings intended to be boolean (0 or 1) are wrong, please check the "
                                 . "configuration." )

If ( CACHE_ENABLED )
{
    CACHE_DIR := ( CACHE_DIR ) ? GetFullPath(CACHE_DIR) : A_ScriptDir "\Cache"
    If ( !InStr(FileExist(CACHE_DIR), "D") )
    {
        FileCreateDir, %CACHE_DIR%
        If ( ErrorLevel )
            ExitMessage(0x40, SCRIPTNAME, "Error creating the cache directory.")
    }
    
    CACHE_EXE_DIR := ( InStr(FileExist(CACHE_EXE_DIR), "D") ) ? GetFullPath(CACHE_EXE_DIR) : A_ScriptDir "\Tools"
    If ( !FileExist(CACHE_EXE_DIR "\wget.exe") || !FileExist(CACHE_EXE_DIR "\gzip.exe") )
        ExitMessage( 0x40, SCRIPTNAME, "Wget and/or Gzip not present. Adjust CACHE_EXE_DIR or put the required files "
                                     . "inside the Tools directory." )
    
    If ( CACHE_PARAM )
    {
        sRegExO := "S)-{1,2}(?:o|output-file)(?:[=:]?|\s+)['""]?([^-\s].*?)?['""]?(?=\s+[-\/]|$)"
        sRegExP := "S)-{1,2}(?:P|directory-prefix)(?:[=:]?|\s+)['""]?([^-\s].*?)?['""]?(?=\s+[-\/]|$)"
        
        If ( RegExMatch(CACHE_PARAM, sRegExO, sMatch) && sMatch1 )
            ExitMessage( 0x40, SCRIPTNAME, "Please avoid using the -o/--file-output parameter in the CACHE_PARAM "
                                         . "setting. Set the DEBUG_ENABLED setting to 1 if you want a dump in the "
                                         . "cache directory." )
        
        If ( RegExMatch(CACHE_PARAM, sRegExP, sMatch) && sMatch1 )
            ExitMessage( 0x40, SCRIPTNAME, "Please don't use the -P/--directory-prefix parameter in the CACHE_PARAM "
                                         . "setting. Use the CACHE_DIR setting to specify a different directory." )
    }
    Else CACHE_PARAM := "--no-check-certificate --restrict-file-names=windows -e robots=off -U ""Mozilla/5.0 "
                     .  "(compatible; NSSPinC)"" --wait=0.25 -N -E -H -k -nd -p"
}

; ======================================================================================================================
; ===[ WKHTML VARIABLES ]===============================================================================================
; ======================================================================================================================

IniRead, WKHTML_PATH,      %INI_FILENAME%, SETTINGS, WKHTML_PATH,      0
IniRead, WKHTML_IMG_PARAM, %INI_FILENAME%, SETTINGS, WKHTML_IMG_PARAM, 0
IniRead, WKHTML_PDF_PARAM, %INI_FILENAME%, SETTINGS, WKHTML_PDF_PARAM, 0

WKHTML_PATH        := ( InStr(FileExist(WKHTML_PATH), "D") )          ? GetFullPath(WKHTML_PATH) : A_ScriptDir "\Tools"
WKHTML_IMG_ENABLED := ( FileExist(WKHTML_PATH "\wkhtmltoimage.exe") ) ? 1                        : 0
WKHTML_PDF_ENABLED := ( FileExist(WKHTML_PATH "\wkhtmltopdf.exe")   ) ? 1                        : 0
WKHTML_IMG_PARAM   := ( WKHTML_IMG_PARAM )                            ? WKHTML_IMG_PARAM         : ""
WKHTML_PDF_PARAM   := ( WKHTML_PDF_PARAM )                            ? WKHTML_PDF_PARAM         : "--no-outline"

; ======================================================================================================================
; ===[ WINDOWS SIZE AND POSITION VARIABLES ]============================================================================
; ======================================================================================================================

IniRead, AUTOHDR,         %INI_FILENAME%, SETTINGS, AUTOHDR,         0
IniRead, COL1,            %INI_FILENAME%, SETTINGS, COL1,            300
IniRead, COL2,            %INI_FILENAME%, SETTINGS, COL2,            200
IniRead, FULLSCREEN,      %INI_FILENAME%, SETTINGS, FULLSCREEN,      0
IniRead, HEIGHT,          %INI_FILENAME%, SETTINGS, HEIGHT,          300
IniRead, HEIGHT_2,        %INI_FILENAME%, SETTINGS, HEIGHT_2,        60
IniRead, POSX,            %INI_FILENAME%, SETTINGS, POSX,            Center
IniRead, POSX_2,          %INI_FILENAME%, SETTINGS, POSX_2,          Center
IniRead, POSY,            %INI_FILENAME%, SETTINGS, POSY,            Center
IniRead, POSY_2,          %INI_FILENAME%, SETTINGS, POSY_2,          Center
IniRead, SAVE_ON_CLOSE,   %INI_FILENAME%, SETTINGS, SAVE_ON_CLOSE,   1
IniRead, SAVE_ON_CLOSE_2, %INI_FILENAME%, SETTINGS, SAVE_ON_CLOSE_2, 1
IniRead, WIDTH,           %INI_FILENAME%, SETTINGS, WIDTH,           520
IniRead, WIDTH_2,         %INI_FILENAME%, SETTINGS, WIDTH_2,         300

AUTOHDR         := ( AUTOHDR         < 0 || AUTOHDR         > 1              ) ? 0        : AUTOHDR
COL1            := ( COL1            < 0 || COL1            > A_ScreenWidth  ) ? 300      : COL1
COL2            := ( COL2            < 0 || COL2            > A_ScreenWidth  ) ? 200      : COL2
FULLSCREEN      := ( FULLSCREEN      < 0 || FULLSCREEN      > 1              ) ? 0        : FULLSCREEN
HEIGHT          := ( HEIGHT          < 0 || HEIGHT          > A_ScreenHeight ) ? 300      : HEIGHT
HEIGHT_2        := ( HEIGHT_2        < 0 || HEIGHT_2        > A_ScreenHeight ) ? 60       : HEIGHT_2
POSX            := ( POSX            < 0 || POSX            > A_ScreenWidth  ) ? "Center" : POSX
POSX_2          := ( POSX_2          < 0 || POSX_2          > A_ScreenWidth  ) ? "Center" : POSX_2
POSY            := ( POSY            < 0 || POSY            > A_ScreenHeight ) ? "Center" : POSY
POSY_2          := ( POSY_2          < 0 || POSY_2          > A_ScreenHeight ) ? "Center" : POSY_2
SAVE_ON_CLOSE   := ( SAVE_ON_CLOSE   < 0 || SAVE_ON_CLOSE   > 1              ) ? 1        : SAVE_ON_CLOSE
SAVE_ON_CLOSE_2 := ( SAVE_ON_CLOSE_2 < 0 || SAVE_ON_CLOSE_2 > 1              ) ? 1        : SAVE_ON_CLOSE_2
WIDTH           := ( WIDTH           < 0 || WIDTH           > A_ScreenWidth  ) ? 520      : WIDTH
WIDTH_2         := ( WIDTH_2         < 0 || WIDTH_2         > A_ScreenWidth  ) ? 300      : WIDTH_2

; ======================================================================================================================
; ===[ OBJECTS CREATION ]===============================================================================================
; ======================================================================================================================

DebugMessage( "===========================================`n"
            . "===[ "   A_Now    " :: NSSPinC started ]===`n"
            . "===========================================`n" )

objPinConnector := New PinboardConnector( API_TOKEN, Func("DebugMessage") )

objPinDbHandler := New PinboardDbHandler( objPinConnector, DB_FILENAME, BINVAR_FILENAME, Func("CbSetInfo")
                                        , Func("DebugMessage") )

If ( objPinDbHandler.InitDb() )
    objPinDb := Object(objPinDbHandler.GetDbObject())

If ( CACHE_ENABLED )
    objPinCacheMngr := New PinboardCacheMngr( objPinDb, CACHE_EXE_DIR, CACHE_DIR, CACHE_PARAM, Func("CbSetInfo")
                                            , Func("DebugMessage") )


#Include NSSPinC_UI.ahk
#Include NSSPinC_UI_2.ahk
#Include NSSPinC_UI_3.ahk
#Include NSSPinC_Func.ahk
#Include PinboardConnector.ahk
#Include PinboardDbHandler.ahk
#Include PinboardCacheMngr.ahk
