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

    -- Fallback simples. O runtime ideal deve implementar http.download para
    -- evitar manter um binário de ~30 MB inteiro na memória Lua.
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

function Host:sleep(milliseconds)
    if type(self.api.sleep) ~= "function" then
        error("addko.sleep não está disponível")
    end
    self.api.sleep(milliseconds)
end

return Host
