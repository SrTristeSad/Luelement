local ElementumClient = require("src.elementum_client")

local config = {
    elementum = {
        scheme = "http",
        host = "127.0.0.1",
        port = 65220,
        request_timeout_seconds = 15,
        playback_timeout_seconds = 120,
    },
}

test("elementum health usa torrents/list e não status", function()
    local seen = nil
    local host = {
        http = function(_, request)
            seen = request
            return {
                status = 200,
                body = "[]",
                headers = {},
            }
        end,
        decode_json = function(_, text)
            assert_equal(text, "[]")
            return {}
        end,
    }

    local client = ElementumClient.new(host, config)
    local health = client:health()

    assert_equal(seen.url, "http://127.0.0.1:65220/torrents/list")
    assert_equal(health.running, true)
    assert_equal(health.torrent_count, 0)
end)

test("resolve_stream não segue redirect e devolve URL files absoluta", function()
    local seen = nil
    local host = {
        http = function(_, request)
            seen = request
            return {
                status = 302,
                body = "",
                headers = {
                    Location = "/files/Linux%20Test.iso",
                },
            }
        end,
        decode_json = function() return {} end,
    }

    local client = ElementumClient.new(host, config)
    local url = client:stream_uri("magnet:?xt=urn:btih:ABC", 0)

    assert_equal(seen.follow_redirects, false)
    assert_contains(seen.url, "/play?")
    assert_contains(seen.url, "index=0")
    assert_contains(seen.url, "uri=magnet%3A%3Fxt%3Durn%3Abtih%3AABC")
    assert_equal(url, "http://127.0.0.1:65220/files/Linux%20Test.iso")
end)

test("resolve_stream preserva Location absoluta", function()
    local host = {
        http = function()
            return {
                status = 302,
                body = "",
                headers = {
                    location = "http://127.0.0.1:65220/files/video.mkv",
                },
            }
        end,
        decode_json = function() return {} end,
    }

    local client = ElementumClient.new(host, config)
    local url = client:stream_torrent("abcdef", 1)
    assert_equal(url, "http://127.0.0.1:65220/files/video.mkv")
end)
