local LUELEMENT = "io.addko.luelement"

local Plugin = {}

local function text(value, style)
    return {
        type = "text",
        text = tostring(value or ""),
        style = style or "body",
    }
end

local function button(label, action, options)
    options = options or {}
    return {
        type = "button",
        label = label,
        action = action,
        args = options.args or {},
        submit_form = options.submit_form == true,
        variant = options.variant or "tonal",
    }
end

local function page(message)
    return {
        type = "page",
        title = "Luelement Client Demo",
        body = {
            type = "column",
            children = {
                text("Plugin dependente", "headline"),
                text(
                    "Este mini-app não implementa torrent. Ele chama o serviço público do Luelement.",
                    "caption"
                ),
                {
                    type = "textarea",
                    name = "uri",
                    label = "Magnet ou URL de torrent",
                    hint = "magnet:?xt=urn:btih:...",
                    max_length = 16384,
                },
                button("Reproduzir via Luelement", "play", {
                    submit_form = true,
                    variant = "primary",
                }),
                button("Verificar engine", "health"),
                message and text(message, "caption") or {
                    type = "spacer",
                    size = 1,
                },
            },
        },
    }
end

function Plugin.start()
    local health = addko.plugins.call(LUELEMENT, "health", {})
    local message = health and health.ready
        and "Luelement pronto."
        or "Luelement instalado, mas engine ainda não respondeu."
    return page(message)
end

function Plugin.health()
    local health = addko.plugins.call(LUELEMENT, "health", {})
    if health and health.ready then
        return page("Engine pronto para uso.")
    end
    return page("Engine indisponível.")
end

function Plugin.play(params)
    params = params or {}
    local uri = tostring(params.uri or "")
    if uri == "" then
        return page("Informe um magnet ou URL de torrent.")
    end

    local result = addko.plugins.call(LUELEMENT, "play", {
        uri = uri,
    })

    if type(result) == "table" and result.started == true then
        return page("Reprodução iniciada pelo Luelement.")
    end
    return page("O Luelement não iniciou a reprodução.")
end

return Plugin
