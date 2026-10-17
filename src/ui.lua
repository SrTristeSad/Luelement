local Ui = {}

local function text(value, style)
    return {
        type = "text",
        text = tostring(value or ""),
        style = style or "body",
    }
end

local function button(label, route, params, options)
    options = options or {}
    local args = { route }
    if params ~= nil then
        table.insert(args, params)
    end

    return {
        type = "button",
        label = label,
        action = "route",
        args = args,
        submit_form = options.submit_form == true,
        variant = options.variant or "tonal",
        enabled = options.enabled ~= false,
        navigation = options.navigation or "replace",
    }
end

local function back_button(label)
    return {
        type = "button",
        label = label or "Voltar",
        variant = "text",
        navigation = "pop",
    }
end

local function column(children)
    return {
        type = "column",
        children = children,
    }
end

local function row(children)
    return {
        type = "row",
        children = children,
    }
end

local function card(children)
    return {
        type = "card",
        child = column(children),
    }
end

local function page(title, children)
    return {
        type = "page",
        title = title,
        body = column(children),
    }
end

local function number(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback or 0
    end
    return parsed
end

local function format_rate(value)
    local kib = number(value, 0)
    if kib >= 1024 then
        return string.format("%.1f MiB/s", kib / 1024)
    end
    return string.format("%.0f KiB/s", kib)
end

local function status_text(engine_ready, engine)
    if not engine_ready then
        return "Motor Elementum parado"
    end

    if type(engine) == "table" and engine.companion == true then
        return "Motor ativo pelo Luelement Engine"
    end
    return "Motor Elementum ativo"
end

function Ui.home(options)
    options = options or {}
    local ready = options.engine_ready == true
    local children = {
        text("Luelement", "headline"),
        text(status_text(ready, options.engine), "title"),
        text(
            "Frontend Lua do AddKo usando Elementum como motor P2P nativo.",
            "caption"
        ),
        { type = "divider" },
    }

    if not ready then
        table.insert(children, button("Iniciar motor", "engine_start", nil, {
            variant = "primary",
        }))
        if options.error then
            table.insert(children, text("Falha: " .. tostring(options.error), "caption"))
        end
    else
        table.insert(children, row({
            button("Torrents", "torrents", nil, {
                variant = "primary",
                navigation = "push",
            }),
            button("Adicionar magnet", "torrent_add", nil, {
                navigation = "push",
            }),
        }))
        table.insert(children, row({
            button("Filmes populares", "movies_popular", nil, {
                navigation = "push",
            }),
            button("Diagnóstico", "engine_diagnostics", nil, {
                navigation = "push",
            }),
        }))
        table.insert(children, button("Parar motor", "engine_stop", nil, {
            variant = "outline",
        }))
    end

    return page("Luelement", children)
end

function Ui.add_torrent()
    return page("Adicionar torrent", {
        text("Magnet ou URL de torrent", "title"),
        {
            type = "textarea",
            name = "uri",
            label = "Magnet / URL",
            hint = "magnet:?xt=urn:btih:...",
            max_length = 16384,
        },
        {
            type = "switch",
            name = "all_files",
            label = "Baixar todos os arquivos",
            value = false,
        },
        button("Adicionar", "torrent_add_submit", nil, {
            submit_form = true,
            variant = "primary",
        }),
        back_button(),
    })
end

function Ui.torrents(torrents, message)
    torrents = type(torrents) == "table" and torrents or {}
    local children = {
        row({
            button("Atualizar", "torrents", nil, { variant = "primary" }),
            button("Adicionar", "torrent_add", nil, { navigation = "push" }),
        }),
    }

    if message and message ~= "" then
        table.insert(children, text(message, "caption"))
    end

    if #torrents == 0 then
        table.insert(children, card({
            text("Nenhum torrent ativo", "title"),
            text("Adicione um magnet para testar o motor.", "caption"),
        }))
    end

    local limit = math.min(#torrents, 15)
    for index = 1, limit do
        local torrent = torrents[index] or {}
        local id = tostring(torrent.id or torrent.info_hash or "")
        local name = tostring(torrent.name or torrent.title or id)
        local progress = number(torrent.progress, 0)
        local status = tostring(torrent.status or "")
        local down = format_rate(torrent.download_rate)
        local up = format_rate(torrent.upload_rate)
        local peers = number(torrent.peers, 0)
        local seeders = number(torrent.seeders, 0)

        table.insert(children, card({
            text(name, "title"),
            text(string.format("%.1f%% • %s", progress, status)),
            text(string.format(
                "↓ %s  ↑ %s  • peers %d • seeds %d",
                down,
                up,
                peers,
                seeders
            ), "caption"),
            row({
                button("Reproduzir", "torrent_play", { id = id }, {
                    variant = "primary",
                    enabled = id ~= "",
                }),
                button("Pausar", "torrent_pause", { id = id }, {
                    enabled = id ~= "",
                }),
            }),
            row({
                button("Retomar", "torrent_resume", { id = id }, {
                    enabled = id ~= "",
                }),
                button("Remover", "torrent_remove", { id = id }, {
                    variant = "outline",
                    enabled = id ~= "",
                }),
            }),
        }))
    end

    if #torrents > limit then
        table.insert(children, text(
            string.format("Mostrando %d de %d torrents.", limit, #torrents),
            "caption"
        ))
    end

    table.insert(children, back_button())
    return page("Torrents", children)
end

function Ui.diagnostics(data)
    data = type(data) == "table" and data or {}
    local companion = type(data.companion) == "table" and data.companion or {}
    local platform = type(data.platform) == "table" and data.platform or {}

    return page("Diagnóstico", {
        text("Engine", "headline"),
        text("Pronto: " .. tostring(data.ready == true)),
        text("Controlado pelo plugin: " .. tostring(data.owned == true)),
        text("RPC iniciado: " .. tostring(data.rpc_started == true)),
        { type = "divider" },
        text("Plataforma", "title"),
        text(string.format(
            "%s / %s / %s",
            tostring(platform.os or "?"),
            tostring(platform.arch or "?"),
            tostring(platform.target or "?")
        )),
        { type = "divider" },
        text("Companion Android", "title"),
        text("Suportado: " .. tostring(companion.supported == true)),
        text("Ativo: " .. tostring(companion.ready == true)),
        text("Iniciado pelo plugin: " .. tostring(companion.started_by_us == true)),
        button("Atualizar diagnóstico", "engine_diagnostics", nil, {
            variant = "primary",
        }),
        back_button(),
    })
end

function Ui.movies(view, title)
    local items = {}
    if type(view) == "table" and type(view.items) == "table" then
        items = view.items
    elseif type(view) == "table" then
        items = view
    end

    local children = {}
    local limit = math.min(#items, 24)
    for index = 1, limit do
        local item = items[index] or {}
        local label = item.label
            or (type(item.info) == "table" and item.info.title)
            or "Sem título"
        table.insert(children, card({
            text(label, "title"),
            type(item.info) == "table" and item.info.year
                and text(tostring(item.info.year), "caption")
                or text("", "caption"),
        }))
    end

    if #children == 0 then
        table.insert(children, text("Nenhum item retornado pelo engine."))
    end
    table.insert(children, back_button())
    return page(title or "Filmes", children)
end

function Ui.error(message)
    return page("Luelement", {
        text("Não foi possível iniciar o motor", "headline"),
        text(tostring(message or "Erro desconhecido")),
        button("Tentar novamente", "engine_start", nil, {
            variant = "primary",
        }),
        button("Diagnóstico", "engine_diagnostics", nil, {
            navigation = "push",
        }),
    })
end

return Ui
