; Тесты JSON для окна настроек.

Test("Json: объект, массив, Map и экранирование", (*) => AssertEq(
    Json.Stringify({a: [1, "x"], b: Map("k", 'q"\'), c: "a`nb"}),
    '{"a":[1,"x"],"b":{"k":"q\"\\"},"c":"a\nb"}'))

Test("Json.Parse: объект, массив, числа, литералы", (*) => AssertEq(
    Json.Parse(' { "a" : [1, -2.5, true, false, null], "b": {}, "c": [] } '),
    Map("a", [1, -2.5, 1, 0, ""], "b", Map(), "c", [])))

Test("Json.Parse: экранирование в строках", (*) => AssertEq(
    Json.Parse('"q\"\\\/\nЖ"'), 'q"\/`nЖ'))

Test("Json.Parse: Stringify и обратно", (*) => AssertEq(
    Json.Parse(Json.Stringify(Map("v", "0.2.0", "n", [1, "x"]))), Map("v", "0.2.0", "n", [1, "x"])))

Test("Json.Parse: негодный JSON — исключение", (*) => AssertThrows(() => Json.Parse('{"a": 1,}')))
Test("Json.Parse: лишнее после значения — исключение", (*) => AssertThrows(() => Json.Parse('1 2')))
