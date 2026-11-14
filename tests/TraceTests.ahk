; Тесты записи отладочного режима (Trace.Record) и значений null/true/false в Json.

TraceSnap(over := {}) {
    s := {hkl: 0x04190419, caret: {x: 100, y: 200, w: 1, h: 16, method: "msaa"}, mouse: {ibeam: false}}
    for k, v in over.OwnProps()
        s.%k% := v
    return s
}
TraceWin := {exe: "notepad.exe", class: "Notepad", focus: "Edit"}
TraceInd := {flag: "ru", text: "RU"}
TraceShown := {caret: {flag: "ru", text: "RU", x: 100, y: 219, w: 16, h: 12}, mouse: ""}

Test("JSON: null, true, false", (*) => AssertEq(Json.Stringify([Json.JNull, Json.JTrue, Json.JFalse, 0, ""]), '[null,true,false,0,""]'))

Test("Трассировка: каретка найдена — место и способ", (*) => AssertEq(
    Json.Stringify(Trace.Record(TraceWin, TraceSnap(), TraceInd, TraceShown)),
    '{"caret":{"h":16,"method":"msaa","w":1,"x":100,"y":200},"flag":"ru","hkl":"04190419","ibeam":false,'
    '"shown":{"caret":{"h":12,"w":16,"x":100,"y":219},"mouse":false},"text":"RU",'
    '"win":{"class":"Notepad","exe":"notepad.exe","focus":"Edit"}}'))

Test("Трассировка: каретки нет — null", (*) => AssertEq(
    Json.Stringify(Trace.Record("", TraceSnap({caret: ""}), TraceInd, {caret: "", mouse: ""})),
    '{"caret":null,"flag":"ru","hkl":"04190419","ibeam":false,"shown":{"caret":null,"mouse":false},"text":"RU","win":null}'))

Test("Трассировка: курсор «I» и флажок у мыши", (*) => AssertEq(
    Json.Parse(Json.Stringify(Trace.Record(TraceWin, TraceSnap({mouse: {ibeam: true}}), TraceInd,
        {caret: "", mouse: {x: 5, y: 5, w: 16, h: 12}})))["shown"]["mouse"], 1))

Test("Трассировка: каретка без способа (из теста) — без поля method", (*) => AssertEq(
    Json.Parse(Json.Stringify(Trace.Record(TraceWin, TraceSnap({caret: {x: 1, y: 2, w: 1, h: 3}}), TraceInd, TraceShown)))["caret"].Has("method"), 0))
