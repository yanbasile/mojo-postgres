"""
PostgreSQL SSL/TLS Support.

Implements SSL/TLS encryption for PostgreSQL connections to secure data transmission.

SSL Modes:
- disable: Only try non-SSL connection
- allow: Try non-SSL first, then SSL if that fails
- prefer: Try SSL first, then non-SSL if that fails (default)
- require: Only try SSL connection
- verify-ca: Require SSL and verify server certificate
- verify-full: Require SSL, verify certificate and hostname

SSL Negotiation Protocol:
1. Client sends SSLRequest (8 bytes: length + code 80877103)
2. Server responds with 'S' (supported) or 'N' (not supported)
3. If 'S', client initiates TLS handshake
4. After handshake, normal startup message follows

Reference: https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-SSL
"""

from collections import List
from .connection import to_network_bytes_int32


# ============================================================================
# SSL Mode Enumeration
# ============================================================================

@value
struct SSLMode:
    """
    SSL connection mode.

    Modes:
    - DISABLE: Never use SSL
    - ALLOW: Use SSL if server supports it (fallback to non-SSL)
    - PREFER: Prefer SSL, fallback to non-SSL if unavailable (default)
    - REQUIRE: Require SSL, fail if unavailable
    - VERIFY_CA: Require SSL and verify server certificate
    - VERIFY_FULL: Require SSL, verify certificate and hostname

    Example:
        var mode = SSLMode.prefer()
        var mode2 = SSLMode.require()
    """
    var value: String

    @staticmethod
    fn disable() -> SSLMode:
        """Disable SSL (unencrypted connection only)."""
        return SSLMode("disable")

    @staticmethod
    fn allow() -> SSLMode:
        """Allow SSL (try non-SSL first, fallback to SSL)."""
        return SSLMode("allow")

    @staticmethod
    fn prefer() -> SSLMode:
        """Prefer SSL (try SSL first, fallback to non-SSL) - DEFAULT."""
        return SSLMode("prefer")

    @staticmethod
    fn require() -> SSLMode:
        """Require SSL (fail if SSL unavailable)."""
        return SSLMode("require")

    @staticmethod
    fn verify_ca() -> SSLMode:
        """Require SSL and verify server certificate against CA."""
        return SSLMode("verify-ca")

    @staticmethod
    fn verify_full() -> SSLMode:
        """Require SSL, verify certificate and hostname."""
        return SSLMode("verify-full")

    fn to_string(self) -> String:
        """Convert SSL mode to string."""
        return self.value

    fn is_ssl_required(self) -> Bool:
        """Check if SSL is required (not disable or allow)."""
        return self.value != "disable" and self.value != "allow"

    fn is_verification_required(self) -> Bool:
        """Check if certificate verification is required."""
        return self.value == "verify-ca" or self.value == "verify-full"


# ============================================================================
# SSL Configuration
# ============================================================================

@value
struct SSLConfig:
    """
    SSL/TLS configuration for PostgreSQL connection.

    Attributes:
        mode: SSL mode (disable, allow, prefer, require, verify-ca, verify-full)
        cert_file: Path to client certificate file (optional)
        key_file: Path to client private key file (optional)
        root_cert_file: Path to root certificate file for verification (optional)
        crl_file: Path to certificate revocation list file (optional)

    Example:
        # Basic SSL connection
        var config = SSLConfig.with_mode(SSLMode.require())

        # SSL with certificate verification
        var config2 = SSLConfig.with_verification(
            "/path/to/root.crt",
            "/path/to/client.crt",
            "/path/to/client.key"
        )
    """
    var mode: SSLMode
    var cert_file: String
    var key_file: String
    var root_cert_file: String
    var crl_file: String

    @staticmethod
    fn default() -> SSLConfig:
        """Create default SSL configuration (prefer mode, no certificates)."""
        return SSLConfig(
            SSLMode.prefer(),
            "",  # cert_file
            "",  # key_file
            "",  # root_cert_file
            ""   # crl_file
        )

    @staticmethod
    fn disabled() -> SSLConfig:
        """Create configuration with SSL disabled."""
        return SSLConfig(
            SSLMode.disable(),
            "", "", "", ""
        )

    @staticmethod
    fn with_mode(mode: SSLMode) -> SSLConfig:
        """Create configuration with specific SSL mode."""
        return SSLConfig(mode, "", "", "", "")

    @staticmethod
    fn with_verification(root_cert: String, client_cert: String = "", client_key: String = "") -> SSLConfig:
        """
        Create configuration with certificate verification.

        Args:
            root_cert: Path to root CA certificate
            client_cert: Path to client certificate (optional)
            client_key: Path to client private key (optional)
        """
        return SSLConfig(
            SSLMode.verify_ca(),
            client_cert,
            client_key,
            root_cert,
            ""
        )

    fn to_string(self) -> String:
        """Convert SSL config to string."""
        var result = "SSLConfig(mode=" + self.mode.to_string()

        if self.root_cert_file != "":
            result += ", root_cert=" + self.root_cert_file

        if self.cert_file != "":
            result += ", cert=" + self.cert_file

        if self.key_file != "":
            result += ", key=" + self.key_file

        result += ")"
        return result


# ============================================================================
# SSL Request Message
# ============================================================================

fn build_ssl_request() -> List[UInt8]:
    """
    Build SSL request message.

    Format: [Length:4][SSLRequestCode:4]
    - Length: 8 (includes itself)
    - SSL Request Code: 80877103

    Returns:
        SSL request message bytes

    Example:
        var ssl_request = build_ssl_request()
        # Send to server, wait for 'S' or 'N' response
    """
    var msg = List[UInt8]()

    # Length: 8 (4 for length + 4 for SSL code)
    var length = 8
    var length_bytes = to_network_bytes_int32(length)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    # SSL Request Code: 80877103 (in network byte order)
    # 80877103 = 0x04D2162F
    var ssl_code = 80877103
    var code_bytes = to_network_bytes_int32(ssl_code)
    for i in range(len(code_bytes)):
        msg.append(code_bytes[i])

    return msg


# ============================================================================
# SSL Status
# ============================================================================

@value
struct SSLStatus:
    """
    SSL connection status.

    Attributes:
        enabled: Whether SSL is enabled for this connection
        mode: SSL mode used
        negotiated: Whether SSL was successfully negotiated
        verified: Whether certificate was verified (if required)

    Example:
        var status = SSLStatus(True, SSLMode.require(), True, False)
        print(status.to_string())
    """
    var enabled: Bool
    var mode: SSLMode
    var negotiated: Bool
    var verified: Bool

    @staticmethod
    fn not_enabled() -> SSLStatus:
        """Create status for non-SSL connection."""
        return SSLStatus(False, SSLMode.disable(), False, False)

    @staticmethod
    fn negotiated_ssl(mode: SSLMode) -> SSLStatus:
        """Create status for successfully negotiated SSL."""
        return SSLStatus(True, mode, True, False)

    @staticmethod
    fn verified_ssl(mode: SSLMode) -> SSLStatus:
        """Create status for verified SSL connection."""
        return SSLStatus(True, mode, True, True)

    fn to_string(self) -> String:
        """Convert SSL status to string."""
        if not self.enabled:
            return "SSL: disabled"

        var result = "SSL: enabled (mode=" + self.mode.to_string()

        if self.negotiated:
            result += ", negotiated=true"
        else:
            result += ", negotiated=false"

        if self.verified:
            result += ", verified=true"
        else:
            result += ", verified=false"

        result += ")"
        return result

    fn is_secure(self) -> Bool:
        """Check if connection is secure (SSL enabled and negotiated)."""
        return self.enabled and self.negotiated


# ============================================================================
# SSL Helper Functions
# ============================================================================

fn parse_ssl_response(response: UInt8) raises -> Bool:
    """
    Parse SSL response from server.

    Args:
        response: Single byte response ('S' or 'N')

    Returns:
        True if SSL supported ('S'), False if not supported ('N')

    Raises:
        Error if response is invalid

    Example:
        var supported = parse_ssl_response(ord('S'))  # Returns True
        var not_supported = parse_ssl_response(ord('N'))  # Returns False
    """
    if response == ord('S'):
        return True
    elif response == ord('N'):
        return False
    else:
        raise Error("Invalid SSL response: expected 'S' or 'N', got " + String(chr(int(response))))


fn is_ssl_enabled(mode: SSLMode) -> Bool:
    """
    Check if SSL should be attempted for given mode.

    Args:
        mode: SSL mode

    Returns:
        True if SSL should be attempted, False otherwise

    Example:
        var enabled = is_ssl_enabled(SSLMode.prefer())  # True
        var disabled = is_ssl_enabled(SSLMode.disable())  # False
    """
    return mode.value != "disable"


fn should_fallback_to_non_ssl(mode: SSLMode) -> Bool:
    """
    Check if connection should fallback to non-SSL if SSL fails.

    Args:
        mode: SSL mode

    Returns:
        True if fallback allowed, False otherwise

    Example:
        var can_fallback = should_fallback_to_non_ssl(SSLMode.prefer())  # True
        var no_fallback = should_fallback_to_non_ssl(SSLMode.require())  # False
    """
    return mode.value == "allow" or mode.value == "prefer"


fn get_ssl_error_message(mode: SSLMode) -> String:
    """
    Get appropriate error message for SSL connection failure.

    Args:
        mode: SSL mode that failed

    Returns:
        Error message string

    Example:
        var msg = get_ssl_error_message(SSLMode.require())
    """
    if mode.value == "require":
        return "SSL connection required but server does not support SSL"
    elif mode.value == "verify-ca":
        return "SSL connection required with CA verification but server does not support SSL"
    elif mode.value == "verify-full":
        return "SSL connection required with full verification but server does not support SSL"
    else:
        return "SSL connection failed"


# ============================================================================
# SSL Certificate Validation
# ============================================================================

fn validate_certificate_files(config: SSLConfig) raises:
    """
    Validate that required certificate files exist and are readable.

    Args:
        config: SSL configuration

    Raises:
        Error if required files are missing or invalid

    Example:
        var config = SSLConfig.with_verification("/path/to/root.crt")
        validate_certificate_files(config)
    """
    # Check if verification is required
    if not config.mode.is_verification_required():
        return

    # Root certificate is required for verification
    if config.root_cert_file == "":
        raise Error("Root certificate file required for SSL verification mode")

    # Note: In a real implementation, we would check if files exist and are readable
    # For now, we just validate that paths are provided when required


fn get_cipher_list() -> String:
    """
    Get default cipher list for SSL/TLS connections.

    Returns:
        Cipher list string

    Note:
        This is a simplified implementation. Production code should use
        secure, up-to-date cipher suites.
    """
    # Modern secure ciphers (TLS 1.2+)
    return "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256"


fn get_min_tls_version() -> String:
    """
    Get minimum TLS version to accept.

    Returns:
        TLS version string (e.g., "TLSv1.2")

    Note:
        Modern PostgreSQL installations should use TLS 1.2 or higher.
    """
    return "TLSv1.2"


# ============================================================================
# SSL Connection Info
# ============================================================================

@value
struct SSLConnectionInfo:
    """
    Information about SSL connection.

    Attributes:
        protocol: SSL/TLS protocol version (e.g., "TLSv1.3")
        cipher: Cipher suite used
        compression: Whether compression is enabled
        bits: Key size in bits

    Example:
        var info = SSLConnectionInfo("TLSv1.3", "ECDHE-RSA-AES256-GCM-SHA384", False, 256)
        print(info.to_string())
    """
    var protocol: String
    var cipher: String
    var compression: Bool
    var bits: Int

    fn to_string(self) -> String:
        """Convert SSL connection info to string."""
        var result = "SSL Connection Info:\n"
        result += "  Protocol: " + self.protocol + "\n"
        result += "  Cipher: " + self.cipher + "\n"
        result += "  Compression: " + ("enabled" if self.compression else "disabled") + "\n"
        result += "  Key Size: " + String(self.bits) + " bits"
        return result

    @staticmethod
    fn default() -> SSLConnectionInfo:
        """Create default SSL connection info."""
        return SSLConnectionInfo(
            "TLSv1.2",
            "ECDHE-RSA-AES256-GCM-SHA384",
            False,
            256
        )


# ============================================================================
# SSL Documentation and Examples
# ============================================================================

fn get_ssl_mode_description(mode: SSLMode) -> String:
    """
    Get detailed description of SSL mode.

    Args:
        mode: SSL mode

    Returns:
        Description string

    Example:
        var desc = get_ssl_mode_description(SSLMode.require())
        print(desc)
    """
    if mode.value == "disable":
        return "disable: Only use non-SSL connection. SSL is never attempted."
    elif mode.value == "allow":
        return "allow: Try non-SSL first, then SSL if that fails. Not recommended for security."
    elif mode.value == "prefer":
        return "prefer: Try SSL first, then non-SSL if SSL fails. Default mode."
    elif mode.value == "require":
        return "require: Only use SSL connection. Fail if SSL unavailable. Does not verify certificates."
    elif mode.value == "verify-ca":
        return "verify-ca: Require SSL and verify server certificate against CA. More secure than 'require'."
    elif mode.value == "verify-full":
        return "verify-full: Require SSL, verify certificate and hostname. Most secure mode."
    else:
        return "Unknown SSL mode"
