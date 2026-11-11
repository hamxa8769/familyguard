package com.familyguard.fg_native

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Web filter: a local, DNS-only VPN.
 *
 * Only DNS traffic goes through it — the VPN routes nothing but its own DNS
 * address, so normal browsing traffic never touches this code. Each DNS query
 * is checked against the parent's blocked domains: blocked names get a
 * "doesn't exist" (NXDOMAIN) answer, everything else is forwarded to a public
 * resolver and the answer passed back unchanged. Nothing is logged or sent
 * to the FamilyGuard server.
 *
 * Android shows its VPN key icon while this runs, and the child must approve
 * the VPN once (system dialog) — it is never silent.
 *
 * Limits: apps using encrypted DNS of their own (DNS-over-HTTPS) or a
 * "Private DNS" set to a hostname bypass it; FamilyGuard itself is excluded.
 */
class DnsVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null
    private val stop = AtomicBoolean(false)
    private val pool = Executors.newFixedThreadPool(4)
    private var rules = Rules()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            stopSelf()
            return START_NOT_STICKY
        }
        rules = Rules.load(this)
        if (rules.blockedDomains.isEmpty()) {
            shutdown()
            stopSelf()
            return START_NOT_STICKY
        }
        if (tun == null) start()
        return START_STICKY
    }

    override fun onRevoke() {
        // The child (or another VPN app) turned it off in Settings.
        shutdown()
        super.onRevoke()
    }

    override fun onDestroy() {
        shutdown()
        pool.shutdownNow()
        super.onDestroy()
    }

    private fun start() {
        val builder = Builder()
            .setSession("FamilyGuard web filter")
            .addAddress(TUN_ADDR, 32)
            .addDnsServer(DNS_ADDR)
            .addRoute(DNS_ADDR, 32) // only DNS goes through the tunnel
            .setBlocking(true)
        try {
            builder.addDisallowedApplication(packageName)
        } catch (_: Exception) {
        }
        val fd = builder.establish() ?: return // not approved by the user
        tun = fd
        stop.set(false)
        running = true
        Thread({ loop(fd) }, "fg-dns-vpn").start()
    }

    private fun shutdown() {
        stop.set(true)
        running = false
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
    }

    private fun loop(fd: ParcelFileDescriptor) {
        val input = FileInputStream(fd.fileDescriptor)
        val output = FileOutputStream(fd.fileDescriptor)
        val buf = ByteArray(32767)
        while (!stop.get()) {
            val n = try {
                input.read(buf)
            } catch (_: Exception) {
                break
            }
            if (n <= 0) continue
            val packet = buf.copyOf(n)
            val q = DnsPacket.parseQuery(packet) ?: continue
            pool.execute {
                val answer = if (rules.domainBlocked(q.name)) {
                    DnsPacket.nxdomain(q.dns)
                } else {
                    forward(q.dns)
                } ?: return@execute
                val reply = DnsPacket.wrapReply(q, answer)
                synchronized(output) {
                    try {
                        output.write(reply)
                    } catch (_: Exception) {
                    }
                }
            }
        }
    }

    /** Sends the raw DNS query to a public resolver (outside the VPN). */
    private fun forward(query: ByteArray): ByteArray? {
        for (upstream in UPSTREAMS) {
            try {
                DatagramSocket().use { s ->
                    protect(s) // don't loop back into this VPN
                    s.soTimeout = 4000
                    s.send(DatagramPacket(query, query.size, InetAddress.getByName(upstream), 53))
                    val resp = ByteArray(4096)
                    val p = DatagramPacket(resp, resp.size)
                    s.receive(p)
                    return resp.copyOf(p.length)
                }
            } catch (_: Exception) {
                // try the next resolver
            }
        }
        return null
    }

    companion object {
        const val ACTION_STOP = "com.familyguard.fg_native.STOP_VPN"
        private const val TUN_ADDR = "10.111.222.1"
        private const val DNS_ADDR = "10.111.222.2"
        private val UPSTREAMS = listOf("1.1.1.1", "8.8.8.8")

        @Volatile
        var running = false
            private set

        /** True when the child has approved the VPN (system dialog). */
        fun prepared(ctx: Context) = VpnService.prepare(ctx) == null

        /** Starts/refreshes the filter when there are blocked domains, stops it otherwise. */
        fun sync(ctx: Context): Boolean {
            val rules = Rules.load(ctx)
            val intent = Intent(ctx, DnsVpnService::class.java)
            if (rules.blockedDomains.isEmpty()) {
                if (running) ctx.startService(intent.setAction(ACTION_STOP))
                return false
            }
            if (!prepared(ctx)) return false
            return try {
                ctx.startService(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}

/**
 * Minimal IPv4 + UDP + DNS handling for the web filter: read a query packet
 * from the tunnel, and build the reply packet that goes back into it.
 */
object DnsPacket {
    class Query(
        val srcIp: ByteArray,
        val dstIp: ByteArray,
        val srcPort: Int,
        val dstPort: Int,
        val dns: ByteArray,
        val name: String,
    )

    fun parseQuery(p: ByteArray): Query? {
        if (p.size < 28) return null
        val version = (p[0].toInt() shr 4) and 0xF
        if (version != 4) return null // the tunnel only has an IPv4 DNS address
        val ihl = (p[0].toInt() and 0xF) * 4
        if (p[9].toInt() != 17) return null // UDP only
        val total = u16(p, 2).coerceAtMost(p.size)
        if (total < ihl + 8) return null
        val srcPort = u16(p, ihl)
        val dstPort = u16(p, ihl + 2)
        if (dstPort != 53) return null
        val dns = p.copyOfRange(ihl + 8, total)
        val name = questionName(dns) ?: return null
        return Query(p.copyOfRange(12, 16), p.copyOfRange(16, 20), srcPort, dstPort, dns, name)
    }

    /** First question's name, e.g. "www.example.com". */
    fun questionName(dns: ByteArray): String? {
        if (dns.size < 12 || u16(dns, 4) < 1) return null
        val labels = mutableListOf<String>()
        var i = 12
        while (i < dns.size) {
            val len = dns[i].toInt() and 0xFF
            if (len == 0) return labels.joinToString(".")
            if (len and 0xC0 != 0) return null // no compression in questions
            if (i + 1 + len > dns.size) return null
            labels.add(String(dns, i + 1, len, Charsets.US_ASCII))
            i += 1 + len
        }
        return null
    }

    /** "No such domain" answer to [query]: header + first question only. */
    fun nxdomain(query: ByteArray): ByteArray? {
        var i = 12
        while (i < query.size && query[i].toInt() != 0) i += 1 + (query[i].toInt() and 0xFF)
        val end = i + 1 + 4 // zero byte + QTYPE + QCLASS
        if (end > query.size) return null
        val r = query.copyOf(end)
        r[2] = ((query[2].toInt() or 0x80) and 0xFB).toByte() // QR=1, keep opcode/RD, AA=0
        r[3] = 0x83.toByte() // RA=1, RCODE=3 (NXDOMAIN)
        r[4] = 0; r[5] = 1 // QDCOUNT=1
        for (k in 6..11) r[k] = 0 // AN/NS/AR = 0
        return r
    }

    /** IPv4/UDP packet carrying [dns] from the DNS address back to the asker. */
    fun wrapReply(q: Query, dns: ByteArray): ByteArray {
        val total = 20 + 8 + dns.size
        val p = ByteArray(total)
        p[0] = 0x45
        put16(p, 2, total)
        p[6] = 0x40 // don't fragment
        p[8] = 64 // TTL
        p[9] = 17 // UDP
        System.arraycopy(q.dstIp, 0, p, 12, 4) // from: our DNS address
        System.arraycopy(q.srcIp, 0, p, 16, 4) // to: the app that asked
        put16(p, 10, checksum(p, 0, 20))
        put16(p, 20, q.dstPort)
        put16(p, 22, q.srcPort)
        put16(p, 24, 8 + dns.size)
        // UDP checksum 0 = "not computed", valid for IPv4.
        System.arraycopy(dns, 0, p, 28, dns.size)
        return p
    }

    private fun u16(b: ByteArray, o: Int) =
        ((b[o].toInt() and 0xFF) shl 8) or (b[o + 1].toInt() and 0xFF)

    private fun put16(b: ByteArray, o: Int, v: Int) {
        b[o] = (v shr 8).toByte()
        b[o + 1] = v.toByte()
    }

    private fun checksum(b: ByteArray, off: Int, len: Int): Int {
        var sum = 0L
        var i = off
        while (i < off + len - 1) {
            sum += u16(b, i)
            i += 2
        }
        if (len % 2 == 1) sum += (b[off + len - 1].toInt() and 0xFF) shl 8
        while (sum shr 16 != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        return sum.inv().toInt() and 0xFFFF
    }
}
