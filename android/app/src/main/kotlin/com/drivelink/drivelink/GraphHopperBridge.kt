package com.drivelink.drivelink

import com.graphhopper.GHRequest
import com.graphhopper.GHResponse
import com.graphhopper.GraphHopper
import com.graphhopper.config.CHProfile
import com.graphhopper.config.Profile
import com.graphhopper.util.CustomModel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

/**
 * MethodChannel bridge exposing GraphHopper offline routing to Flutter.
 *
 * Channel: `drivelink/graphhopper`
 *
 *  - load(graphPath: String, profile: String)
 *      → opens the GraphHopper graph directory. Expected to contain the
 *        files produced by `graphhopper import` (edges, geometry, nodes, …).
 *
 *  - route(fromLat, fromLng, toLat, toLng, profile?)
 *      → returns a map with distanceMetres, durationSeconds, polyline
 *        (flat [lat, lng, lat, lng, …]) and instructions (list of maps).
 *
 *  - close()
 *      → releases the loaded graph.
 *
 * All heavy operations run on a single background executor so that the
 * UI thread stays responsive.
 */
class GraphHopperBridge(engine: FlutterEngine) : MethodCallHandler {

    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "drivelink/graphhopper",
    ).also { it.setMethodCallHandler(this) }

    private val executor = Executors.newSingleThreadExecutor()

    @Volatile
    private var hopper: GraphHopper? = null

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "load" -> loadAsync(call, result)
            "route" -> routeAsync(call, result)
            "close" -> closeAsync(result)
            else -> result.notImplemented()
        }
    }

    // ── load ─────────────────────────────────────────────────────────

    private fun loadAsync(call: MethodCall, result: Result) {
        val graphPath = call.argument<String>("graphPath")
        val profile = call.argument<String>("profile") ?: "car"
        if (graphPath == null) {
            result.error("ARG", "graphPath required", null)
            return
        }
        executor.execute {
            try {
                hopper?.close()
                // Force MMAP on every data access — default is RAM_STORE
                // which puts the whole graph on the heap. Turkey's graph is
                // hundreds of MB post-CH, which OOMs on Android even with
                // largeHeap=true. MMAP backs storage with the OS page cache
                // so heap stays tiny.
                System.setProperty("graphhopper.graph.dataaccess.default_type", "MMAP")

                // "shortest" weighting + empty CustomModel matches the
                // profile baked into the graph by build.py. We avoid
                // weighting=custom because GraphHopper compiles custom-
                // model expressions with Janino, which cannot load
                // Android DEX class files. But GraphHopper 9.x still
                // requires the custom_model field to be non-null even
                // when weighting is "shortest", so we hand it an empty
                // CustomModel.
                val gh = GraphHopper()
                gh.graphHopperLocation = graphPath
                gh.profiles = listOf(
                    Profile(profile)
                        .setWeighting("shortest")
                        .setCustomModel(CustomModel()),
                )
                gh.chPreparationHandler.setCHProfiles(CHProfile(profile))
                gh.importOrLoad()
                hopper = gh
                postSuccess(result, null)
            } catch (e: Throwable) {
                postError(result, "LOAD_FAIL", e.message, e.stackTraceToString())
            }
        }
    }

    // ── route ────────────────────────────────────────────────────────

    private fun routeAsync(call: MethodCall, result: Result) {
        val fromLat = call.argument<Double>("fromLat")
        val fromLng = call.argument<Double>("fromLng")
        val toLat = call.argument<Double>("toLat")
        val toLng = call.argument<Double>("toLng")
        val profile = call.argument<String>("profile") ?: "car"
        if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
            result.error("ARG", "fromLat/fromLng/toLat/toLng required", null)
            return
        }
        val gh = hopper
        if (gh == null) {
            result.error("NOT_LOADED", "GraphHopper not loaded — call load() first", null)
            return
        }

        executor.execute {
            try {
                val req = GHRequest(fromLat, fromLng, toLat, toLng)
                req.profile = profile
                val resp: GHResponse = gh.route(req)

                if (resp.hasErrors()) {
                    val msg = resp.errors.joinToString("; ") { it.message ?: it.toString() }
                    postError(result, "ROUTE_FAIL", msg, null)
                    return@execute
                }

                val best = resp.best
                val poly = ArrayList<Double>(best.points.size() * 2)
                for (i in 0 until best.points.size()) {
                    poly.add(best.points.getLat(i))
                    poly.add(best.points.getLon(i))
                }

                val instructions = ArrayList<Map<String, Any?>>()
                for (instr in best.instructions) {
                    instructions.add(mapOf(
                        "sign" to instr.sign,
                        "name" to instr.name,
                        "distanceMetres" to instr.distance,
                        "durationMs" to instr.time,
                    ))
                }

                postSuccess(result, mapOf(
                    "distanceMetres" to best.distance,
                    "durationSeconds" to best.time / 1000.0,
                    "polyline" to poly,
                    "instructions" to instructions,
                ))
            } catch (e: Throwable) {
                postError(result, "ROUTE_FAIL", e.message, e.stackTraceToString())
            }
        }
    }

    // ── close ────────────────────────────────────────────────────────

    private fun closeAsync(result: Result) {
        executor.execute {
            try {
                hopper?.close()
                hopper = null
                postSuccess(result, null)
            } catch (e: Throwable) {
                postError(result, "CLOSE_FAIL", e.message, null)
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────

    /** Deliver a success on the platform main thread. */
    private fun postSuccess(result: Result, value: Any?) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.success(value)
        }
    }

    /** Deliver an error on the platform main thread. */
    private fun postError(result: Result, code: String, msg: String?, details: String?) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            result.error(code, msg ?: code, details)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
        try { hopper?.close() } catch (_: Throwable) {}
        hopper = null
    }
}
