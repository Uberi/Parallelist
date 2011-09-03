#NoEnv

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

;initializes the message handler
ParallelistInitializeMessageHandler()
{
 OnMessage(0x4A,"ParallelistHandleWorkerMessage") ;WM_COPYDATA
}

;handles messages sent by workers
ParallelistHandleWorkerMessage(WorkerID,pCopyDataStruct)
{
 global ParallelistWorkerJob, ParallelistWorkerLength, ParallelistWorkerData, ParallelistWorkerID
 Critical

 ParallelistWorkerJob := Object(NumGet(pCopyDataStruct + 0)) ;retrieve the job object from the pointer given

 ParallelistWorkerLength := NumGet(pCopyDataStruct + A_PtrSize,0,"UInt") ;retrieve the length of the data
 VarSetCapacity(ParallelistWorkerData,ParallelistWorkerLength), DllCall("RtlMoveMemory","UPtr",&ParallelistWorkerData,"UPtr",NumGet(pCopyDataStruct + A_PtrSize + 4),"UPtr",ParallelistWorkerLength) ;copy the data from the structure

 SetTimer, ParallelistHandleWorkerMessage, -0
 Return, 1 ;successfully processed result
}

ParallelistHandleWorkerMessage:
ParallelistReceiveResult(ParallelistWorkerJob,ParallelistWorkerID,ParallelistWorkerData,ParallelistWorkerLength)
Return

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
ParallelistOpenWorker(Job,ByRef ScriptCode,ByRef hWorker) ;job object, worker code, variable to receive the worker handle
{ ;returns 1 on worker start failure, 0 otherwise
 static WorkerIndex := 0 ;initialize the worker index to zero
 WorkerIndex ++ ;increment the worker index so no two workers share the same index
 PipeName := "\\.\pipe\ParallelistWorker" . WorkerIndex ;create a pipe name that is unique across jobs and worker indexes
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
 hWorker := WinExist("ahk_pid " . WorkerPID) + 0 ;retrieve the worker ID
 DetectHiddenWindows, %DetectHidden%
 If !hWorker ;could not find the worker window
 {
  Process, Close, %WorkerPID% ;close the worker process if the window could not be found
  Return, 1
 }
 Return, 0
}

;closes a worker
ParallelistCloseWorker(hWorker)
{ ;returns 1 on worker close error, 0 otherwise
 DetectHidden := A_DetectHiddenWindows
 DetectHiddenWindows, On ;need to detect a hidden window
 WinClose, ahk_id %hWorker% ;send the WM_CLOSE message to the worker to allow it to execute any OnExit routines
 WinWaitClose, ahk_id %hWorker%,, 1
 CloseError := ErrorLevel
 DetectHiddenWindows, %DetectHidden%
 Return, !!CloseError
}