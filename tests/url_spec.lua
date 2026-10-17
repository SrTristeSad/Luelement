local Url = require("src.url")

test("url.encode preserva caracteres não reservados", function()
    assert_equal(Url.encode("abc-_.~XYZ09"), "abc-_.~XYZ09")
end)

test("url.encode protege magnet e query interna", function()
    local value = "magnet:?xt=urn:btih:ABC&dn=Teste"
    assert_equal(
        Url.encode(value),
        "magnet%3A%3Fxt%3Durn%3Abtih%3AABC%26dn%3DTeste"
    )
end)

test("url.query ordena chaves e ignora nil", function()
    local query = Url.query({ z = "fim", a = "1 2", skip = nil })
    assert_equal(query, "?a=1%202&z=fim")
end)
