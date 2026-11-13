; Тесты JSON для окна настроек.

Test("Json: объект, массив, Map и экранирование", (*) => AssertEq(
    Json.Stringify({a: [1, "x"], b: Map("k", 'q"\'), c: "a`nb"}),
    '{"a":[1,"x"],"b":{"k":"q\"\\"},"c":"a\nb"}'))
