local Companion = require("src.companion")

local function fixture(initial_ready)
    local state = {
        ready = initial_ready == true,
        opened = {},
        sleeps = 0,
    }

    local host = {
        api = {
            capabilities = {
                open_uri = true,
            },
            system = {},
        },
    }

    function host:platform()
        return { os = "android", arch = "arm64" }
    end

    function host:log(_, _)
    end

    function host:sleep(_)
        state.sleeps = state.sleeps + 1
    end

    host.api.system.open_uri = function(uri)
        table.insert(state.opened, uri)
        if uri == "luelement-engine://start" then
            state.ready = true
        elseif uri == "luelement-engine://stop" then
            state.ready = false
        end
        return true
    end

    local client = {}
    function client:health()
        if not state.ready then
            error("offline")
        end
        return { running = true, torrent_count = 0 }
    end

    local config = {
        elementum = {
            startup_timeout_seconds = 1,
        },
        daemon = {
            startup_poll_ms = 10,
        },
        companion = {
            start_uri = "luelement-engine://start",
            stop_uri = "luelement-engine://stop",
        },
    }

    return Companion.new(host, client, config), state
end

test("companion Android starts engine through generic open_uri", function()
    local companion, state = fixture(false)

    assert_true(companion:is_supported())
    local result = companion:start()

    assert_true(result.companion)
    assert_true(result.started_by_plugin)
    assert_equal(state.opened[1], "luelement-engine://start")
    assert_true(state.ready)
end)

test("companion reuses an engine that is already running", function()
    local companion, state = fixture(true)

    local result = companion:start()

    assert_true(result.already_running)
    assert_equal(#state.opened, 0)
    assert_true(state.ready)
end)

test("companion only stops an engine started by this plugin unless forced", function()
    local companion, state = fixture(true)

    local reused = companion:start()
    assert_true(reused.already_running)

    local passive = companion:stop(false)
    assert_equal(passive.reason, "companion_not_owned")
    assert_true(state.ready)

    local forced = companion:stop(true)
    assert_true(forced.stopped)
    assert_equal(state.opened[1], "luelement-engine://stop")
    assert_true(not state.ready)
end)

test("companion is disabled outside Android", function()
    local companion, _ = fixture(false)
    function companion.host:platform()
        return { os = "windows", arch = "x64" }
    end

    assert_true(not companion:is_supported())
end)
