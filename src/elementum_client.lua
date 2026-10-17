local Url = require("src.url")

local Client = {}
Client.__index = Client

local function response_status(response)
    return tonumber(response.status or response.status_code or response.code or 0) or 0
end

function Client.new(host, config)
    local endpoint = config.elementum
    local base_url = string.format(
        "%s://%s:%d",
        endpoint.scheme,
        endpoint.host,
        endpoint.port
    )

    return setmetatable({
        host = host,
        config = config,
        base_url = base_url,
    }, Client)
end

function Client:url(path, query)
    return self.base_url .. path .. Url.query(query)
end

function Client:request(method, path, options)
    options = options or {}

    local response = self.host:http({
        method = method or "GET",
        url = self:url(path, options.query),
        headers = options.headers,
        body = options.body,
        timeout_seconds = options.timeout_seconds
            or self.config.elementum.request_timeout_seconds,
    })

    local status = response_status(response)
    if status < 200 or status >= 300 then
        error(string.format(
            "Elementum respondeu HTTP %d em %s: %s",
            status,
            path,
            tostring(response.body or "")
        ))
    end

    if options.json == false then
        return response.body, response
    end

    local body = response.body
    if body == nil or body == "" then
        return nil, response
    end

    return self.host:decode_json(body), response
end

function Client:status()
    return self:request("GET", "/status")
end

function Client:torrents()
    return self:request("GET", "/torrents/list")
end

function Client:add_torrent(uri, all_files)
    assert(type(uri) == "string" and uri ~= "", "uri do torrent é obrigatória")

    return self:request("POST", "/torrents/add", {
        query = {
            uri = uri,
            all = all_files and "1" or nil,
        },
        json = false,
    })
end

function Client:pause_torrent(id)
    assert(type(id) == "string" and id ~= "", "id do torrent é obrigatório")
    return self:request("GET", "/torrents/pause/" .. Url.encode(id), { json = false })
end

function Client:resume_torrent(id)
    assert(type(id) == "string" and id ~= "", "id do torrent é obrigatório")
    return self:request("GET", "/torrents/resume/" .. Url.encode(id), { json = false })
end

function Client:recheck_torrent(id)
    assert(type(id) == "string" and id ~= "", "id do torrent é obrigatório")
    return self:request("GET", "/torrents/recheck/" .. Url.encode(id), { json = false })
end

function Client:remove_torrent(id, delete_torrent, delete_files)
    assert(type(id) == "string" and id ~= "", "id do torrent é obrigatório")

    return self:request("GET", "/torrents/delete/" .. Url.encode(id), {
        query = {
            torrent = delete_torrent and "true" or "false",
            files = delete_files and "true" or "false",
            confirmation = "false",
        },
        json = false,
    })
end

function Client:pause_session()
    return self:request("GET", "/torrents/pause", { json = false })
end

function Client:resume_session()
    return self:request("GET", "/torrents/resume", { json = false })
end

function Client:movies_popular(page)
    return self:request("GET", "/movies/popular", {
        query = { page = page or 1 },
    })
end

function Client:movies_top(page)
    return self:request("GET", "/movies/top", {
        query = { page = page or 1 },
    })
end

function Client:raw(path, query)
    assert(type(path) == "string" and path:sub(1, 1) == "/", "path inválido")
    return self:request("GET", path, { query = query })
end

function Client:shutdown()
    return self:request("GET", "/shutdown", { json = false })
end

return Client
