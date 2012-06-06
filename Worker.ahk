class Worker
{
    static WorkerIndex := 0

    __New()
    {
        this.base.WorkerIndex ++

        ;create named pipes to hold the worker code
        PipeName := "\\.\pipe\ParallelistWorker" . A_ScriptHwnd . "_" . this.base.WorkerIndex ;create a globally unique pipe name
        hTempPipe := DllCall("CreateNamedPipe","Str",PipeName,"UInt",2,"UInt",0,"UInt",255,"UInt",0,"UInt",0,"UInt",0,"UInt",0) ;temporary pipe
        If hTempPipe = -1
            throw Exception("Could not create temporary named pipe.")
        hExecutablePipe := DllCall("CreateNamedPipe","Str",PipeName,"UInt",2,"UInt",0,"UInt",255,"UInt",0,"UInt",0,"UInt",0,"UInt",0) ;executable pipe
        If hExecutablePipe = -1
            throw Exception("Could not create executable named pipe.")

        ;start the worker
        CodePage := A_IsUnicode ? 1200 : 65001 ;UTF-16 or UTF-8
        Run, % """" . A_AhkPath . """ /CP" . CodePage . " """ . PipeName . """ " . A_ScriptHwnd . " " . &this,, UseErrorLevel, WorkerPID
        If ErrorLevel
        {
            DllCall("CloseHandle","UPtr",hTempPipe) ;close the temporary pipe
            DllCall("CloseHandle","UPtr",hExecutablePipe) ;close the executable pipe
            throw Exception("Could not start worker.")
        }

        ;wait for the worker to connect to the temporary pipe and close it
        DllCall("ConnectNamedPipe","UPtr",hTempPipe,"UPtr",0)
        DllCall("CloseHandle","UPtr",hTempPipe)

        ;wait for the worker to connect the executable pipe and transfer the code
        DllCall("ConnectNamedPipe","UPtr",hExecutablePipe,"UPtr",0)
        DllCall("WriteFile","UPtr",hExecutablePipe,"UPtr",&ScriptCode,"UInt",StrLen(ScriptCode) << !!A_IsUnicode,"UPtr",0,"UPtr",0)
        DllCall("CloseHandle","UPtr",hExecutablePipe) ;send the script code

        ;obtain a handle to the worker
        DetectHidden := A_DetectHiddenWindows
        DetectHiddenWindows, On
        WinWait, ahk_pid %WorkerPID%,, 5 ;wait up to five seconds for the script to start
        If ErrorLevel ;worker could not be found
        {
            DetectHiddenWindows, %DetectHidden%
            Process, Close, %WorkerPID% ;close the worker process
            throw Exception("Could not obtain worker handle.")
        }
        this.hWorker := WinExist() ;retrieve the worker ID
        DetectHiddenWindows, %DetectHidden%
    }

    Close()
    {
        DetectHidden := A_DetectHiddenWindows
        DetectHiddenWindows, On
        WinClose, % "ahk_id " . this.hWorker ;send the WM_CLOSE message to the worker to allow it to clean up
        WinWaitClose, % "ahk_id " . hWorker ;wait for the worker to close
        DetectHiddenWindows, %DetectHidden%
    }

    Send(ByRef Data,Length = -1)
    {
        If Length = -1
            Length := StrLen(Data)

        ;set up the COPYDATASTRUCT structure
        VarSetCapacity(CopyDataStruct,4 + (A_PtrSize << 1)) ;structure contains an integer field and two pointer sized fields
        ;NumPut(0,CopyDataStruct,0) ;set data type ;wip: not needed
        NumPut(Length,CopyDataStruct,A_PtrSize,"UInt") ;insert the length of the data to be sent
        NumPut(&Data,CopyDataStruct,A_PtrSize << 1) ;insert the address of the data to be sent

        ;send the data to the worker
        DetectHidden := A_DetectHiddenWindows
        DetectHiddenWindows, On
        SendMessage, 0x4A, 0, &CopyDataStruct,, ahk_id %hWorker% ;send the WM_COPYDATA message to the window
        DetectHiddenWindows, %DetectHidden%
        If (ErrorLevel = "FAIL") ;could not send the message
            throw Exception("Could not send data to worker.")
    }
}