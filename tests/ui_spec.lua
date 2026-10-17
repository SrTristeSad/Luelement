local Ui = require("src.ui")

local function find_action(node, action, route)
    if type(node) ~= "table" then
        return nil
    end

    if node.action == action
        and type(node.args) == "table"
        and node.args[1] == route then
        return node
    end

    if type(node.child) == "table" then
        local found = find_action(node.child, action, route)
        if found then return found end
    end

    if type(node.children) == "table" then
        for _, child in ipairs(node.children) do
            local found = find_action(child, action, route)
            if found then return found end
        end
    end

    if type(node.body) == "table" then
        return find_action(node.body, action, route)
    end

    return nil
end

local function find_navigation(node, navigation)
    if type(node) ~= "table" then
        return nil
    end

    if node.navigation == navigation then
        return node
    end

    if type(node.child) == "table" then
        local found = find_navigation(node.child, navigation)
        if found then return found end
    end

    if type(node.children) == "table" then
        for _, child in ipairs(node.children) do
            local found = find_navigation(child, navigation)
            if found then return found end
        end
    end

    if type(node.body) == "table" then
        return find_navigation(node.body, navigation)
    end

    return nil
end

test("home do Luelement é uma página declarativa válida", function()
    local document = Ui.home({ engine_ready = true })
    assert_equal(document.type, "page")
    assert_equal(document.title, "Luelement")
    assert_equal(document.body.type, "column")

    local torrents = find_action(document, "route", "torrents")
    assert_true(torrents ~= nil)
    assert_equal(torrents.navigation, "push")
end)

test("home offline oferece ação para iniciar engine", function()
    local document = Ui.home({ engine_ready = false, error = "offline" })
    assert_true(find_action(document, "route", "engine_start") ~= nil)
end)

test("formulário de torrent envia dados pelo submit_form e volta por pop", function()
    local document = Ui.add_torrent()
    local submit = find_action(document, "route", "torrent_add_submit")
    assert_true(submit ~= nil)
    assert_true(submit.submit_form == true)

    local back = find_navigation(document, "pop")
    assert_true(back ~= nil)
    assert_equal(back.action, nil)
end)

test("lista de torrents limita quantidade de cards", function()
    local torrents = {}
    for index = 1, 40 do
        torrents[index] = {
            id = "hash-" .. index,
            name = "Torrent " .. index,
            progress = index,
            status = "Downloading",
            download_rate = 10,
            upload_rate = 2,
            peers = 3,
            seeders = 4,
        }
    end

    local document = Ui.torrents(torrents)
    assert_equal(document.type, "page")
    assert_true(find_action(document, "route", "torrent_play") ~= nil)
    assert_true(find_navigation(document, "pop") ~= nil)

    -- 15 cards de torrent + controles fixos mantêm a árvore abaixo do limite
    -- de 256 nós imposto pelo AddKo.
    assert_true(#document.body.children < 25)
end)
