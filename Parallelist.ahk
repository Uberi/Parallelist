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

#Warn All
#Warn LocalSameAsGlobal, Off

;wip: Job.WaitFinish() function that waits for active queue to be empty
;wip: singly linked list queue
;wip: outputs should be in the same order as the inputs
;wip: restructure IPC to use sockets, so the library works over a network. have the design support multiple partitioners for better scalability. paritioning can be done with BucketIndex := Mod(Hash(Key),BucketCount)
;wip: periodically give out heartbeats to detect worker failures and close or cleanup the worker (or detect if it times out processing a task). the master server should log worker and scheduling state to storage periodically, so when master is restarted, it can read in the state again and keep scheduling. worker should wait if the master does not respond, and then send the data again when it receives the new master's startup ping
;wip: automatically start up workers based on available processing units. automatically close workers if they take too long to complete a task or stop responding to pings

WorkerCode = 
(
class Worker
{
    __New()
    {
        ;startup code goes here, throws exception on error
    }

    __Delete()
    {
        ;cleanup code goes here, throws exception on error
    }

    Process(Task)
    {
        ;task processing code goes here, throws exception on error
        Task.Result := "Finished " . Task.Data . "."
    }
}
)

Counter := 0
Job := new Parallelist(WorkerCode)
Loop, 2
    Job.AddWorker()
Job.RemoveWorker()
Job.Queue := ["task1","task2","task3","task4","task5","task6","task7","task8","task9"]
Job.Start()
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

class Parallelist
{
    __New(WorkerCode,Worker = "")
    {
        global LocalWorker
        If IsObject(Worker)
            this.Worker := Worker
        Else
            this.Worker := LocalWorker

        this.WorkerCode := WorkerCode
        this.Working := False
        this.Workers := Object()
        this.Workers.Active := Object()
        this.Workers.Idle := Object()
        this.Queue := []
        this.Result := []
    }

    AddWorker()
    {
        Worker := new this.Worker(this.WorkerCode)
        this.Workers.Idle[Worker] := 0
    }

    RemoveWorker()
    {
        If !this.Workers.Idle.NewEnum().Next(Worker) ;no idle workers
            throw Exception("No idle workers to remove.")
        this.Workers.Idle.Remove(Worker)
    }

    Start()
    {
        If !this.Workers.Idle.NewEnum().Next(Worker)
            throw Exception("No idle workers to start.")
        this.Working := True
        For Worker In this.Workers.Idle
        {
            Task := this.Queue.Remove(1)
            Worker.Send(Task) ;wip: length
        }
    }

    Stop()
    {
        For Worker In this.Workers.Active
        {
            ;wip: send pause message to workers
        }
        this.Working := False
    }

    Receive(Result)
    {
        ;wip
    }
}

#Include LocalWorker.ahk