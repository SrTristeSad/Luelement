local Config = require("src.config")
local ElementumClient = require("src.elementum_client")
local DaemonManager = require("src.daemon_manager")

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
    return self
end

function App:start()
    self.host:log("info", "Iniciando Luelement " .. self.config.version)

    local success, engine = pcall(function()
        return self.daemon:start()
    end)

    if not success then
        self.host:log("error", "Falha ao iniciar Elementum: " .. tostring(engine))
        return fail("elementum_start_failed", engine)
    end

    return ok({
        route = "home",
        engine = engine,
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
            return self.daemon:diagnostics()
        elseif name == "engine_start" then
            return self.daemon:start()
        elseif name == "engine_stop" then
            return self.daemon:stop()
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
    local success, result = pcall(function()
        return self.daemon:stop()
    end)

    if not success then
        self.host:log("warning", "Falha ao encerrar daemon: " .. tostring(result))
    end

    self.host:log("info", "Encerrando frontend Luelement")
    return ok({
        daemon = success and result or nil,
    })
end

return App
