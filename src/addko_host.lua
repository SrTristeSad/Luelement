local Host = {}
Host.__index = Host

local function require_table(value, name)
    if type(value) ~= "table" then
        error("Luelement precisa de " .. name .. " no runtime AddKo")
    end
    return value
end

function Host.new(api)
    api = require_table(api, "_G.addko")

    local self = setmetatable({
        api = api,
        daemon_handle = nil,
    }, Host)

    return self
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

function Host:decode_json(text)
    local json = require_table(self.api.json, "addko.json")
    if type(json.decode) ~= "function" then
        error("addko.json.decode não está disponível")
    end
    return json.decode(text)
end

function Host:platform()
    local platform = require_table(self.api.platform, "addko.platform")
    return {
        os = platform.os,
        arch = platform.arch,
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
