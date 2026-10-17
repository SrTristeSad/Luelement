local StandaloneConfig = require("src.standalone_config")

local config = {
    id = "io.addko.luelement",
    name = "Luelement",
    version = "test",
}

local platform = {
    os = "windows",
    arch = "x64",
}

local paths = {
    root = "C:/data",
    plugin = "C:/plugin",
    profile = "C:/data/profile",
    temp = "C:/data/temp",
    torrents = "C:/data/torrents",
    library = "C:/data/library",
    downloads = "C:/data/downloads",
}

test("standalone config evita dependência de Kodi real", function()
    local bundle = StandaloneConfig.build(config, platform, paths, {
        language = "pt",
        region = "BR",
    })

    assert_equal(bundle.Info.ID, "io.addko.luelement")
    assert_equal(bundle.Platform.Kodi, 20)
    assert_equal(bundle.Language, "pt")
    assert_equal(bundle.Region, "BR")
    assert_equal(bundle.Settings.library_enabled, false)
    assert_equal(bundle.Settings.library_sync_enabled, false)
end)

test("standalone config mantém defaults críticos de seleção e buffer", function()
    local bundle = StandaloneConfig.build(config, platform, paths, {})
    local settings = bundle.Settings

    assert_equal(settings.download_storage, 1)
    assert_equal(settings.min_candidate_size, 100)
    assert_equal(settings.min_candidate_show_size, 4)
    assert_equal(settings.buffer_size, 20)
    assert_equal(settings.end_buffer_size, 4)
    assert_equal(settings.buffer_timeout, 60)
end)

test("standalone config explicita integrações opcionais desativadas", function()
    local settings = StandaloneConfig.build(config, platform, paths, {}).Settings

    assert_equal(settings.force_use_trakt, false)
    assert_equal(settings.trakt_sync_enabled, false)
    assert_equal(settings.trakt_token, "")
    assert_equal(settings.opensubtitles_token, "")
    assert_equal(settings.proxy_enabled, false)
    assert_equal(settings.internal_proxy_enabled, false)
    assert_equal(settings.internal_dns_enabled, false)
    assert_equal(settings.antizapret_enabled, false)
end)

test("standalone config fornece campos consultados pelo Elementum mesmo quando neutros", function()
    local settings = StandaloneConfig.build(config, platform, paths, {}).Settings

    assert_equal(settings.tmdb_api_key, "")
    assert_equal(settings.tmdb_images_quality, 1)
    assert_equal(settings.playback_percent, 85)
    assert_equal(settings.disable_bg_progress, true)
    assert_equal(settings.disable_bg_progress_playback, true)
    assert_equal(settings.osdb_auto_language, true)
    assert_equal(settings.internal_dns_server, "")
    assert_equal(settings.internal_dns_server_custom, "")
end)
