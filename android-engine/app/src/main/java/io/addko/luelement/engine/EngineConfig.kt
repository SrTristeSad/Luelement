package io.addko.luelement.engine

import android.content.Context
import org.json.JSONObject
import java.io.File

internal data class EngineRuntime(
    val root: File,
    val profile: File,
    val temp: File,
    val torrents: File,
    val library: File,
    val downloads: File,
    val addon: File,
    val config: File,
    val log: File,
) {
    fun args(): String = listOf(
        "-configPath=${config.absolutePath}",
        "-addonPath=${addon.absolutePath}",
        "-profilePath=${profile.absolutePath}",
        "-tempPath=${temp.absolutePath}",
        "-torrentsPath=${torrents.absolutePath}",
        "-libraryPath=${library.absolutePath}",
        "-downloadsPath=${downloads.absolutePath}",
        "-logPath=${log.absolutePath}",
        "-localHost=127.0.0.1",
        "-localPort=65220",
        "-remoteHost=127.0.0.1",
        "-remotePort=65221",
        "-disableParentProcessWatcher",
        "-disableLibrarySync",
    ).joinToString(" ")
}

internal object EngineConfig {
    fun prepare(context: Context): EngineRuntime {
        val root = File(context.filesDir, "elementum").apply { mkdirs() }
        val profile = File(root, "profile").apply { mkdirs() }
        val temp = File(context.cacheDir, "elementum").apply { mkdirs() }
        val torrents = File(root, "torrents").apply { mkdirs() }
        val library = File(root, "library").apply { mkdirs() }
        val downloads = File(root, "downloads").apply { mkdirs() }
        val addon = File(root, "addon").apply { mkdirs() }
        val config = File(root, "elementum-config.json")
        val log = File(root, "elementum.log")

        val runtime = EngineRuntime(
            root = root,
            profile = profile,
            temp = temp,
            torrents = torrents,
            library = library,
            downloads = downloads,
            addon = addon,
            config = config,
            log = log,
        )

        config.writeText(buildJson(runtime).toString())
        return runtime
    }

    private fun buildJson(paths: EngineRuntime): JSONObject {
        val info = JSONObject()
            .put("Author", "SrTristeSad")
            .put("Description", "Luelement Android companion engine")
            .put("Disclaimer", "")
            .put("Fanart", "")
            .put("Home", paths.root.absolutePath)
            .put("Icon", "")
            .put("ID", "io.addko.luelement.engine")
            .put("Name", "Luelement Engine")
            .put("Path", paths.addon.absolutePath)
            .put("Profile", paths.profile.absolutePath)
            .put("TempPath", paths.temp.absolutePath)
            .put("Stars", "")
            .put("Summary", "Embedded Elementum engine for Luelement")
            .put("Type", "service")
            .put("Version", "0.1.0-dev")
            .put("Xbmc", "")

        val platform = JSONObject()
            .put("OS", "android")
            .put("Arch", "arm64")
            .put("Version", android.os.Build.VERSION.RELEASE ?: "")
            .put("Kodi", 20)
            .put("Build", "LuelementEngine")

        val settings = JSONObject()
            .put("download_path", paths.downloads.absolutePath)
            .put("library_path", paths.library.absolutePath)
            .put("torrents_path", paths.torrents.absolutePath)
            .put("play_resume_action", 1)
            .put("play_resume_back", 0)
            .put("download_storage", 1)
            .put("download_file_strategy", 0)
            .put("keep_downloading", 1)
            .put("keep_files_playing", 1)
            .put("keep_files_finished", 1)
            .put("auto_memory_size", true)
            .put("auto_memory_size_strategy", 1)
            .put("memory_size", 100)
            .put("auto_adjust_memory_size", true)
            .put("auto_kodi_buffer_size", false)
            .put("auto_adjust_buffer_size", false)
            .put("min_candidate_size", 100)
            .put("min_candidate_show_size", 4)
            .put("buffer_size", 20)
            .put("end_buffer_size", 4)
            .put("buffer_timeout", 60)
            .put("use_torrent_history", true)
            .put("torrent_history_size", 50)
            .put("autoload_torrents", true)
            .put("autoload_torrents_paused", true)
            .put("use_cache_selection", true)
            .put("use_cache_search", true)
            .put("use_cache_torrents", true)
            .put("cache_search_duration", 24)
            .put("results_per_page", 20)
            .put("silent_stream_start", false)
            .put("autoyes_enabled", true)
            .put("autoyes_timeout", 5)
            .put("choose_stream_auto_movie", false)
            .put("choose_stream_auto_show", false)
            .put("choose_stream_auto_search", false)
            .put("smart_episode_match", true)
            .put("smart_episode_start", true)
            .put("smart_episode_choose", true)
            .put("library_enabled", false)
            .put("library_sync_enabled", false)
            .put("library_sync_playback_enabled", false)
            .put("seed_forever", false)
            .put("share_ratio_limit", 200)
            .put("seed_time_ratio_limit", 700)
            .put("seed_time_limit", 24)
            .put("disable_upload", false)
            .put("disable_lsd", false)
            .put("disable_dht", false)
            .put("disable_tcp", false)
            .put("disable_utp", false)
            .put("disable_upnp", false)
            .put("disable_natpmp", false)
            .put("listen_autodetect_ip", true)
            .put("listen_autodetect_port", true)
            .put("listen_port_min", 6881)
            .put("listen_port_max", 6891)
            .put("listen_interfaces", "")
            .put("outgoing_interfaces", "")
            .put("encryption_policy", 0)
            .put("max_upload_rate", 0)
            .put("max_download_rate", 0)
            .put("limit_after_buffering", false)
            .put("connections_limit", 0)
            .put("conntracker_limit_auto", true)
            .put("conntracker_limit", 0)
            .put("session_save", 15)
            .put("tuned_storage", true)
            .put("disk_cache_size", 12)
            .put("use_libtorrent_config", false)
            .put("use_libtorrent_logging", false)
            .put("use_libtorrent_deadline", true)
            .put("use_libtorrent_pauseresume", true)
            .put("libtorrent_profile", 0)
            .put("magnet_resolve_timeout", 30)
            .put("add_extra_trackers", 0)
            .put("remove_original_trackers", false)
            .put("modify_trackers_strategy", 0)
            .put("force_use_trakt", false)
            .put("trakt_scrobble", false)
            .put("trakt_sync_enabled", false)
            .put("trakt_sync_playback_enabled", false)
            .put("completed_move", false)
            .put("skip_burst_search", false)
            .put("skip_repository_search", true)
            .put("force_link_type", false)
            .put("use_fanart_tv", false)
            .put("proxy_enabled", false)
            .put("internal_proxy_enabled", false)
            .put("internal_dns_enabled", false)
            .put("antizapret_enabled", false)
            .put("local_only_client", false)
            .put("log_level", 2)

        return JSONObject()
            .put("Info", info)
            .put("Platform", platform)
            .put("Settings", settings)
            .put("Language", "pt")
            .put("SecondLanguage", "en")
            .put("Region", "BR")
    }
}
