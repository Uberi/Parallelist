#NoEnv

;#Warn All

;wip: licensing and headers (AGPLv3)
;wip: Job.WaitFinish() function that waits for active queue to be empty
;wip: singly linked list queue
;wip: outputs should be in the same order as the inputs
;wip: restructure library into a class
;wip: restructure IPC to use sockets, so the library works over a network. have the design support multiple partitioners for better scalability. paritioning can be done with BucketIndex := Mod(Hash(Key),BucketCount)
;wip: periodically give out heartbeats to detect worker failures and close or cleanup the worker (or detect if it times out processing a task). the master server should log worker and scheduling state to storage periodically, so when master is restarted, it can read in the state again and keep scheduling. worker should wait if the master does not respond, and then send the data again when it receives the new master's startup ping
;wip: automatically start up workers based on available processing units. automatically close workers if they take too long to complete a task or stop responding to pings

ScriptCode = 
(
WorkerInitialize()
{ ;returns 1 on error, 0 otherwise
 Return, 0
}

WorkerProcess(ByRef Parallelist)
{ ;returns 1 on error, 0 otherwise
 Parallelist.Output := "Worker " . WorkerIndex . " has completed the task:``n``n""" . Parallelist.Data . """"
 Return, 0
}

WorkerUninitialize()
{ ;returns 1 on error, 0 otherwise
 Return, 0
}
)

Job := ParallelistOpenJob(ScriptCode)
Job.AddWorker()
Job.AddWorker()
Job.RemoveWorker()
Job.Queue := Array("task1","task2","task3","task4","task5","task6","task7","task8","task9")
Job.Start()
MsgBox
While, Job.Working ;wip: not sure if this is still needed
 Sleep, 1
For Index, Value In Job.Result
 MsgBox Index: %Index%`nValue: %Value%
Job.Stop()
Job.Close()
ExitApp

Space::
hWorker := ObjRemove(Job.Workers.Idle)
ObjInsert(Job.Workers.Active,hWorker)
ParallelistSendData(hWorker,"Something",10 << !!A_IsUnicode)
Return

Tab::MsgBox % WinExist("A") + 0

Esc::
Job.Close()
ExitApp

ParallelistOpenJob(ByRef ScriptCode)
{
 ParallelistInitializeMessageHandler()
 Return, Object("ScriptCode",ParallelistGetWorkerTemplate(ScriptCode)
  ,"Working",0 ;wip: not sure if still needed
  ,"Queue",Array()
  ,"Result",Array()
  ,"Workers"
   ,Object("Idle",Array()
   ,"Active",Array())
  ,"AddWorker",Func("ParallelistAddWorker")
  ,"RemoveWorker",Func("ParallelistRemoveWorker")
  ,"Start",Func("ParallelistStartJob")
  ,"Stop",Func("ParallelistStopJob")
  ,"Close",Func("ParallelistCloseJob"))
}

ParallelistAddWorker(This)
{ ;returns 1 on error, 0 otherwise
 If ParallelistOpenWorker(This,This.ScriptCode,hWorker) ;could not start worker
  Return, 1
 ObjInsert(This.Workers.Idle,hWorker) ;append the worker to the idle worker array
 Return, 0
}

ParallelistRemoveWorker(This)
{ ;returns 1 on error, 0 otherwise
 IdleWorkers := This.Workers.Idle, Index := ObjMaxIndex(IdleWorkers)
 If Index ;workers are still present
 {
  ParallelistCloseWorker(IdleWorkers[Index]) ;close the worker
  ObjRemove(IdleWorkers,Index) ;remove the worker from the worker list
  Return, 0
 }
 Return, 1 ;no workers to remove
}

ParallelistStartJob(This)
{
 For Index, Worker In This.Workers.Idle
  ;wip: send a message to the workers notifying that the job is to be started
 This.Working := 1
}

ParallelistStopJob(This)
{
 For Index, Worker In This.Workers.Active
  ;wip: send a message to the workers notifying that the job is to be stopped
 This.Working := 0
}

ParallelistCloseJob(This)
{
 For Index, hWorker In This.Workers.Idle
  ParallelistCloseWorker(hWorker)
}

ParallelistReceiveResult(This,WorkerIndex,ByRef Result,Length)
{
 Workers := This.Workers
 hWorker := Workers.Active[WorkerIndex], ObjRemove(Workers.Active,WorkerIndex), ObjInsert(Workers.Idle,hWorker) ;move the worker entry from the active queue to the idle queue
 MsgBox % Clipboard := WorkerIndex . "`n" . ShowObject(This)
}

#Include Functions.ahk
#Include WorkerTemplate.ahk