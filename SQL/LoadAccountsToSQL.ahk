#SingleInstance, force
CoordMode, Mouse, Screen
SetTitleMatchMode, 3

#include *i %A_ScriptDir%\Class_SQLiteDB.ahk

; ========== Prepare SQLite DB ==========
; INTEGER, TEXT, BLOB, REAL, NUMERIC
sql_dllPath := A_ScriptDir . "\sqlite3.dll"
sql_DBPath := A_ScriptDir . "\poke.db"

if (FileExist(sql_dllPath)) {
	; Initiate the DB
	sql_DB := new SQLiteDB2(sql_dllPath)
	
	; Open our DB
	sql_existingDB := FileExist(sql_DBPath)
	If !sql_DB.OpenDB(sql_DBPath) {
		MsgBox, 16, SQLite Error, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode
		ExitApp
	 }
}

query := "SELECT account_id, accountBody FROM InjectAccounts WHERE last_used < (unixepoch() - (24*60*60)) AND deletedAccount = 0 ORDER BY RANDOM() LIMIT 1;"
;;HFILE := FileOpen("Blob.gif", "w")
If !sql_DB.Query(query, RecordSet)
   MsgBox, 16, SQLite Error: Query, % "Msg:`t" . RecordSet.ErrorMsg . "`nCode:`t" . RecordSet.ErrorCode
If (RecordSet.HasRows) {
   If (RecordSet.Next(Row) < 1) {
      MsgBox, 16, %A_ThisFunc%, % "Msg:`t" . RecordSet.ErrorMsg . "`nCode:`t" . RecordSet.ErrorCode
      return
   }
   account_id := Row[1]
   Size := Row[2].Size
   Addr := Row[2].GetAddress("Blob")
   If (Addr) && (Size) {
    VarSetCapacity(MyBLOBVar, Size) ; added
    DllCall("Kernel32.dll\RtlMoveMemory", "Ptr", &MyBLOBVar, "Ptr", Addr, "Ptr", Size) ; added
    ;;;;HFILE.RawWrite(&MyBLOBVar, Size) ; changed
    }
}
RecordSet.Free()
;;;;HFILE.Close()

ExitApp

saveDir := A_ScriptDir "\..\Accounts\Saved"

Loop Files, %saveDir%\*.xml, R
{
    xml := A_LoopFileLongPath
    SplitPath, xml, name, dir, ext, name_no_ext, driveLetter
    StringLeft, TimeFound, name, 14
    EnvSub, TimeFound, 1970, seconds
    FileGetTime, fileTime, %xml%, M
    EnvSub, fileTime, 1970, seconds
    ; timeDiff := A_Now - fileTime  ; Calculate time difference
    
    ;;;FileRead, FileBody, %xml%
    f := FileOpen(xml, "r")
    f.Pos := 0
    BytesRead := f.RawRead(FileBody, 1024*1024)
    f.Close()

    ;;BlobArray := []
    ;;BlobArray.Insert({Addr: &FileBody, Size: BytesRead})

    sql_DB.Exec("BEGIN TRANSACTION;")
    query =
    (
        INSERT INTO InjectAccounts (filename, created, last_used, accountBody)
        VALUES('%name%', '%TimeFound%', '%fileTime%', ?);
    )
    ;If !sql_DB.Exec(query)
    ;    MsgBox, 16, SQLite Error, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode
;    If !DB.StoreBLOB(SQL, BlobArray)
;        MsgBox, 16, SQLite Error, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode

    If !sql_DB.Prepare(query, ST)
        MsgBox, 16, sql_DB.Prepare, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode
    If !ST.Bind(1, "Blob", &FileBody, BytesRead)
        MsgBox, 16, ST.Bind, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode
    If !ST.Step()
        MsgBox, 16, ST.Step, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode
    If !ST.Reset()
        MsgBox, 16, ST.Reset, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode
    If !ST.Free()
        MsgBox, 16, ST.Free, % "Msg:`t" . sql_DB.ErrorMsg . "`nCode:`t" . sql_DB.ErrorCode



    sql_DB.Exec("COMMIT TRANSACTION;")
}
