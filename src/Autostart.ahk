; Автозапуск: задача Планировщика при входе пользователя с наивысшими правами —
; так программа стартует с правами администратора без запроса UAC.
; Задача создаётся из XML: через ключи schtasks нельзя снять лимит в 3 дня
; и остановку при работе от батареи.

class Autostart {
    static taskName := "Language Indicator"

    static IsEnabled() => Autostart.Schtasks('/Query /TN "' Autostart.taskName '"') = 0

    ; true — получилось. Создать задачу с наивысшими правами можно только из процесса администратора.
    static Set(enable) {
        if !enable
            return !Autostart.IsEnabled() || Autostart.Schtasks('/Delete /TN "' Autostart.taskName '" /F') = 0
        xml := A_Temp "\language-indicator-task.xml"
        if FileExist(xml)
            FileDelete(xml)
        FileAppend(Autostart.TaskXml(), xml, "UTF-16")
        ok := Autostart.Schtasks('/Create /TN "' Autostart.taskName '" /XML "' xml '" /F') = 0
        FileDelete(xml)
        return ok
    }

    static Schtasks(args) {
        try return RunWait('schtasks.exe ' args, , "Hide")
        catch
            return -1
    }

    static TaskXml() {
        user := A_UserName
        try user := EnvGet("USERDOMAIN") "\" A_UserName
        cmd := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        args := A_IsCompiled ? "" : '"' A_ScriptFullPath '"'
        return Format('
        (
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled><UserId>{1}</UserId></LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>{1}</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec><Command>{2}</Command><Arguments>{3}</Arguments><WorkingDirectory>{4}</WorkingDirectory></Exec>
  </Actions>
</Task>
        )', Autostart.XmlEscape(user), Autostart.XmlEscape(cmd), Autostart.XmlEscape(args), Autostart.XmlEscape(A_ScriptDir))
    }

    static XmlEscape(s) => StrReplace(StrReplace(StrReplace(StrReplace(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"), '"', "&quot;")
}
