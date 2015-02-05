; ----------------------------------------------------------------------------------------------------------------------
; Name .........: NSSPinC - Not So Sucky Pinboard Client
; File .........: PinboardConnector.ahk - "Light" Pinboard API implementation.
; ----------------------------------------------------------------------------------------------------------------------

Class PinboardConnector
{
    ; Workaround to make __Call work also for static class method calling.
    ; http://ahkscript.org/boards/viewtopic.php?f=5&t=5933
    Static _ := (PinboardConnector := new PinboardConnector) && 0

    __New(sApiToken, fDebug)
    {
        ; This assignment must be the first, because of the
        ; __Call method returning "NO_OBJECT" if not set.
        this.API_TOKEN  := sApiToken
        
        this.FUNC_DEBUG := fDebug
        
        Return this
      , this.FUNC_DEBUG.Call("PinboardConnector object created.`n", 1)
    }
    
    ; Release and empty all objects/vars.
    __Delete()
    {
        this.API_TOKEN := "", this.FUNC_DEBUG := ""
    }

    ; All methods return "NO_OBJECT" if the object is not instantiated.
    ; Require the _ static class variable workaround.
    __Call()
    {
        If ( !this.API_TOKEN )
            Return "NO_OBJECT"
    }
    
    ; Open the URL and return server response.
    __OpenURL(sURL)
    {        
        hMod  := DllCall( "Kernel32.dll\LoadLibrary",    Str,"Wininet.dll"                                           )
        hInet := DllCall( "Wininet.dll\InternetOpen",    Str,"AutoHotkey", UInt,0, Str,"", Str,"", UInt,0            )
        hURL  := DllCall( "Wininet.dll\InternetOpenUrl", Ptr,hInet, Str,sURL, Str,"", Int,0, UInt,0x80000000, UInt,0 )
        VarSetCapacity(cBuf, 1024, 0), VarSetCapacity(nRead, 4, 0)
        
        Loop
        {
            bFlag := DllCall( "Wininet.dll\InternetReadFile", Ptr,hURL, Ptr,&cBuf, UInt,1024, Ptr,&nRead )
            szBuf := NumGet(nRead)
            If ( (bFlag) && (!szBuf) )
                Break
            sRetStr := sRetStr . StrGet(&cBuf, szBuf, A_FileEncoding)
        }
        
        DllCall( "Wininet.dll\InternetCloseHandle", Ptr,hInet ) 
        DllCall( "Wininet.dll\InternetCloseHandle", Ptr,hURL  ) 
        DllCall( "Kernel32.dll\FreeLibrary",        Ptr,hMod  )
        Return sRetStr
      , this.FUNC_DEBUG.Call("__OpenURL -> Opened API URL: [" sUrl "]`n", 1)
    }
    
    ; Implement the Pinboard posts/all API, return an array of post objects.
    ; REMEMBER: posts/all is a restricted API, once every 5 minutes.
    ; Return: sXml - Server response as XML string.
    ;         0     - Server error.
    Pinboard_Posts_All(tag:="", start:="", results:="", fromdt:="", todt:="", meta:="")
    {
        sQuery := "https://api.pinboard.in/v1/posts/all?format=xml"
                  . ((tag)     ? "&tag=" tag : "")
                  . ((start)   ? "&start=" start : "")
                  . ((results) ? "&results=" results : "")
                  . ((fromdt)  ? "&fromdt=" fromdt : "")
                  . ((todt)    ? "&todt=" todt : "")
                  . ((meta)    ? "&meta=" meta : "")
                  . "&auth_token=" this.API_TOKEN
        sXml   := this.__OpenURL(sQuery)
        
        ; Trivial check, to discriminate between error response or XML.
        If ( !RegexMatch(sXml, "S)<[\s\S]*>") )
            Return 0 ; Server Error
          , this.FUNC_DEBUG.Call("PinboardConnector.Pinboard_Posts_All -> posts/all error.`n", 1)
        
        Return sXml
      , this.FUNC_DEBUG.Call("PinboardConnector.Pinboard_Posts_All -> posts/all API called.`n", 1)
    }
    
    ; Implement the Pinboard posts/update API, return the update time of last post.
    ; REMEMBER: posts/update is a restricted API, once every 3 seconds.
    ; Return: sXml - Server response as XML string.
    ;         0     - Server error.
    Pinboard_Posts_Update()
    {
        sQuery := "https://api.pinboard.in/v1/posts/update?format=xml&auth_token=" this.API_TOKEN       
        sXml   := this.__OpenURL(sQuery)
        
        ; Trivial check, to discriminate between error response or XML.
        If ( !RegexMatch(sXml, "S)<[\s\S]*>") )
            Return 0 ; Server Error
          , this.FUNC_DEBUG.Call("PinboardConnector.Pinboard_Posts_Update -> posts/update error.`n", 1)
            
        Return sXml
      , this.FUNC_DEBUG.Call("PinboardConnector.Pinboard_Posts_Update -> posts/update API called.`n", 1)
    }
}
