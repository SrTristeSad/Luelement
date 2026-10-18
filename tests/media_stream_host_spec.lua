local Host = require("src.addko_host")

test("adapter do Luelement registra fonte no streaming genérico", function()
    local calls = { opened = nil, revoked = nil }
    local api = {
        capabilities = {media_stream_proxy = true},
        stream = {
            register = function(options)
                calls.opened = options.url
                return {id = "token-1", url = "http://127.0.0.1:9876/media/token-1"}
            end,
            revoke = function(id)
                calls.revoked = id
                return true
            end,
            stats = function(id)
                assert_equal(id, "token-1")
                return {
                    requests = 3,
                    range_requests = 1,
                    bytes_forwarded = 8192,
                    last_http_status = 206,
                }
            end,
        },
    }
    local host = Host.new(api)
    local uri, id = host:prepare_media_stream("http://127.0.0.1:65220/files/video.mp4")
    assert_equal(id, "token-1")
    assert_equal(uri, "http://127.0.0.1:9876/media/token-1")
    assert_equal(calls.opened, "http://127.0.0.1:65220/files/video.mp4")
    local stats = host:media_stream_stats(id)
    assert_true(stats.ready)
    assert_equal(stats.requests, 3)
    assert_equal(stats.range_requests, 1)
    assert_equal(stats.bytes_forwarded, 8192)
    assert_true(host:release_media_stream(id))
    assert_equal(calls.revoked, "token-1")
end)

test("host anterior sem streaming usa URL HTTP original", function()
    local host = Host.new({capabilities = {http = true}})
    local uri, id = host:prepare_media_stream("http://127.0.0.1:65220/files/video.mp4")
    assert_equal(uri, "http://127.0.0.1:65220/files/video.mp4")
    assert_equal(id, nil)
    assert_true(host:release_media_stream(nil) == false)
    local stats = host:media_stream_stats(id)
    assert_true(stats.ready == false)
end)

test("falha na resposta do núcleo impede falsa confirmação de reprodução", function()
    local host = Host.new({
        capabilities = {media_stream_proxy = true},
        stream = {register = function() return {url = "http://x"} end},
    })
    local ok, err = pcall(function()
        host:prepare_media_stream("http://127.0.0.1/video.mp4")
    end)
    assert_true(not ok)
    assert_contains(err, "não registrou a fonte")
end)
