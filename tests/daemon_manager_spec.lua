local DaemonManager = require("src.daemon_manager")

local function new_fixture(started)
    local state = {
        started = started == true,
        spawn_count = 0,
        stop_count = 0,
        writes = {},
        dirs = {},
        last_spawn = nil,
    }

    local config = {
        elementum = {
            host = "127.0.0.1",
            port = 65220,
            startup_timeout_seconds = 1,
        },
        rpc = {
            host = "127.0.0.1",
            port = 65221,
        },
        daemon = {
            auto_start = true,
            auto_download = false,
            startup_poll_ms = 10,
            shutdown_timeout_seconds = 1,
            engine_version = "0.1.114",
            binary_commit = "test",
            binary_base_url = "https://example.invalid",
        },
    }

    local host = {}
    function host:data_path(path)
        return "/data/" .. tostring(path or "")
    end
    function host:plugin_path(path)
        return "/plugin/" .. tostring(path or "")
    end
    function host:platform()
        return { os = "windows", arch = "x64" }
    end
    function host:locale()
        return { language = "pt", second_language = "", region = "BR" }
    end
    function host:file_exists(path)
        return path == "/plugin/native/windows_x64/elementum.exe"
    end
    function host:mkdirp(path)
        state.dirs[path] = true
    end
    function host:write_text(path, text)
        state.writes[path] = text
    end
    function host:encode_json(_)
        return "{}"
    end
    function host:set_executable(_) end
    function host:log(_, _) end
    function host:sleep(_) end
    function host:spawn_process(options)
        state.spawn_count = state.spawn_count + 1
        state.last_spawn = options
        state.started = true
        return { pid = 123 }
    end
    function host:stop_process(_)
        state.stop_count = state.stop_count + 1
        state.started = false
    end

    local client = { base_url = "http://127.0.0.1:65220" }
    function client:status()
        if not state.started then
            error("offline")
        end
        return { healthy = true }
    end
    function client:shutdown()
        state.started = false
        return true
    end

    return {
        state = state,
        config = config,
        host = host,
        client = client,
        manager = DaemonManager.new(host, client, config),
    }
end

test("daemon manager reutiliza engine já iniciado", function()
    local fixture = new_fixture(true)
    local result = fixture.manager:start()

    assert_true(result.already_running)
    assert_equal(result.owned, false)
    assert_equal(fixture.state.spawn_count, 0)
end)

test("daemon manager inicia Elementum standalone no Windows", function()
    local fixture = new_fixture(false)
    local result = fixture.manager:start()

    assert_equal(result.platform, "windows_x64")
    assert_true(result.owned)
    assert_equal(fixture.state.spawn_count, 1)
    assert_true(fixture.state.last_spawn ~= nil)
    assert_equal(
        fixture.state.last_spawn.path,
        "/plugin/native/windows_x64/elementum.exe"
    )

    local args = table.concat(fixture.state.last_spawn.args, " ")
    assert_contains(args, "-configPath=/data/elementum/0.1.114/elementum-config.json")
    assert_contains(args, "-localPort=65220")
    assert_contains(args, "-remotePort=65221")
    assert_contains(args, "-disableParentProcessWatcher")
end)

test("daemon manager encerra daemon que ele próprio iniciou", function()
    local fixture = new_fixture(false)
    fixture.manager:start()

    local result = fixture.manager:stop()
    assert_true(result.stopped)
    assert_equal(result.forced, false)
    assert_equal(fixture.manager.owned, false)
end)
