; Описание релиза (release.json) и его подпись. Проверка — CNG (bcrypt.dll): ECDSA P-256 над SHA-256,
; подпись — 64 байта r‖s, как её делает build\sign.ps1. Сеть и файлы здесь не трогаются.
class Release {
    ; Открытый ключ релизов: base64 BCRYPT_ECCPUBLIC_BLOB из build\keygen.ps1
    static publicKey := "RUNTMSAAAACOb6acc44ZnIbC2sWDIm4+xwiCj4RIBwiAFAFNykmV2kGzkHfeUF9jnQvJ23T9KT7ToIF6BQmtXCgp6sqWyBlO"

    ; Верна ли подпись sig (Buffer) данных data (Buffer) ключом pub (base64)
    static Verify(data, sig, pub := Release.publicKey) {
        if pub = "" || sig.Size != 64
            return false
        blob := Release.FromBase64(pub)
        DllCall("LoadLibrary", "str", "bcrypt", "ptr")
        if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", &alg := 0, "wstr", "ECDSA_P256", "ptr", 0, "uint", 0, "uint")
            return false
        ok := false
        if !DllCall("bcrypt\BCryptImportKeyPair", "ptr", alg, "ptr", 0, "wstr", "ECCPUBLICBLOB", "ptr*", &key := 0, "ptr", blob, "uint", blob.Size, "uint", 0, "uint") {
            hash := Release.Hash(data)
            ok := DllCall("bcrypt\BCryptVerifySignature", "ptr", key, "ptr", 0, "ptr", hash, "uint", 32, "ptr", sig, "uint", 64, "uint", 0, "uint") = 0
            DllCall("bcrypt\BCryptDestroyKey", "ptr", key)
        }
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", alg, "uint", 0)
        return ok
    }

    ; SHA-256 буфера — 32 байта
    static Hash(data) {
        DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", &alg := 0, "wstr", "SHA256", "ptr", 0, "uint", 0, "uint")
        out := Buffer(32)
        DllCall("bcrypt\BCryptHash", "ptr", alg, "ptr", 0, "uint", 0, "ptr", data, "uint", data.Size, "ptr", out, "uint", 32, "uint")
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", alg, "uint", 0)
        return out
    }

    ; SHA-256 буфера строкой hex в нижнем регистре (как Get-FileHash, но строчными)
    static Sha256(data) {
        h := Release.Hash(data), s := ""
        loop 32
            s .= Format("{:02x}", NumGet(h, A_Index - 1, "uchar"))
        return s
    }

    ; Разбор release.json: {version, files: Map(вид → {name, size, sha256})}. Негодное описание — исключение.
    static Parse(text) {
        j := Json.Parse(text)
        if !(j is Map) || !j.Has("version") || !RegExMatch(j["version"], "^\d+\.\d+\.\d+$")
            throw ValueError("release.json: нет версии")
        if !j.Has("files") || !(j["files"] is Map)
            throw ValueError("release.json: нет файлов")
        files := Map()
        for kind, f in j["files"] {
            if !(f is Map) || !f.Has("name") || !f.Has("size") || !f.Has("sha256")
                || !RegExMatch(f["name"], "^[\w.-]+$") || !IsInteger(f["size"]) || !RegExMatch(f["sha256"], "^[0-9a-fA-F]{64}$")
                throw ValueError("release.json: негодное описание файла " kind)
            files[kind] := {name: f["name"], size: Integer(f["size"]), sha256: StrLower(f["sha256"])}
        }
        return {version: j["version"], files: files}
    }

    ; Сравнение версий X.Y.Z: -1, 0, 1. Негодная строка считается меньше любой годной.
    static Compare(a, b) {
        ok := (v) => RegExMatch(v, "^\d+\.\d+\.\d+$")
        if !ok(a) || !ok(b)
            return ok(a) - ok(b)
        pa := StrSplit(a, "."), pb := StrSplit(b, ".")
        loop 3
            if Integer(pa[A_Index]) != Integer(pb[A_Index])
                return Integer(pa[A_Index]) > Integer(pb[A_Index]) ? 1 : -1
        return 0
    }

    static FromBase64(s) {
        DllCall("crypt32\CryptStringToBinary", "str", s, "uint", 0, "uint", 1, "ptr", 0, "uint*", &n := 0, "ptr", 0, "ptr", 0)
        buf := Buffer(n)
        DllCall("crypt32\CryptStringToBinary", "str", s, "uint", 0, "uint", 1, "ptr", buf, "uint*", &n, "ptr", 0, "ptr", 0)
        return buf
    }

    ; Строка → байты UTF-8 без BOM (так подписываются файлы)
    static Utf8(s) {
        buf := Buffer(StrPut(s, "UTF-8") - 1)
        StrPut(s, buf, buf.Size, "UTF-8")
        return buf
    }
}
