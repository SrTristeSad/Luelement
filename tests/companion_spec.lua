local Companion = require("src.companion")

local function fixture(initial_ready)
    local state = {
        ready = initial_ready == true,
        starts = 0,
        stops = 0,
        sleeps = 0,
    }
    local host = {
        api = {
            capabilities = { native_engines = true },
            engines = {},
        },
    }
    function host:platform() return { os = "android", arch = "arm64" } end
    function host:log(_, _) end
    function host:sleep(_) state.sleeps = state.sleeps + 1 end

    host.api.engines.available = function(name)
        return name == "elementum"
    end
    host.api.engines.start = function(name)
        assert_equal(name, "elementum")
        state.starts = state.starts + 1
        state.ready = true
        return true
    end
    host.api.engines.stop = function(name)
        assert_equal(name, "elementum")
        state.stops = state.stops + 1
        state.ready = false
        return true
    end
    host.api.engines.status = function(name)
        return { state = state.ready and "running" or "stopped" }
    end
    local client = {}
    function client:health()
        if not state.ready then error("offline") end
        return { running = true, torrent_count = 0 }
    end
    local config = {
        elementum = { startup_timeout_seconds = 1 },
        daemon = { startup_poll_ms = 10 },
    }
    return Companion.new(host, client, config), state
end

test("APK bundled native engine starts through addko.engines", function()
    local engine, state = fixture(false)
    assert_true(engine:is_supported())
    local result = engine:start()
    assert_true(result.native_engine)
    assert_true(result.started_by_plugin)
    assert_equal(state.starts, 1)
    assert_true(state.ready)
end)

test("bundled engine is reused if it is already running", function()
    local engine, state = fixture(true)
    local result = engine:start()
    assert_true(result.already_running)
    assert_equal(state.starts, 0)
end)

test("engine can only be stopped by owner unless forced", function()
    local engine, state = fixture(true)
    engine:start()
    local not_owned = engine:stop(false)
    assert_equal(not_owned.reason, "native_engine_not_owned")
    assert_true(state.ready)
    local stop = engine:stop(true)
    assert_true(stop.stopped)
    assert_equal(state.stops, 1)
end)

test("native engine is unavailable outside Android", function()
    local engine, _ = fixture(false)
    function engine.host:platform()
        return { os = "windows", arch = "x64" }
    end
    assert_true(not engine:is_supported())
end)

test("addon requires the approved module in the AddKo build", function()
    local engine, _ = fixture(false)
    engine.host.api.engines.available = function() return false end
    assert_true(not engine:is_supported())
    local ok = pcall(function() engine:start() end)
    assert_true(not ok)
end)
