;initializes the message handler
ParallelistInitializeMessageHandler()
{
 OnMessage(0x4A,"ParallelistHandleWorkerMessage") ;WM_COPYDATA
}

;handles messages sent by workers
ParallelistHandleWorkerMessage(WorkerID,pCopyDataStruct)
{
 Critical

 Job := Object(NumGet(pCopyDataStruct + 0)) ;retrieve the job object from the pointer given

 ;find the worker in the queue
 WorkerIndex := 0
 For Index, Value In Job.Workers.Active ;iterate through the active workers queue to find the index of the worker ;wip: there should be a faster way to do this
 {
  If (Value = WorkerID) ;found the worker in the queue
   WorkerIndex := Index
 }
 If (WorkerIndex = 0) ;window ID was not found in the worker queue
  Return, 1 ;message came from an unknown window, can safely ignore

 Length := NumGet(pCopyDataStruct + A_PtrSize,0,"UInt") ;retrieve the length of the data
 VarSetCapacity(Data,Length), DllCall("RtlMoveMemory","UPtr",&Data,"UPtr",NumGet(pCopyDataStruct + A_PtrSize + 4),"UPtr",Length) ;copy the data from the structure

 ParallelistReceiveResult(Job,WorkerIndex,Data,Length)
}

ShowObject(ShowObject,Padding = "")
{
 ListLines, Off
 If !IsObject(ShowObject)
 {
  ListLines, On
  Return, ShowObject
 }
 ObjectContents := ""
 For Key, Value In ShowObject
 {
  If IsObject(Value)
   Value := "`n" . ShowObject(Value,Padding . A_Tab)
  ObjectContents .= Padding . Key . ": " . Value . "`n"
 }
 ObjectContents := SubStr(ObjectContents,1,-1)
 If (Padding = "")
  ListLines, On
 Return, ObjectContents
}

;sends data to a window
ParallelistSendData(hWorker,ByRef Data,DataSize) ;window ID, number to be sent, data to be sent, length of the data in bytes
{ ;returns 1 on send failure, 0 otherwise
 VarSetCapacity(CopyData,4 + (A_PtrSize << 1),0) ;COPYDATASTRUCT contains an integer field and two pointer sized fields
 NumPut(DataSize,CopyData,A_PtrSize,"UInt") ;insert the length of the data to be sent
 NumPut(&Data,CopyData,A_PtrSize << 1) ;insert the address of the data to be sent
 DetectHidden := A_DetectHiddenWindows
 DetectHiddenWindows, On ;hidden window detection required to send the message
 SendMessage, 0x4A, 0, &CopyData,, ahk_id %hWorker% ;send the WM_COPYDATA message to the window
 DetectHiddenWindows, %DetectHidden%
 If (ErrorLevel = "FAIL") ;could not send the message
  Return, 1
 Return, 0
}

;opens a worker
ParallelistOpenWorker(Job,ByRef ScriptCode,ByRef hWorker) ;job object, worker code
{ ;returns 1 on worker start failure, 0 otherwise
 WorkerIndex := ObjMaxIndex(Job.Workers.Idle), WorkerIndex := (WorkerIndex = "") ? 1 : (WorkerIndex + 1) ;find the index of the current worker in the idle array
 Temp1 := ObjMaxIndex(Job.Workers.Active), (Temp1 != "") ? (WorkerIndex += Temp1) ;find the index of the current worker in the active array

 PipeName := "\\.\pipe\ParallelistJob" . &Job . "Worker" . WorkerIndex ;create a pipe name that is unique across jobs and worker indexes
 hPipe1 := DllCall("CreateNamedPipe","Str",PipeName,"UInt",2,"UInt",0,"UInt",255,"UInt",0,"UInt",0,"UInt",0,"UInt",0) ;temporary pipe
 hPipe2 := DllCall("CreateNamedPipe","Str",PipeName,"UInt",2,"UInt",0,"UInt",255,"UInt",0,"UInt",0,"UInt",0,"UInt",0) ;executable pipe
 CodePage := A_IsUnicode ? 1200 : 65001 ;UTF-16 or UTF-8
 Run, % """" . A_AhkPath . """ /CP" . CodePage . " """ . PipeName . """ " . A_ScriptHwnd . " " . &Job,, UseErrorLevel, WorkerPID ;run the script with the window and job ID as the parameter
 If ErrorLevel ;could not run the script
 {
  DllCall("CloseHandle","UPtr",hPipe1), DllCall("CloseHandle","UPtr",hPipe2) ;close the created pipes
  Return, 1
 }
 DllCall("ConnectNamedPipe","UPtr",hPipe1,"UPtr",0), DllCall("CloseHandle","UPtr",hPipe1) ;use temporary pipe
 DllCall("ConnectNamedPipe","UPtr",hPipe2,"UPtr",0), DllCall("WriteFile","UPtr",hPipe2,"UPtr",&ScriptCode,"UInt",StrLen(ScriptCode) << !!A_IsUnicode,"UPtr",0,"UPtr",0), DllCall("CloseHandle","UPtr",hPipe2) ;send the script code

 DetectHidden := A_DetectHiddenWindows
 DetectHiddenWindows, On ;need to detect a hidden window
 WinWait, ahk_pid %WorkerPID%,, 5 ;wait up to five seconds for the script to start
 hWorker := WinExist("ahk_pid " . WorkerPID) ;retrieve the worker ID
 DetectHiddenWindows, %DetectHidden%
 If !hWorker ;could not find the worker window
  Return, 1
 Return, 0
}

;closes a worker
ParallelistCloseWorker(hWorker)
{ ;returns 1 on worker close error, 0 otherwise
 DetectHidden := A_DetectHiddenWindows
 DetectHiddenWindows, On ;need to detect a hidden window
 WinClose, ahk_id %hWorker% ;send the WM_CLOSE message to the worker to allow it to execute any OnExit routines
 DetectHiddenWindows, %DetectHidden%
}