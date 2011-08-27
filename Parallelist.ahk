#NoEnv

;wip: Job.WaitFinish() function
;wip: singly linked list queue
;wip: outputs should be in the same order as the inputs
;wip: restructure library into a class
;wip: restructure IPC to use sockets, so the library works over a network. have the design support multiple partitioners for better scalability. paritioning can be done with BucketIndex := Mod(Hash(Key),BucketCount)
;wip: store the idle workers in a separate queue so they can be rapidly found when there is work to be done again. periodically give out heartbeats to detect worker failures and close or cleanup the worker. the master server should log worker and scheduling state to storage periodically, so when master is restarted, it can read in the state again and keep scheduling. worker should wait if the master does not respond, and then send the data again when it receives the new master's startup ping
;wip: automatically start up workers based on available processing units. automatically close workers if they take too long to complete a task or stop responding to pings

ScriptCode = 
(
Parallelist.Output := "Worker " . WorkerIndex . " has completed the task:``n``n""" . Parallelist.Data . """"
)

Job := ParallelistOpenJob(ScriptCode)
Job.AddWorker()
MsgBox % ShowObject(Job)
;Job.AddWorker()
;Job.RemoveWorker()
Job.Queue := Array("task1","task2","task3","task4","task5","task6","task7","task8","task9")
Job.Start
While, Job.Working
 Sleep, 1
For Index, Value In Job.Result
 MsgBox Index: %Index%`nValue: %Value%
Job.Stop()
Job.Close()
ExitApp

Esc::
DetectHiddenWindows, On
For Index, Worker In Job.Workers
 WinKill, ahk_id %Worker%
ExitApp
Space::ParallelistSendData(Job.Workers.1,_ := "abcdef",7 << A_IsUnicode)

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

ParallelistOpenJob(ByRef ScriptCode)
{
 Gui, +LastFound
 hWindow := WinExist() ;get ID of script window
 Return, Object("ScriptCode",ScriptCode,"WindowID",hWindow,"Working",0,"Queue",Array(),"Result",Array(),"Workers",Array(),"AddWorker",Func("ParallelistAddWorker"),"RemoveWorker",Func("ParallelistRemoveWorker"),"Start",Func("ParallelistStartJob"),"Stop",Func("ParallelistStopJob"))
}

;wip: error check all the DllCall()'s
ParallelistAddWorker(This)
{ ;returns 1 on error, 0 otherwise
 ;prepare the script code for usage
 ScriptCode = ;insert the multiprocessing wrapper
 ( LTrim
 ;#NoTrayIcon
 #SingleInstance Force
 ParallelistMainWindowID = `%1`% ;retrieve the window ID of the main script
 OnMessage(0x4A,"ParallelistReceiveData") ;WM_COPYDATA
 Return

 ;incoming message handler
 ParallelistReceiveData(wParam,lParam)
 {
  Command := NumGet(lParam + 0) ;retrieve the command to perform
  Length := NumGet(lParam + A_PtrSize,0,"UInt") ;retrieve the length of the data
  VarSetCapacity(Data,Length), DllCall("RtlMoveMemory","UPtr",&Data,"UPtr",NumGet(lParam + A_PtrSize + 4),"UInt",Length) ;copy the data into a variable
  MsgBox, Received "`%Data`%" from the main script. `%Length`%
  Return, 1
 }

 ParallelistProcessTask:

 )
 ScriptCode .= This.ScriptCode ;insert the script code

 ;create a worker process in an idle state
 Suffix := A_IsUnicode ? "W" : "A"
 WorkerIndex := ObjMaxIndex(This.Workers), (WorkerIndex = "") ? (WorkerIndex := 1) : (WorkerIndex ++) ;find the index of the current worker
 PipeName := "\\.\pipe\ParallelistJob" . &This . "Worker" . WorkerIndex ;create a pipe name that is unique across jobs and worker indexes
 hPipe1 := DllCall("CreateNamedPipe" . Suffix,"Str",PipeName,"UInt",2,"UInt",0,"UInt",255,"UInt",0,"UInt",0,"UInt",0,"UInt",0) ;temporary pipe
 hPipe2 := DllCall("CreateNamedPipe" . Suffix,"Str",PipeName,"UInt",2,"UInt",0,"UInt",255,"UInt",0,"UInt",0,"UInt",0,"UInt",0) ;executable pipe
 CodePage := A_IsUnicode ? 1200 : 65001 ;UTF-16 or UTF-8
 Run, % """" . A_AhkPath . """ /CP" . CodePage . " """ . PipeName . """ " . This.WindowID,, UseErrorLevel, WorkerPID ;run the script with the window ID as the parameter
 If ErrorLevel ;could not run the script
 {
  DllCall("CloseHandle","UPtr",hPipe1), DllCall("CloseHandle","UPtr",hPipe2) ;close the created pipes
  Return, 1
 }
 DllCall("ConnectNamedPipe","UPtr",hPipe1,"UPtr",0), DllCall("CloseHandle","UPtr",hPipe1) ;use temporary pipe
 DllCall("ConnectNamedPipe","UPtr",hPipe2,"UPtr",0), DllCall("WriteFile","UPtr",hPipe2,"UPtr",&ScriptCode,"UInt",StrLen(ScriptCode) << !!A_IsUnicode,"UPtr",0,"UPtr",0), DllCall("CloseHandle","UPtr",hPipe2) ;send the script code
 DetectHidden := A_DetectHiddenWindows
 DetectHiddenWindows, On
 WinWait, ahk_pid %WorkerPID%,, 5 ;wait up to five seconds for the script to start
 If ErrorLevel ;could not find the worker
 {
  DetectHiddenWindows, %DetectHidden%
  Return, 1
 }
 hWindow := WinExist("ahk_pid " . WorkerPID)
 DetectHiddenWindows, %DetectHidden%
 If !hWindow ;could not find worker's main window
  Return, 1
 ObjInsert(This.Workers,WorkerIndex,hWindow)
 Return, 0
}

ParallelistRemoveWorker(This)
{
 
}

ParallelistStartJob(This)
{
 For Index, Worker In This.Workers
  ;wip: send a message to the workers notifying that the job is to be started
 This.Working := 1
}

ParallelistStopJob(This)
{
 For Index, Worker In This.Workers
  ;wip: send a message to the workers notifying that the job is to be stopped
 This.Working := 1
}

ParallelistCloseJob(This)
{
 ;For Index, Worker In This.Workers
  ;wip: execute an exitapp on the worker so they can run their OnExit routines
}

ParallelistSendData(hWindow,ByRef Data,DataSize) ;wip: not sure if the Ptr type is right for the CopyDataStruct, also check the receiver too
{ ;returns 1 on error, 0 otherwise
 VarSetCapacity(CopyData,4 + (A_PtrSize << 1),0) ;an integer and two pointer sized fields
 NumPut(DataSize,CopyData,0)
 NumPut(DataSize,CopyData,A_PtrSize,"UInt")
 NumPut(&Data,CopyData,A_PtrSize << 1)
 DetectHidden := A_DetectHiddenWindows
 DetectHiddenWindows, On
 SendMessage, 0x4A, 0, &CopyData,, ahk_id %hWindow% ;send a WM_COPYDATA message to the script
 DetectHiddenWindows, %DetectHidden%
 If (ErrorLevel = "FAIL") ;could not send the message
  Return, 1
 Return, 0
}