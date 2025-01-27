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
    MIIDZDCCAkwCCQD0NlEDBAHjqjANBgkqhkiG9w0BAQsFADB0MQswCQYDVQQGEwJV
    SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxFDASBgNV
    BAoMC0h1bW1pbmdiaXJkMQswCQYDVQQLDAJDQTEaMBgGA1UEAwwRaHVtbWluZ2Jp
    cmQuY29kZXMwHhcNMjUwMTI3MDg1NTM5WhcNMzAwMTI2MDg1NTM5WjB0MQswCQYD
    VQQGEwJVSzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gx
    FDASBgNVBAoMC0h1bW1pbmdiaXJkMQswCQYDVQQLDAJDQTEaMBgGA1UEAwwRaHVt
    bWluZ2JpcmQuY29kZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDI
    uzaSit8quh4TvdVPAT0QqH6gYluhsGgVjU+w55E+Yx698Os44IE5pudYiI/ufo2a
    Ttc14uNqx15/irz6xWHYlPrAoBaH6Q14gs4Zw7ZPh1ngx8/JqzEwJ523a+CPCc73
    Q9VdwjfN09C9DpkRpym6Kuoo3+h9/StgTmf1izf5fyNKtr1sWlRAps1H1AZpFP0B
    K/qxCXC/oOfRzjeaQ+vw/vdEA4w998ePX0CaCkDOa/aQKZEFsjJ5w3xEhRipgzPw
    6pMdNhvrL/MzSwJvdt9Y2EjXzhlqj6H+JU8tCseUf8u1ij0Mv6ux+oBCBmRUs2vm
    CROEulZKLPAubjGUqi89AgMBAAEwDQYJKoZIhvcNAQELBQADggEBALkJRZaH6GtK
    fyFP3PnTdu319XShP6feBz1v0XlTGSJYA+ufE8fruoJoB+a/AonB0BqNnt5UUBL3
    fz3z3GEcEHiu9h83bq7vRnKYTyflqKn7YMtQegRMROLFmtPyPOvZTWt0OCKR2OwP
    OFAdj8yblVy/rYetoOBGjvX2H9UuAn9w+3fDbWExPD4BEyeEoZnMh9xUgXau8GMu
    bhQmaGE4lDGL8XU6a2M+XkI+YdwKQs+HviT2Cmv3QwCfBZuMnOD4U4+tcnYlz3q2
    O67quuvn46uQFcgxaZwuzQ2vVBzSWSj5JA2GDej4UQipGFLkoLtXdckiJI0LFkHr
    jGFTl9ts7yg=
    -----END CERTIFICATE-----
    """

let serverCertificateData =
    """
    -----BEGIN CERTIFICATE-----
    MIIDuzCCAqOgAwIBAgIJAIKDFx1aQwi8MA0GCSqGSIb3DQEBCwUAMHQxCzAJBgNV
    BAYTAlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5idXJnaDEU
    MBIGA1UECgwLSHVtbWluZ2JpcmQxCzAJBgNVBAsMAkNBMRowGAYDVQQDDBFodW1t
    aW5nYmlyZC5jb2RlczAeFw0yNTAxMjcwODU1MzlaFw0zMDAxMjYwODU1MzlaMHgx
    CzAJBgNVBAYTAlVLMRIwEAYDVQQIDAlFZGluYnVyZ2gxEjAQBgNVBAcMCUVkaW5i
    dXJnaDEUMBIGA1UECgwLSHVtbWluZ2JpcmQxDzANBgNVBAsMBlNlcnZlcjEaMBgG
    A1UEAwwRaHVtbWluZ2JpcmQuY29kZXMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
    ggEKAoIBAQChAarpHioO8b3MVwPFOPq+1YEFAeLZxOXnPRPof+qT0apRsYsDpQQu
    hPWF6fvW1HcpkAGCb9e935Sx172FqHCfAMKI7JaNPn1+wZNAHd0d4tho8bgONdkf
    s9XQZcVLRbc4Gym14sIcfKEOsPUDJISXYQ2nNprSgBVb709SO/JxpTTugJAeAqyW
    bln4db98LpaXNoakaL9py1yUgkosD2GLJl8maueR7Aimf40MmOaVZvvTce11raVg
    iUZtz3CkOdzFLFdQSP9CczkM7Bon8+RyXgM7BUpF9bXu8dL7kRkSu5E9S6bR8CR5
    lwBtoXzw6187GBThVc0R9hiYM/e6cjIHAgMBAAGjTDBKMAsGA1UdDwQEAwIFoDAd
    BgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwHAYDVR0RBBUwE4IRaHVtbWlu
    Z2JpcmQuY29kZXMwDQYJKoZIhvcNAQELBQADggEBACGATnuWnyBK97EeiI+c+8QK
    Aqr9DCt2NQDrC/RIjPgTMfQ3GFWB+8O2rdr2EwGSVj7ovdw8T8LNvccg8P8B6CFL
    E2oPftWghIg5o23BnO5IovpbQKeDien9oUwiEloYvVc6k221Ah3iC/mW9VYJeFYd
    29fhSypXao0mWnzl8CKeB665XX9Q64wRL6tzoiFzRVJCCfF3cQytpI2FzuWmkJfJ
    ECf8CLOYAK3Ko218h14e02J3T1ZMbXJa8mSAG32HqRpABxxfBZdi88XsA6h8qKT/
    dTF/dRScAjFXwxAwFIUVCqct+IfGokUHvkij73bCIJNZL79kRZh2MrndM/OOkNw=
    -----END CERTIFICATE-----
    """

let serverPrivateKeyData =
    """
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQChAarpHioO8b3M
    VwPFOPq+1YEFAeLZxOXnPRPof+qT0apRsYsDpQQuhPWF6fvW1HcpkAGCb9e935Sx
    172FqHCfAMKI7JaNPn1+wZNAHd0d4tho8bgONdkfs9XQZcVLRbc4Gym14sIcfKEO
    sPUDJISXYQ2nNprSgBVb709SO/JxpTTugJAeAqyWbln4db98LpaXNoakaL9py1yU
    gkosD2GLJl8maueR7Aimf40MmOaVZvvTce11raVgiUZtz3CkOdzFLFdQSP9CczkM
    7Bon8+RyXgM7BUpF9bXu8dL7kRkSu5E9S6bR8CR5lwBtoXzw6187GBThVc0R9hiY
    M/e6cjIHAgMBAAECggEABBDdtwta9oumRl3AK5/XvS/5FR5KE0PEpoVFVm68hsUZ
    rvxzzUDCjUYwSRRylqdA5xzK3PdkFFhsEd2n3JM3XNyRDRIkbyav1p6e0FSwu8t5
    uZS5GCrF8+X/tUaMp+z3xoPxFrXGPx/qlUtktJKcgpIh3SIk4MH5SBwP/byjz7jZ
    DfqDIbVG07PCwXe0LEmd8AEGT6vOXULG5SBkTwz/7BSdzgKvDWIgCDjIdDAahdhW
    LSIn9FT1xDeCeOimFwA4ZdM96ZnFlLJwP4WBmqUWgKfsXBc+Oa8ZDlmsDEkhmzCy
    mBNDOxJVgJ5YOURTpTRPeMoDBxkQbQ1V5MRJng9q0QKBgQDRrVORq74LqtgMOb9o
    Ff2T3z/RE1PzW8jlXnrK3lBcW4Ivt4N4xmFCSWlW7PBTtkCGJfSMZA1MNkK1sBl7
    L2FWqh6KymTdBCedsGFrwNiaVXmJWtUimxS3OAFr4/mJWYIIwz43wzXsxhmSOQD+
    T3/kquDCtYq1cvPHtOdTgu/26QKBgQDEk7BNdIZw0TM8YprdC+OiaO05juXEnp2+
    ObKCVDH0KJjpQ9OfqhppMOBG/RP34zGX8c7iJ0uRIgjlIhTHkeDQp974ei8geCTK
    PI90/fhO8pkkpLJZVPreAdj7502jyFYuy79FjQQRMUVOF3YgCYc3kf9aqWGsGT7O
    KkVP3GUrbwKBgFEC37vzmBzX6Fto4GwtuuisI/L6vb/T4Z3FUDobhP76GCWpiLFc
    LG25AWslZoFhdDKgbYjki0K74DBklqPCnaAnYF+NbUT7evbxE+LXApk2lxubraeO
    NYXIrLvrvBj2LUiHbv2KfcY6j9ywC5M2UhqebvKrw6jxfgDWA15/w4kpAoGAK682
    asAOcFvNKwouqBjQSXNP5I6g+QTWwUNJLDVRtJShBpWQHddLbzzxWlU7bscKal3O
    P+vDm0kY+PKN85uzfisQHd/pQSnx4w96QeF+oOzAo6gGClwcM+HtOm24j0EiBdw5
    cVdZJAjzAdus4Im9htfnC1rA3eHuVxqFtK2hvfkCgYEAttVDzfbXDWo4X4g5ZvON
    7ZAldvxQuHhb5JDPwfWR3H/W99tUma5T8e4UhSOU+7dng3xE+LK2aLJXZN6H4VsR
    GeLymDyXs3JLtJyO4JvRp6C+acALua/pyLfeJj+Mk+A+76bmAftqcJ2e7rzp/EgH
    7VbyN0IbfqD+MmEjFat0hRw=
    -----END PRIVATE KEY-----
    """

let clientCertificateData =
    """
    -----BEGIN CERTIFICATE-----
    MIIDaDCCAlACCQCCgxcdWkMIvTANBgkqhkiG9w0BAQsFADB0MQswCQYDVQQGEwJV
    SzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gxFDASBgNV
    BAoMC0h1bW1pbmdiaXJkMQswCQYDVQQLDAJDQTEaMBgGA1UEAwwRaHVtbWluZ2Jp
    cmQuY29kZXMwHhcNMjUwMTI3MDg1NTM5WhcNMzAwMTI2MDg1NTM5WjB4MQswCQYD
    VQQGEwJVSzESMBAGA1UECAwJRWRpbmJ1cmdoMRIwEAYDVQQHDAlFZGluYnVyZ2gx
    FDASBgNVBAoMC0h1bW1pbmdiaXJkMQ8wDQYDVQQLDAZDbGllbnQxGjAYBgNVBAMM
    EWh1bW1pbmdiaXJkLmNvZGVzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
    AQEAsi3Y6b4a1ljWQp2fbC9zLvQNDFHgVMiSNH1XS9rWM9Bqy83BdWsmk1gLEdfb
    XJ6UNvN4KlD7TX0Bf1RUsjEiH8Eqj7nOBaWXm3CFovohFSIfB822ziiGaT6qo9J1
    fhwJ7Mk1dSgs1DRGxWVXV2F7rY3LCBNcdS6N1oAknlOPl4dLOj0GriUO4HH/1Xsh
    TfKyM8GV6oGvca3RP5wHRxe/Xc6zK+RifjTcRfYdeqDjBvTKqt2Lvrmg58xcGZY3
    gyVABOIk95BvMicpSLKG8esYdxNqplmjm5ChhkgD5vBdPF6PYVDVVEqg2s2AKxJ6
    WOzZyKmU3onLdp3QZimEuree7QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQCpBfYg
    df90gpq+lgcfgBp1TyShkPCYV16HKLZLbds5cvNYfEP/tt7G2PdhtAHerPzXNUVi
    Z7xFCX6XNwXlU9JLTOUyhceoCL/9KOt5ec6DwikB9VnpdYQV+Y28cG34ukrr+y7W
    AMm0RrS5pGdk6rka2cOhwYE3D1vzRpuKhXxFqXBp2LC8LsJAeZ+GzqgXl96coLyO
    fzGAqu6nrXCZgJbYNSrMBTL0dKwQaoG5Nxl+Tcr8Ya8K3t4dHG578+6Vz7aLrS34
    GCYKq4yH1XhvkY9yqp94X1XCUkULvWU2xNxcFsmZM2e3uSJUxxBWLHo0yHqCepiN
    Pg7GUe0dKwhJXyWC
    -----END CERTIFICATE-----
    """

let clientPrivateKeyData =
    """
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCyLdjpvhrWWNZC
    nZ9sL3Mu9A0MUeBUyJI0fVdL2tYz0GrLzcF1ayaTWAsR19tcnpQ283gqUPtNfQF/
    VFSyMSIfwSqPuc4FpZebcIWi+iEVIh8HzbbOKIZpPqqj0nV+HAnsyTV1KCzUNEbF
    ZVdXYXutjcsIE1x1Lo3WgCSeU4+Xh0s6PQauJQ7gcf/VeyFN8rIzwZXqga9xrdE/
    nAdHF79dzrMr5GJ+NNxF9h16oOMG9Mqq3Yu+uaDnzFwZljeDJUAE4iT3kG8yJylI
    sobx6xh3E2qmWaObkKGGSAPm8F08Xo9hUNVUSqDazYArEnpY7NnIqZTeict2ndBm
    KYS6t57tAgMBAAECggEACQdru4SHpZ8A1IVaQ8gvxQxW8O3hOUqkpgZH+y8Otbd1
    AfjeOc4BOWw3u2K92farOhGiYDqUUXvpLIOgexskSImoV3op531ZrmXIT9bvADwn
    aGTTQ6UoEoM7cGvEymwvUJFtpQ8xHlu7zlrxTxtAgi3yQOmCQOnoBBugP2mqmBoM
    QDk/8Pn0RBsfDiwiBQtmwibCwpbdMPnkK+6nKhG4SXvhFn3zoxrhzvfL0ypJ759T
    CQHDxjfpoEelONuWOJLEB4oIuLG2KOYxmOqMJrlHgXMGK5a/B7yOHGjdwpgb1zjz
    PNbpIK27fHjZrqEIbtoAJi/sYxe3fSv30XZPbAF1HQKBgQDtjAbbNcAvJZgNh+tZ
    D7g5TDX8J6Mc7GltfyXb7sLArVGWJkv9vZ0hHdESPKcqmMQkuuKQ+lyWzLfTBXZX
    KwB6cNWgAsewOL9gawdBnxr+sp0VTf1fj5+Dq1vS/tk/M9jGtFmCV3z7m1T4Ix5M
    btfPYJMJS/+j5b29jWxs3+wLZwKBgQDABTPEd43dVeq9F27t2NQyBUKblZKBkvtg
    6cr0os4lN2ACFyrsL8lhcPGRJF/ZvPN4C9LVxHbzvHnJZ+5N8nghq/C/o5R+VGpx
    wEnUcyfOUmmRCfifvae+Ra/5cmQrRDPiSL5wFI5sRCWnIvSjF8Ki8Zo9VGamiKtF
    YaHQX1BiiwKBgQDsh0ksbND4IQ7OKlCFVcmyA9idQzp/SkeP59Lis1LoV6utPmTc
    OzmCCBZtekdZetOTXyLKCQC4hw9i50V2djL7t+5+bUY4icjFUMzg4nQWt/MBi66G
    wJOsn6vG5EudSxrGgD3AMy0XuwtYKF+664On0hmWYD4kDFZpr7AOmMiIcQKBgD+V
    +WyHwnyW5OK1DdDJSos93q6yuw8ZYxDWmpSkDOuaCLrofRg1QtR3mCbeCreJsH4C
    PFD5fAJ+WT3uoqVBM7LCwzhSrOugfJcqe8hUUcwq0jZrPN946EFDxmAuFymUrjGy
    sQ1gYUFM18Me+i+/wH5Azzib6FohS8Xv7KuZxH69AoGATjpHMzKhJZiaCi9BhRJM
    0V+ynnGvu1OnZlmiRDljQ4ps1ppAo37myKRSHp1NpTRY+ehKZ08FBhuK2iqyOyz7
    JmltfFmdaEWPaTywNVLfS4/7RJzE80/O4Qslq5/yGdaqdvd1ODiHvYOBKFHd98lQ
    rW3vjyuACFnZb51Qz37qybs=
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
