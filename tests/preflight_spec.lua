local Preflight = require("src.preflight")

local function complete_api()
    return {
        http = {
            request = function() end,
            download = function() end,
        },
        json = {
            encode = function() end,
            decode = function() end,
        },
        platform = {
            os = "windows",
            arch = "amd64",
        },
        paths = {
            plugin = function() end,
            data = function() end,
        },
        fs = {
            exists = function() end,
            mkdirp = function() end,
            write_text = function() end,
        },
        process = {
            spawn = function() end,
            stop = function() end,
        },
        net = {
            tcp = {
                listen = function() end,
                close = function() end,
            },
        },
        player = {
            play = function() end,
            is_playing = function() end,
            is_paused = function() end,
            times = function() end,
        },
        sleep = function() end,
    }
end

test("preflight aceita host mínimo Windows", function()
    local report = Preflight.check({ api = complete_api() })
    assert_true(report.ok)
    assert_equal(#report.missing, 0)
end)

test("preflight informa APIs ausentes", function()
    local api = complete_api()
    api.process.spawn = nil
    api.player.play = nil

    local report = Preflight.check({ api = api })
    assert_equal(report.ok, false)
    assert_true(#report.missing >= 2)
    assert_contains(table.concat(report.missing, "|"), "addko.process.spawn")
    assert_contains(table.concat(report.missing, "|"), "addko.player.play")
end)
