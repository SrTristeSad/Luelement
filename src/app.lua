local Config = require("src.config")
local ElementumClient = require("src.elementum_client")
local DaemonManager = require("src.daemon_manager")
local RpcBridge = require("src.rpc_bridge")

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

function App.new(host)
    local self = setmetatable({
        host = host,
        config = Config,
    }, App)

    self.elementum = ElementumClient.new(host, Config)
    self.daemon = DaemonManager.new(host, self.elementum, Config)
    self.rpc = RpcBridge.new(host, Config)
    return self
end

function App:ensure_engine()
    self.rpc:start()
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
                sections = {
                    { id = "torrents", title = "Torrents" },
                    { id = "movies_popular", title = "Filmes populares" },
                    { id = "movies_top", title = "Mais bem avaliados" },
                },
            }
        elseif name == "status" then
            return self.elementum:status()
        elseif name == "engine_diagnostics" then
            local diagnostics = self.daemon:diagnostics()
            diagnostics.rpc_started = self.rpc.server ~= nil
            return diagnostics
        elseif name == "engine_start" then
            return self:ensure_engine()
        elseif name == "engine_stop" then
            local daemon_result = self.daemon:stop()
            self.rpc:stop()
            return daemon_result
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

    local rpc_success, rpc_result = pcall(function()
        return self.rpc:stop()
    end)

    if not rpc_success then
        self.host:log("warning", "Falha ao encerrar ponte RPC: " .. tostring(rpc_result))
    end

    self.host:log("info", "Encerrando frontend Luelement")
    return ok({
        daemon = daemon_success and daemon_result or nil,
        rpc = rpc_success and rpc_result or nil,
    })
end

return App
