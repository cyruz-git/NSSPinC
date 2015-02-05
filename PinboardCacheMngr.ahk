; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: PinboardCacheMngr.ahk - Cache manager, allows URL caching.
; ----------------------------------------------------------------------------------------------------------------------

Class PinboardCacheMngr
{
    ; Workaround to make __Call work also for static class method calling.
    ; http://ahkscript.org/boards/viewtopic.php?f=5&t=5933
    Static _ := (PinboardCacheMngr := new PinboardCacheMngr) && 0
    
    __New( ByRef objPinDb, sExeDir, sCacheDir, sCacheParam, fCallback, fDebug )
    {
        ; This assignment must be the first, because of the
        ; __Call method returning "NO_OBJECT" if not set.
        this.PINBOARD_DB    := objPinDb
        
        this.CACHE_DIR      := sCacheDir
        this.CACHE_DUMP_FN  := "WGET_DUMP.TXT"
        this.CACHE_EXE      := sExeDir "\wget.exe"
        this.CACHE_EXE_DIR  := sExeDir
        this.CACHE_PARAM    := sCacheParam
        this.CACHE_RUNNING  := 0
        this.CACHE_STOP     := 0
        this.FUNC_CALLBACK  := fCallback
        this.FUNC_DEBUG     := fDebug
        this.GZIP_EXE       := sExeDir "\gzip.exe"
      
        Return this
      , this.FUNC_DEBUG.Call("PinboardCacheMngr object created.`n", 1)
    }
    
    ; Release and empty all objects/vars.
    __Delete()
    {
        this.CACHE_DIR   := "", this.CACHE_DUMP_FN := "", this.CACHE_EXE   := "", this.CACHE_EXE_DIR := "" 
      , this.CACHE_PARAM := "", this.CACHE_RUNNING := "", this.CACHE_STOP  := "", this.FUNC_CALLBACK := ""
      , this.FUNC_DEBUG  := "", this.GZIP_EXE      := "", this.PINBOARD_DB := ""
    }
    
    ; All methods return "NO_OBJECT" if the object is not instantiated.
    ; Require the _ static class variable workaround.
    __Call()
    {
        If ( !this.PINBOARD_DB )
            Return "NO_OBJECT"
    }

    ; Create a cache for the provided bookmark. Allow to override command parameters and overwrite cache folder.
    ; Return Wget exit code, -1 if caching was stopped, -2 if the cache directory could not be created.
    __CreateCache(sUrl, sSubDir, sCacheParam:="", bOverwriteDir:=0)
    {
        Static sRegExP := "S)-{1,2}(?:P|directory-prefix)(?:[=:]?|\s+)['""]?([^-\s].*?)?['""]?(?=\s+[-\/]|$)"
        
        If ( sCacheParam == "" )
            sCachePath  := this.CACHE_DIR "\" sSubDir
          , sCacheParam := this.CACHE_PARAM " -P """ sCachePath """" (( this.DEBUG_ENABLED ) 
                        ?  " -o """ this.CACHE_DIR "\" sSubDir "\" this.CACHE_DUMP_FN """" : "")
        Else If ( RegExMatch(sCacheParam, sRegExP, sMatch) && sMatch1 )
            sCachePath  := Trim(sMatch1)
        
        sWgetCmdline := """" this.CACHE_EXE """ " sCacheParam " """ sUrl """"
        
        If ( bOverwriteDir)
            FileRemoveDir, %sCachePath%
        
        If ( !InStr(FileExist(sCachePath), "D") )
            FileCreateDir, %sCachePath%
        
        If ( ErrorLevel )
            Return -2
          , this.FUNC_DEBUG.Call( "PinboardCacheMngr.__CreateCache -> "
                                . "Error creating cache subdirectory: [" sCachePath "].`n", 1 )
        
        ; Ensure that the CACHE_STOP flag is not set.
        this.CACHE_STOP := 0
        
        Run, %sWgetCmdline%,, Hide UseErrorLevel, nPid
        ; PROCESS_QUERY_LIMITED_INFORMATION = 0x1000, SYNCHRONIZE = 0x00100000
        hProc := DllCall( "OpenProcess", UInt,0x1000|0x00100000, Int,0, UInt,nPid ) 
        Loop
		{
            If ( this.CACHE_STOP )
            {   ; If caching is stopped, kill process and remove directory.
                Process, Close, %nPid%
                FileRemoveDir, %sCachePath%, 1
                Break
            }
            ; INFINITE = -1, QS_ALLINPUT = 0x04FF
			hWait := DllCall( "MsgWaitForMultipleObjectsEx", UInt,1, PtrP,hProc, UInt,-1, UInt,0x04FF, UInt,0 )
			If ( hWait == 0 || hWait == -1 )
			{
				While( DllCall( "GetExitCodeProcess", Ptr,hProc, PtrP,nExitCode ) && nExitCode == 259 )
                    Sleep, 100
                DllCall( "CloseHandle", Ptr,hProc )
                
                ; * Wget has no support for compression, so if a file is downloaded with a gzip/deflate encoding, to 
                ; * keep it consistent with the cache, we must decompress it. Actually we try to decompress it with 
                ; * gzip, adding the .gz extension to the file and extracting it. Please be aware that this is a 
                ; * workaround and, as such, it can be bugged.
                
                VarSetCapacity(nMN, 2, 0)
                Loop, %sCachePath%\*, 0, 1
                {
                    oF := FileOpen(A_LoopFileLongPath, "r"), oF.RawRead(nMN, 2), oF.Close()
                    If ( (NumGet(&nMN, 0, "UChar") == 0x1F && NumGet(&nMN, 1, "UChar") == 0x8B)
                    ||   (NumGet(&nMN, 0, "UChar") == 0x78 && NumGet(&nMN, 1, "UChar") == 0x9C) )
                    {   ; GZIP Magic Number = 0x8B, ZLIB Magic Number = 0x9C
                        FileMove, %A_LoopFileLongPath%, %A_LoopFileLongPath%.gz
                        Run, % this.GZIP_EXE " -d " A_LoopFileLongPath,, Hide
                    }
                }
                Break
			}
			Sleep, 100
		}
        
        this.FUNC_DEBUG.Call( "PinboardCacheMngr.__CreateCache -> "
                            . (( this.CACHE_STOP ) ? "Caching stopped.`n" : "Item cached:`n"
                                                                          . "DIR:      [" sCachePath   "]`n"
                                                                          . "URL:      [" sUrl         "]`n"
                                                                          . "WGET:     [" sWgetCmdline "]`n"
                                                                          . "EXITCODE: [" nExitCode    "]`n"), 1 )
        Return (this.CACHE_STOP) ? -1 : nExitCode
    }
    
    ; Generic DB caching, allow caching of new links or all. Ignore errors.
    ; Return 1 on success or -1 if caching was stopped.
    CacheDb(bCacheAll:=0)
    {
        ; Calculate how many bookmarks will be cached.
        If ( bCacheAll )
            nHowMany := this.PINBOARD_DB.length
        Else
        {
            aDontCache := []
            Loop % this.PINBOARD_DB.length
            {
                If ( !InStr(FileExist(this.CACHE_DIR "\" this.PINBOARD_DB[A_Index-1].hash), "D") )
                     nHowMany += 1
                Else aDontCache[A_Index-1] := 1
            }
        }
        
        this.FUNC_DEBUG.Call( "PinboardCacheMngr.CacheDb -> Caching of " 
                            . (( bCacheAll ) ? "ALL" : "NEW") " bookmarks started.`n"
                            . "*** BOOKMARKS TOTAL: [" nHowMany       "]`n"
                            . "*** CACHE DIRECTORY: [" this.CACHE_DIR "]`n", 1 )
        
      ; =============================================================================================
        this.CACHE_RUNNING := 1                                                ; Toggle running flag.
      ; =============================================================================================
        nIdx := 1
        Loop % this.PINBOARD_DB.length
        {
            If ( aDontCache[A_Index-1] )
                Continue
            this.FUNC_CALLBACK.Call(" Caching " nIdx++ " of " nHowMany, 1)
            nRetVal := this.__CreateCache(this.PINBOARD_DB[A_Index-1].href, this.PINBOARD_DB[A_Index-1].hash, "", 1)
            If ( nRetVal == -1 )
                Break
        }
        If ( !bCacheAll )
            ObjRelease(aDontCache)
      ; =============================================================================================
        this.FUNC_CALLBACK.Call(( nRetVal == -1 ) ? " Stopped." : " Done.", 0) ; Update caching info.
        this.CACHE_RUNNING := 0                                                ; Toggle running flag.
      ; =============================================================================================
        
        this.FUNC_DEBUG.Call( "PinboardCacheMngr.CacheDb -> Caching of bookmarks " 
                            . (( nRetVal == -1 ) ? "stopped" : "terminated") ".`n", 1 )
            
        Return ( nRetVal == -1 ) ? -1 : 1
    }
    
    ; Remove old cache directories related to deleted bookmarks
    CacheMaintenance()
    {
        this.FUNC_DEBUG.Call("PinboardCacheMngr.CacheMaintenance -> Cache maintenance started.`n", 1)
        
      ; =============================================================================================
        this.CACHE_RUNNING := 1                                                ; Toggle running flag.
        this.FUNC_CALLBACK.Call(" Maintaining cache", 1)                       ; Update caching info.
      ; =============================================================================================
        Loop, % this.CACHE_DIR "\*", 2
        {
            If ( !InStr(this.PINBOARD_DB.hashlist, A_LoopFileName) )
            {
                FileRemoveDir, %A_LoopFileLongPath%, 1
                If ( ErrorLevel )
                     this.FUNC_DEBUG.Call( "PinboardCacheMngr.CacheMaintenance -> Error removing directory: ["
                                         . A_LoopFileLongPath "],`n", 1 )
                Else this.FUNC_DEBUG.Call( "PinboardCacheMngr.CacheMaintenance -> Directory successfully removed: ["
                                         . A_LoopFileLongPath "],`n", 1 )
            }
            Sleep, 100
        }
      ; =============================================================================================
        this.FUNC_CALLBACK.Call(" Done.", 0)                                   ; Update caching info.
        this.CACHE_RUNNING := 0                                                ; Toggle running flag.
      ; =============================================================================================
        
        this.FUNC_DEBUG.Call("PinboardCacheMngr.CacheMaintenance -> Cache maintenance terminated.`n", 1)
    }

    ; Cache a single URL. Allow to override command parameters with a custom command line.
    ; Return Wget exit code, -1 if caching was stopped, -2 if the cache directory could not be created.
    CacheSingleBookmark(ByRef objSelected, sCacheParam:="")
    {
        this.FUNC_DEBUG.Call("PinboardCacheMngr.CacheSingleBookmark -> Caching of single bookmark started.`n", 1)
        
      ; =============================================================================================
        this.CACHE_RUNNING := 1                                                ; Toggle running flag.
        this.FUNC_CALLBACK.Call(" Caching", 1)                                 ; Update caching info.
      ; =============================================================================================
        nRetVal := this.__CreateCache(objSelected.href, objSelected.hash, sCacheParam, 1)
      ; =============================================================================================
        sMsg := ( nRetVal == -1 )             ? " Stopped." 
             :  ( nRetVal == -2 )             ? " Directory Error." 
             :  ( InStr("1234567", nRetVal) ) ? " Wget Error."
             :                                  " Done."
        this.FUNC_CALLBACK.Call(sMsg, 0)                                       ; Update caching info.
        this.CACHE_RUNNING := 0                                                ; Toggle running flag.
      ; =============================================================================================
        
        this.FUNC_DEBUG.Call( "PinboardCacheMngr.CacheSingleBookmark -> Caching of single bookmark "
                            . (( nRetVal == -1 ) ? "stopped" : "terminated"
                            . (( InStr("1234567-2", nRetVal) ) ? " with error" : "")) ".`n", 1 )
        
        Return nRetVal
    }
    
    ; Set the stop flag for the caching process.
    CacheStop()
    {
        this.CACHE_STOP := 1
        this.FUNC_DEBUG.Call("PinboardCacheMngr.CacheStop -> Set the caching stop flag.`n", 1)
    }
    
    GetCacheParameters(ByRef objSelected)
    {
        this.FUNC_DEBUG.Call("PinboardCacheMngr.GetCacheParameters -> Returned cache parameters.`n", 1)
        
        Return this.CACHE_PARAM " -P """ this.CACHE_DIR "\" objSelected.hash """ " (( this.DEBUG_ENABLED ) 
        ? " -o """ this.CACHE_DIR "\" objSelected.hash "\" this.CACHE_DUMP_FN """" : "") " """ objSelected.href """"
    }
    
    ; Set the internal database.
    SetDbObject(ByRef objPinDb)
    {
        this.PINBOARD_DB := objPinDb
        this.FUNC_DEBUG.Call("PinboardCacheMngr.SetDbObject -> Set a new database object.`n", 1)
    }
}
