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
MIIDyTCCArGgAwIBAgIUMlPXRgNMa+eUbn/hsCK88Zm1FI8wDQYJKoZIhvcNAQEL
BQAwdDELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAGA1UEBwwJ
RWRpbmJ1cmdoMRQwEgYDVQQKDAtIdW1taW5nYmlyZDELMAkGA1UECwwCQ0ExGjAY
BgNVBAMMEWh1bW1pbmdiaXJkLmNvZGVzMB4XDTI0MDEyNzE1NDc0MloXDTI1MDEy
NjE1NDc0MlowdDELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAG
A1UEBwwJRWRpbmJ1cmdoMRQwEgYDVQQKDAtIdW1taW5nYmlyZDELMAkGA1UECwwC
Q0ExGjAYBgNVBAMMEWh1bW1pbmdiaXJkLmNvZGVzMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAoSMlfkfyINkI63a0q5KpMjtulVb9/MESJtaiZeG0HNMj
pVGJ5c9p/Ypzp7qodgoX/6vEQahLqdfyw0dB9MzA5hOuKrLDTXhnBFiyOBrrzYLH
CBYwhJiGVPaG8HUof/UfZwYmK7NpK+g3oSyl7PKbiWTQTq+Z3uOmV7FGD1XSTSks
cU2ARsJROxWz2sTFGwqc7I4Qa8XuIIhRhLVJinagKnGnv6dyTNwFO6fl4oU0Ils9
V19jIrBZ6cDRLTPsqMuIxjqk6YQNZ+W7CmrgT6MEceigidyBRJi7Q5iz7FniXurz
+T3lMXBaZFVFv1E3P5j4FTfBVt9n7yo07fp/QoVd3QIDAQABo1MwUTAdBgNVHQ4E
FgQU19wgSafcyM6xz0CJt+0IePdAj24wHwYDVR0jBBgwFoAU19wgSafcyM6xz0CJ
t+0IePdAj24wDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEALb9o
kmr6qHQFvgaM7Cv4ETZ67rsZ7PlG3uTH1m3zqjJhMDYaDGHcUXOioSkfwON2+tYK
crs6IjuE9XqiZBoszBqUeSze67/095xysUTC0JyljE259PSb2Woal3g/zOh1d3Dm
SKFNZDmkp/coRkz9UlJNbafwmYFzaMl0nVkIf3LKFj8gBd1qW+H+2uSQAZFIWCDY
MJoLF8vhJR0W5/vO3axmASFyAwSiP0NlIVC3HE0rNziE2CMBs5aXkUcikZKvC+q+
TRLXM40Ead4Ne1aJb4aABzscrzApfa1ZRfF9CuVawqp1pYn/XJS/WCSlMyiJe8ms
oJasPVFZ9xo0TPg5uw==
-----END CERTIFICATE-----
"""

let serverCertificateData =
"""
-----BEGIN CERTIFICATE-----
MIIECDCCAvCgAwIBAgIUZ3cPKQJZL0/i8e3twD3UNRQnJfUwDQYJKoZIhvcNAQEL
BQAwdDELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAGA1UEBwwJ
RWRpbmJ1cmdoMRQwEgYDVQQKDAtIdW1taW5nYmlyZDELMAkGA1UECwwCQ0ExGjAY
BgNVBAMMEWh1bW1pbmdiaXJkLmNvZGVzMB4XDTI0MDEyNzE1NDc0MloXDTI1MDEy
NjE1NDc0MloweDELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAG
A1UEBwwJRWRpbmJ1cmdoMRQwEgYDVQQKDAtIdW1taW5nYmlyZDEPMA0GA1UECwwG
U2VydmVyMRowGAYDVQQDDBFodW1taW5nYmlyZC5jb2RlczCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAKX+mOG6fZko5yv3OrOrHBuBWE+dchwezM5hi7xp
Zyja/dDhhO6IZBkJtmR9Uw11+ZAxWao2yVIkpT+0jehhDzGRFn88+CrKPR2/r5eh
Bmv4dUQNxnJPjvMzx9QgcjSJf6uxTFNngJID0BmA5UeJ2Xi+/WsX8zELm+CD7e7V
1gfcCTLY5Y12dfHd0J1ZbTxp7k3XpadXLdhZq0lLjYIwdLbmZxtOgqXirwCRU4SR
bvJLEwnMcnJvEIg9Q4zXf4aWM45BAUYz9rMr8WlLKl31j6fQP/TcZ4QNVrVVpKfC
Ok0w8b9BEebvMNhStgndJ4sn5oBpZEA40kbCcdr0d8rM6wsCAwEAAaOBjTCBijAL
BgNVHQ8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMBwGA1Ud
EQQVMBOCEWh1bW1pbmdiaXJkLmNvZGVzMB0GA1UdDgQWBBSyCStEARj5dJucaIGj
WlJYkEOeBTAfBgNVHSMEGDAWgBTX3CBJp9zIzrHPQIm37Qh490CPbjANBgkqhkiG
9w0BAQsFAAOCAQEASb4IHtnr1GcbgpyX/6rjoeZ1s56O1mG3bv4c91dV4ca0nr7r
UxbgUkqBSf88fpgd82Dr/AcU4XmD/W1b5J8P/+RZiIH4+ztuN1MWiWiRduEbN3Vo
2hfTcCQFTcvO36nkqy/vFUgKwAUS7/Qm5pNoThf7paWSvOdcPg3zZhjU2qzIb9KR
SlXZ0YooUc7uQ6lFmgmgZEZ2bKykKue2TfXRPLI86yXv2dVzShMvv+njCbxkWBEh
Mra6nBnNkdj9PoB2eKZV3VvWgGrSVher8JVDW7bN1dJ94ppugO6Pnwy06fbLo7+h
ijBsqIWiDQNOQQrPx1iCTbdtg5UOKNIFwWynVQ==
-----END CERTIFICATE-----
"""

let serverPrivateKeyData =
"""
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCl/pjhun2ZKOcr
9zqzqxwbgVhPnXIcHszOYYu8aWco2v3Q4YTuiGQZCbZkfVMNdfmQMVmqNslSJKU/
tI3oYQ8xkRZ/PPgqyj0dv6+XoQZr+HVEDcZyT47zM8fUIHI0iX+rsUxTZ4CSA9AZ
gOVHidl4vv1rF/MxC5vgg+3u1dYH3Aky2OWNdnXx3dCdWW08ae5N16WnVy3YWatJ
S42CMHS25mcbToKl4q8AkVOEkW7ySxMJzHJybxCIPUOM13+GljOOQQFGM/azK/Fp
Sypd9Y+n0D/03GeEDVa1VaSnwjpNMPG/QRHm7zDYUrYJ3SeLJ+aAaWRAONJGwnHa
9HfKzOsLAgMBAAECggEAA/RGyP2Mw6+cG5Ev4yZhg2GEd9tnmHoCaVKGQHUZ2w+H
uBeFUfdz6RiLT4NkSa4JTRAna9R8KKapLcokO/d7dtIa6p5wBGIbhtXkP8Eklciu
GusHNJRBEOqJNnDhTxy6Odo59g7nBDkUcOy8LyMkGtdOHeRjdQffpYqztx5ukwlR
OP3Br47APSlhB/LoJxfg6tk59tqidx+cwxZeu3HaW4s46/mHWw5FqW74PAt53XN9
aSQdWscXhuutRtPbM+GY9d6Lf1pp9/Cq+XCAV3iRgjfFQPgD2INc0ySTY10uGOWc
YQpa4UBX1ZPRAPa0YBwCwF4Xz/4BBfDzfiCrosungQKBgQDXuMFEcuQFsjLYm3Vz
W9N4UZg3HeuABH29Dt09yyFlg6hZD3FFFBBWDPipT6aFdmewYDTyTZ5RPBfBLH4r
MTIYuIje/jF9bxGkKzK0Pos5nsBeJDxLf3CcJvALEc2u7l0spS5y2MJ9RU6PMaF9
0DoABf7yNmYbyHtyRB5a52fBEQKBgQDE/PD0TinVgWsjxkogv/rQcLn0aFVufoT7
j01VPloATzntYdmvVT/EiAnTf4IJx8p0TqvFnvlYQj7Tffzv1B8iXmx6wAmWeS94
ElnWi/5pkIy1XI1DUy6MCdOcOCSwL36tcKEzFjYrVJtwGiR8gxz3PQuxquFmoofQ
jYy1V1aqWwKBgBKZ0LhpO7YuBmpdBUScL2DZkEl4X/0a5giuRm90m32YW6TKSxcM
wtfYqHxY7N/nNMulkAswnC0fBGFYx8xLoqk1CEBKJNRPBnNkcivOlMy0Hpw/fZ94
7qnYRax+rYCe9xPJbnbir+qDVmHMgsNJeCbWXYRfInDU2aghrYhjGbQxAoGBAMRG
k3+Zci1+alaW+L1xDGQsLdzNKHKUNcTBoHhTTDIKvtk8Kj59XrBgLApEfjlojN0e
liCuqhu6xgbM/f2pCeyg0M3uEp+P2DB3eHRBwRlGIi2DLm3qr/JwyBxcBJJYgIwo
MTZJ52d9QfOM2NYHfhELDl/UuAof39t5br4xa/UJAoGBAKUYB48+AK9oFPj6YG8U
N7XHfElJPggmygAUtndYwJeNRGbFew+P4fhrRG+2nhIVjVOBSwAvTnGPexwbkWCz
NOAf/sV8p4YEBa+KwkN/dSXUD+LE+s3ARmLzFaEkYyl03U9bJ9RfCz2wLCpTmjq0
50ies8PMrKKJxjkhVycT3pFJ
-----END PRIVATE KEY-----
"""

let clientCertificateData =
"""
-----BEGIN CERTIFICATE-----
MIIDvDCCAqSgAwIBAgIUZ3cPKQJZL0/i8e3twD3UNRQnJfYwDQYJKoZIhvcNAQEL
BQAwdDELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAGA1UEBwwJ
RWRpbmJ1cmdoMRQwEgYDVQQKDAtIdW1taW5nYmlyZDELMAkGA1UECwwCQ0ExGjAY
BgNVBAMMEWh1bW1pbmdiaXJkLmNvZGVzMB4XDTI0MDEyNzE1NDc0MloXDTI1MDEy
NjE1NDc0MloweDELMAkGA1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAG
A1UEBwwJRWRpbmJ1cmdoMRQwEgYDVQQKDAtIdW1taW5nYmlyZDEPMA0GA1UECwwG
Q2xpZW50MRowGAYDVQQDDBFodW1taW5nYmlyZC5jb2RlczCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAKWNbU5Xk/FBhHdVu1CPuQJGwxqTOggJq/7tp5Wu
HR9aMpgb/zWuEaT/eL5tZJKYX8Y2MY8/AOkoVE0fjB8sK8nwG4CgGrrxBV7MsSQJ
43PqQE4WXxC2bZbn5dLIr6ABZ4nTvuQvq8Pv/ylp/7Pek6aFEM8APIac0lAFcJzn
OArC2x7jUap53cgHP64xiO+ZF2tT88CGVNEBYCWAZ6x1Eaz0PbKm/wWc5pIGbgW+
i4lP69bkfzXczLjN3xce61Jyx9Kj6DeUqIPR2YQwYHORnEpwDCrlhL1o6NGDzM/j
2/t9IzMnjIeoNGOZtrbx1QhjH6Hu4waRhkck30my+ukYLpsCAwEAAaNCMEAwHQYD
VR0OBBYEFL8Uh8IaSnv66cS3mHy4rE1RHdm9MB8GA1UdIwQYMBaAFNfcIEmn3MjO
sc9AibftCHj3QI9uMA0GCSqGSIb3DQEBCwUAA4IBAQAGG8Fv4eTFT8UaNZkuhnMA
BT2+he8O0xlvFXse+QpL451ISU1KjSbh/N2jDfpob3/nO1EKYEuG5XKHmhlTjrzb
sa0YW5ad31jPgCExm69WRVfJOlnVL1olbzmyibGbQ8lFax0QgYO9rLhvkJocQs2D
tJX0xNL/2BccaVQvj7i8qAHeiQ9NqO46g4Uob5jE2nswJLZh9REddNsFWKxxL8jK
k+Ez6oW1s6QUaOoOm3Dh94fuYD34hgDeDIu+ec7bOiIIwKAholKQuoHqphMbZvQ5
QWv2gB3vE9Ep1VKrVr9dT4NST80Bmw7E1piUuqBShsohLc0GEkSrWboGP8vWbu+F
-----END CERTIFICATE-----
"""

let clientPrivateKeyData =
"""
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCljW1OV5PxQYR3
VbtQj7kCRsMakzoICav+7aeVrh0fWjKYG/81rhGk/3i+bWSSmF/GNjGPPwDpKFRN
H4wfLCvJ8BuAoBq68QVezLEkCeNz6kBOFl8Qtm2W5+XSyK+gAWeJ077kL6vD7/8p
af+z3pOmhRDPADyGnNJQBXCc5zgKwtse41Gqed3IBz+uMYjvmRdrU/PAhlTRAWAl
gGesdRGs9D2ypv8FnOaSBm4FvouJT+vW5H813My4zd8XHutScsfSo+g3lKiD0dmE
MGBzkZxKcAwq5YS9aOjRg8zP49v7fSMzJ4yHqDRjmba28dUIYx+h7uMGkYZHJN9J
svrpGC6bAgMBAAECggEACW02pdXXYjVK78KaPyzLEF9rUszCt3XZhqANdIWGbTEY
UJ0tGIDk/bV547OPg2HMXkx0R1+DU6nMtw5OgiRK1mpNUcy/PBkz2mFWATyg6D17
IOPynZ1NoZPQ/DVNYfm1snbnCs/RSRkvn2UrC380GBcoM4+kL3DbI6kgb7nvJBZu
p5ftCeUjSOJWi5ImmaPFvBsF24bxCAuwk0Gw8q9ybqpJHLm8ybkXpiF3SvXlnKGt
RLxKhAVSOKbyrWQNUv9RDx2xAfibpqUAo3gZVyxkDY2Gkb1J5YT27bhFricJNaVz
FFxhC3O+X3ihMBBNnq1VwwjoeSzWmwS1BFPgVFzLbQKBgQDWTnT2eFrzV7ADXCMT
1bg4hoFJD/QUJXqozAvCIAQx6xSamoadUHKMzYpGvI/5YEYbn3sgoRiQDrZd5jZf
zWRJuyQxdq1bakBsx4vji3TJ1eN0ovzTQHAB1Z+5tAw6CN9htUTyW/NbvzS4/eMd
9we68ye2gHrgFVtfVC6emIriNQKBgQDFwsYb5xRKce5F/iL4o11LfA0Dyu9Vekvg
FPBXdE6pSzZimeyC3Y8u144eWiXTfo7DT8nY1b5JTXmhUH9Q84lTkELq666rTn9N
KV3LIMEweHX//GBi+unZC5K6H8dnc9YzBsL4P6SO/ZqHzef02EGadGEyg4rlSkpp
yqJ+SI7njwKBgBer7OF4o9szOV71o25CcinUOZ2fZH+BME5K05Wqwavd4pW9MddY
ln6VCYwMsf6CstvEPu54vOTUqzIuBp2Ia2Z1hGbuS/HIB7u8QuhsdAcDWC9+/Vw8
RuL8/Lqfd6ZFap85TZdTrsrYkPNKH/ckXTc6Oo2/HVN5KHGcM9YS1WxtAoGAKMnE
bIrbn4MiHuOMuPWQz3nVgVvAw0OHFL+c1pzRgI9XtzyCEHe8CXBCCraTKKzoqxXw
zr0/EwVcuc3NhJfGUirl8mgLzZ9SGEsY4kVuMx4VUGfwRVn1E2QUrjjRut+kZT/W
xLbzrN5Xmfz5A4H6/e1VAsMoyaPp9ynpG9zBRLcCgYEAj/J9KsG6gqECwK12dcqz
brMAb7X3v05Kk22Nskhis6p31AOgg67MI8y3ANko2LADOHfov1HNaTwkCdhAaFoZ
1mJhowXVjxJJA4QWzPYGQSrVfKrUGJf8y5vHos5NQWF2VYNVJsSP5D17MoMwagqW
kPQvfvMHrv6al2joWL+8/3U=
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
