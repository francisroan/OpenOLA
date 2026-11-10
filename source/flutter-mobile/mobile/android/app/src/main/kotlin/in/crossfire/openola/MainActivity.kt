package `in`.crossfire.openola

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Base64
import com.flyfishxu.kadb.Kadb
import com.flyfishxu.kadb.cert.KadbCert
import com.flyfishxu.kadb.cert.OkioFilePrivateKeyStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayInputStream
import java.math.BigInteger
import java.net.Inet6Address
import java.net.InetAddress
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.cert.CertificateFactory
import java.security.interfaces.RSAPublicKey
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.runBlocking
import okio.Path.Companion.toPath
import okio.sink
import okio.source

class MainActivity : FlutterActivity() {
    private val networkChannel = "in.crossfire.openola/network"
    private val hapticsChannel = "in.crossfire.openola/haptics"
    private val adbChannel = "in.crossfire.openola/adb"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var directAdb: Kadb? = null
    private var adbMethodChannel: MethodChannel? = null
    private var lastProgressMs = 0L

    /// Throttled native→Dart byte-progress event (at most ~10/s, plus the
    /// final one so the bar always reaches 100 %).
    private fun emitProgress(op: String, sent: Long, total: Long, index: Int, count: Int) {
        val now = System.currentTimeMillis()
        if (sent < total && now - lastProgressMs < 100) return
        lastProgressMs = now
        mainHandler.post {
            adbMethodChannel?.invokeMethod(
                "progress",
                mapOf("op" to op, "sent" to sent, "total" to total, "index" to index, "count" to count),
            )
        }
    }

    private class CountingSource(
        private val delegate: okio.Source,
        private val onBytes: (Long) -> Unit,
    ) : okio.Source {
        override fun read(sink: okio.Buffer, byteCount: Long): Long {
            val n = delegate.read(sink, byteCount)
            if (n > 0) onBytes(n)
            return n
        }
        override fun timeout() = delegate.timeout()
        override fun close() = delegate.close()
    }

    private class CountingSink(
        private val delegate: okio.Sink,
        private val onBytes: (Long) -> Unit,
    ) : okio.Sink {
        override fun write(source: okio.Buffer, byteCount: Long) {
            delegate.write(source, byteCount)
            onBytes(byteCount)
        }
        override fun flush() = delegate.flush()
        override fun timeout() = delegate.timeout()
        override fun close() = delegate.close()
    }

    // Held for the lifetime of a Wi-Fi session. Holding the NetworkRequest is
    // what keeps a no-internet scooter AP alive; without it Android validates
    // the network, finds no upstream, and is free to drop or replace the
    // Network object, which kills the bound socket mid-stream (HTTP/2
    // CONNECT_ERROR / "connection forcefully terminated").
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Each OpenOLA installation owns one persistent ADB identity. Its
        // private key never leaves app-private storage; the matching Android
        // public-key token can be authorized through the root gRPC bridge.
        val adbKey = File(filesDir, "adb/openola_adb_key.pem")
        KadbCert.configure(
            store = OkioFilePrivateKeyStore(adbKey.absolutePath.toPath()),
        )
        KadbCert.ensureReady()
        adbMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, adbChannel)
        adbMethodChannel!!
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val host = call.argument<String>("host")?.trim().orEmpty()
                        val port = call.argument<Int>("port") ?: 5555
                        if (host.isEmpty() || port !in 1..65535) {
                            result.error("adb_target_invalid", "Enter a valid ADB host and port.", null)
                        } else {
                            runAdbTask(result) {
                                directAdb?.close()
                                directAdb = null
                                val client = Kadb.create(
                                    host = host,
                                    port = port,
                                    connectTimeout = 12_000,
                                    socketTimeout = 30_000,
                                )
                                try {
                                    val identity = client.shell("id").allOutput.trim()
                                    directAdb = client
                                    "Authorized & connected · app identity${if (identity.isEmpty()) "" else " · $identity"}"
                                } catch (error: Throwable) {
                                    client.close()
                                    throw error
                                }
                            }
                        }
                    }
                    "publicKey" -> runAdbTask(result) {
                        androidAdbPublicKeyToken()
                    }
                    "shell" -> {
                        val command = call.argument<String>("command")?.trim().orEmpty()
                        if (command.isEmpty()) {
                            result.error("adb_command_empty", "Enter a shell command.", null)
                        } else {
                            runAdbTask(result) {
                                val client = directAdb
                                    ?: error("Direct ADB is not connected")
                                val response = client.shell(command)
                                if (response.exitCode != 0) {
                                    error(
                                        response.allOutput.trim().ifEmpty {
                                            "ADB command exited with ${response.exitCode}"
                                        },
                                    )
                                }
                                response.allOutput
                            }
                        }
                    }
                    "install" -> {
                        val path = call.argument<String>("path")?.trim().orEmpty()
                        val file = File(path)
                        if (!file.isFile || file.length() !in 1..(300L * 1024L * 1024L)) {
                            result.error(
                                "adb_apk_invalid",
                                "APK is missing or exceeds the 300 MB limit.",
                                null,
                            )
                        } else {
                            runAdbTask(result) {
                                val client = directAdb
                                    ?: error("Direct ADB is not connected")
                                client.install(file, "-r")
                                "Success"
                            }
                        }
                    }
                    "installFiles" -> {
                        val files = (call.argument<List<String>>("paths") ?: emptyList())
                            .map { File(it.trim()) }
                        val total = files.sumOf { if (it.isFile) it.length() else -1L }
                        if (files.isEmpty() || files.size > 64 || total !in 1..(300L * 1024L * 1024L)) {
                            result.error(
                                "adb_apk_invalid",
                                "APK files are missing or exceed the 300 MB limit.",
                                null,
                            )
                        } else {
                            runAdbTask(result) {
                                val client = directAdb
                                    ?: error("Direct ADB is not connected")
                                val remotes = files.indices
                                    .map { "/data/local/tmp/openola_install_$it.apk" }
                                var sent = 0L
                                try {
                                    files.forEachIndexed { i, file ->
                                        client.push(
                                            CountingSource(file.source()) { n ->
                                                sent += n
                                                emitProgress("install", sent, total, i, files.size)
                                            },
                                            remotes[i],
                                            420, // 0644
                                            System.currentTimeMillis(),
                                        )
                                    }
                                    emitProgress("install", total, total, files.size - 1, files.size)
                                    if (files.size == 1) {
                                        val response = client.shell("pm install -r ${remotes[0]}")
                                        response.allOutput.trim()
                                            .ifEmpty { "ADB exited with ${response.exitCode}" }
                                    } else {
                                        // pm has no install-multiple: open a session, stage
                                        // each file, then commit.
                                        val created = client.shell("pm install-create -r").allOutput
                                        val session = Regex("\\[(\\d+)\\]").find(created)?.groupValues?.get(1)
                                            ?: error("Package manager did not open a session: ${created.trim()}")
                                        try {
                                            files.forEachIndexed { i, file ->
                                                val name = if (i == 0) "base.apk" else "split_$i.apk"
                                                val staged = client.shell(
                                                    "pm install-write -S ${file.length()} $session $name ${remotes[i]}",
                                                ).allOutput
                                                if (!staged.contains("Success")) {
                                                    error("Could not stage $name: ${staged.trim()}")
                                                }
                                            }
                                            client.shell("pm install-commit $session").allOutput.trim()
                                        } catch (error: Throwable) {
                                            runCatching { client.shell("pm install-abandon $session") }
                                            throw error
                                        }
                                    }
                                } finally {
                                    runCatching {
                                        client.shell("rm -f ${remotes.joinToString(" ")}")
                                    }
                                }
                            }
                        }
                    }
                    "pull" -> {
                        val remote = call.argument<String>("remote")?.trim().orEmpty()
                        val local = call.argument<String>("local")?.trim().orEmpty()
                        val total = (call.argument<Number>("total") ?: 0).toLong()
                        if (!Regex("^/[A-Za-z0-9._@=+~/-]+$").matches(remote) ||
                            remote.contains("..") || local.isEmpty()
                        ) {
                            result.error("adb_pull_invalid", "Invalid pull path.", null)
                        } else {
                            runAdbTask(result) {
                                val client = directAdb
                                    ?: error("Direct ADB is not connected")
                                val target = File(local)
                                var received = 0L
                                client.pull(
                                    CountingSink(target.sink()) { n ->
                                        received += n
                                        emitProgress("pull", received, if (total > 0) total else received, 0, 1)
                                    },
                                    remote,
                                )
                                if (total > 0) emitProgress("pull", total, total, 0, 1)
                                "Success ${target.length()}"
                            }
                        }
                    }
                    "disconnect" -> {
                        directAdb?.close()
                        directAdb = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Native vibrator: HapticFeedback is muted by many Android skins
        // (ColorOS/MIUI) unless the app drives the Vibrator service directly.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        val ms = (call.argument<Int>("ms") ?: 20).toLong()
                        val amp = call.argument<Int>("amplitude") ?: -1
                        vibrate(ms, amp)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkChannel)
            .setMethodCallHandler { call, result ->
                val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                when (call.method) {
                    "bindProcessToWifi" -> {
                        val phoneHotspot = call.argument<Boolean>("phoneHotspot") == true
                        if (phoneHotspot) {
                            // Phone hosts the scooter's hotspot: there is no Wi-Fi
                            // client network to bind. Clear any binding so Android
                            // uses its local tethering route to the scooter instead
                            // of the cellular upstream.
                            releaseWifiRequest(connectivity)
                            if (connectivity.bindProcessToNetwork(null)) {
                                result.success(true)
                            } else {
                                result.error(
                                    "network_restore_failed",
                                    "Android could not restore local routing for the hotspot.",
                                    null,
                                )
                            }
                        } else {
                            requestAndBindWifi(connectivity, result)
                        }
                    }
                    "restoreDefaultNetwork" -> {
                        releaseWifiRequest(connectivity)
                        result.success(connectivity.bindProcessToNetwork(null))
                    }
                    "discoverIpv6Hosts" -> {
                        // LinkProperties contains the IPv6 default gateway when
                        // the phone has joined a Gen2/3 scooter AP. `ip neigh`
                        // also covers a scooter joined to this phone's hotspot.
                        // Run the process read off the UI thread.
                        Thread {
                            val hosts = discoverIpv6Hosts(connectivity)
                            mainHandler.post { result.success(hosts) }
                        }.start()
                    }
                    "bleCancelDiscovery" -> {
                        // ColorOS: a classic discovery in progress starves LE connect.
                        try {
                            BluetoothAdapter.getDefaultAdapter()?.cancelDiscovery()
                        } catch (_: SecurityException) {
                        }
                        result.success(true)
                    }
                    "bleBondState" -> {
                        val address = call.argument<String>("address")?.trim()?.uppercase().orEmpty()
                        try {
                            val device = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(address)
                            result.success(device.bondState)
                        } catch (error: Exception) {
                            result.error("ble_bond", error.message ?: "Bond state unavailable", null)
                        }
                    }
                    "bleCreateBond" -> {
                        val address = call.argument<String>("address")?.trim()?.uppercase().orEmpty()
                        Thread {
                            val bonded = awaitBond(address, true)
                            mainHandler.post { result.success(bonded) }
                        }.start()
                    }
                    "bleRemoveBond" -> {
                        // Clears a stale bond (for example from the official app) by
                        // reflection; the system pairing dialog then appears again.
                        val address = call.argument<String>("address")?.trim()?.uppercase().orEmpty()
                        try {
                            val device = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(address)
                            val removed = device.javaClass.getMethod("removeBond").invoke(device) as? Boolean ?: false
                            result.success(removed)
                        } catch (error: Exception) {
                            result.success(false)
                        }
                    }
                    "startKeepAlive" -> {
                        try {
                            val intent = Intent(this, ConnectionService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stopKeepAlive" -> {
                        stopService(Intent(this, ConnectionService::class.java))
                        result.success(true)
                    }
                    "saveToDownloads" -> {
                        // Copies a finished file into Download/<folder> through
                        // MediaStore, which needs no storage permission (a plain
                        // File write to a picked folder is blocked on Android 11+).
                        try {
                            val src = File(call.argument<String>("source")!!)
                            val name = call.argument<String>("name")!!
                            val folder = call.argument<String>("folder") ?: "OpenOLA"
                            if (Build.VERSION.SDK_INT >= 29) {
                                val values = android.content.ContentValues().apply {
                                    put(android.provider.MediaStore.Downloads.DISPLAY_NAME, name)
                                    put(
                                        android.provider.MediaStore.Downloads.MIME_TYPE,
                                        "application/octet-stream",
                                    )
                                    put(
                                        android.provider.MediaStore.Downloads.RELATIVE_PATH,
                                        "Download/$folder",
                                    )
                                }
                                val uri = contentResolver.insert(
                                    android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                    values,
                                ) ?: throw IllegalStateException("MediaStore refused the file")
                                contentResolver.openOutputStream(uri)!!.use { out ->
                                    src.inputStream().use { it.copyTo(out) }
                                }
                                result.success("Download/$folder/$name")
                            } else {
                                val dir = File(
                                    android.os.Environment.getExternalStoragePublicDirectory(
                                        android.os.Environment.DIRECTORY_DOWNLOADS,
                                    ),
                                    folder,
                                )
                                dir.mkdirs()
                                val target = File(dir, name)
                                src.copyTo(target, overwrite = false)
                                result.success("Download/$folder/$name")
                            }
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    "enableBluetooth" -> {
                        // Shows the system "turn on Bluetooth?" dialog. Needs the
                        // BLUETOOTH_CONNECT runtime permission on API 31+, which
                        // the BLE flow requests before calling this.
                        try {
                            startActivity(
                                Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                            )
                            result.success(true)
                        } catch (error: Exception) {
                            result.error(
                                "bt_enable_failed",
                                error.message ?: "Could not request Bluetooth enable.",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Starts (or joins) bonding with [address] and waits up to 30 s for the
    /// result. Returns true only when the device ends up bonded.
    private fun awaitBond(address: String, create: Boolean): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        val device = try {
            adapter.getRemoteDevice(address)
        } catch (_: Exception) {
            return false
        }
        if (device.bondState == android.bluetooth.BluetoothDevice.BOND_BONDED) return true
        val latch = java.util.concurrent.CountDownLatch(1)
        val receiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val changed = intent?.getParcelableExtra<android.bluetooth.BluetoothDevice>(
                    android.bluetooth.BluetoothDevice.EXTRA_DEVICE,
                )
                if (changed?.address?.equals(address, ignoreCase = true) != true) return
                val state = intent.getIntExtra(
                    android.bluetooth.BluetoothDevice.EXTRA_BOND_STATE,
                    android.bluetooth.BluetoothDevice.BOND_NONE,
                )
                if (state != android.bluetooth.BluetoothDevice.BOND_BONDING) latch.countDown()
            }
        }
        registerReceiver(
            receiver,
            android.content.IntentFilter(android.bluetooth.BluetoothDevice.ACTION_BOND_STATE_CHANGED),
        )
        return try {
            if (create && device.bondState == android.bluetooth.BluetoothDevice.BOND_NONE) {
                if (!device.createBond()) return false
            }
            latch.await(60, java.util.concurrent.TimeUnit.SECONDS)
            device.bondState == android.bluetooth.BluetoothDevice.BOND_BONDED
        } catch (_: SecurityException) {
            false
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
        }
    }

    private fun runAdbTask(result: MethodChannel.Result, action: () -> String) {
        Thread {
            try {
                val value = action()
                mainHandler.post { result.success(value) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "direct_adb_failed",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }.start()
    }

    private fun androidAdbPublicKeyToken(): String {
        val snapshot = KadbCert.ensureReady()
        val certificate = CertificateFactory.getInstance("X.509")
            .generateCertificate(ByteArrayInputStream(snapshot.certificatePem))
        val publicKey = certificate.publicKey as? RSAPublicKey
            ?: error("OpenOLA ADB identity is not an RSA key")
        val encoded = ByteBuffer.allocate(524).order(ByteOrder.LITTLE_ENDIAN)
        encoded.putInt(64)
        val r32 = BigInteger.ONE.shiftLeft(32)
        val n0inv = r32.subtract(publicKey.modulus.mod(r32).modInverse(r32))
        encoded.putInt(n0inv.toInt())
        encoded.put(littleEndianPadded(publicKey.modulus, 256))
        val rr = BigInteger.ONE.shiftLeft(2048)
            .modPow(BigInteger.valueOf(2L), publicKey.modulus)
        encoded.put(littleEndianPadded(rr, 256))
        encoded.putInt(publicKey.publicExponent.toInt())
        return Base64.encodeToString(encoded.array(), Base64.NO_WRAP)
    }

    private fun littleEndianPadded(value: BigInteger, size: Int): ByteArray {
        val bigEndian = value.toByteArray()
        val unsigned = if (bigEndian.size > 1 && bigEndian[0] == 0.toByte()) {
            bigEndian.copyOfRange(1, bigEndian.size)
        } else {
            bigEndian
        }
        require(unsigned.size <= size) { "RSA value exceeds Android key field" }
        return ByteArray(size).also { output ->
            for (index in unsigned.indices) {
                output[index] = unsigned[unsigned.lastIndex - index]
            }
        }
    }

    private fun requestAndBindWifi(connectivity: ConnectivityManager, result: MethodChannel.Result) {
        // Drop any prior request so reconnects do not leak callbacks.
        releaseWifiRequest(connectivity)

        // Request a Wi-Fi network WITHOUT requiring internet. The default builder
        // demands NET_CAPABILITY_INTERNET, which a scooter AP never has, so it
        // would never match. Removing it lets us hold (and keep alive) the
        // local-only network for the whole session.
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        val replied = AtomicBoolean(false)
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Fires on first match and again if Android swaps the Network
                // object; re-bind each time so the process always points at the
                // live scooter network.
                val bound = connectivity.bindProcessToNetwork(network)
                if (replied.compareAndSet(false, true)) {
                    mainHandler.post {
                        if (bound) {
                            result.success(true)
                        } else {
                            result.error(
                                "wifi_bind_failed",
                                "Android could not route the app over Wi-Fi.",
                                null,
                            )
                        }
                    }
                }
            }

            override fun onUnavailable() {
                if (replied.compareAndSet(false, true)) {
                    mainHandler.post {
                        result.error(
                            "wifi_unavailable",
                            "No scooter Wi-Fi was found. Join the scooter's Wi-Fi, then retry.",
                            null,
                        )
                    }
                }
            }
        }
        wifiCallback = callback
        try {
            // 6s < the 8s Dart-side timeout, so onUnavailable surfaces a clean
            // error before Dart times the channel call out.
            connectivity.requestNetwork(request, callback, 6_000)
        } catch (e: SecurityException) {
            wifiCallback = null
            if (replied.compareAndSet(false, true)) {
                result.error(
                    "wifi_request_failed",
                    e.message ?: "Android denied the Wi-Fi network request.",
                    null,
                )
            }
        }
    }

    private fun releaseWifiRequest(connectivity: ConnectivityManager) {
        wifiCallback?.let {
            try {
                connectivity.unregisterNetworkCallback(it)
            } catch (_: Exception) {
                // Already unregistered or never registered; ignore.
            }
        }
        wifiCallback = null
    }

    private fun discoverIpv6Hosts(connectivity: ConnectivityManager): List<String> {
        val candidates = linkedSetOf<String>()
        val localAddresses = mutableSetOf<String>()

        fun normalized(raw: String, interfaceName: String?): String? {
            val unbracketed = raw.removePrefix("[").removeSuffix("]")
            val base = unbracketed.substringBefore('%')
            if (!base.contains(':')) return null
            val address = try {
                InetAddress.getByName(base)
            } catch (_: Exception) {
                return null
            }
            if (address !is Inet6Address || address.isAnyLocalAddress ||
                address.isLoopbackAddress || address.isMulticastAddress
            ) return null
            if (base.lowercase() in localAddresses) return null
            val scoped = if (address.isLinkLocalAddress && !unbracketed.contains('%')) {
                val scope = interfaceName?.takeIf { it.isNotBlank() } ?: return null
                "$base%$scope"
            } else {
                unbracketed
            }
            return "[$scoped]"
        }

        for (network in connectivity.allNetworks) {
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) continue
            val properties = connectivity.getLinkProperties(network) ?: continue
            for (link in properties.linkAddresses) {
                val address = link.address
                if (address is Inet6Address) {
                    localAddresses += address.hostAddress.substringBefore('%').lowercase()
                }
            }
            for (route in properties.routes) {
                val gateway = route.gateway
                if (gateway is Inet6Address) {
                    normalized(gateway.hostAddress, properties.interfaceName)?.let(candidates::add)
                }
            }
        }

        // Android does not expose tethered-client neighbours through
        // ConnectivityManager. The kernel neighbour table is read-only and is
        // available on the builds we target; failure simply leaves the gateway
        // candidates above.
        try {
            val process = ProcessBuilder("ip", "-6", "neigh", "show")
                .redirectErrorStream(true)
                .start()
            if (!process.waitFor(2, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                return candidates.toList()
            }
            process.inputStream.bufferedReader().useLines { lines ->
                lines.forEach { line ->
                    val fields = line.trim().split(Regex("\\s+"))
                    if (fields.isEmpty() || !fields[0].contains(':')) return@forEach
                    if (fields.any { it.equals("FAILED", ignoreCase = true) }) return@forEach
                    val dev = fields.indexOf("dev")
                        .takeIf { it >= 0 && it + 1 < fields.size }
                        ?.let { fields[it + 1] }
                    normalized(fields[0], dev)?.let(candidates::add)
                }
            }
        } catch (_: Exception) {
            // Gateway discovery still works when the `ip` utility is hidden.
        }
        return candidates.toList()
    }

    @Suppress("DEPRECATION")
    private fun vibrate(ms: Long, amplitude: Int) {
        val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vib.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val amp = if (amplitude in 1..255) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
            vib.vibrate(VibrationEffect.createOneShot(ms, amp))
        } else {
            vib.vibrate(ms)
        }
    }

    override fun onDestroy() {
        directAdb?.close()
        directAdb = null
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        releaseWifiRequest(connectivity)
        super.onDestroy()
    }
}
