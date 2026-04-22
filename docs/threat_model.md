# Threat Model

## Overview

This document describes a high-level threat model for the Hummingbird package and its first party modules included in this repository including `Hummingbird`, `HummingbirdCore`, `HummingbirdTLS`, `HummingbirdHTTP2`.

Its focus is on the network facing elements of a Hummingbird server deployed in a production environment.

## Objectives

- Ensure the confidentiality of request/response data and any secrets handled by application built on top of Hummingbird.
- Preserve the availability of services under malicious or malformed traffic.

The purpose of this document is not to build a full threat model for an application built on top of Hummingbird.

## Context

At a high level Hummingbird is a server framework built on top of the Apple library swift-nio. It exposes web server functionality via HTTP1.1, with optional modules that provide TLS and HTTP2 connections. It provides a router and a middleware chain for applications to route requests to their own defined handlers.

Typical data flow is untrusted client traffic is consumed by swift-nio library and this generates an HTTP request. Router then selects an application handler based on the contents of that HTTP request and passes the request to the application defined middleware chain. Handler then returns a response which is passed back through the middleware chain in the opposite direction. Hummingbird then writes it back to the swift-nio library.

## Assets

Here is a list of assets that require protection
- Request payloads, HTTP path, URL query parameters and headers (may contain credentials, tokens or PII)
- Response payloads and headers which may also contain sensitive data.
- (TLS) private keys and certificates.
- Service availability
- Dependency and release integrity for the package.

## What do we not trust

- The contents of the requests supplied to us via underlying network transport (SwiftNIO).
- The source of new connections to the server framework.
- Environment variables.
- Configuration files.

## What do we trust

- We trust the underlying network transport to generate a valid HTTP request from untrusted inbound network data or generate an error when receiving invalid data.
- We trust the underlying OS and file system to work as expected.

## Examples of vulnerabilities

Exposing credentials or PII via logging, metrics or tracing
- Hummingbird provides middleware to generate logging information, metrics and trace spans. These should not be allowed to expose credentials or PII unless explicitly asked for.

Memory exhaustion via large HTTP payloads
- Hummingbird should stream request payloads and should use backpressure to ensure in-transit payload chunks don't consume too much memory while waiting to be processed.

CPU/Memory exhaustion through connection floods
- Hummingbird provides mechanisms to limit the number of connections a server will accept but these are not very well documented.

CPU/Memory exhaustion through slowloris style behaviours.
- Slowloris is an attack method where a single machine can bring down a server by opening many connections to the server and holding them open for as long as possible. Hummingbird provides mechanisms to close idle connections and thus limit the number of connections a single machine can keep open. These are currently not very well documented.

Passing untrusted data directly to upstream services
- For example using the request uri as a dimension in a metric could inflict a denial of service on a metrics backend if an attacker hit the server with thousands of random URIs.

HTTP request smuggling
- SwiftNIO does our parsing of the HTTP requests and catches attempts at HTTP request smuggling and closes the connection.

Response header splitting
- An application that passes unvalidated data from an untrusted service in a response header can return unexpected additional header fields. SwiftNIO protects against this and nulls out any malicious characters.

## Examples of non-vulnerabilities

Memory exhaustion because an application collates an unbounded request payload into one buffer.
- There are limits that can be applied to ensure large payloads are rejected. Applications should use these.

We are not responsible for the contents of a request being passed onto third party services by user application
- For example we are not responsible for vulnerabilities like SQL injection.

Cross-Site Request Forgery (CSRF)
- CSRF attacks are not something that the server framework can protect against. The application is responsible for protecting against these.
