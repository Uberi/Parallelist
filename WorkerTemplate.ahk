#NoEnv

ParallelistGetWorkerTemplate(ByRef ScriptCode)
{
 Code = 
 ( LTrim
 ;#NoTrayIcon ;wip: debug
 ParallelistMainWindowID = `%1`% ;retrieve the window ID of the main script
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

 ParallelistWorkerTaskHook:
 WorkerProcess(Parallelist) ;call the user defined processing function
 ParallelistSendResult(Window)
 Return

 ParallelistWorkerExitHook:
 WorkerUninitialize() ;call the user defined uninitialization function
 ExitApp

 ParallelistSendResult()
 {
  
 }

 %ScriptCode%
 )
 Return, Code
}