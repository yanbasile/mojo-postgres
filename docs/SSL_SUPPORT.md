# SSL/TLS Support for mojo-postgres

Comprehensive guide to SSL/TLS encrypted connections in mojo-postgres.

## Table of Contents

- [Overview](#overview)
- [Implementation Status](#implementation-status)
- [SSL Modes](#ssl-modes)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Production Setup](#production-setup)
- [Certificate Management](#certificate-management)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [Implementation Guide](#implementation-guide)

## Overview

SSL/TLS encryption provides:
- **Confidentiality**: Encrypted data transmission
- **Authentication**: Verify server identity
- **Integrity**: Detect tampering
- **Compliance**: Meet security standards (PCI DSS, HIPAA, etc.)

## Implementation Status

| Component | Status | Description |
|-----------|--------|-------------|
| SSL Protocol Structures | ✅ Complete | SSLMode, SSLConfig, SSLStatus |
| SSL Request/Response | ✅ Complete | PostgreSQL SSL negotiation protocol |
| Configuration API | ✅ Complete | Full configuration options |
| Documentation | ✅ Complete | Comprehensive guides and examples |
| TLS Handshake | ⏳ Pending | Requires OpenSSL bindings |
| Certificate Verification | ⏳ Pending | Requires OpenSSL bindings |
| Encrypted I/O | ⏳ Pending | Requires OpenSSL bindings |

**Note**: Full SSL/TLS implementation requires binding to OpenSSL, LibreSSL, or BoringSSL. The framework and API are complete and ready for integration.

## SSL Modes

### Available Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `disable` | No SSL, unencrypted only | Development, trusted networks |
| `allow` | Try non-SSL first, fallback to SSL | Legacy compatibility |
| `prefer` | Try SSL first, fallback to non-SSL (DEFAULT) | Development |
| `require` | SSL required, no verification | Basic encryption |
| `verify-ca` | SSL + verify server certificate | Production (recommended) |
| `verify-full` | SSL + verify certificate + hostname | High security (recommended) |

### Mode Selection Guide

```
Development: prefer (default)
Staging: require or verify-ca
Production: verify-ca or verify-full
High Security: verify-full + mutual TLS
```

## Quick Start

### Basic SSL Connection

```mojo
from src.protocol.connection import PostgresConnection
from src.protocol.ssl import SSLConfig, SSLMode

# Default SSL (prefer mode)
var conn = PostgresConnection("localhost", 5432)
var config = SSLConfig.default()

# When OpenSSL bindings available:
# conn.connect_with_ssl("mydb", "user", "password", config)
```

### Required SSL

```mojo
# SSL required, fail if unavailable
var config = SSLConfig.with_mode(SSLMode.require())
conn.connect_with_ssl("mydb", "user", "password", config)
```

### SSL with Certificate Verification

```mojo
# Verify server certificate
var config = SSLConfig.with_verification(
    "/etc/ssl/certs/postgresql-ca.crt",     # Root CA
    "/etc/ssl/client/postgresql-client.crt", # Client cert (optional)
    "/etc/ssl/client/postgresql-client.key"  # Client key (optional)
)
conn.connect_with_ssl("mydb", "user", "password", config)
```

## Configuration

### SSL Configuration Options

```mojo
@value
struct SSLConfig:
    var mode: SSLMode                # SSL mode
    var cert_file: String            # Client certificate path
    var key_file: String             # Client private key path
    var root_cert_file: String       # Root CA certificate path
    var crl_file: String             # Certificate revocation list path
```

### Configuration Methods

```mojo
# Default configuration (prefer mode)
var config1 = SSLConfig.default()

# Disabled SSL
var config2 = SSLConfig.disabled()

# Specific mode
var config3 = SSLConfig.with_mode(SSLMode.require())

# With verification
var config4 = SSLConfig.with_verification("/path/to/ca.crt")

# Custom configuration
var config5 = SSLConfig(
    SSLMode.verify_full(),
    "/path/to/client.crt",
    "/path/to/client.key",
    "/path/to/root.crt",
    "/path/to/crl.pem"
)
```

## Production Setup

### PostgreSQL Server Configuration

Edit `postgresql.conf`:

```ini
# Enable SSL
ssl = on

# Certificate files
ssl_cert_file = '/etc/postgresql/15/main/server.crt'
ssl_key_file = '/etc/postgresql/15/main/server.key'
ssl_ca_file = '/etc/postgresql/15/main/root.crt'
ssl_crl_file = '/etc/postgresql/15/main/root.crl'

# Protocol and ciphers
ssl_min_protocol_version = 'TLSv1.2'
ssl_max_protocol_version = 'TLSv1.3'
ssl_ciphers = 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384'
ssl_prefer_server_ciphers = on

# Additional security
ssl_dh_params_file = '/etc/postgresql/15/main/dh2048.pem'
```

### Access Control Configuration

Edit `pg_hba.conf`:

```conf
# TYPE  DATABASE    USER        ADDRESS           METHOD

# Require SSL for all remote connections
hostssl all         all         0.0.0.0/0         md5
hostssl all         all         ::/0              md5

# Require client certificates for sensitive databases
hostssl sensitive   all         0.0.0.0/0         cert clientcert=verify-full

# Local connections (no SSL)
local   all         all                           peer
```

### Client Configuration

```mojo
# Production: Always use verify-ca or verify-full
var config = SSLConfig.with_verification(
    "/etc/ssl/certs/postgresql-ca.crt"
)

# High security: Mutual TLS
var config_mtls = SSLConfig.with_verification(
    "/etc/ssl/certs/postgresql-ca.crt",
    "/etc/ssl/client/client.crt",
    "/etc/ssl/client/client.key"
)
```

## Certificate Management

### Generate Certificates

#### Root CA Certificate

```bash
# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate (valid 10 years)
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=PostgreSQL CA"
```

#### Server Certificate

```bash
# Generate server private key
openssl genrsa -out server.key 2048

# Generate certificate signing request
openssl req -new -key server.key -out server.csr \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=db.example.com"

# Sign server certificate with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 365 \
    -sha256 -extfile <(echo "subjectAltName=DNS:db.example.com,DNS:*.db.example.com")

# Set correct permissions
chmod 600 server.key
chmod 644 server.crt
```

#### Client Certificate

```bash
# Generate client private key
openssl genrsa -out client.key 2048

# Generate client CSR
openssl req -new -key client.key -out client.csr \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=dbuser"

# Sign client certificate
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out client.crt -days 365

# Set permissions
chmod 600 client.key
chmod 644 client.crt
```

### Certificate Verification

```bash
# Verify certificate
openssl verify -CAfile ca.crt server.crt

# Check certificate details
openssl x509 -in server.crt -text -noout

# Check expiration
openssl x509 -in server.crt -noout -dates

# Test server SSL
openssl s_client -connect db.example.com:5432 -starttls postgres
```

## Troubleshooting

### Common Issues

#### 1. Server Doesn't Support SSL

**Error**: `SSL connection required but server does not support SSL`

**Solutions**:
- Enable SSL in postgresql.conf: `ssl = on`
- Verify server has certificate files
- Check PostgreSQL logs
- Test with psql: `psql "sslmode=require host=localhost dbname=test"`

#### 2. Certificate Verification Failed

**Error**: `Certificate verification failed`

**Solutions**:
- Verify root CA certificate path is correct
- Check certificate validity dates
- Ensure certificate chain is complete
- Verify hostname matches certificate CN/SAN
- Check certificate hasn't been revoked

#### 3. Permission Denied on Certificate Files

**Error**: `Permission denied` when reading certificates

**Solutions**:
```bash
# Server certificates (PostgreSQL user must read)
chmod 600 server.key
chmod 644 server.crt
chown postgres:postgres server.key server.crt

# Client certificates
chmod 600 client.key
chmod 644 client.crt
```

#### 4. SSL Handshake Timeout

**Error**: `SSL handshake timeout`

**Solutions**:
- Check network connectivity
- Verify firewall allows port 5432
- Check for SSL offloading at load balancer
- Increase connection timeout

### Debug Commands

```bash
# Check PostgreSQL SSL status
psql "sslmode=require host=localhost" -c "SHOW ssl;"

# View SSL connection info
psql "sslmode=require host=localhost" -c "
  SELECT ssl_is_used, version, cipher
  FROM pg_stat_ssl
  WHERE pid = pg_backend_pid();"

# Test different SSL modes
psql "sslmode=disable host=localhost dbname=test"
psql "sslmode=require host=localhost dbname=test"
psql "sslmode=verify-ca sslrootcert=ca.crt host=localhost dbname=test"
psql "sslmode=verify-full sslrootcert=ca.crt host=db.example.com dbname=test"

# Check certificate
openssl x509 -in server.crt -text -noout | grep -A2 "Subject:"
openssl x509 -in server.crt -text -noout | grep -A2 "Validity"
```

## Security Best Practices

### Certificate Security

- ✅ Use 2048-bit or 4096-bit RSA keys
- ✅ Use strong signing algorithms (SHA-256 or better)
- ✅ Set appropriate certificate validity periods (1 year recommended)
- ✅ Protect private keys (600 permissions, encrypted storage)
- ✅ Use certificate revocation lists (CRL)
- ✅ Rotate certificates before expiration
- ✅ Monitor certificate expiration dates

### Protocol Security

- ✅ Use TLS 1.2 or TLS 1.3 only
- ✅ Disable older protocols (TLS 1.0, 1.1, SSLv3)
- ✅ Use strong cipher suites (ECDHE, AES-GCM)
- ✅ Prefer forward secrecy (ECDHE, DHE)
- ✅ Disable compression (prevent CRIME attack)
- ✅ Enable server cipher preference

### Recommended Cipher Suites

```
TLS 1.3 (preferred):
- TLS_AES_256_GCM_SHA384
- TLS_CHACHA20_POLY1305_SHA256
- TLS_AES_128_GCM_SHA256

TLS 1.2:
- ECDHE-RSA-AES256-GCM-SHA384
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-RSA-CHACHA20-POLY1305
```

### Connection Security

- ✅ Use `verify-ca` or `verify-full` in production
- ✅ Implement mutual TLS for high-security applications
- ✅ Use certificate pinning for critical connections
- ✅ Implement connection timeout policies
- ✅ Log all SSL connection attempts
- ✅ Monitor for SSL/TLS vulnerabilities

## Implementation Guide

For developers adding full SSL/TLS support to mojo-postgres.

### Required Components

1. **OpenSSL FFI Bindings**
   - SSL context creation
   - SSL session management
   - Certificate operations
   - Encrypted I/O

2. **SSL Integration**
   - Integrate with PostgreSQL connection
   - Handle SSL negotiation
   - Manage SSL state

3. **Error Handling**
   - SSL error codes
   - Certificate validation errors
   - Connection failures

### Implementation Checklist

#### Phase 1: OpenSSL Bindings
- [ ] Create FFI declarations for OpenSSL functions
- [ ] Implement SSL_CTX lifecycle management
- [ ] Implement SSL session creation/destruction
- [ ] Add certificate loading functions
- [ ] Add SSL I/O wrappers

#### Phase 2: SSL Negotiation
- [ ] Integrate SSL request sending
- [ ] Handle SSL response
- [ ] Perform TLS handshake
- [ ] Implement fallback logic

#### Phase 3: Certificate Verification
- [ ] Load CA certificates
- [ ] Verify certificate chain
- [ ] Check certificate validity
- [ ] Verify hostname (for verify-full)
- [ ] Handle CRL checking

#### Phase 4: Encrypted Communication
- [ ] Replace send() with SSL_write()
- [ ] Replace recv() with SSL_read()
- [ ] Handle SSL errors
- [ ] Implement proper shutdown

#### Phase 5: Testing
- [ ] Unit tests for SSL functions
- [ ] Integration tests with real PostgreSQL
- [ ] Certificate validation tests
- [ ] Error handling tests
- [ ] Performance testing

### Code Example (Pseudocode)

```mojo
fn connect_with_ssl(
    inout self,
    database: String,
    user: String,
    password: String,
    config: SSLConfig
) raises:
    # Create socket
    self.socket_fd = self._create_and_connect_socket()

    # Send SSL request if enabled
    if is_ssl_enabled(config.mode):
        var ssl_request = build_ssl_request()
        self._send_bytes(ssl_request)

        var response = self._recv_byte()
        var ssl_supported = parse_ssl_response(response)

        if ssl_supported:
            # Perform TLS handshake
            var ssl_ctx = create_ssl_context(config)
            self.ssl_handle = perform_handshake(ssl_ctx, self.socket_fd)

            # Verify certificate if required
            if config.mode.is_verification_required():
                verify_certificate(self.ssl_handle, config)
        elif config.mode.is_ssl_required():
            raise Error("SSL required but not supported")

    # Continue with startup message (over SSL if enabled)
    var startup_msg = build_startup_message(user, database)
    self._send_bytes(startup_msg)
    # ... rest of connection flow
```

### OpenSSL Function References

```c
// Context creation
SSL_CTX *SSL_CTX_new(const SSL_METHOD *method);
int SSL_CTX_set_min_proto_version(SSL_CTX *ctx, int version);
int SSL_CTX_load_verify_locations(SSL_CTX *ctx, const char *CAfile, const char *CApath);

// Certificate loading
int SSL_CTX_use_certificate_file(SSL_CTX *ctx, const char *file, int type);
int SSL_CTX_use_PrivateKey_file(SSL_CTX *ctx, const char *file, int type);

// Session creation
SSL *SSL_new(SSL_CTX *ctx);
int SSL_set_fd(SSL *ssl, int fd);

// Handshake
int SSL_connect(SSL *ssl);
long SSL_get_verify_result(SSL *ssl);

// I/O
int SSL_write(SSL *ssl, const void *buf, int num);
int SSL_read(SSL *ssl, void *buf, int num);

// Cleanup
int SSL_shutdown(SSL *ssl);
void SSL_free(SSL *ssl);
void SSL_CTX_free(SSL_CTX *ctx);
```

## Additional Resources

- [PostgreSQL SSL Documentation](https://www.postgresql.org/docs/current/ssl-tcp.html)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [TLS Best Practices (Mozilla)](https://wiki.mozilla.org/Security/Server_Side_TLS)
- [OWASP TLS Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)

## License

This implementation follows the same license as mojo-postgres.
