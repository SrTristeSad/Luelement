package io.addko.luelement.engine

internal object EngineBridge {
    init {
        // Elementum's shared build depends on libc++_shared. Both libraries are
        // packaged in the signed APK by the Gradle prepareElementumNative task.
        System.loadLibrary("c++_shared")
        System.loadLibrary("elementum")
        System.loadLibrary("luelement_bridge")
    }

    external fun start(logPath: String, args: String): Long
}
