#NoEnv

ParallelistGetWorkerTemplate(ByRef ScriptCode)
{
 Code = 
 ( LTrim
 ;#NoTrayIcon ;wip: debug

 ParallelistMainWindowID = `%1`% ;retrieve the window ID of the main script
 ParallelistJobID = `%2`% ;retrieve the job ID
 
 Parallelist := Object("Data",""
  ,"DataLength",0
  ,"Output",""
  ,"OutputLength",0)
 OnMessage(0x4A,"ParallelistReceiveData") ;WM_COPYDATA
 OnExit, ParallelistWorkerExitHook
 WorkerInitialize() ;call the user defined initialization function
 Return

 ;incoming message handler
 ParallelistReceiveData(wParam,lParam)
 {
  global Parallelist
  Critical
  Length := NumGet(lParam + A_PtrSize,0,"UInt") ;retrieve the length of the data

  ObjSetCapacity(Parallelist,"Data",Length), Parallelist.DataLength := Length ;allocate memory and store the length of the data
  DllCall("RtlMoveMemory","UPtr",ObjGetAddress(Parallelist,"Data"),"UPtr",NumGet(lParam + A_PtrSize + 4),"UPtr",Length) ;copy the data from the structure

  SetTimer, ParallelistWorkerTaskHook, -0 ;dispatch a subroutine to handle the task processing
  Return, 1 ;successfully processed data ;wip: allow errors to be returned to the main script
 }

 ParallelistSendResult(hWindow,JobID,pData,Length)
 {
  VarSetCapacity(CopyData,4 + (A_PtrSize << 1),0) ;COPYDATASTRUCT contains an integer field and two pointer sized fields
  NumPut(JobID,CopyData) ;insert the length of the data to be sent
  NumPut(Length,CopyData,A_PtrSize,"UInt") ;insert the length of the data to be sent
  NumPut(pData,CopyData,A_PtrSize << 1) ;insert the address of the data to be sent
  DetectHidden := A_DetectHiddenWindows
  DetectHiddenWindows, On ;hidden window detection required to send the message
  SendMessage, 0x4A, A_ScriptHwnd, &CopyData,, ahk_id `%hWindow`% ;send the WM_COPYDATA message to the window
  DetectHiddenWindows, `%DetectHidden`%
  If (ErrorLevel = "FAIL") ;could not send the message
   Return, 1
  Return, 0
 }

 ParallelistWorkerTaskHook:
 Parallelist.OutputLength := -1 ;autodetect length
 WorkerProcess(Parallelist) ;call the user defined processing function
 ParallelistSendResult(ParallelistMainWindowID,ParallelistJobID,ObjGetAddress(Parallelist,"Output"),(Parallelist.OutputLength >= 0) ? Parallelist.OutputLength : StrLen(Parallelist.Output))
 Return

 ParallelistWorkerExitHook:
 WorkerUninitialize() ;call the user defined uninitialization function
 ExitApp

 %ScriptCode%
 )
 Return, Code
}