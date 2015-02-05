; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: PinboardDbHandler.ahk - Database handler, broker Pinboard<>AHK.
; ----------------------------------------------------------------------------------------------------------------------

Class PinboardDbHandler
{
    ; Workaround to make __Call work also for static class method calling.
    ; http://ahkscript.org/boards/viewtopic.php?f=5&t=5933
    Static _ := (PinboardDbHandler := new PinboardDbHandler) && 0

    __New(ByRef objPinConnector, sDbFilename, sBinVarFilename, fCallback, fDebug)
    {
        ; This assignment must be the first, because of the
        ; __Call method returning "NO_OBJECT" if not set.
        this.PINBOARD_CONNECTOR := objPinConnector
        
        this.BINVAR_FILENAME    := sBinVarFilename
        this.BINVAR_OBJ         := this.__ReadBinVar()
        this.DB_FILENAME        := sDbFilename
        this.DB_OBJ             := ""
        this.FUNC_CALLBACK      := fCallback
        this.FUNC_DEBUG         := fDebug
        this.LIMIT_P_ALL        := 300 ; 5 minutes
        this.LIMIT_P_UPDATE     := 3   ; 3 seconds
        this.UPDATE_RUNNING     := 0
        
        Return this
      , this.FUNC_DEBUG.Call("PinboardDbHandler object created.`n", 1)
    }
    
    ; Release and empty all objects/vars.
    __Delete()
    {
        this.BINVAR_FILENAME    := "", this.BINVAR_OBJ     := "", this.DB_FILENAME := "", this.DB_OBJ         := ""
      , this.FUNC_CALLBACK      := "", this.FUNC_DEBUG     := "", this.LIMIT_P_ALL := "", this.LIMIT_P_UPDATE := ""
      , this.PINBOARD_CONNECTOR := "", this.UPDATE_RUNNING := ""
      
    }

    ; All methods return "NO_OBJECT" if the object is not instantiated.
    ; Require the _ static class variable workaround.
    __Call()
    {
        If ( !this.PINBOARD_CONNECTOR )
            Return "NO_OBJECT"
    }
    
    ; Read the database helper variables from a binary file.
    ; Return: Default object     - Object with all fields = 0.
    ;         Initialized object - Object with all fields initialized.
    __ReadBinVar()
    {
        Static szStr := 256, szBuf := szStr * 6
        oFile := FileOpen(this.BINVAR_FILENAME, "r")
        
        If ( !oFile )
            Return { "WAIT_TIME" : "0", "LAST_UPDATE"     : "0", "NEW_UPDATE"   : "0"
                   , "LAST_CALL" : "0", "IDXERR_P_UPDATE" : "0", "IDXERR_P_ALL" : "0" }
          , this.FUNC_DEBUG.Call("PinboardDbHandler.__ReadBinVar -> Loaded default database helper variables.`n", 1)
        
        oFile.RawRead(cBuf, szBuf)
        oBinVar := Object( "WAIT_TIME",       StrGet(&cBuf + 0      ), "LAST_UPDATE",  StrGet(&cBuf + szStr  )
                         , "NEW_UPDATE",      StrGet(&cBuf + szStr*2), "LAST_CALL",    StrGet(&cBuf + szStr*3)
                         , "IDXERR_P_UPDATE", StrGet(&cBuf + szStr*4), "IDXERR_P_ALL", StrGet(&cBuf + szStr*5) )
        oFile.Close()
        
        Return oBinVar
      , this.FUNC_DEBUG.Call("PinboardDbHandler.__ReadBinVar -> Database helper variables loaded.`n", 1)
    }
    
    ; Write the helper variables object into a binary file.
    __WriteBinVar()
    {
        Static szStr := 256, szBuf := szStr * 6
        
        this.FUNC_DEBUG.Call( "PinboardDbHandler.__WriteBinVar -> Database helper variable stored:`n"
                            . "WAIT_TIME:       [" this.BINVAR_OBJ.WAIT_TIME       "]`n"
                            . "LAST_UPDATE:     [" this.BINVAR_OBJ.LAST_UPDATE     "]`n"
                            . "NEW_UPDATE:      [" this.BINVAR_OBJ.NEW_UPDATE      "]`n"
                            . "LAST_CALL:       [" this.BINVAR_OBJ.LAST_CALL       "]`n"
                            . "IDXERR_P_UPDATE: [" this.BINVAR_OBJ.IDXERR_P_UPDATE "]`n"
                            . "IDXERR_P_ALL:    [" this.BINVAR_OBJ.IDXERR_P_ALL    "]`n", 1)
        
        FileDelete, % this.BINVAR_FILENAME
        VarSetCapacity( cBuf, szBuf, 0                           )
      , StrPut( this.BINVAR_OBJ.WAIT_TIME,       &cBuf + 0       )
      , StrPut( this.BINVAR_OBJ.LAST_UPDATE,     &cBuf + szStr   )
      , StrPut( this.BINVAR_OBJ.NEW_UPDATE,      &cBuf + szStr*2 )
      , StrPut( this.BINVAR_OBJ.LAST_CALL,       &cBuf + szStr*3 )
      , StrPut( this.BINVAR_OBJ.IDXERR_P_UPDATE, &cBuf + szStr*4 )
      , StrPut( this.BINVAR_OBJ.IDXERR_P_ALL,    &cBuf + szStr*5 )
      
        oFile := FileOpen(this.BINVAR_FILENAME, "w")
        oFile.RawWrite(cBuf, szBuf)
        oFile.Close()
    }

    ; Initialize an array of database items.
    ; Return: -2 - Error reading the database file.
    ;         -1 - COM error.
    ;          0 - Database present but empty. Not initialized.
    ;          1 - Database initialized.
    InitDb() {
        If ( !(sXml := this.GetDbString()) )
            Return -2
          , this.FUNC_DEBUG.Call("PinboardDbHandler.InitDb -> Error reading the database file.`n", 1)
        
        If ( (oXml := ComObjCreate("MSXML2.DOMDocument.6.0")) == "" )
            Return -1
          , this.FUNC_DEBUG.Call("PinboardDbHandler.InitDb -> COM error.`n", 1)
        
        oXml.async := false, oXml.loadXML(sXml), sXml := ""
        oPostXml := oXml.getElementsByTagName("post")
        
        If ( !oPostXml.length )
            Return 0
          , this.FUNC_DEBUG.Call("PinboardDbHandler.InitDb -> Database present but empty. Not initialized.`n", 1)
        
        this.DB_OBJ := Object()
        Loop % oPostXml.length
        {
            oAttr := oPostXml.nextNode().attributes
            this.DB_OBJ[A_Index-1] := Object( "href",        oAttr.getNamedItem( "href"        ).text
                                            , "time",        oAttr.getNamedItem( "time"        ).text
                                            , "description", oAttr.getNamedItem( "description" ).text
                                            , "extended",    oAttr.getNamedItem( "extended"    ).text
                                            , "tag",         oAttr.getNamedItem( "tag"         ).text
                                            , "hash",        oAttr.getNamedItem( "hash"        ).text
                                            , "meta",        oAttr.getNamedItem( "meta"        ).text
                                            , "shared",      oAttr.getNamedItem( "shared"      ).text
                                            , "toread",      oAttr.getNamedItem( "toread"      ).text )
            this.DB_OBJ["hashlist"] .= oAttr.getNamedItem("hash").text "`n"
        }
        this.DB_OBJ["length"] := oPostXml.length
        oPostXml := "", oXml := ""
        
        Return 1
      , this.FUNC_DEBUG.Call("PinboardDbHandler.InitDb -> Database initialized.`n", 1)
    }
    
    ; Check if NSSPinC DB is synchronized with Pinboard and eventually update it.
    ; API rate limits and server errors are managed here.
    ; In case of server error, WAIT TIME is doubled (WAIT_TIME * 2^n).
    ; Return: -2 - Rate limit reached.
    ;         -1 - Server is busy.
    ;          0 - Database already updated.
    ;          1 - Database updated.
    UpdateDb()
    {
        this.FUNC_DEBUG.Call("PinboardDbHandler.UpdateDb -> DB update started.`n", 1)
            
      ; =============================================================================================
        this.FUNC_CALLBACK.Call(" Updating DB", 1)                            ; Update updating info.
        this.UPDATE_RUNNING := 1                                              ;  Toggle running flag.
      ; =============================================================================================
      
        ; Determine how much time passed since last call.
        nTimeCheck := A_Now
        EnvSub, nTimeCheck, % this.BINVAR_OBJ.LAST_CALL, seconds
        
        ; If the passed time is less than WAIT_TIME...
        If ( nTimeCheck && nTimeCheck < this.BINVAR_OBJ.WAIT_TIME )
        {
            ; Update WAIT_TIME;
            this.BINVAR_OBJ.WAIT_TIME -= nTimeCheck 
            ; Write the helper variables.
            this.__WriteBinVar()
            
          ; =========================================================================================
            this.UPDATE_RUNNING := 0                                          ;  Toggle running flag.
            this.FUNC_CALLBACK.Call(" Rate limit reached.", 0)                ; Update updating info.
          ; =========================================================================================
            
            Return -2
          , this.FUNC_DEBUG.Call("PinboardDbHandler.UpdateDb -> Update interrupted: [RATE LIMIT REACHED]`n", 1)
        }
        
        ; Call posts/update and update WAIT_TIME and LAST_CALL.
        sXml := this.PINBOARD_CONNECTOR.Pinboard_Posts_Update()
        this.BINVAR_OBJ.WAIT_TIME := this.LIMIT_P_UPDATE
        this.BINVAR_OBJ.LAST_CALL := A_Now
        
        ; If the answer is not correct XML...
        If ( !sXml )
        {
            ; Double WAIT_TIME.
            this.BINVAR_OBJ.WAIT_TIME := this.LIMIT_P_UPDATE * (2 ** this.BINVAR_OBJ.IDXERR_P_UPDATE++)
            ; Write the helper variables.
            this.__WriteBinVar()
            
          ; =========================================================================================
            this.UPDATE_RUNNING := 0                                          ;  Toggle running flag.
            this.FUNC_CALLBACK.Call(" Server Busy.", 0)                       ; Update updating info.
          ; =========================================================================================
            
            Return -1
          , this.FUNC_DEBUG.Call("PinboardDbHandler.UpdateDb -> Update interrupted: [SERVER BUSY]`n", 1)
        }
        
        ; Get the update time from the XML answer and reset the index for doubling WAIT_TIME.
        this.BINVAR_OBJ.NEW_UPDATE      := this.GetUpdateTime(sXml)
        this.BINVAR_OBJ.IDXERR_P_UPDATE := 0
        
        ; If LAST_UPDATE == NEW_UPDATE the database doesn't need to be updated.
        If( this.BINVAR_OBJ.LAST_UPDATE == this.BINVAR_OBJ.NEW_UPDATE )
        {
            ; Write the helper variables.
            this.__WriteBinVar()
            
          ; =========================================================================================
            this.UPDATE_RUNNING := 0                                          ;  Toggle running flag.
            this.FUNC_CALLBACK.Call(" DB already updated.", 0)                ; Update updating info.
          ; =========================================================================================
            
            Return 0
          , this.FUNC_DEBUG.Call("PinboardDbHandler.UpdateDb -> Update interrupted: [DATABASE ALREADY UPDATED]`n", 1)
        }
        
        ; Sleep LIMIT_P_UPDATE seconds before calling posts/all and update WAIT_TIME and LAST_CALL.
        Sleep, % this.LIMIT_P_UPDATE * 1000
        sXml := this.PINBOARD_CONNECTOR.Pinboard_Posts_All() 
        this.BINVAR_OBJ.WAIT_TIME := this.LIMIT_P_ALL
        this.BINVAR_OBJ.LAST_CALL := A_Now
        
        ; If the answer is not correct XML...
        If ( !sXml )
        {
            ; Double WAIT_TIME.
            this.BINVAR_OBJ.WAIT_TIME := this.LIMIT_P_ALL * (2 ** this.BINVAR_OBJ.IDXERR_P_ALL++)
            ; Write the helper variables.
            this.__WriteBinVar()
            
          ; =========================================================================================
            this.UPDATE_RUNNING := 0                                          ;  Toggle running flag.
            this.FUNC_CALLBACK.Call(" Server Busy.", 0)                       ; Update updating info.
          ; =========================================================================================
            
            Return -1
          , this.FUNC_DEBUG.Call("PinboardDbHandler.UpdateDb -> Update interrupted: [SERVER BUSY]`n", 1)
        }
        
        ; If we are here, it means that we received a new database from Pinboard.
        ; 1st: We delete the old one and append the new one.
        FileDelete,         % this.DB_FILENAME
        FileAppend, %sXml%, % this.DB_FILENAME
        ; 2nd: We update LAST_UPDATE with the NEW_UPDATE value and reset the index for doubling WAIT_TIME.
        this.BINVAR_OBJ.LAST_UPDATE  := this.BINVAR_OBJ.NEW_UPDATE
        this.BINVAR_OBJ.IDXERR_P_ALL := 0
        ; 3d: As usual we write the helper variables.
        this.__WriteBinVar()

      ; =============================================================================================
        this.UPDATE_RUNNING := 0                                              ;  Toggle running flag.
        this.FUNC_CALLBACK.Call(" Done.", 0)                                  ; Update updating info.
      ; =============================================================================================
        
        Return 1
      , this.FUNC_DEBUG.Call("PinboardDbHandler.UpdateDb -> Update terminated.`n", 1)
    }
    
    ; Get the database as a string.
    ; Return the database as a string or 0 on FileRead error.
    GetDbString()
    {
        FileRead, sXml, % this.DB_FILENAME
        bErr := ErrorLevel
        this.FUNC_DEBUG.Call( "PinboardDbHandler.GetDbString -> " 
                            . (( bErr ) ? "FileRead error" : "Database file read success") ".`n", 1 )
        Return (( bErr ) ? 0 : sXml)
    }
    
    ; Get the address of the database object, to be converted with Object(x).
    ; Return the address of the object or 0 if database is not initialized.
    GetDbObject()
    {
        bObj := IsObject(this.DB_OBJ)
        this.FUNC_DEBUG.Call( "PinboardDbHandler.GetDbObject -> "
                            . (( bObj ) ? "Database load success" : "Database not initialized") ".`n", 1 )
        Return ( bObj ) ? Object(this.DB_OBJ) : 0
    }
    
    ; Get the update time contained in the XML.
    GetUpdateTime(sXml)
    {
        If ( (oXml := ComObjCreate("MSXML2.DOMDocument.6.0")) == "" )
            Return 0
          , this.FUNC_DEBUG.Call("PinboardDbHandler.GetUpdateTime -> COM error.`n", 1)

        oXml.async := false, oXml.loadXML(sXml)
        nTime := oXml.selectSingleNode("//update").attributes.getNamedItem("time").text, oXml := ""

        Return  nTime
      , this.FUNC_DEBUG.Call("PinboardDbHandler.GetUpdateTime -> Update time retrieved: [" nTime "]`n", 1)
    }
}
