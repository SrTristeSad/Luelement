local Config = require("src.config")
local ElementumClient = require("src.elementum_client")
local DaemonManager = require("src.daemon_manager")
local Companion = require("src.companion")
local RpcBridge = require("src.rpc_bridge")
local Preflight = require("src.preflight")
local Ui = require("src.ui")

local App = {}
App.__index = App

local function log_warnings(host, report)
    for _, warning in ipairs(report.warnings or {}) do
        host:log("warning", warning)
    end
end

function App.new(host)
    local self = setmetatable({
        host = host,
        config = Config,
        last_engine = nil,
        active_media_stream_id = nil,
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

function App:home(error_message)
    local ready, status = self.daemon:is_ready()
    local engine = self.last_engine or status
    return Ui.home({
        engine_ready = ready,
        engine = engine,
        companion = self.companion:diagnostics(),
        error = error_message,
    })
end

function App:torrent_page(message)
    return Ui.torrents(self.elementum:torrents(), message)
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
        self.last_engine = self.daemon:start()
        return self.last_engine
    end

    local companion_config = self.config.companion or {}
    if companion_config.auto_start ~= false and self.companion:is_supported() then
        self.last_engine = self.companion:start()
        return self.last_engine
    end

    if tostring(self.host:platform().os or ""):lower() == "android" then
        error("O Luelement requer uma build AddKo Android com o motor aprovado Elementum incluído no APK. Nenhum APK auxiliar é necessário.")
    end

    local launch_report = Preflight.assert_ready(
        self.host,
        { launch = true }
    )
    log_warnings(self.host, launch_report)
    self.last_engine = self.daemon:start()
    return self.last_engine
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
        -- A service has no launcher page for displaying errors.
        -- Propagate startup failures to the calling addon.
        error("Luelement não iniciou: " .. tostring(engine))
    end

    self.last_engine = engine
    return {
        type = "service",
        id = self.config.id,
        ready = true,
    }
end

-- Service owns its source until the next stream or service stop.
function App:publish_media_stream(url)
    local playable_url, new_id = self.host:prepare_media_stream(url)
    local old_id = self.active_media_stream_id
    self.active_media_stream_id = new_id
    if old_id then
        local ok, err = pcall(function()
            return self.host:release_media_stream(old_id)
        end)
        if not ok then
            self.host:log("warning", "Falha ao revogar fonte anterior: " .. tostring(err))
        end
    end
    return playable_url
end

function App:route(name, params)
    params = params or {}

    local success, result = pcall(function()
        if name == nil or name == "" or name == "home" then
            return self:home()
        elseif name == "preflight" or name == "engine_diagnostics" then
            local diagnostics = self.daemon:diagnostics()
            diagnostics.rpc_started = self.rpc.server ~= nil
            diagnostics.preflight = self:preflight()
            diagnostics.companion = self.companion:diagnostics()
            return Ui.diagnostics(diagnostics)
        elseif name == "status" then
            return self:home()
        elseif name == "engine_start" then
            self.last_engine = self:ensure_engine()
            return self:home()
        elseif name == "engine_stop" then
            self.daemon:stop()
            self.companion:stop(true)
            self.rpc:stop()
            self.last_engine = nil
            return self:home()
        elseif name == "torrents" then
            return self:torrent_page()
        elseif name == "torrent_add" then
            return Ui.add_torrent()
        elseif name == "torrent_add_submit" then
            local uri = tostring(params.uri or "")
            if uri == "" then
                return Ui.add_torrent()
            end
            self.elementum:add_torrent(uri, params.all_files == true)
            return self:torrent_page("Torrent adicionado.")
        elseif name == "torrent_pause" then
            self.elementum:pause_torrent(params.id)
            return self:torrent_page("Torrent pausado.")
        elseif name == "torrent_resume" then
            self.elementum:resume_torrent(params.id)
            return self:torrent_page("Torrent retomado.")
        elseif name == "torrent_recheck" then
            self.elementum:recheck_torrent(params.id)
            return self:torrent_page("Rechecagem iniciada.")
        elseif name == "torrent_remove" then
            local confirmed = self.host:dialog_confirm(
                "Remover torrent?",
                "Remover este torrent da sessão do Luelement?"
            )
            if confirmed then
                self.elementum:remove_torrent(
                    params.id,
                    params.delete_torrent == true,
                    params.delete_files == true
                )
                return self:torrent_page("Torrent removido.")
            end
            return self:torrent_page()
        elseif name == "torrent_play" then
            local stream_url = self.elementum:stream_torrent(params.id, params.index)
            local playable_url = self:publish_media_stream(stream_url)
            local started = self.host:player_play(playable_url)
            if not started then
                error("o player do AddKo recusou a reprodução")
            end
            return self:torrent_page("Reprodução iniciada.")
        elseif name == "play_uri" then
            local stream_url = self.elementum:stream_uri(params.uri, params.index)
            local playable_url = self:publish_media_stream(stream_url)
            local started = self.host:player_play(playable_url)
            if not started then
                error("o player do AddKo recusou a reprodução")
            end
            return self:torrent_page("Reprodução iniciada.")
        elseif name == "session_pause" then
            self.elementum:pause_session()
            return self:torrent_page("Sessão pausada.")
        elseif name == "session_resume" then
            self.elementum:resume_session()
            return self:torrent_page("Sessão retomada.")
        elseif name == "movies_popular" then
            return Ui.movies(
                self.elementum:movies_popular(params.page or 1),
                "Filmes populares"
            )
        elseif name == "movies_top" then
            return Ui.movies(
                self.elementum:movies_top(params.page or 1),
                "Mais bem avaliados"
            )
        end

        error("rota desconhecida: " .. tostring(name))
    end)

    if not success then
        self.host:log("error", tostring(result))
        return Ui.error(result)
    end

    return result
end

-- Public service contract used by other AddKo plugins that explicitly declare
-- io.addko.luelement in their manifest dependencies.
function App:service(name, params)
    params = params or {}

    if name == "health" then
        local ready, status = self.daemon:is_ready()
        return {
            ready = ready,
            status = status,
            engine = self.last_engine,
            companion = self.companion:diagnostics(),
        }
    elseif name == "torrents" then
        return self.elementum:torrents()
    elseif name == "add" then
        local uri = tostring(params.uri or "")
        if uri == "" then
            error("service add exige params.uri")
        end
        self.elementum:add_torrent(uri, params.all_files == true)
        return self.elementum:torrents()
    elseif name == "stream" then
        if params.id and tostring(params.id) ~= "" then
            return self:publish_media_stream(self.elementum:stream_torrent(params.id, params.index))
        end
        local uri = tostring(params.uri or "")
        if uri == "" then
            error("service stream exige params.id ou params.uri")
        end
        return self:publish_media_stream(self.elementum:stream_uri(uri, params.index))
    elseif name == "play" then
        local stream_url
        if params.id and tostring(params.id) ~= "" then
            stream_url = self.elementum:stream_torrent(params.id, params.index)
        else
            local uri = tostring(params.uri or "")
            if uri == "" then
                error("service play exige params.id ou params.uri")
            end
            stream_url = self.elementum:stream_uri(uri, params.index)
        end

        local playable_url = self:publish_media_stream(stream_url)
            local started = self.host:player_play(playable_url)
        if not started then
            error("o player do AddKo recusou a reprodução")
        end
        return {
            started = true,
            url = playable_url,
        }
    elseif name == "pause" then
        self.elementum:pause_torrent(params.id)
        return true
    elseif name == "resume" then
        self.elementum:resume_torrent(params.id)
        return true
    elseif name == "recheck" then
        self.elementum:recheck_torrent(params.id)
        return true
    elseif name == "remove" then
        self.elementum:remove_torrent(
            params.id,
            params.delete_torrent == true,
            params.delete_files == true
        )
        return true
    elseif name == "session_pause" then
        self.elementum:pause_session()
        return true
    elseif name == "session_resume" then
        self.elementum:resume_session()
        return true
    end

    error("método de serviço Luelement desconhecido: " .. tostring(name))
end

function App:stop()
    if self.active_media_stream_id then
        local id = self.active_media_stream_id
        self.active_media_stream_id = nil
        local ok, err = pcall(function() self.host:release_media_stream(id) end)
        if not ok then
            self.host:log("warning", "Falha ao revogar fonte na parada: " .. tostring(err))
        end
    end
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
    return {
        stopped = true,
        daemon = daemon_success and daemon_result or nil,
        companion = companion_success and companion_result or nil,
        rpc = rpc_success and rpc_result or nil,
    }
end

return App
