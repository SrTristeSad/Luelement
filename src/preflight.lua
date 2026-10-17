local Preflight = {}

local function is_function(value)
    return type(value) == "function"
end

local function has_any(table_value, names)
    if type(table_value) ~= "table" then
        return false
    end
    for _, name in ipairs(names) do
        if is_function(table_value[name]) then
            return true
        end
    end
    return false
end

local function missing_function(missing, value, label)
    if not is_function(value) then
        table.insert(missing, label)
    end
end

local function require_capability(missing, capabilities, name)
    if type(capabilities) == "table" and capabilities[name] ~= true then
        table.insert(missing, "capability:" .. name)
    end
end

function Preflight.check(host, options)
    options = options or {}
    local launch = options.launch ~= false

    local api = host.api or {}
    local missing = {}
    local warnings = {}
    local capabilities = api.capabilities

    require_capability(missing, capabilities, "http")
    require_capability(missing, capabilities, "tcp_server")
    require_capability(missing, capabilities, "player")
    require_capability(missing, capabilities, "sleep")
    require_capability(missing, capabilities, "ui")

    if launch then
        require_capability(missing, capabilities, "filesystem")
        require_capability(missing, capabilities, "process")
    end

    local http = api.http or {}
    missing_function(missing, http.request, "addko.http.request")

    local json = api.json or {}
    missing_function(missing, json.decode, "addko.json.decode")
    missing_function(missing, json.encode, "addko.json.encode")

    local platform = api.platform or {}
    if platform.os == nil then
        table.insert(missing, "addko.platform.os")
    end
    if platform.arch == nil then
        table.insert(missing, "addko.platform.arch")
    end

    local paths = api.paths or {}
    missing_function(missing, paths.plugin, "addko.paths.plugin")
    missing_function(missing, paths.data, "addko.paths.data")

    local fs = api.fs or api.files or {}
    if launch then
        missing_function(missing, fs.exists, "addko.fs.exists")
        if not has_any(fs, { "mkdirp", "mkdirs", "create_directories" }) then
            table.insert(missing, "addko.fs.mkdirp")
        end
        if not has_any(fs, { "write_text", "write" }) then
            table.insert(missing, "addko.fs.write_text")
        end

        if not is_function(http.download)
            and not has_any(fs, { "write_bytes", "write" }) then
            table.insert(missing, "addko.http.download ou addko.fs.write_bytes")
        end

        local process = api.process or {}
        missing_function(missing, process.spawn, "addko.process.spawn")
        missing_function(missing, process.stop, "addko.process.stop")
    end

    local net = api.net or {}
    local tcp = type(net.tcp) == "table" and net.tcp or net
    if not has_any(tcp, { "listen_lines", "listen" }) then
        table.insert(missing, "addko.net.tcp.listen")
    end
    if not has_any(tcp, { "close" }) and not is_function(net.close) then
        table.insert(warnings, "addko.net.tcp.close não disponível; o runtime deve permitir fechar o servidor RPC")
    end

    local ui = api.ui or {}
    missing_function(missing, ui.input, "addko.ui.input")
    missing_function(missing, ui.alert, "addko.ui.alert")
    missing_function(missing, ui.confirm, "addko.ui.confirm")
    missing_function(missing, ui.select, "addko.ui.select")

    missing_function(missing, api.sleep, "addko.sleep")

    local player = api.player or {}
    missing_function(missing, player.play, "addko.player.play")
    missing_function(missing, player.is_playing, "addko.player.is_playing")
    missing_function(missing, player.is_paused, "addko.player.is_paused")
    missing_function(missing, player.times, "addko.player.times")

    if launch and not is_function(http.download) then
        table.insert(warnings, "addko.http.download ausente; o fallback pode manter o binário inteiro em memória")
    end

    local os_name = string.lower(tostring(platform.os or ""))
    local process_available = type(capabilities) ~= "table" or capabilities.process == true
    if launch
        and process_available
        and os_name ~= "windows"
        and os_name ~= "win"
        and os_name ~= "win32"
        and not has_any(fs, { "set_executable", "chmod" }) then
        table.insert(missing, "addko.fs.set_executable/chmod (necessário fora do Windows)")
    end

    if os_name == "android"
        and type(capabilities) == "table"
        and capabilities.process ~= true then
        if launch then
            table.insert(
                warnings,
                "Android não executa binário nativo baixado pelo plugin; use um engine local nativo/companion já iniciado"
            )
        else
            table.insert(
                warnings,
                "Modo externo: o Luelement pode usar um engine local já iniciado sem process.spawn"
            )
        end
    end

    return {
        ok = #missing == 0,
        launch = launch,
        missing = missing,
        warnings = warnings,
    }
end

function Preflight.assert_ready(host, options)
    local report = Preflight.check(host, options)
    if report.ok then
        return report
    end

    error(
        "runtime AddKo incompleto para Luelement: "
        .. table.concat(report.missing, ", ")
    )
end

return Preflight
