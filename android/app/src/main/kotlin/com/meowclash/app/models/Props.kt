package com.meowclash.app.models

import java.net.InetAddress

enum class AccessControlMode {
    acceptSelected, rejectSelected,
}

data class AccessControl(
    val enable: Boolean = false,
    val mode: AccessControlMode = AccessControlMode.rejectSelected,
    val acceptList: List<String>? = null,
    val rejectList: List<String>? = null,
)

data class CIDR(val address: InetAddress, val prefixLength: Int)

data class VpnOptions(
    val enable: Boolean,
    val port: Int,
    val accessControl: AccessControl? = null,
    val allowBypass: Boolean,
    val systemProxy: Boolean,
    val bypassDomain: List<String>? = null,
    val routeAddress: List<String>? = null,
    val ipv4Address: String,
    val ipv6Address: String,
    val dnsServerAddress: String,
    val includePackage: List<String>? = null,
    val excludePackage: List<String>? = null,
)

data class StartForegroundParams(
    val title: String,
    val server: String?,
    val content: String,
)
