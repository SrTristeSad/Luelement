local Companion = {}
Companion.__index = Companion

function Companion.new(host, client, config)
    return setmetatable({
        host = host,
        client = client,
        config = config,
        started_by_us = false,
    }, Companion)
end

function Companion:is_android()
    local platform = self.host:platform()
    return string.lower(tostring(platform.os or "")) == "android"
end

function Companion:is_supported()
    if not self:is_android() then
        return false
    end

    local capabilities = self.host.api.capabilities
    local system = self.host.api.system
    return type(capabilities) == "table"
        and capabilities.open_uri == true
        and type(system) == "table"
        and type(system.open_uri) == "function"
end

function Companion:is_ready()
    local ok, status = pcall(function()
        return self.client:health()
    end)
    return ok, status
end

function Companion:open(uri)
    local system = self.host.api.system
    if type(system) ~= "table" or type(system.open_uri) ~= "function" then
        error("runtime AddKo não expõe addko.system.open_uri")
    end

    local opened = system.open_uri(uri)
    if opened ~= true then
        error(
            "Luelement Engine não está instalado ou o Android não encontrou "
            .. tostring(uri)
        )
    end
    return true
end

function Companion:wait_until_ready()
    local poll_ms = self.config.daemon.startup_poll_ms or 250
    local timeout_seconds = self.config.elementum.startup_timeout_seconds or 30
    local attempts = math.max(1, math.floor((timeout_seconds * 1000) / poll_ms))

    for _ = 1, attempts do
        local ready, status = self:is_ready()
        if ready then
            return status
        end
        self.host:sleep(poll_ms)
    end

    error(string.format(
        "Luelement Engine foi acionado, mas Elementum não respondeu em %ss",
        tostring(timeout_seconds)
    ))
end

function Companion:start()
    local ready, status = self:is_ready()
    if ready then
        return {
            already_running = true,
            companion = true,
            owned = false,
            status = status,
        }
    end

    if not self:is_supported() then
        error("Luelement Engine companion não está disponível neste host")
    end

    local companion = self.config.companion or {}
    self.host:log("info", "Solicitando inicialização do Luelement Engine")
    self:open(companion.start_uri or "luelement-engine://start")
    self.started_by_us = true

    local ok, result = pcall(function()
        return self:wait_until_ready()
    end)
    if not ok then
        self.started_by_us = false
        error(result)
    end

    return {
        already_running = false,
        companion = true,
        owned = false,
        started_by_plugin = true,
        status = result,
    }
end

function Companion:stop(force)
    if not self:is_supported() then
        return {
            stopped = false,
            reason = "companion_not_supported",
        }
    end

    if force ~= true and not self.started_by_us then
        return {
            stopped = false,
            reason = "companion_not_owned",
        }
    end

    local companion = self.config.companion or {}
    local ok, err = pcall(function()
        self:open(companion.stop_uri or "luelement-engine://stop")
    end)
    self.started_by_us = false

    if not ok then
        return {
            stopped = false,
            reason = tostring(err),
        }
    end

    return {
        stopped = true,
        requested = true,
    }
end

function Companion:diagnostics()
    local ready, status = self:is_ready()
    return {
        android = self:is_android(),
        supported = self:is_supported(),
        ready = ready,
        status = status,
        started_by_us = self.started_by_us,
    }
end

return Companion
