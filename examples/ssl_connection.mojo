"""
PostgreSQL SSL/TLS Connection Examples.

Demonstrates SSL/TLS configuration and usage for secure PostgreSQL connections.

⚠️  IMPLEMENTATION NOTE:
This example shows the API design for SSL support. Full SSL/TLS implementation
requires binding to OpenSSL or LibreSSL libraries. See ssl_integration.mojo
for implementation requirements.

SSL Modes:
- disable: No SSL (unencrypted)
- allow: Try non-SSL, fallback to SSL
- prefer: Try SSL, fallback to non-SSL (DEFAULT)
- require: Require SSL, fail if unavailable
- verify-ca: Require SSL + verify certificate
- verify-full: Require SSL + verify certificate + hostname

Examples:
1. SSL modes overview
2. SSL configuration
3. Certificate-based authentication
4. SSL connection information
5. Production SSL setup
6. Troubleshooting SSL connections

Prerequisites:
- PostgreSQL with SSL enabled (ssl=on in postgresql.conf)
- Server certificate and key configured
- Client certificates (for mutual TLS)
"""

from src.protocol.ssl import (
    SSLMode,
    SSLConfig,
    SSLStatus,
    SSLConnectionInfo,
    build_ssl_request,
    get_ssl_mode_description,
    validate_certificate_files,
)


fn example1_ssl_modes_overview() raises:
    """Example 1: Overview of SSL modes."""
    print("=" * 70)
    print("Example 1: SSL Modes Overview")
    print("=" * 70)

    print("\n📋 Available SSL Modes:\n")

    # Disable
    var mode_disable = SSLMode.disable()
    print("1️⃣  " + mode_disable.to_string())
    print("   " + get_ssl_mode_description(mode_disable))
    print("   SSL Required:", mode_disable.is_ssl_required())
    print("   Verification Required:", mode_disable.is_verification_required())

    # Allow
    print("\n2️⃣  " + SSLMode.allow().to_string())
    print("   " + get_ssl_mode_description(SSLMode.allow()))

    # Prefer (DEFAULT)
    print("\n3️⃣  " + SSLMode.prefer().to_string() + " (DEFAULT)")
    print("   " + get_ssl_mode_description(SSLMode.prefer()))

    # Require
    print("\n4️⃣  " + SSLMode.require().to_string())
    print("   " + get_ssl_mode_description(SSLMode.require()))

    # Verify CA
    print("\n5️⃣  " + SSLMode.verify_ca().to_string())
    print("   " + get_ssl_mode_description(SSLMode.verify_ca()))

    # Verify Full
    print("\n6️⃣  " + SSLMode.verify_full().to_string())
    print("   " + get_ssl_mode_description(SSLMode.verify_full()))

    print("\n✅ Example 1 complete!\n")


fn example2_ssl_configuration() raises:
    """Example 2: SSL configuration options."""
    print("=" * 70)
    print("Example 2: SSL Configuration")
    print("=" * 70)

    # Default configuration
    print("\n1️⃣  Default Configuration (prefer mode):")
    var config1 = SSLConfig.default()
    print("   " + config1.to_string())
    print("   Mode:", config1.mode.to_string())

    # SSL disabled
    print("\n2️⃣  SSL Disabled:")
    var config2 = SSLConfig.disabled()
    print("   " + config2.to_string())

    # SSL required
    print("\n3️⃣  SSL Required:")
    var config3 = SSLConfig.with_mode(SSLMode.require())
    print("   " + config3.to_string())

    # SSL with verification
    print("\n4️⃣  SSL with Certificate Verification:")
    var config4 = SSLConfig.with_verification(
        "/path/to/root.crt",
        "/path/to/client.crt",
        "/path/to/client.key"
    )
    print("   " + config4.to_string())
    print("   Verification required:", config4.mode.is_verification_required())

    # Custom configuration
    print("\n5️⃣  Custom Configuration:")
    var config5 = SSLConfig(
        SSLMode.verify_full(),
        "/etc/ssl/client.crt",
        "/etc/ssl/client.key",
        "/etc/ssl/ca.crt",
        "/etc/ssl/crl.pem"
    )
    print("   " + config5.to_string())

    print("\n✅ Example 2 complete!\n")


fn example3_ssl_connection_usage() raises:
    """Example 3: How to use SSL with connections (API demonstration)."""
    print("=" * 70)
    print("Example 3: SSL Connection Usage")
    print("=" * 70)

    print("\n📝 Code Examples:\n")

    print("1️⃣  Basic SSL Connection (prefer mode - default):")
    print("""
    from src.protocol.connection import PostgresConnection
    from src.protocol.ssl import SSLConfig

    var conn = PostgresConnection("localhost", 5432)
    var config = SSLConfig.default()  # Prefer SSL

    # When OpenSSL bindings available:
    # conn.connect_with_ssl("mydb", "user", "password", config)
    """)

    print("\n2️⃣  Require SSL Connection:")
    print("""
    var config = SSLConfig.with_mode(SSLMode.require())
    conn.connect_with_ssl("mydb", "user", "password", config)

    # Connection will fail if server doesn't support SSL
    """)

    print("\n3️⃣  SSL with Certificate Verification:")
    print("""
    var config = SSLConfig.with_verification(
        "/etc/ssl/certs/ca.crt",       # Root CA certificate
        "/etc/ssl/client/client.crt",  # Client certificate
        "/etc/ssl/client/client.key"   # Client private key
    )
    conn.connect_with_ssl("mydb", "user", "password", config)

    # Verifies server certificate against CA
    # Provides client certificate for mutual TLS
    """)

    print("\n4️⃣  Disable SSL (unencrypted):")
    print("""
    var config = SSLConfig.disabled()
    conn.connect_with_ssl("mydb", "user", "password", config)

    # Uses regular unencrypted connection
    # Not recommended for production!
    """)

    print("\n✅ Example 3 complete!\n")


fn example4_ssl_status_and_info() raises:
    """Example 4: SSL status and connection information."""
    print("=" * 70)
    print("Example 4: SSL Status and Connection Info")
    print("=" * 70)

    # SSL Status examples
    print("\n1️⃣  SSL Status Examples:\n")

    var status_disabled = SSLStatus.not_enabled()
    print("   Disabled:", status_disabled.to_string())
    print("   Is Secure:", status_disabled.is_secure())

    var status_negotiated = SSLStatus.negotiated_ssl(SSLMode.require())
    print("\n   Negotiated:", status_negotiated.to_string())
    print("   Is Secure:", status_negotiated.is_secure())

    var status_verified = SSLStatus.verified_ssl(SSLMode.verify_ca())
    print("\n   Verified:", status_verified.to_string())
    print("   Is Secure:", status_verified.is_secure())

    # SSL Connection Info
    print("\n2️⃣  SSL Connection Information:\n")

    var info = SSLConnectionInfo.default()
    print(info.to_string())

    var custom_info = SSLConnectionInfo(
        "TLSv1.3",
        "ECDHE-RSA-AES256-GCM-SHA384",
        False,
        256
    )
    print("\n   Custom:")
    print(custom_info.to_string())

    print("\n✅ Example 4 complete!\n")


fn example5_production_ssl_setup() raises:
    """Example 5: Production SSL setup recommendations."""
    print("=" * 70)
    print("Example 5: Production SSL Setup")
    print("=" * 70)

    print("\n🔒 Production SSL Best Practices:\n")

    print("1️⃣  Server Configuration (postgresql.conf):")
    print("""
    ssl = on
    ssl_cert_file = '/etc/postgresql/server.crt'
    ssl_key_file = '/etc/postgresql/server.key'
    ssl_ca_file = '/etc/postgresql/root.crt'
    ssl_crl_file = '/etc/postgresql/root.crl'
    ssl_min_protocol_version = 'TLSv1.2'
    ssl_ciphers = 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384'
    ssl_prefer_server_ciphers = on
    """)

    print("\n2️⃣  Access Control (pg_hba.conf):")
    print("""
    # Require SSL for all remote connections
    hostssl all all 0.0.0.0/0 md5
    hostssl all all ::/0 md5

    # Require client certificates for sensitive databases
    hostssl sensitive_db all 0.0.0.0/0 cert
    """)

    print("\n3️⃣  Client Configuration (Mojo code):")
    print("""
    # Recommended: verify-ca or verify-full
    var config = SSLConfig.with_verification(
        "/etc/ssl/certs/postgresql-ca.crt"
    )

    # For mutual TLS (client certificates):
    var config_mtls = SSLConfig.with_verification(
        "/etc/ssl/certs/postgresql-ca.crt",
        "/etc/ssl/client/client.crt",
        "/etc/ssl/client/client.key"
    )
    """)

    print("\n4️⃣  Certificate Generation:")
    print("""
    # Generate CA certificate
    openssl req -new -x509 -days 3650 -nodes -out ca.crt -keyout ca.key

    # Generate server certificate
    openssl req -new -nodes -out server.csr -keyout server.key
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \\
                 -CAcreateserial -out server.crt -days 365

    # Generate client certificate
    openssl req -new -nodes -out client.csr -keyout client.key
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \\
                 -CAcreateserial -out client.crt -days 365
    """)

    print("\n5️⃣  Security Checklist:")
    print("""
    ✅ Use TLS 1.2 or higher (TLS 1.0/1.1 deprecated)
    ✅ Use strong cipher suites (ECDHE, AES-GCM)
    ✅ Verify server certificates (verify-ca or verify-full)
    ✅ Keep certificates up to date
    ✅ Protect private keys (600 permissions)
    ✅ Use certificate revocation lists (CRL)
    ✅ Disable SSL compression (prevent CRIME)
    ✅ Monitor certificate expiration
    ✅ Use mutual TLS for high-security applications
    ✅ Regular security audits
    """)

    print("\n✅ Example 5 complete!\n")


fn example6_troubleshooting_ssl() raises:
    """Example 6: Troubleshooting SSL connections."""
    print("=" * 70)
    print("Example 6: Troubleshooting SSL Connections")
    print("=" * 70)

    print("\n🔍 Common SSL Issues and Solutions:\n")

    print("1️⃣  Server doesn't support SSL:")
    print("""
    Error: "SSL connection required but server does not support SSL"

    Solution:
    - Check PostgreSQL config: ssl = on
    - Verify server has certificate and key files
    - Check PostgreSQL logs for SSL errors
    - Test with: psql "sslmode=require host=localhost dbname=test"
    """)

    print("\n2️⃣  Certificate verification failed:")
    print("""
    Error: "Certificate verification failed"

    Solutions:
    - Verify root CA certificate is correct
    - Check certificate validity dates
    - Ensure certificate chain is complete
    - Verify hostname matches certificate CN/SAN
    - Check certificate revocation list
    """)

    print("\n3️⃣  Client certificate rejected:")
    print("""
    Error: "Client certificate authentication failed"

    Solutions:
    - Verify client certificate is signed by trusted CA
    - Check certificate validity
    - Ensure private key matches certificate
    - Verify pg_hba.conf requires cert authentication
    - Check certificate subject matches database user
    """)

    print("\n4️⃣  SSL handshake timeout:")
    print("""
    Error: "SSL handshake timeout"

    Solutions:
    - Check network connectivity
    - Verify firewall allows SSL/TLS traffic
    - Increase connection timeout
    - Check server load and resources
    """)

    print("\n5️⃣  Mixed SSL modes:")
    print("""
    Error: "Connection failed with allow/prefer mode"

    Solutions:
    - Check if server supports SSL
    - Try explicit require mode to force SSL
    - Review server SSL configuration
    - Check for proxy/load balancer SSL termination
    """)

    print("\n6️⃣  Debugging Tips:")
    print("""
    # Enable PostgreSQL SSL logging
    log_connections = on
    log_disconnections = on

    # Test SSL with psql
    psql "sslmode=require sslcert=client.crt sslkey=client.key \\
          sslrootcert=ca.crt host=localhost dbname=test"

    # Check server certificate
    openssl s_client -connect localhost:5432 -starttls postgres

    # Verify certificate
    openssl verify -CAfile ca.crt server.crt

    # Check certificate expiration
    openssl x509 -in server.crt -noout -dates
    """)

    print("\n✅ Example 6 complete!\n")


fn example7_ssl_request_protocol() raises:
    """Example 7: SSL request protocol details."""
    print("=" * 70)
    print("Example 7: SSL Request Protocol")
    print("=" * 70)

    print("\n📡 PostgreSQL SSL Negotiation Protocol:\n")

    print("1️⃣  Client sends SSLRequest:")
    var ssl_request = build_ssl_request()
    print("   Message length:", len(ssl_request), "bytes")
    print("   Format: [Length:4] [Code:4]")
    print("   SSL Request Code: 80877103")
    print("   Bytes:", end="")
    for i in range(len(ssl_request)):
        print(" " + hex(int(ssl_request[i])), end="")
    print()

    print("\n2️⃣  Server responds with single byte:")
    print("   'S' (0x53) - SSL supported, proceed with TLS handshake")
    print("   'N' (0x4E) - SSL not supported, use unencrypted connection")

    print("\n3️⃣  If server responds 'S':")
    print("   - Client initiates TLS handshake")
    print("   - Negotiate TLS version (1.2+)")
    print("   - Exchange certificates")
    print("   - Establish encryption")

    print("\n4️⃣  If server responds 'N':")
    print("   - Check SSL mode")
    print("   - If allow/prefer: continue with unencrypted")
    print("   - If require/verify-ca/verify-full: fail with error")

    print("\n5️⃣  After successful SSL handshake:")
    print("   - Send startup message over SSL")
    print("   - All subsequent communication is encrypted")

    print("\n✅ Example 7 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 PostgreSQL SSL/TLS Connection Examples")
    print("Secure Database Connection Configuration")
    print("\n")

    # Run examples
    example1_ssl_modes_overview()
    example2_ssl_configuration()
    example3_ssl_connection_usage()
    example4_ssl_status_and_info()
    example5_production_ssl_setup()
    example6_troubleshooting_ssl()
    example7_ssl_request_protocol()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n⚠️  IMPLEMENTATION NOTE:")
    print("   Full SSL/TLS support requires OpenSSL library bindings.")
    print("   See src/protocol/ssl_integration.mojo for implementation guide.")
    print("\n💡 Key Takeaways:")
    print("   - Use verify-ca or verify-full in production")
    print("   - Keep certificates updated")
    print("   - Use TLS 1.2 or higher")
    print("   - Protect private keys")
    print("   - Monitor certificate expiration")
    print("\n💡 Security Benefits:")
    print("   - Encrypted data transmission")
    print("   - Server authentication")
    print("   - Client authentication (mutual TLS)")
    print("   - Protection against MITM attacks")
    print("   - Compliance with security standards")
    print("\n")
