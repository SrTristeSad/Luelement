local Url = require("src.url")

local Client = {}
Client.__index = Client

local function response_status(response)
    return tonumber(response.status or response.status_code or response.code or 0) or 0
end

local function response_header(response, name)
    local headers = response.headers
    if type(headers) ~= "table" then
        return nil
    end

    return headers[name]
        or headers[string.lower(name)]
        or headers[string.upper(name)]
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
        follow_redirects = options.follow_redirects,
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

-- /status do Elementum é uma ação de UI: ele abre um diálogo pela ponte RPC.
-- Para detectar se o daemon está vivo usamos /torrents/list, que é silencioso
-- em server mode e devolve JSON mesmo quando não há torrents ativos.
function Client:health()
    local torrents = self:torrents()
    return {
        running = true,
        torrent_count = type(torrents) == "table" and #torrents or 0,
    }
end

function Client:status()
    return self:health()
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

function Client:resolve_stream(options)
    options = options or {}

    local query = {
        uri = options.uri,
        resume = options.resume,
        index = options.index,
        oindex = options.oindex,
        doresume = options.doresume == true and "true" or "false",
        file_match = options.file_match,
        type = options.content_type,
        tmdb = options.tmdb,
        show = options.show,
        season = options.season,
        episode = options.episode,
    }

    assert(
        (type(query.uri) == "string" and query.uri ~= "")
            or (type(query.resume) == "string" and query.resume ~= ""),
        "resolve_stream exige uri ou resume"
    )

    local request_url = self:url("/play", query)
    local response = self.host:http({
        method = "GET",
        url = request_url,
        headers = {
            ["User-Agent"] = "Luelement",
        },
        timeout_seconds = self.config.elementum.playback_timeout_seconds or 120,
        follow_redirects = false,
        headers_only = true,
    })

    local status = response_status(response)
    if status == 301 or status == 302 or status == 303 or status == 307 or status == 308 then
        local location = response_header(response, "Location")
        if not location or location == "" then
            error("Elementum respondeu redirecionamento sem cabeçalho Location")
        end

        if location:sub(1, 1) == "/" then
            location = self.base_url .. location
        end

        return location, response
    end

    -- Alguns adapters HTTP podem seguir o redirect mesmo quando solicitado o
    -- contrário. Aceitamos a URL final se o runtime a informar sem baixar o
    -- corpo inteiro do vídeo para Lua.
    if status >= 200 and status < 300 then
        local final_url = response.final_url or response.url
        if type(final_url) == "string"
            and final_url ~= ""
            and final_url ~= request_url then
            return final_url, response
        end
    end

    error(string.format(
        "não foi possível obter URL de reprodução: HTTP %d (%s)",
        status,
        tostring(response.body or "")
    ))
end

function Client:stream_uri(uri, index)
    assert(type(uri) == "string" and uri ~= "", "uri é obrigatória")
    return self:resolve_stream({
        uri = uri,
        index = index,
        doresume = false,
    })
end

function Client:stream_torrent(id, index)
    assert(type(id) == "string" and id ~= "", "id do torrent é obrigatório")
    return self:resolve_stream({
        resume = id,
        index = index,
        doresume = false,
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
