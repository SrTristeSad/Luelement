return {
    id = "io.addko.luelement",
    name = "Luelement",
    version = "0.2.0-dev",

    elementum = {
        scheme = "http",
        host = "127.0.0.1",
        port = 65220,
        request_timeout_seconds = 15,
        startup_timeout_seconds = 30,
        playback_timeout_seconds = 120,
    },

    rpc = {
        host = "127.0.0.1",
        port = 65221,
    },

    daemon = {
        auto_start = true,
        auto_download = true,
        startup_poll_ms = 250,
        shutdown_timeout_seconds = 5,

        -- Pinado na build oficial Elementum v0.1.114.
        engine_version = "0.1.114",
        binary_commit = "2bfca0cd91cdf31e94eff121f997b78ff022224c",
        binary_base_url = "https://raw.githubusercontent.com/elgatito/elementum-binaries",
    },
}
