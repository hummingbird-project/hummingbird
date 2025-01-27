//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird open source project
//
// Copyright (c) YEARS the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOSSL

let testServerName = "hummingbird.codes"

let caCertificateData =
"""
-----BEGIN CERTIFICATE-----
MIIDZDCCAkwCCQC/h+690H5uwDANBgkqhkiG9w0BAQsFADB0MQswCQYDVQQGEwJV
SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxFDASBgNV
BAoMC0h1bW1pbmdiaXJkMQswCQYDVQQLDAJDQTEaMBgGA1UEAwwRaHVtbWluZ2Jp
cmQuY29kZXMwHhcNMjUwMTI3MDgzMjA3WhcNMzAwMTI2MDgzMjA3WjB0MQswCQYD
VQQGEwJVSzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gx
FDASBgNVBAoMC0h1bW1pbmdiaXJkMQswCQYDVQQLDAJDQTEaMBgGA1UEAwwRaHVt
bWluZ2JpcmQuY29kZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCz
PObkaQ5rIRPTc+ulozigdmRKEE8W6Dl9FYPwn/l1buVZZMjiY29S5nvRdWCR0d5b
ERv8t10VOcBObiThvLVmRfitCVqMc8Lwfqg3FvH2R71z5fz0R0iY3XAEst/5feZQ
XXeLPnXNw0otIiojQy9dmLpWqWhhMQk+KHvWf1Z3NLopraJxUBnoMoCtfm+q6PKO
jJOIJrR3oRQuUmqiMY24wfwuFxO9vWkZl7H3a7I7mtlbSJ90XXX1Nd5LAAUP0ESa
bubZz3fCveJLqRWCyfaqvHHKWYic5TxRiZTgJEBMr8+f950scrWwq3RtgSMoIsc1
lFWNty4BPARY9utwY+5TAgMBAAEwDQYJKoZIhvcNAQELBQADggEBADgvogMpIbfw
YwvwGZ8X+gJmgNQHl4tPndHAiGecAozvZxm+9hulqSqJ04uWqy3j+8YfQTNqpWXl
bk0jg6reWmoH4rxH56SiecndGwh61rvffS0RUg6lhZeHftUsOnYhcviLQka0dMDS
Wu+jwv9rDT6MpQPvwjw8+oM5QZ2DDDs4zJUEiSFN2EXcCZQU4og5lmCcGOj81/f/
yGq4e4aHPNmQALhKHRPHzvaw0nWC9DjNGwlJnvx71b8Nrekn13YmoAIzdBE6aR/7
QnRumONZypiQJ/cVMqY9JHckyQIc7QLmlAu/ntEJ/5Amvz5MWNoT6GsU6GiwwGwQ
9TKGw8wiSDE=
-----END CERTIFICATE-----
"""

let serverCertificateData =
"""
-----BEGIN CERTIFICATE-----
MIIDuzCCAqOgAwIBAgIJAKRfJQF2h7STMA0GCSqGSIb3DQEBCwUAMHQxCzAJBgNV
BAYTAlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5idXJnaDEU
MBIGA1UECgwLSHVtbWluZ2JpcmQxCzAJBgNVBAsMAkNBMRowGAYDVQQDDBFodW1t
aW5nYmlyZC5jb2RlczAeFw0yNTAxMjcwODMyMDdaFw0zMDAxMjYwODMyMDdaMHgx
CzAJBgNVBAYTAlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5i
dXJnaDEUMBIGA1UECgwLSHVtbWluZ2JpcmQxDzANBgNVBAsMBlNlcnZlcjEaMBgG
A1UEAwwRaHVtbWluZ2JpcmQuY29kZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
ggEKAoIBAQDE4+nEaCM6Zn1w0O1EGkPGS4eAN8wkNofDDK0p3u2NoUNihcFrgxs7
ShVFYiFnWflCe9zWaY9riSMG3/6a3sbmjNrgfWQ5qMpHY42papgZKB1vGfVqkQE/
3/YJ+ST191L4Gmx7jw3bsaM2HeLDHY5wfh6hmKrb7qo9WQlw0Hm56lPdCYcxuPYA
eWlawP489tgJfPBIoFtPxIGeJy75+hPjNjbMpiCusFuuiTutkyyWSXROs92t8+bV
4Ss95y6JYfC3/aC7ZAtCww/FVxdnPZpNty1XmS6LOui27Inel1QKb+RHWUc9uuGd
8Vl/o7Yuirl9y5MUhAOEAsKjrq286mJnAgMBAAGjTDBKMAsGA1UdDwQEAwIFoDAd
BgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwHAYDVR0RBBUwE4IRaHVtbWlu
Z2JpcmQuY29kZXMwDQYJKoZIhvcNAQELBQADggEBAKXmIF78LaqbXmw+Mv1t7XnC
jFrBc5VNRWTqqWKWWXnXjN9CKl8ubX8YpefD0/wWXYneNSwL+0foylR62FRETEe9
76NzgsBiH95WE0lNCxvP2l8+BMesuHJ1ElpJOxYThNKVvPb6VoCZBT3Ve4QifQi1
AjatLY/o9xFuFJ62txKqsHL6FULYRaHU2TQci/9VZxnd6ozGMJRSAfGqwlb2J6j/
GCbqHCuYOFDV6YiSI0CpuylcKt5+1hyAVIuwRRNogYyCfwkBm0Z6dwVXVXgO1iPq
TtQPe6jEgVuwqM2U7dzBRBzCyw+a33KJbt1St/OBCNbtQjD7oSAaoALB0gTNJzg=
-----END CERTIFICATE-----
"""

let serverPrivateKeyData =
"""
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDE4+nEaCM6Zn1w
0O1EGkPGS4eAN8wkNofDDK0p3u2NoUNihcFrgxs7ShVFYiFnWflCe9zWaY9riSMG
3/6a3sbmjNrgfWQ5qMpHY42papgZKB1vGfVqkQE/3/YJ+ST191L4Gmx7jw3bsaM2
HeLDHY5wfh6hmKrb7qo9WQlw0Hm56lPdCYcxuPYAeWlawP489tgJfPBIoFtPxIGe
Jy75+hPjNjbMpiCusFuuiTutkyyWSXROs92t8+bV4Ss95y6JYfC3/aC7ZAtCww/F
VxdnPZpNty1XmS6LOui27Inel1QKb+RHWUc9uuGd8Vl/o7Yuirl9y5MUhAOEAsKj
rq286mJnAgMBAAECggEBAJ5fZe5ihdO4FTbmF7QsHFAo+Pmd6EtIwbOXQsLnWtYN
3ZImXQsKDqGGWc3RvWTQ7rsXvu+JQaASU2Z4TuhsQjm5G2Zv9mqa5vq9jXm1EFtL
9UEk9E+gDA1BLTugeKaRJuADATfyPgd1v/8L0xd3ctfx2tnJX8ZBGBb4w6tHRmLQ
OrD69CDLN7+cB/v8MzbAWvwl4p+7eyTqvhMf6fnOLq5g4oujW9AOjJRxfAt2g0Di
xCpIjpyupxYcGWU5mYAdbhYU9m8QsWiaOP1P0TkbwABu04lJVo4X4D5giw5HSSNs
I7WBYisDorbMXJOeWOD+lWHpz71IgGjIpTKhIFg6B0ECgYEA/Hj7BBpID4FVTPcE
ip55dXDhMhq8wxSiGTjVP4ujlcMg6vj4HeL2EaA0e8cgcNig1ckj4KRcywvn/H3p
d86vK3R5TCqatZhNxrCqQxc2uR7Gt38bE99fcQ4eBhd1FB+YbPPAYs5HSQYknRQT
yjAJROG0ZRZB14MOIe2eOVdDum8CgYEAx6Qhme+4a4YOr/DMZ0AlOg3VRAwjS06C
4F+8R+wX8Tv1vuqhchpeDpn3WkPKoxMAahbHcSc0/qrb1YZ1piHUezzvv0kX9s7c
shMFJEyzU/a/uTrbEn8ISeIvEZW+lWmQKWfQLVDAZLx6dJZSTcgySaizgLVlDPnc
Qmg3t56ws4kCgYAStAescyH5fBRMolQEzN6kk5srMg3fycyEX9B0Z6zTsGPk5FLF
LAYcoiihLsw5b+LiU4dD4gk5xYUHEHDWPkp9xqAhw1o4r7K7UGUcmUClkCEagOEJ
pNeWMXyJ6Pz0Y67QC3KqHyvqvfjCZjVdGhflsW7CulZgV8YZP1gkWVGcIwKBgClq
p33j+YJ1AT8G2aDh8dclX4UKb5gD5aresZTKKf1lzwmYa33ccn7c+i/DuJo0KvXX
W/DhjWD32Ttm9alNg2M9tQ8d/ta4+5gF0h9BukJFAmlPCHvB1tpdDh67zhn5GGs+
mjWMdx1u7IibVt/EFIqrcPHWr+wNOeCc9lIlncrhAoGBAM5QwKRPwRQzDZbabWhl
J84ObRGbwYqBY9+i4rFxQaOZ9+SzWOdA3op2kFIWBvYwimhe+Yk3ym7Xf5iftBSc
MDrQWyCT59zRj/EdE3T3hRzxqcAHndkH7B4j/H478NdpaUxEpf0o0xNGX9Pjdgln
Qo5POJoKyy9ZsJpTPbuZNXLH
-----END PRIVATE KEY-----
"""

let clientCertificateData =
"""
-----BEGIN CERTIFICATE-----
MIIDaDCCAlACCQCkXyUBdoe0lDANBgkqhkiG9w0BAQsFADB0MQswCQYDVQQGEwJV
SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxFDASBgNV
BAoMC0h1bW1pbmdiaXJkMQswCQYDVQQLDAJDQTEaMBgGA1UEAwwRaHVtbWluZ2Jp
cmQuY29kZXMwHhcNMjUwMTI3MDgzMjA3WhcNMzAwMTI2MDgzMjA3WjB4MQswCQYD
VQQGEwJVSzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gx
FDASBgNVBAoMC0h1bW1pbmdiaXJkMQ8wDQYDVQQLDAZDbGllbnQxGjAYBgNVBAMM
EWh1bW1pbmdiaXJkLmNvZGVzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEApv6vC0Uobzug9WpXsjwfCtOudup4brQtVskEQxmu80Z9yOalvLdQg3m9olza
YB/eB6HBR9LGTFdhkvXc+50L2CKEH0286NcikcQ11xoZ4BHdcXl2RN5PoC9vggJ8
wnjVfbf14eCoTbLlZ3ocaGj3cb4YagdmkC4CiO9C8P6HWRF2j+73CETos1/vtVkH
Dnl4KgdMKIKTrGCEjvP1ACUgLftcSTJPQxbU9xlc8iTo1ydtkoH6jrZUPYX74ezO
wPUCkAxitFkw6cpEVFZRg4ur8Xmm02kzSMLnqi76phCEO/AP6dh5HJxfGztFhwaH
Ygc0ZhC4VUdpzDGJtj6wGim6VwIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQA2ss0D
5qpmUzjMe7fZ7Gj586voqLy7KO/JbthkkscFtx4MlW4XsOWpINJ8e5UDYuIsgsgk
7ww3ZNci1AZ1AixeOP5BLDyXVlGbfrUKeZ4g29vblaXEB4WS0bQpLx/hIGhhjp50
YhyO+r7BpxWrKvlWtQzGswV9nTuufFr7ScprHtuu6Nj2mmvdEY3aVbmPIWSYXVjv
fIpz2F/TLPWVe4A9xlb6as8IgtEB/QpaKPshRymXtDlUAxqH33Smt8avB8wedZBR
NVJ4J7O5CsbEgA6Fypdib1XVNmcPEQytXK3D4geR0Hxpcxn3y1121uMsRT9qdOHw
gCZSmbfWImbMfFcm
-----END CERTIFICATE-----
"""

let clientPrivateKeyData =
"""
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQCm/q8LRShvO6D1
aleyPB8K06526nhutC1WyQRDGa7zRn3I5qW8t1CDeb2iXNpgH94HocFH0sZMV2GS
9dz7nQvYIoQfTbzo1yKRxDXXGhngEd1xeXZE3k+gL2+CAnzCeNV9t/Xh4KhNsuVn
ehxoaPdxvhhqB2aQLgKI70Lw/odZEXaP7vcIROizX++1WQcOeXgqB0wogpOsYISO
8/UAJSAt+1xJMk9DFtT3GVzyJOjXJ22SgfqOtlQ9hfvh7M7A9QKQDGK0WTDpykRU
VlGDi6vxeabTaTNIwueqLvqmEIQ78A/p2HkcnF8bO0WHBodiBzRmELhVR2nMMYm2
PrAaKbpXAgMBAAECggEAGtlt+WjoJGI48dxkNzL1Zr88GMCAFoR/mal+Nu+lMlYO
GUQEN8BdgJYNSFKXhcb54s4+Djc0TMfr1z4Shp3sbpa2GXZdPi6Az2D1qxz2NhGJ
QhpeSppXwRB/ZC7UMkxNPwZZ0TRWuw9dVPLMKHlf93ix4jJIajwLikq1v5uc1VP3
+EuKT21uyk3xhfnyxi9OcZfHOuO86zqRbwzeIUJ9aIWH9gHloo1CAb+5IUsyR/Tp
GSHSoB6X27FFLs9dhvi4vHRZFNQRXQIYhHJVW2Ru9BW83e2Qsb6lTX416nmgPi2n
Xt3t6FMEX8w7gQEdCM4iLHBd4TaKuE0dGSUQRKrkoQKBgQDPKq+cCKC9zGE3AuZO
voNi3+ZoVfdIqNnl4NDuP8+L30j6EKtTc9Bw3RubZxkKhv34ZMRRjqEWJbT8CDl/
VNXmKFkYZXNQiUNGAQjZ1Vi+g0XXKYIybshPpdh6ty/emcXNqsJ8iW8QKkS0EtCN
gm8/3W8KEEDKBT+bdbfuY1tv8QKBgQDOW9tp/VbnMpWTTvi2/0ZETbHKqRjXotGO
DBRfNSGYab0u8c6XN09qUisqvdcJT+oR4fD6UXeQ+1bSOMdxYQlsHSLK+NcZqeNa
ALnzcpVQsEsQIJlQ5agcJ+sIEUp1xsGhNEqdpZg9Tq4KDN4lwLXKV9VZZFUTTicU
RJqlAOcWxwKBgQCRcmqwpe4U0zU9pi+EAYXFGWVuw0xGGyZAmsKVQv+4OB/IUYO3
p4wkcVg8lvmhxnzws+6RRA4cuoSCnlOf7jPuz00eL7vyQyyULY3FQmB4ATo7gc0D
E3xXTxzZq1tUcanKZ6T8QpFTTBnIQ51gfL8Wm6Sl8BtMurqZruBf4ioEQQKBgQCR
UHIUEwhNSnu1/hh6lQygMK4Qbj9GKiuzAaKe4MVFlMBZ/IFkTtinoDExqflxX0sP
SLHvM8sk1zjuVHltx81gyqujjtO6CL5GtNg9LOUkquBQ/QO5yd815I5HYhWzFkFo
CXC5ztCD65H3FdShdTEOygc9KcAXFiPCzASySQ5yJQKBgQCIDRl72BNv638rj1tO
9LjHOC56i3Slj+l0EPlgGnt8/YczVTL2q8SCO6ZGkmdPvzbix6/J7ETAkMk64R5l
iIcbs2BHPP1XIUo6C0sXi/VHDvWVNHKfsZLkTmKtGTxzePPZ6Pg1UnapDLvlfgFV
iQv+V3qUVkaRN9nqDyiXb4Lhzg==
-----END PRIVATE KEY-----
"""

func getServerTLSConfiguration() throws -> TLSConfiguration {
    let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
    let certificate = try NIOSSLCertificate(bytes: [UInt8](serverCertificateData.utf8), format: .pem)
    let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](serverPrivateKeyData.utf8), format: .pem)
    var tlsConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
    tlsConfig.trustRoots = .certificates([caCertificate])
    return tlsConfig
}

func getClientTLSConfiguration() throws -> TLSConfiguration {
    let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
    let certificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData.utf8), format: .pem)
    let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](clientPrivateKeyData.utf8), format: .pem)
    var tlsConfig = TLSConfiguration.makeClientConfiguration()
    tlsConfig.trustRoots = .certificates([caCertificate])
    tlsConfig.certificateChain = [.certificate(certificate)]
    tlsConfig.privateKey = .privateKey(privateKey)
    return tlsConfig
}
