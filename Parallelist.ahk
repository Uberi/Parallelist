#NoEnv

;MsgBox % ComObjGet("winmgmts:root\cimv2:Win32_Processor='cpu0'").CurrentClockSpeed

/*
Copyright 2011 Anthony Zhang <azhang9@gmail.com>

This file is part of Parallelist. Source code is available at <https://github.com/Uberi/Parallelist>.

Parallelist is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

;wip: better error checking everywhere any functions.ahk function is called. assume each one is able to fail.
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
 Parallelist.Output := "Worker has completed the task:``n``n""" . Parallelist.Data . """"
 Return, 0
}

WorkerUninitialize()
{ ;returns 1 on error, 0 otherwise
 Return, 0
}
)

Counter := 0
Job := ParallelistOpenJob(ScriptCode)
Loop, 2
 Job.AddWorker()
Job.RemoveWorker()
Job.Queue := Array("task1","task2","task3","task4","task5","task6","task7","task8","task9")
Job.Start()
While, Job.Working
 Sleep, 1
For Index, Value In Job.Result
 MsgBox Index: %Index%`nValue: %Value%
Job.Stop()
Job.Close()
ExitApp

Tab::
If !ObjNewEnum(Job.Workers.Idle).Next(hWorker)
 Return ;no idle workers available
Job.Workers.Active[hWorker] := 0
Counter ++, Temp1 := "Something" . Counter
ParallelistSendData(hWorker,Temp1,StrLen(Temp1) << !!A_IsUnicode)
Return

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
 This.Workers.Idle[hWorker] := 0 ;insert the worker into the idle worker array
 Return, 0
}

ParallelistRemoveWorker(This)
{ ;returns 1 on error, 0 otherwise
 IdleWorkers := This.Workers.Idle
 If ObjNewEnum(IdleWorkers).Next(hWorker) ;idle workers are still present
 {
  ParallelistCloseWorker(hWorker) ;close the worker
  ObjRemove(IdleWorkers,hWorker,"") ;remove the worker from the worker list
  Return, 0
 }
 Return, 1 ;no workers to remove
}

ParallelistStartJob(This)
{
 For hWorker In This.Workers.Idle
  ;wip: send a message to the workers notifying that the job is to be started
 This.Working := 1
}

ParallelistStopJob(This)
{
 For hWorker In This.Workers.Active
  ;wip: send a message to the workers notifying that the job is to be stopped
 This.Working := 0
}

ParallelistCloseJob(This)
{
 CloseError := 0
 For hWorker In This.Workers.Idle
  CloseError := ParallelistCloseWorker(hWorker) || CloseError
 This.Workers.Idle := Array() ;clear the idle workers array
 This.Working := 0
 Return, CloseError
}

ParallelistReceiveResult(This,hWorker,ByRef Result,Length)
{
 Workers := This.Workers
 ObjRemove(Workers.Active,hWorker,""), Workers.Idle[hWorker] := 0 ;move the worker entry from the active queue to the idle queue
 MsgBox % StrGet(&Result,Length)
}

#Include Functions.ahk
#Include WorkerTemplate.ahk