package com.drivelink.drivelink

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var graphHopperBridge: GraphHopperBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        graphHopperBridge = GraphHopperBridge(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        graphHopperBridge?.dispose()
        graphHopperBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
