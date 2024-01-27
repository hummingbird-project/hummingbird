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
    MIIDXDCCAkQCCQCH7vjrDu9x8jANBgkqhkiG9w0BAQsFADBwMQswCQYDVQQGEwJV
    SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxEDAOBgNV
    BAoMB01RVFROSU8xCzAJBgNVBAsMAkNBMRowGAYDVQQDDBFodW1taW5nYmlyZC5j
    b2RlczAeFw0yMzAyMjAxNzQ0MDFaFw0yNDAyMjAxNzQ0MDFaMHAxCzAJBgNVBAYT
    AlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5idXJnaDEQMA4G
    A1UECgwHTVFUVE5JTzELMAkGA1UECwwCQ0ExGjAYBgNVBAMMEWh1bW1pbmdiaXJk
    LmNvZGVzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA8IuHmnE/Gzqr
    IY4DPvpniTT2UdELbV2x8jUkVdOo40FNvyp3EksrNlKoI/Qw/g3pedpnuW0y36Xk
    1xryMXq105opZsaIljnbC8V7Pf1bhGuWvGcmN5SxqvP036+CmrO4rF+J1st/zj2s
    6vZcQT9jIJyG1gSRtoAl0WK7BQwgC3IHFZ/NRL35TiCRqV2oP0GYbEH8AVYIZaLo
    zs4xfYEKINz7VhK52Whwfs6TY9sa1y5ATCSBkxD5ZxebQ3bQGkisjzNPxewiSPrx
    K8ZhvachUeGpKPBL9uRo6Eu9Z1wGkSZQUYJ9aLKa8zTAym2Mc+8KnDaYXyJCOB+H
    Ny7hTMsAMQIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAukrWFMghAXr8xG+isQtYk
    tzdJPWjQURX7eq4Yzj4q6uH+u+5q/Z2XheahNjBxbksIWpadpjRBXLkfEHTU6FxX
    2VCESTI1ECBH96XDqZBx3G5nfH20p8xKuNz5wnCrHb9GAuFIMK4pi3vLbRmP7qyi
    R8GuuYSM75nbuhJGsyVfwwJTUZxrt+Ye3TBoSF3b6zqmCjn/6bK8pI/ef6VGq2Iy
    VCCtxWhE8hcnzRCp43D0wrcyahHD+5PKEQP7WDwU6oc5YzvDQDkrvV8+OhQ4fvnn
    gNRjRrZ9ejmTNU0/Q01jhMTqB7p08biA80e/WUt3WlnVhj8NjQ64q87DwZvK6iXi
    -----END CERTIFICATE-----
    """

let serverCertificateData =
    """
    -----BEGIN CERTIFICATE-----
    MIIDszCCApugAwIBAgIJAOII8XZK4EWkMA0GCSqGSIb3DQEBCwUAMHAxCzAJBgNV
    BAYTAlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5idXJnaDEQ
    MA4GA1UECgwHTVFUVE5JTzELMAkGA1UECwwCQ0ExGjAYBgNVBAMMEWh1bW1pbmdi
    aXJkLmNvZGVzMB4XDTIzMDIyMDE3NDQwMVoXDTI0MDIyMDE3NDQwMVowdDELMAkG
    A1UEBhMCVUsxEjAQBgNVBAgMCUVkaW5idXJnaDESMBAGA1UEBwwJRWRpbmJ1cmdo
    MRAwDgYDVQQKDAdNUVRUTklPMQ8wDQYDVQQLDAZTZXJ2ZXIxGjAYBgNVBAMMEWh1
    bW1pbmdiaXJkLmNvZGVzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
    z1VRlcWnYylZqNvFdaku44G+sMcohB69yvqFRf6vn5KlZRf2cp4MnhCrhJOs9hZv
    s6aitc8GSIPVBbxrIqAapBh0FtxCkhBWX5tmNJRXp255ByoPNUfGROHfMVoZfZ3E
    NhBauRjmB2l9lXMVQj7HTlX4X/k+6M/Gv9fTAmJ4+pu+K+n/1H+VIoOmmpWAFCqE
    RbHld/hq7CkHII/KmdhgV3gyZyV6Xe4kUtZPZQU5UmnvaFHzUeOWmPV8CKnhZLMF
    8Rl+oU87pwM6PHZTOmk274zduGiM3cIy8GEh2rC777sfovZq833duQ/hDhEvbiYH
    ro9IXjrhWJpnawQ2qvp4uQIDAQABo0wwSjALBgNVHQ8EBAMCBaAwHQYDVR0lBBYw
    FAYIKwYBBQUHAwEGCCsGAQUFBwMCMBwGA1UdEQQVMBOCEWh1bW1pbmdiaXJkLmNv
    ZGVzMA0GCSqGSIb3DQEBCwUAA4IBAQDgGA+qKHlI0TiBwxQX9V423vOEd/pqQ2ry
    Drj0c24KlTHz+mKq2i1AnQO8mwCX3GhGXc7MqyoXFgIgTVR+KQkjDrrsnt5IqUFe
    d7QWWydIW4qOqQwlJGbNDXVQ9pCwHvnHlHd+Yb2De42GBqimWrBqa9iXTHHUF8/D
    dQ29NFkB7r1Bpau1ELyHPkvYdk9sM4jwEinkYPB010y0nuhAR2/NBf49rwoammtS
    Xp9XhKqSCnZgvdPCYGDkA5VQhnoY8jh1yFa+E3KxhRMEcPdspgkcmOSEtoDoUTX3
    mzOzBXlZOfxruyRA7rWwEeutzF4wdTUGIqEW08o3LmQB17wuKUBv
    -----END CERTIFICATE-----
    """

let serverPrivateKeyData =
    """
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDPVVGVxadjKVmo
    28V1qS7jgb6wxyiEHr3K+oVF/q+fkqVlF/ZyngyeEKuEk6z2Fm+zpqK1zwZIg9UF
    vGsioBqkGHQW3EKSEFZfm2Y0lFenbnkHKg81R8ZE4d8xWhl9ncQ2EFq5GOYHaX2V
    cxVCPsdOVfhf+T7oz8a/19MCYnj6m74r6f/Uf5Uig6aalYAUKoRFseV3+GrsKQcg
    j8qZ2GBXeDJnJXpd7iRS1k9lBTlSae9oUfNR45aY9XwIqeFkswXxGX6hTzunAzo8
    dlM6aTbvjN24aIzdwjLwYSHasLvvux+i9mrzfd25D+EOES9uJgeuj0heOuFYmmdr
    BDaq+ni5AgMBAAECggEABuwGSUXMDNd4ktajhQYc9qOCRkyf4alVFM3AXVHfcyhm
    NTXTmIgGS9CqqUZ049Jj8E+D5yX+Q7WDCyn7ObC2svvOBGVeI5pAB/kcNG0vb/uU
    NtUEpPa8e9g+p1smtrbpshRhswRNybmP48lv0EJgTRE5tZqQqx0kuYrvFIlNGLDD
    B4W9g0VvrPRqNcAoR/kJK7smJy3rQEcweU62Y3aajy19ZDSjMiIaV2NbfmF4qYiu
    ggi4j9mhOxQ6T6CzfydMZ92d5oawmUFmSxjTb9WZ9mxGt6KkELpz/fn/00fPwUkO
    xMKmCEGvbArBl/OONbvScUgZwt2eTTQC/Qj9x97qwQKBgQDvdslatq2ssLBLaU26
    sJarNXy1GhJs55nxGVhJFP1vmSRtzT72kk8sGVyVJil9jzUqOC/dkGQCSjvzew8W
    fCAyUCmL3PXhaCidIZyFiy5MLNvV0E7Mhq/zqxNa7pIXGxxDEUd3rpDzX8ZO098k
    Hh8/yiGUqErGh2ogHkzOKVDW1QKBgQDdpod8SBBGs83Wfjl+PJQunnHPN4NtJYB9
    ZlFIKuG5T2dbkbT54IeDhChs0irwS7T/1tV+/Z1nw45QaL9mTc3Y3+Gzkbw0V+R+
    oFX/N0x9tkLqbrpQF5h7IBkmPv/eRGEUDJp/zK49c7V9UXYe0W1A+iCXwE6Bctk0
    7Mb9szCUVQKBgFX0KWpqUATAl0c6UTBF2o8x78WBykNVDqjAFDSHWEEKk0zmc0dG
    VSzbHaRbwmDTWp4A9Q1umrdHtiU7crr7awMkSwVtFsUGAi4Eto4o20F0iKRC1UYM
    wnOQYK4vHDk2/foE5cZL3rO9GQ2Kd3obZdQb1dnqXozMZoeI2MDXi7DRAoGBAKsb
    4OH3u+Do85GPdhDW8Uof9RoT7/i1h8DG2R7OQ91LyC2viTeRtuu3fYGsqYtB1qPe
    lIhpfzdYhyfaBVAT5kJzawi2C8WYyINcgab5aKpvpq7V9izYWlVKzT9ySRKsVQkm
    Ras9NpGoHsZ0uaxG3oHX1otv4Osb30R1OZUm3OzVAoGAHHFLpDDs/aZ6daCp0Yn5
    RKdBlfG9mgGZV/Q8+Qj8ZnmONHT5WPOeWv2qcbLRQ83KvFx8Ulo1AAaS0g1Yg1z2
    wkxgiS4tNzMFsHYYx1kEZYnDtfPp52Y3TYE5+Anp8ecOirbGn9F7ckHxD0qXsG35
    +wMKd17BBe23nIjeLvKMSqU=
    -----END PRIVATE KEY-----
    """

let clientCertificateData =
    """
    -----BEGIN CERTIFICATE-----
    MIIDYDCCAkgCCQDiCPF2SuBFpTANBgkqhkiG9w0BAQsFADBwMQswCQYDVQQGEwJV
    SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxEDAOBgNV
    BAoMB01RVFROSU8xCzAJBgNVBAsMAkNBMRowGAYDVQQDDBFodW1taW5nYmlyZC5j
    b2RlczAeFw0yMzAyMjAxNzQ0MDFaFw0yNDAyMjAxNzQ0MDFaMHQxCzAJBgNVBAYT
    AlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5idXJnaDEQMA4G
    A1UECgwHTVFUVE5JTzEPMA0GA1UECwwGQ2xpZW50MRowGAYDVQQDDBFodW1taW5n
    YmlyZC5jb2RlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMftq4Gu
    Qc/1xc8p6kvXopZkh5ikzWE1yhvoJttn2JzoGZitNkqtpag1mY0j/TuuawHx/4hz
    Ew16GtFhD6eqEVzqd8IsOezuhYZnNe3oBkWIgItQlHHqCeASk79yKzH9Di4uWTQ5
    H570poY4kJUQqanMTrxnYaaToIc+qgiV7FycFVZn8scCTYpLJN+9cIVK8uUjepAL
    7tSHUneRV8Yd35Ym/wc8NN3WK3ANUlY7TTMPxQSFESExgYAM0oWBL7ymXyXY/aIK
    V6b7upMfuIKAuhURP0BbUBdwZLpcJv1BL6L4cB7bHFcn9bgrfPMyg7piOODP5lgy
    MZTqgsYAGFk5yCECAwEAATANBgkqhkiG9w0BAQsFAAOCAQEASIpUoZ44pN4Vt8R2
    H3mRVNDAnx2ZGikTavPt1GRAY18H9tjPfFIlVeDhCtdmcxDetozt3IVynp048pUR
    k7jpsKwBVs30uyWloyitzntcwHj23o2BzfjbHPVZyr86vDoa1TNkeNLrbLejLFkN
    d9UAwGpD8AqXoVa6MkOzC6/rxyPZpRJpV4IL4z9DgNObBCfqzRM5CE2alVCdLgm+
    b/yAfMfUilt4o/OqKcgfRANimVYGP3dUfXbbco7hFldeyinkm6Qs7qEEDpHn+o9z
    JZlrGcNUV+aMIStC1NXvQcwSKFUbHdAfynUpUxtwj2rlRQsRM0SoKwHNjxqUNZdA
    sfN2MA==
    -----END CERTIFICATE-----
    """

let clientPrivateKeyData =
    """
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDH7auBrkHP9cXP
    KepL16KWZIeYpM1hNcob6CbbZ9ic6BmYrTZKraWoNZmNI/07rmsB8f+IcxMNehrR
    YQ+nqhFc6nfCLDns7oWGZzXt6AZFiICLUJRx6gngEpO/cisx/Q4uLlk0OR+e9KaG
    OJCVEKmpzE68Z2Gmk6CHPqoIlexcnBVWZ/LHAk2KSyTfvXCFSvLlI3qQC+7Uh1J3
    kVfGHd+WJv8HPDTd1itwDVJWO00zD8UEhREhMYGADNKFgS+8pl8l2P2iClem+7qT
    H7iCgLoVET9AW1AXcGS6XCb9QS+i+HAe2xxXJ/W4K3zzMoO6Yjjgz+ZYMjGU6oLG
    ABhZOcghAgMBAAECggEBAI6NZ5GSt3hZjM6W22lyeopzab+sGojquo5FbJdapzfR
    wpZ7Qs/imtCiTzc05xYL2l7Lt2EKdBZS7xZF98yb1b+Dqxp3QGIw/GIF640TuI0R
    tF4heYbz0lDDzjdeZ3BAOEEzaQV0iZhkZuwjHuw6sk7Qz39E03rbnkVwp/pxM9Qf
    b+XK78GROi+SXO54ftHsh0y/cGQFtsSYdttSvdYwY6nWoEYSZIY4Ydfb0piQCS7B
    LU0omcQuOLqVQPpA0UXwig6b78g6lC5yoA5Rag6VEo1Miw2BeBPSa4e+Apcv0CH+
    usbEAaL0+9TC8BbtqVSV3P2e+yYpqY9hwFxmRQn4vGUCgYEA5oBnReunFsIlu0a3
    wPsD1QVh2oBEkG90GUnFVKgU2k+LDeO5NL35t4zByBQNoC7Ov8F4+bH2mE7f/3Fp
    +ST6SSIamNPboiDMdKUSFfOxMCQt/4j626/np2uSnLBEfVWI/m8Jc1pA/aqtMSHk
    wk1ipcEZTabX/Xgg/RF61kgoTF8CgYEA3gt2NKtFww6pOx1NHe7akQdHaCyKL+iv
    04oTxdeCton/UGB3WDxSacX/mf2H2J7Nlb9PCx7JEJlpoxtbLOQ9Q3ZsTEAU8olz
    aorWQHeZGAKcGsDYl751Brp060oIMwpWMJ9lXGfU5wFdjXdIuZiF7Hq3DtKaDkis
    RODi+X+eO38CgYBZ80vZ7l9TM0qULcGxroNNUv9fzGR1VPkikTZPlhQlKZtjPTXe
    TjCwH17T3HeAxiNqk27JSlioEUe6oKCxWGvPtF5au3pfZ5tB/dTz+hhwZ/4HVYZH
    yvqEzCb3vJXNr155pA01Fch89WkG3mouJRLVCmj8c5qgUIvXFkYwbxJC0wKBgHib
    ByiSgwDw3LDUOIfyrdsqdfm6f5CINcCT9it25HPbvsbcrtZJZYY4Wp483GWn1Ajr
    cbabkSCoA33ppPtcOX6EO0yrXfVi/UK4iKlZjNlCyaGqb7r0Y0I1Ur5eZte6XJhq
    a7bmWvjif/sP+Ht+wfdxrC6r66uog5GiCQb1729nAoGBAL3BIQ1HjpKfwIhYKIZt
    mHpA8hqfe2hZxRs1wnCiKRsY+oSiWeT1ZvCjQ1qaryVlHn8l94R0/S0h2tYCMEGU
    XuptTzDXNUKCu9UG+0G7b2O9R96bAhYwoXBbPd2YQycw/NtQ6RMvv3oCbQWEpsT8
    exHN+mnZFXk8FgxAyAitGLRt
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
