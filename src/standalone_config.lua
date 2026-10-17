local StandaloneConfig = {}

local function default_settings(paths)
    return {
        download_path = paths.downloads,
        library_path = paths.library,
        torrents_path = paths.torrents,

        download_storage = 1,
        download_file_strategy = 0,
        keep_downloading = 1,
        keep_files_playing = 1,
        keep_files_finished = 1,

        auto_memory_size = true,
        auto_memory_size_strategy = 1,
        memory_size = 100,
        auto_adjust_memory_size = true,
        auto_kodi_buffer_size = false,
        auto_adjust_buffer_size = false,
        buffer_size = 20,
        end_buffer_size = 4,
        buffer_timeout = 60,

        use_torrent_history = true,
        torrent_history_size = 50,
        autoload_torrents = true,
        autoload_torrents_paused = true,
        silent_stream_start = false,
        autoyes_enabled = true,
        autoyes_timeout = 5,

        use_cache_selection = true,
        use_cache_search = true,
        use_cache_torrents = true,
        cache_search_duration = 24,
        show_files_watched = true,

        results_per_page = 20,
        greeting_enabled = false,
        enable_overlay_status = false,
        disable_bg_progress = true,
        disable_bg_progress_playback = true,
        add_episode_numbers = true,
        seasons_all = true,
        seasons_order = 0,
        seasons_specials = true,
        show_unwatched_episodes_number = true,
        playback_percent = 85,

        choose_stream_auto_movie = false,
        choose_stream_auto_show = false,
        choose_stream_auto_search = false,
        smart_episode_match = true,
        smart_episode_start = true,
        smart_episode_choose = true,

        library_enabled = false,
        library_sync_enabled = false,
        library_sync_playback_enabled = false,
        library_update = 0,
        library_update_delay = 300,
        library_update_frequency = 6,
        library_nfo_movies = false,
        library_nfo_shows = false,
        strm_language = "",

        seed_forever = false,
        share_ratio_limit = 200,
        seed_time_ratio_limit = 700,
        seed_time_limit = 24,

        disable_upload = false,
        disable_lsd = false,
        disable_dht = false,
        disable_tcp = false,
        disable_utp = false,
        disable_upnp = false,
        disable_natpmp = false,
        listen_autodetect_ip = true,
        listen_autodetect_port = true,
        listen_port_min = 6881,
        listen_port_max = 6891,
        listen_interfaces = "",
        outgoing_interfaces = "",
        encryption_policy = 0,

        max_upload_rate = 0,
        max_download_rate = 0,
        limit_after_buffering = false,
        connections_limit = 0,
        conntracker_limit_auto = true,
        conntracker_limit = 0,
        session_save = 10,

        tuned_storage = true,
        disk_cache_size = 12,
        use_libtorrent_config = false,
        use_libtorrent_logging = false,
        use_libtorrent_deadline = true,
        use_libtorrent_pauseresume = true,
        libtorrent_profile = 0,
        magnet_resolve_timeout = 30,
        add_extra_trackers = 0,
        remove_original_trackers = false,
        modify_trackers_strategy = 0,

        force_use_trakt = false,
        trakt_scrobble = false,
        trakt_sync_enabled = false,
        trakt_sync_playback_enabled = false,
        trakt_sync_frequency_min = 5,

        completed_move = false,
        completed_movies_path = "",
        completed_shows_path = "",

        skip_burst_search = false,
        skip_repository_search = true,
        force_link_type = false,
        add_specials = false,
        unaired_seasons = false,
        unaired_episodes = false,
        show_episodes_on_release_day = false,
        use_fanart_tv = false,
        tmdb_images_quality = 1,
        tmdb_show_use_prod_company_as_studio = false,

        proxy_enabled = false,
        internal_proxy_enabled = false,
        internal_dns_enabled = false,
        antizapret_enabled = false,

        local_only_client = false,
        log_level = 2,
    }
end

function StandaloneConfig.build(config, platform, paths, locale)
    locale = locale or {}

    local language = locale.language or "en"
    local second_language = locale.second_language or ""
    local region = locale.region or "US"

    return {
        Info = {
            Author = "SrTristeSad",
            Description = "Luelement standalone Elementum host",
            Disclaimer = "",
            Fanart = "",
            Home = paths.root,
            Icon = "",
            ID = config.id,
            Name = config.name,
            Path = paths.plugin,
            Profile = paths.profile,
            TempPath = paths.temp,
            Stars = "",
            Summary = "Elementum engine for Luelement",
            Type = "plugin",
            Version = config.version,
            Xbmc = "",
        },
        Platform = {
            OS = platform.os,
            Arch = platform.arch,
            Version = "",
            Kodi = 0,
            Build = "Luelement",
        },
        Settings = default_settings(paths),
        Language = language,
        SecondLanguage = second_language,
        Region = region,
    }
end

return StandaloneConfig
