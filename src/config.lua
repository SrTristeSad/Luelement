return {
    id = "io.addko.luelement",
    name = "Luelement",
    version = "0.1.0-dev",

    elementum = {
        scheme = "http",
        host = "127.0.0.1",
        port = 65220,
        request_timeout_seconds = 15,
        startup_timeout_seconds = 20,
    },

    daemon = {
        auto_start = true,
        executable = {
            windows = "elementum.exe",
            linux = "elementum",
            android = "elementum",
            macos = "elementum",
        },
    },
}
