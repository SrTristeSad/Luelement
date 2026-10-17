local Config = require("src.config")
local ElementumClient = require("src.elementum_client")

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
    return self
end

function App:start()
    self.host:log("info", "Iniciando Luelement " .. self.config.version)

    local success, status = pcall(function()
        return self.elementum:status()
    end)

    if not success then
        self.host:log("warning", "Daemon Elementum indisponível: " .. tostring(status))
        return fail("elementum_unavailable", status)
    end

    return ok({
        route = "home",
        engine = status,
    })
end

function App:route(name, params)
    params = params or {}

    local success, result = pcall(function()
        if name == nil or name == "" or name == "home" then
            return {
                name = "home",
                sections = {
                    { id = "torrents", title = "Torrents" },
                    { id = "movies_popular", title = "Filmes populares" },
                    { id = "movies_top", title = "Mais bem avaliados" },
                },
            }
        elseif name == "status" then
            return self.elementum:status()
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
    self.host:log("info", "Encerrando frontend Luelement")
    return ok(true)
end

return App
