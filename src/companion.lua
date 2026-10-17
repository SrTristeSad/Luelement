-- Compatibility adapter: the old name "companion" is retained internally
-- to avoid breaking Lua routes, but no external Android APK is used.
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
    return tostring(self.host:platform().os or ""):lower() == "android"
end

function Companion:is_supported()
    if not self:is_android() then return false end
    local api = self.host.api or {}
    local capabilities = api.capabilities or {}
    local engines = api.engines or {}
    return capabilities.native_engines == true
        and type(engines.available) == "function"
        and type(engines.start) == "function"
        and type(engines.stop) == "function"
        and engines.available("elementum") == true
end

function Companion:is_ready()
    local ok, status = pcall(function()
        return self.client:health()
    end)
    return ok, status
end

function Companion:wait_until_ready()
    local poll_ms = self.config.daemon.startup_poll_ms or 250
    local timeout_seconds = self.config.elementum.startup_timeout_seconds or 30
    local attempts = math.max(1, math.floor((timeout_seconds * 1000) / poll_ms))
    for _ = 1, attempts do
        local ready, status = self:is_ready()
        if ready then return status end
        self.host:sleep(poll_ms)
    end
    error("O motor nativo foi solicitado, mas Elementum não respondeu a tempo.")
end

function Companion:start()
    local ready, status = self:is_ready()
    if ready then
        return { already_running = true, companion = false, native_engine = true,
            owned = false, status = status }
    end
    if not self:is_supported() then
        error("AddKo não possui o módulo nativo aprovado Elementum neste APK.")
    end
    self.host:log("info", "Solicitando o motor nativo assinado ao AddKo")
    local started = self.host.api.engines.start("elementum")
    if started ~= true then
        error("AddKo recusou iniciar o motor aprovado Elementum")
    end
    self.started_by_us = true
    local ok, response = pcall(function()
        return self:wait_until_ready()
    end)
    if not ok then
        self.started_by_us = false
        error(response)
    end
    return { already_running = false, native_engine = true, companion = false,
        owned = false, started_by_plugin = true, status = response }
end

function Companion:stop(force)
    if not self:is_supported() then
        return { stopped = false, reason = "native_engine_not_available" }
    end
    if force ~= true and not self.started_by_us then
        return { stopped = false, reason = "native_engine_not_owned" }
    end
    local ok, err = pcall(function()
        return self.host.api.engines.stop("elementum")
    end)
    self.started_by_us = false
    if not ok then
        return { stopped = false, reason = tostring(err) }
    end
    return { stopped = true, requested = true }
end

function Companion:diagnostics()
    local ready, status = self:is_ready()
    local available = self:is_supported()
    local engine = nil
    if available and type(self.host.api.engines.status) == "function" then
        local ok, details = pcall(function()
            return self.host.api.engines.status("elementum")
        end)
        if ok then engine = details end
    end
    return {
        android = self:is_android(), supported = available,
        native_engine = true, ready = ready, status = status,
        engine = engine, started_by_us = self.started_by_us,
    }
end

return Companion
