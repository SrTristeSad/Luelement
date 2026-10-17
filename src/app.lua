local Config = require("src.config")
local ElementumClient = require("src.elementum_client")
local DaemonManager = require("src.daemon_manager")
local Companion = require("src.companion")
local RpcBridge = require("src.rpc_bridge")
local Preflight = require("src.preflight")

local App = {}
App.__index = App

local function ok(data)
    return { ok = true, data = data }
end

local function fail(code, message)
    return {
        ok = false,
        error = {
            code = code,
            message = tostring(message),
        },
    }
end

local function log_warnings(host, report)
    for _, warning in ipairs(report.warnings or {}) do
        host:log("warning", warning)
    end
end

function App.new(host)
    local self = setmetatable({
        host = host,
        config = Config,
    }, App)

    self.elementum = ElementumClient.new(host, Config)
    self.daemon = DaemonManager.new(host, self.elementum, Config)
    self.companion = Companion.new(host, self.elementum, Config)
    self.rpc = RpcBridge.new(host, Config)
    return self
end

function App:preflight()
    return {
        external = Preflight.check(self.host, { launch = false }),
        local_launch = Preflight.check(self.host, { launch = true }),
        companion = self.companion:diagnostics(),
    }
end

function App:ensure_engine()
    -- Networking, the Lua RPC bridge and a real player are required in every
    -- mode. process.spawn/filesystem are required only when Luelement itself
    -- starts a desktop-style standalone daemon.
    local external_report = Preflight.assert_ready(
        self.host,
        { launch = false }
    )
    log_warnings(self.host, external_report)

    self.rpc:start()

    local ready = self.daemon:is_ready()
    if ready then
        self.host:log("info", "Usando engine Elementum local já iniciado")
        return self.daemon:start()
    end

    local companion_config = self.config.companion or {}
    if companion_config.auto_start ~= false and self.companion:is_supported() then
        return self.companion:start()
    end

    local launch_report = Preflight.assert_ready(
        self.host,
        { launch = true }
    )
    log_warnings(self.host, launch_report)
    return self.daemon:start()
end

function App:start()
    self.host:log("info", "Iniciando Luelement " .. self.config.version)

    local success, engine = pcall(function()
        return self:ensure_engine()
    end)

    if not success then
        pcall(function()
            self.rpc:stop()
        end)
        self.host:log("error", "Falha ao iniciar Elementum: " .. tostring(engine))
        return fail("elementum_start_failed", engine)
    end

    return ok({
        route = "home",
        engine = engine,
        rpc = {
            host = self.config.rpc.host,
            port = self.config.rpc.port,
        },
    })
end

function App:route(name, params)
    params = params or {}

    local success, result = pcall(function()
        if name == nil or name == "" or name == "home" then
            local ready = self.daemon:is_ready()
            return {
                name = "home",
                engine_ready = ready,
                companion = self.companion:diagnostics(),
                sections = {
                    { id = "torrents", title = "Torrents" },
                    { id = "movies_popular", title = "Filmes populares" },
                    { id = "movies_top", title = "Mais bem avaliados" },
                },
            }
        elseif name == "preflight" then
            return self:preflight()
        elseif name == "status" then
            return self.elementum:status()
        elseif name == "engine_diagnostics" then
            local diagnostics = self.daemon:diagnostics()
            diagnostics.rpc_started = self.rpc.server ~= nil
            diagnostics.preflight = self:preflight()
            diagnostics.companion = self.companion:diagnostics()
            return diagnostics
        elseif name == "engine_start" then
            return self:ensure_engine()
        elseif name == "engine_stop" then
            local daemon_result = self.daemon:stop()
            local companion_result = self.companion:stop(true)
            self.rpc:stop()
            return {
                daemon = daemon_result,
                companion = companion_result,
            }
        elseif name == "torrents" then
            return self.elementum:torrents()
        elseif name == "torrent_add" then
            self.elementum:add_torrent(params.uri, params.all_files == true)
            return self.elementum:torrents()
        elseif name == "torrent_pause" then
            self.elementum:pause_torrent(params.id)
            return self.elementum:torrents()
        elseif name == "torrent_resume" then
            self.elementum:resume_torrent(params.id)
            return self.elementum:torrents()
        elseif name == "torrent_recheck" then
            self.elementum:recheck_torrent(params.id)
            return self.elementum:torrents()
        elseif name == "torrent_remove" then
            self.elementum:remove_torrent(
                params.id,
                params.delete_torrent == true,
                params.delete_files == true
            )
            return self.elementum:torrents()
        elseif name == "torrent_play" then
            local stream_url = self.elementum:stream_torrent(params.id, params.index)
            local started = self.host:player_play(stream_url)
            return {
                url = stream_url,
                started = started,
            }
        elseif name == "play_uri" then
            local stream_url = self.elementum:stream_uri(params.uri, params.index)
            local started = self.host:player_play(stream_url)
            return {
                url = stream_url,
                started = started,
            }
        elseif name == "session_pause" then
            self.elementum:pause_session()
            return self.elementum:torrents()
        elseif name == "session_resume" then
            self.elementum:resume_session()
            return self.elementum:torrents()
        elseif name == "movies_popular" then
            return self.elementum:movies_popular(params.page or 1)
        elseif name == "movies_top" then
            return self.elementum:movies_top(params.page or 1)
        end

        error("rota desconhecida: " .. tostring(name))
    end)

    if not success then
        self.host:log("error", tostring(result))
        return fail("route_failed", result)
    end

    return ok(result)
end

function App:stop()
    local daemon_success, daemon_result = pcall(function()
        return self.daemon:stop()
    end)

    if not daemon_success then
        self.host:log("warning", "Falha ao encerrar daemon: " .. tostring(daemon_result))
    end

    local companion_success, companion_result = pcall(function()
        return self.companion:stop(false)
    end)

    if not companion_success then
        self.host:log("warning", "Falha ao encerrar companion: " .. tostring(companion_result))
    end

    local rpc_success, rpc_result = pcall(function()
        return self.rpc:stop()
    end)

    if not rpc_success then
        self.host:log("warning", "Falha ao encerrar ponte RPC: " .. tostring(rpc_result))
    end

    self.host:log("info", "Encerrando frontend Luelement")
    return ok({
        daemon = daemon_success and daemon_result or nil,
        companion = companion_success and companion_result or nil,
        rpc = rpc_success and rpc_result or nil,
    })
end

return App
