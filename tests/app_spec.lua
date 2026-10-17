local App = require("src.app")

local function make_host()
    local state = {
        engine_ready = false,
        opened = {},
        played = nil,
        requests = {},
        rpc_started = false,
    }

    local host = {
        api = {
            capabilities = {
                http = true,
                tcp_server = true,
                player = true,
                sleep = true,
                ui = true,
                native_engines = true,
                filesystem = false,
                process = false,
            },
            http = {
                request = function() end,
            },
            json = {
                encode = function() end,
                decode = function() end,
            },
            platform = {
                os = "android",
                arch = "arm64",
            },
            paths = {
                plugin = function(path) return "/plugin/" .. tostring(path or "") end,
                data = function(path) return "/data/" .. tostring(path or "") end,
            },
            net = {
                tcp = {
                    listen = function() end,
                    close = function() end,
                },
            },
            ui = {
                input = function() return "" end,
                alert = function() return true end,
                confirm = function() return true end,
                select = function() return 0 end,
            },
            player = {
                play = function() return true end,
                is_playing = function() return false end,
                is_paused = function() return false end,
                times = function()
                    return { position = 0, duration = 0 }
                end,
            },
            engines = {},
            sleep = function() end,
        },
    }

    host.api.engines.available = function(id)
        return id == "elementum"
    end
    host.api.engines.start = function(id)
        assert_equal(id, "elementum")
        table.insert(state.opened, "engine-start")
        state.engine_ready = true
        return true
    end
    host.api.engines.stop = function(id)
        assert_equal(id, "elementum")
        table.insert(state.opened, "engine-stop")
        state.engine_ready = false
        return true
    end
    host.api.engines.status = function(id)
        return { state = state.engine_ready and "running" or "stopped" }
    end

    function host:platform()
        return { os = "android", arch = "arm64" }
    end

    function host:locale()
        return { language = "pt", second_language = "", region = "BR" }
    end

    function host:log(_, _)
    end

    function host:sleep(_)
    end

    function host:http(request)
        table.insert(state.requests, request)

        if request.url:find("/torrents/list", 1, true) then
            if not state.engine_ready then
                error("connection refused")
            end
            return {
                status = 200,
                body = "[]",
                headers = {},
                url = request.url,
            }
        end

        if not state.engine_ready then
            error("engine offline")
        end

        if request.url:find("/play", 1, true) then
            return {
                status = 302,
                body = "",
                headers = {
                    location = "/files/test.mp4",
                },
                url = request.url,
            }
        end

        return {
            status = 200,
            body = "",
            headers = {},
            url = request.url,
        }
    end

    function host:decode_json(text)
        if text == "[]" then
            return {}
        end
        return {}
    end

    function host:encode_json(_)
        return "{}"
    end

    function host:start_line_server(options)
        state.rpc_started = true
        state.rpc_options = options
        return 65221
    end

    function host:stop_server(_)
        state.rpc_started = false
    end

    function host:dialog_confirm(_, _)
        return true
    end

    function host:player_play(url)
        state.played = url
        return true
    end

    -- Métodos de diagnóstico do launcher standalone não são usados no fluxo
    -- Android companion, mas o DaemonManager constrói paths ao abrir a tela de
    -- diagnóstico.
    function host:plugin_path(path)
        return "/plugin/" .. tostring(path or "")
    end

    function host:data_path(path)
        return "/data/" .. tostring(path or "")
    end

    return host, state
end

test("app inicia módulo nativo integrado e retorna página real", function()
    local host, state = make_host()
    local app = App.new(host)

    local document = app:start()

    assert_equal(document.type, "page")
    assert_equal(document.title, "Luelement")
    assert_true(state.rpc_started)
    assert_equal(state.opened[1], "engine-start")
    assert_true(state.engine_ready)
end)

test("app adiciona magnet e retorna lista de torrents", function()
    local host, _ = make_host()
    local app = App.new(host)
    app:start()

    local form = app:route("torrent_add", {})
    assert_equal(form.title, "Adicionar torrent")

    local list = app:route("torrent_add_submit", {
        uri = "magnet:?xt=urn:btih:0123456789abcdef",
        all_files = true,
    })
    assert_equal(list.type, "page")
    assert_equal(list.title, "Torrents")
end)

test("app resolve redirect do Elementum e entrega stream ao player", function()
    local host, state = make_host()
    local app = App.new(host)
    app:start()

    local document = app:route("torrent_play", {
        id = "0123456789abcdef",
    })

    assert_equal(document.title, "Torrents")
    assert_equal(state.played, "http://127.0.0.1:65220/files/test.mp4")
end)

test("service health expõe estado do engine para plugin dependente", function()
    local host, state = make_host()
    local app = App.new(host)
    app:start()

    local health = app:service("health", {})

    assert_true(health.ready)
    assert_true(state.engine_ready)
    assert_true(type(health.companion) == "table")
end)

test("service stream devolve URL local sem abrir player", function()
    local host, state = make_host()
    local app = App.new(host)
    app:start()

    local url = app:service("stream", {
        uri = "magnet:?xt=urn:btih:0123456789abcdef",
    })

    assert_equal(url, "http://127.0.0.1:65220/files/test.mp4")
    assert_equal(state.played, nil)
end)

test("service play resolve stream e usa player do próprio Luelement", function()
    local host, state = make_host()
    local app = App.new(host)
    app:start()

    local result = app:service("play", {
        uri = "magnet:?xt=urn:btih:0123456789abcdef",
    })

    assert_true(result.started)
    assert_equal(result.url, "http://127.0.0.1:65220/files/test.mp4")
    assert_equal(state.played, result.url)
end)

test("service rejeita método desconhecido", function()
    local host, _ = make_host()
    local app = App.new(host)
    app:start()

    local ok, err = pcall(function()
        app:service("root_shell", {})
    end)

    assert_true(not ok)
    assert_contains(err, "método de serviço Luelement desconhecido")
end)

test("app stop fecha RPC e solicita parada do motor que iniciou", function()
    local host, state = make_host()
    local app = App.new(host)
    app:start()

    local result = app:stop()

    assert_true(result.stopped)
    assert_true(not state.rpc_started)
    assert_equal(state.opened[#state.opened], "engine-stop")
    assert_true(not state.engine_ready)
end)
