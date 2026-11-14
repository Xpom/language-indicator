; Тесты описания релиза: подпись, контрольная сумма, разбор, сравнение версий.
; Тестовая пара ключей сделана build\keygen.ps1, подпись — build\sign.ps1; закрытого ключа здесь нет.

TestPub := "RUNTMSAAAAAYzjPqLaZ9qalL1IHJFEaE4TF4nQMaP/HlQpmGKUzRGqVnOZxj4ns1mEuUurLVobCuWSTtQeg4Jc59bhfznjya"
TestData := '{"version":"0.2.0","files":{"setup":{"name":"LanguageIndicator-Setup-0.2.0.exe","size":3080875,"sha256":"ab12"}}}'
TestSig := "/4IMvhYXv/C5b83KzMlMO+Dr/9Ja8T3BXdddtfifdCahFRMLHJaf89nWrXkR2ETeLsWenKWjE7hYJXCE2RKLag=="
; Другой ключ P-256 — подпись им не проходит
OtherPub := "RUNTMSAAAADSvpPfwMBo5R7TG2GtzAL3FSx/CFTGeZj0GcCF9imoIZvSe+UFJEHKCYQuw90SxrXlWQXcVJHddJLCqgfESKj1"

Test("Подпись: верная проходит",
    (*) => AssertEq(Release.Verify(Release.Utf8(TestData), Release.FromBase64(TestSig), TestPub), 1))

Test("Подпись: изменённые данные не проходят",
    (*) => AssertEq(Release.Verify(Release.Utf8(StrReplace(TestData, "0.2.0", "0.2.1")), Release.FromBase64(TestSig), TestPub), 0))

Test("Подпись: испорченный байт подписи не проходит", (*) => (
    sig := Release.FromBase64(TestSig), NumPut("uchar", NumGet(sig, 10, "uchar") ^ 1, sig, 10),
    AssertEq(Release.Verify(Release.Utf8(TestData), sig, TestPub), 0)))

Test("Подпись: чужой ключ не проходит",
    (*) => AssertEq(Release.Verify(Release.Utf8(TestData), Release.FromBase64(TestSig), OtherPub), 0))

Test("Подпись: без ключа не проходит",
    (*) => AssertEq(Release.Verify(Release.Utf8(TestData), Release.FromBase64(TestSig), ""), 0))

Test("SHA-256: известное значение",
    (*) => AssertEq(Release.Sha256(Release.Utf8("abc")), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))

Test("release.json: разбор", (*) => AssertEq(Release.Parse('{"version":"0.2.0","files":{"setup":{"name":"a-0.2.0.exe","size":12,"sha256":"' StrRepeat("AB", 32) '"}}}'),
    {version: "0.2.0", files: Map("setup", {name: "a-0.2.0.exe", size: 12, sha256: StrRepeat("ab", 32)})}))

Test("release.json: без версии — исключение", (*) => AssertThrows(() => Release.Parse('{"files":{}}')))
Test("release.json: путь в имени файла — исключение", (*) => AssertThrows(() => Release.Parse(
    '{"version":"0.2.0","files":{"setup":{"name":"..\\x.exe","size":1,"sha256":"' StrRepeat("ab", 32) '"}}}')))
Test("release.json: короткая сумма — исключение", (*) => AssertThrows(() => Release.Parse(TestData)))

Test("Версии: 0.10.0 > 0.9.0", (*) => AssertEq(Release.Compare("0.10.0", "0.9.0"), 1))
Test("Версии: равные", (*) => AssertEq(Release.Compare("1.2.3", "1.2.3"), 0))
Test("Версии: меньше по патчу", (*) => AssertEq(Release.Compare("1.2.3", "1.2.4"), -1))
Test("Версии: негодная меньше годной", (*) => AssertEq(Release.Compare("v1", "0.0.1"), -1))

StrRepeat(s, n) {
    out := ""
    loop n
        out .= s
    return out
}
