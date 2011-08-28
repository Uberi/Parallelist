#NoEnv

#Warn All

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
;Job.AddWorker()
;Job.RemoveWorker()
MsgBox % ShowObject(Job)
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
Job.Close()
ExitApp

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
 Return, Object("ScriptCode",ScriptCode,"WindowID",hWindow,"Working",0,"Queue",Array(),"Result",Array(),"Workers",Array(),"AddWorker",Func("ParallelistAddWorker"),"RemoveWorker",Func("ParallelistRemoveWorker"),"Start",Func("ParallelistStartJob"),"Stop",Func("ParallelistStopJob"),"Close",Func("ParallelistCloseJob"))
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
 OnExit, ExitSub
 Return

 ExitSub:
 MsgBox, Exiting
 ExitApp

 ;incoming message handler
 ParallelistReceiveData(wParam,lParam)
 {
  Command := NumGet(lParam + 0) ;retrieve the command to perform
  Length := NumGet(lParam + A_PtrSize,0,"UInt") ;retrieve the length of the data
  VarSetCapacity(Data,Length), DllCall("RtlMoveMemory","UPtr",&Data,"UPtr",NumGet(lParam + A_PtrSize + 4),"UPtr",Length) ;copy the data into a variable
  MsgBox, Received "`%Data`%" from the main script. `%Length`%
  Return, 1
 }

 ParallelistProcessTask:

 )
 ScriptCode .= This.ScriptCode ;insert the script code

 ;create a worker process in an idle state
 If ParallelistOpenWorker(This,ScriptCode,hWorker) ;could not start worker
  Return, 1
 ObjInsert(This.Workers,hWorker) ;append the worker to the worker array
 Return, 0
}

ParallelistRemoveWorker(This)
{ ;returns 1 on error, 0 otherwise
 Workers := This.Workers, Index := ObjMaxIndex(Workers)
 If Index ;workers are still present
 {
  ParallelistCloseWorker(Workers[Index]) ;close the worker
  ObjRemove(Workers,Index) ;remove the worker from the worker list
  Return, 0
 }
 Return, 1 ;no workers to remove
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
 For Index, hWorker In This.Workers
  ParallelistCloseWorker(hWorker)
}

#Include Functions.ahk