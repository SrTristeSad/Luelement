local Host = {}
Host.__index = Host

local function require_table(value, name)
    if type(value) ~= "table" then
        error("Luelement precisa de " .. name .. " no runtime AddKo")
    end
    return value
end

local function response_status(response)
    return tonumber(response.status or response.status_code or response.code or 0) or 0
end

function Host.new(api)
    api = require_table(api, "_G.addko")

    return setmetatable({
        api = api,
        daemon_handle = nil,
    }, Host)
end

function Host:log(level, message)
    if type(self.api.log) == "function" then
        self.api.log(level, message)
        return
    end
    print(string.format("[Luelement][%s] %s", tostring(level), tostring(message)))
end

function Host:http(request)
    local http = require_table(self.api.http, "addko.http")
    if type(http.request) ~= "function" then
        error("addko.http.request não está disponível")
    end

    local response = http.request(request)
    if type(response) ~= "table" then
        error("addko.http.request deve retornar uma tabela")
    end
    return response
end

function Host:download_file(url, destination)
    local http = require_table(self.api.http, "addko.http")

    if type(http.download) == "function" then
        local result = http.download({
            url = url,
            path = destination,
            timeout_seconds = 180,
        })

        if result == false then
            error("addko.http.download falhou para " .. tostring(url))
        end
        if type(result) == "table" then
            local status = response_status(result)
            if status ~= 0 and (status < 200 or status >= 300) then
                error(string.format("download falhou com HTTP %d", status))
            end
        end
        return destination
    end

    local response = self:http({
        method = "GET",
        url = url,
        timeout_seconds = 180,
        response_type = "bytes",
    })
    local status = response_status(response)
    if status < 200 or status >= 300 then
        error(string.format("download falhou com HTTP %d", status))
    end

    self:write_bytes(destination, response.body)
    return destination
end

function Host:decode_json(text)
    local json = require_table(self.api.json, "addko.json")
    if type(json.decode) ~= "function" then
        error("addko.json.decode não está disponível")
    end
    return json.decode(text)
end

function Host:encode_json(value)
    local json = require_table(self.api.json, "addko.json")
    if type(json.encode) ~= "function" then
        error("addko.json.encode não está disponível")
    end
    return json.encode(value)
end

function Host:platform()
    local platform = require_table(self.api.platform, "addko.platform")
    return {
        os = platform.os,
        arch = platform.arch,
    }
end

function Host:locale()
    local locale = self.api.locale
    if type(locale) ~= "table" then
        return {
            language = "en",
            second_language = "",
            region = "US",
        }
    end

    local language = locale.language or locale.lang or "en"
    language = tostring(language):match("^([A-Za-z][A-Za-z])") or "en"
    language = string.lower(language)

    local region = locale.region or locale.country or "US"
    region = string.upper(tostring(region):sub(1, 2))

    return {
        language = language,
        second_language = locale.second_language or "",
        region = region,
    }
end

function Host:plugin_path(relative_path)
    local paths = require_table(self.api.paths, "addko.paths")
    if type(paths.plugin) ~= "function" then
        error("addko.paths.plugin não está disponível")
    end
    return paths.plugin(relative_path or "")
end

function Host:data_path(relative_path)
    local paths = require_table(self.api.paths, "addko.paths")
    if type(paths.data) ~= "function" then
        error("addko.paths.data não está disponível")
    end
    return paths.data(relative_path or "")
end

function Host:fs()
    return require_table(self.api.fs or self.api.files, "addko.fs")
end

function Host:file_exists(path)
    local fs = self:fs()
    if type(fs.exists) ~= "function" then
        error("addko.fs.exists não está disponível")
    end
    return fs.exists(path) == true
end

function Host:mkdirp(path)
    local fs = self:fs()
    local fn = fs.mkdirp or fs.mkdirs or fs.create_directories
    if type(fn) ~= "function" then
        error("addko.fs.mkdirp não está disponível")
    end
    fn(path)
    return path
end

function Host:write_text(path, text)
    local fs = self:fs()
    if type(fs.write_text) == "function" then
        fs.write_text(path, text)
        return
    end
    if type(fs.write) == "function" then
        fs.write(path, text)
        return
    end
    error("addko.fs.write_text não está disponível")
end

function Host:write_bytes(path, bytes)
    local fs = self:fs()
    if type(fs.write_bytes) == "function" then
        fs.write_bytes(path, bytes)
        return
    end
    if type(fs.write) == "function" then
        fs.write(path, bytes, { binary = true })
        return
    end
    error("addko.fs.write_bytes não está disponível")
end

function Host:set_executable(path)
    local fs = self:fs()
    if type(fs.set_executable) == "function" then
        fs.set_executable(path, true)
        return
    end
    if type(fs.chmod) == "function" then
        fs.chmod(path, "755")
        return
    end
    self:log("warning", "runtime não expõe chmod; tentando iniciar binário como está")
end

function Host:spawn_process(options)
    local process = require_table(self.api.process, "addko.process")
    if type(process.spawn) ~= "function" then
        error("addko.process.spawn não está disponível")
    end
    self.daemon_handle = process.spawn(options)
    return self.daemon_handle
end

function Host:stop_process(handle)
    if not handle then
        return
    end

    local process = require_table(self.api.process, "addko.process")
    if type(process.stop) == "function" then
        process.stop(handle)
    end
end

function Host:start_line_server(options)
    local net = require_table(self.api.net, "addko.net")
    local tcp = type(net.tcp) == "table" and net.tcp or net
    local listen = tcp.listen_lines or tcp.listen
    if type(listen) ~= "function" then
        error("addko.net.tcp.listen não está disponível")
    end

    return listen({
        host = options.host,
        port = options.port,
        framing = "lines",
        on_message = options.on_message,
    })
end

function Host:stop_server(handle)
    if not handle then
        return
    end

    local net = require_table(self.api.net, "addko.net")
    local tcp = type(net.tcp) == "table" and net.tcp or net
    local close = tcp.close or net.close
    if type(close) == "function" then
        close(handle)
        return
    end

    if type(handle) == "table" and type(handle.close) == "function" then
        handle:close()
    end
end

function Host:ui_refresh()
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.refresh) == "function" then
        ui.refresh()
    end
end

function Host:ui_update(route)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.navigate) == "function" then
        ui.navigate(route)
    end
end

function Host:notify(title, message)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.notify) == "function" then
        ui.notify({ title = title, message = message })
        return
    end
    self:log("info", tostring(title) .. ": " .. tostring(message))
end

function Host:keyboard(default_value, heading, hidden)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.input) == "function" then
        return ui.input({
            value = default_value,
            title = heading,
            password = hidden == true,
        })
    end
    return default_value or ""
end

function Host:dialog_ok(title, message)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.alert) == "function" then
        ui.alert({ title = title, message = message })
        return true
    end
    self:notify(title, message)
    return true
end

function Host:dialog_confirm(title, message)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.confirm) == "function" then
        return ui.confirm({ title = title, message = message }) == true
    end
    return false
end

function Host:dialog_select(title, items, preselect)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.select) == "function" then
        local result = ui.select({
            title = title,
            items = items,
            selected = preselect,
        })
        return tonumber(result) or -1
    end
    return -1
end

function Host:file_picker(title)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.pick_file) == "function" then
        return ui.pick_file({ title = title })
    end
    return ""
end

function Host:progress_create(...)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.progress_create) == "function" then
        return ui.progress_create({ args = { ... } })
    end
    return { cancelled = false }
end

function Host:progress_update(handle, percent, ...)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.progress_update) == "function" then
        ui.progress_update(handle, { percent = percent, args = { ... } })
    end
end

function Host:progress_is_cancelled(handle)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.progress_is_cancelled) == "function" then
        return ui.progress_is_cancelled(handle) == true
    end
    return type(handle) == "table" and handle.cancelled == true
end

function Host:progress_close(handle)
    local ui = self.api.ui
    if type(ui) == "table" and type(ui.progress_close) == "function" then
        ui.progress_close(handle)
    end
end

-- Dart streams the source; Lua does not transfer media bytes.
-- Old hosts may still play the Elementum URL directly.
function Host:prepare_media_stream(url)
    local stream = self.api.stream
    local capabilities = self.api.capabilities or {}
    if capabilities.media_stream_proxy ~= true
        or type(stream) ~= "table"
        or type(stream.register) ~= "function" then
        return url, nil
    end
    local registered = stream.register({url = url})
    if type(registered) ~= "table"
        or type(registered.url) ~= "string"
        or type(registered.id) ~= "string" then
        error("O núcleo AddKo não registrou a fonte de mídia corretamente.")
    end
    return registered.url, registered.id
end

function Host:release_media_stream(id)
    if not id then return false end
    local stream = self.api.stream
    if type(stream) ~= "table" or type(stream.revoke) ~= "function" then
        return false
    end
    return stream.revoke(id)
end

function Host:player()
    return self.api.player
end

function Host:player_play(item)
    local player = self:player()
    if type(player) == "table" and type(player.play) == "function" then
        local result = player.play(item)
        return result == nil and true or result
    end
    return false
end

function Host:player_file()
    local player = self:player()
    if type(player) == "table" and type(player.current_url) == "function" then
        return player.current_url() or ""
    end
    return ""
end

function Host:player_is_playing()
    local player = self:player()
    if type(player) == "table" and type(player.is_playing) == "function" then
        return player.is_playing() == true
    end
    return false
end

function Host:player_is_paused()
    local player = self:player()
    if type(player) == "table" and type(player.is_paused) == "function" then
        return player.is_paused() == true
    end
    return false
end

function Host:player_watch_times()
    local player = self:player()
    if type(player) == "table" and type(player.times) == "function" then
        local value = player.times() or {}
        return {
            watchedTime = tostring(value.position or value.watchedTime or 0),
            videoDuration = tostring(value.duration or value.videoDuration or 0),
            error = tostring(value.error or ""),
        }
    end
    return { watchedTime = "0", videoDuration = "0", error = "" }
end

function Host:player_seek(position)
    local player = self:player()
    if type(player) == "table" and type(player.seek) == "function" then
        player.seek(position)
    end
end

function Host:player_subtitles()
    local player = self:player()
    if type(player) == "table" and type(player.subtitles) == "function" then
        return player.subtitles() or {}
    end
    return {}
end

function Host:player_set_subtitles(urls)
    local player = self:player()
    if type(player) == "table" and type(player.set_subtitles) == "function" then
        player.set_subtitles(urls)
    end
end

function Host:sleep(milliseconds)
    if type(self.api.sleep) ~= "function" then
        error("addko.sleep não está disponível")
    end
    self.api.sleep(milliseconds)
end

return Host
