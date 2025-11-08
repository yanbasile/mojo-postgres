"""
Unit tests for SSL/TLS infrastructure.

Tests SSL configuration, modes, status, and protocol handling.

Test Categories:
1. SSL Mode tests
2. SSL Configuration tests
3. SSL Status tests
4. SSL Request/Response protocol
5. SSL Helper functions
6. Edge cases
"""

from testing import assert_equal, assert_true, assert_false, assert_raises
from src.protocol.ssl import (
    SSLMode,
    SSLConfig,
    SSLStatus,
    SSLConnectionInfo,
    build_ssl_request,
    parse_ssl_response,
    is_ssl_enabled,
    should_fallback_to_non_ssl,
    get_ssl_error_message,
    get_ssl_mode_description,
)


# ============================================================================
# Test 1: SSL Mode Tests
# ============================================================================

fn test_ssl_mode_disable() raises:
    """Test 1.1: Disable SSL mode."""
    print("  test_ssl_mode_disable...", end="")

    var mode = SSLMode.disable()
    assert_equal(mode.to_string(), "disable")
    assert_false(mode.is_ssl_required())
    assert_false(mode.is_verification_required())

    print(" ✅")


fn test_ssl_mode_allow() raises:
    """Test 1.2: Allow SSL mode."""
    print("  test_ssl_mode_allow...", end="")

    var mode = SSLMode.allow()
    assert_equal(mode.to_string(), "allow")
    assert_false(mode.is_ssl_required())

    print(" ✅")


fn test_ssl_mode_prefer() raises:
    """Test 1.3: Prefer SSL mode (default)."""
    print("  test_ssl_mode_prefer...", end="")

    var mode = SSLMode.prefer()
    assert_equal(mode.to_string(), "prefer")
    assert_true(mode.is_ssl_required())
    assert_false(mode.is_verification_required())

    print(" ✅")


fn test_ssl_mode_require() raises:
    """Test 1.4: Require SSL mode."""
    print("  test_ssl_mode_require...", end="")

    var mode = SSLMode.require()
    assert_equal(mode.to_string(), "require")
    assert_true(mode.is_ssl_required())
    assert_false(mode.is_verification_required())

    print(" ✅")


fn test_ssl_mode_verify_ca() raises:
    """Test 1.5: Verify CA mode."""
    print("  test_ssl_mode_verify_ca...", end="")

    var mode = SSLMode.verify_ca()
    assert_equal(mode.to_string(), "verify-ca")
    assert_true(mode.is_ssl_required())
    assert_true(mode.is_verification_required())

    print(" ✅")


fn test_ssl_mode_verify_full() raises:
    """Test 1.6: Verify full mode."""
    print("  test_ssl_mode_verify_full...", end="")

    var mode = SSLMode.verify_full()
    assert_equal(mode.to_string(), "verify-full")
    assert_true(mode.is_ssl_required())
    assert_true(mode.is_verification_required())

    print(" ✅")


# ============================================================================
# Test 2: SSL Configuration Tests
# ============================================================================

fn test_ssl_config_default() raises:
    """Test 2.1: Default SSL configuration."""
    print("  test_ssl_config_default...", end="")

    var config = SSLConfig.default()
    assert_equal(config.mode.to_string(), "prefer")
    assert_equal(config.cert_file, "")
    assert_equal(config.key_file, "")
    assert_equal(config.root_cert_file, "")

    print(" ✅")


fn test_ssl_config_disabled() raises:
    """Test 2.2: Disabled SSL configuration."""
    print("  test_ssl_config_disabled...", end="")

    var config = SSLConfig.disabled()
    assert_equal(config.mode.to_string(), "disable")

    print(" ✅")


fn test_ssl_config_with_mode() raises:
    """Test 2.3: Configuration with specific mode."""
    print("  test_ssl_config_with_mode...", end="")

    var config = SSLConfig.with_mode(SSLMode.require())
    assert_equal(config.mode.to_string(), "require")

    print(" ✅")


fn test_ssl_config_with_verification() raises:
    """Test 2.4: Configuration with verification."""
    print("  test_ssl_config_with_verification...", end="")

    var config = SSLConfig.with_verification(
        "/path/to/root.crt",
        "/path/to/client.crt",
        "/path/to/client.key"
    )

    assert_equal(config.mode.to_string(), "verify-ca")
    assert_equal(config.root_cert_file, "/path/to/root.crt")
    assert_equal(config.cert_file, "/path/to/client.crt")
    assert_equal(config.key_file, "/path/to/client.key")

    print(" ✅")


fn test_ssl_config_to_string() raises:
    """Test 2.5: Configuration to string."""
    print("  test_ssl_config_to_string...", end="")

    var config = SSLConfig.with_verification("/root.crt")
    var str = config.to_string()

    assert_true("SSLConfig" in str)
    assert_true("verify-ca" in str)

    print(" ✅")


# ============================================================================
# Test 3: SSL Status Tests
# ============================================================================

fn test_ssl_status_not_enabled() raises:
    """Test 3.1: SSL not enabled status."""
    print("  test_ssl_status_not_enabled...", end="")

    var status = SSLStatus.not_enabled()
    assert_false(status.enabled)
    assert_false(status.negotiated)
    assert_false(status.verified)
    assert_false(status.is_secure())

    print(" ✅")


fn test_ssl_status_negotiated() raises:
    """Test 3.2: SSL negotiated status."""
    print("  test_ssl_status_negotiated...", end="")

    var status = SSLStatus.negotiated_ssl(SSLMode.require())
    assert_true(status.enabled)
    assert_true(status.negotiated)
    assert_false(status.verified)
    assert_true(status.is_secure())

    print(" ✅")


fn test_ssl_status_verified() raises:
    """Test 3.3: SSL verified status."""
    print("  test_ssl_status_verified...", end="")

    var status = SSLStatus.verified_ssl(SSLMode.verify_ca())
    assert_true(status.enabled)
    assert_true(status.negotiated)
    assert_true(status.verified)
    assert_true(status.is_secure())

    print(" ✅")


fn test_ssl_status_to_string() raises:
    """Test 3.4: SSL status to string."""
    print("  test_ssl_status_to_string...", end="")

    var status1 = SSLStatus.not_enabled()
    var str1 = status1.to_string()
    assert_true("disabled" in str1)

    var status2 = SSLStatus.negotiated_ssl(SSLMode.require())
    var str2 = status2.to_string()
    assert_true("enabled" in str2)
    assert_true("negotiated" in str2)

    print(" ✅")


# ============================================================================
# Test 4: SSL Request/Response Protocol
# ============================================================================

fn test_build_ssl_request() raises:
    """Test 4.1: Build SSL request message."""
    print("  test_build_ssl_request...", end="")

    var request = build_ssl_request()

    # Should be 8 bytes total
    assert_equal(len(request), 8)

    # First 4 bytes should be length (8 in network byte order)
    assert_equal(request[0], 0)
    assert_equal(request[1], 0)
    assert_equal(request[2], 0)
    assert_equal(request[3], 8)

    # Next 4 bytes should be SSL request code (80877103 = 0x04D2162F)
    assert_equal(request[4], 0x04)
    assert_equal(request[5], 0xD2)
    assert_equal(request[6], 0x16)
    assert_equal(request[7], 0x2F)

    print(" ✅")


fn test_parse_ssl_response_supported() raises:
    """Test 4.2: Parse SSL supported response."""
    print("  test_parse_ssl_response_supported...", end="")

    var supported = parse_ssl_response(ord('S'))
    assert_true(supported)

    print(" ✅")


fn test_parse_ssl_response_not_supported() raises:
    """Test 4.3: Parse SSL not supported response."""
    print("  test_parse_ssl_response_not_supported...", end="")

    var not_supported = parse_ssl_response(ord('N'))
    assert_false(not_supported)

    print(" ✅")


fn test_parse_ssl_response_invalid() raises:
    """Test 4.4: Parse invalid SSL response."""
    print("  test_parse_ssl_response_invalid...", end="")

    try:
        var _ = parse_ssl_response(ord('X'))
        raise Error("Should have raised error for invalid response")
    except e:
        # Expected
        pass

    print(" ✅")


# ============================================================================
# Test 5: SSL Helper Functions
# ============================================================================

fn test_is_ssl_enabled_disable() raises:
    """Test 5.1: is_ssl_enabled for disable mode."""
    print("  test_is_ssl_enabled_disable...", end="")

    var enabled = is_ssl_enabled(SSLMode.disable())
    assert_false(enabled)

    print(" ✅")


fn test_is_ssl_enabled_require() raises:
    """Test 5.2: is_ssl_enabled for require mode."""
    print("  test_is_ssl_enabled_require...", end="")

    var enabled = is_ssl_enabled(SSLMode.require())
    assert_true(enabled)

    print(" ✅")


fn test_should_fallback_allow() raises:
    """Test 5.3: should_fallback_to_non_ssl for allow mode."""
    print("  test_should_fallback_allow...", end="")

    var can_fallback = should_fallback_to_non_ssl(SSLMode.allow())
    assert_true(can_fallback)

    print(" ✅")


fn test_should_fallback_prefer() raises:
    """Test 5.4: should_fallback_to_non_ssl for prefer mode."""
    print("  test_should_fallback_prefer...", end="")

    var can_fallback = should_fallback_to_non_ssl(SSLMode.prefer())
    assert_true(can_fallback)

    print(" ✅")


fn test_should_fallback_require() raises:
    """Test 5.5: should_fallback_to_non_ssl for require mode."""
    print("  test_should_fallback_require...", end="")

    var can_fallback = should_fallback_to_non_ssl(SSLMode.require())
    assert_false(can_fallback)

    print(" ✅")


fn test_get_ssl_error_message() raises:
    """Test 5.6: get_ssl_error_message."""
    print("  test_get_ssl_error_message...", end="")

    var msg1 = get_ssl_error_message(SSLMode.require())
    assert_true(len(msg1) > 0)
    assert_true("SSL" in msg1)

    var msg2 = get_ssl_error_message(SSLMode.verify_ca())
    assert_true(len(msg2) > 0)

    print(" ✅")


fn test_get_ssl_mode_description() raises:
    """Test 5.7: get_ssl_mode_description."""
    print("  test_get_ssl_mode_description...", end="")

    var desc_disable = get_ssl_mode_description(SSLMode.disable())
    assert_true("disable" in desc_disable)

    var desc_require = get_ssl_mode_description(SSLMode.require())
    assert_true("require" in desc_require)

    var desc_verify = get_ssl_mode_description(SSLMode.verify_full())
    assert_true("verify-full" in desc_verify)

    print(" ✅")


# ============================================================================
# Test 6: SSL Connection Info
# ============================================================================

fn test_ssl_connection_info_default() raises:
    """Test 6.1: Default SSL connection info."""
    print("  test_ssl_connection_info_default...", end="")

    var info = SSLConnectionInfo.default()
    assert_equal(info.protocol, "TLSv1.2")
    assert_equal(info.bits, 256)
    assert_false(info.compression)

    print(" ✅")


fn test_ssl_connection_info_custom() raises:
    """Test 6.2: Custom SSL connection info."""
    print("  test_ssl_connection_info_custom...", end="")

    var info = SSLConnectionInfo("TLSv1.3", "ECDHE-RSA-AES256-GCM-SHA384", False, 256)
    assert_equal(info.protocol, "TLSv1.3")
    assert_equal(info.cipher, "ECDHE-RSA-AES256-GCM-SHA384")
    assert_equal(info.bits, 256)

    print(" ✅")


fn test_ssl_connection_info_to_string() raises:
    """Test 6.3: SSL connection info to string."""
    print("  test_ssl_connection_info_to_string...", end="")

    var info = SSLConnectionInfo.default()
    var str = info.to_string()

    assert_true("Protocol" in str)
    assert_true("Cipher" in str)
    assert_true("TLSv1.2" in str)

    print(" ✅")


# ============================================================================
# Test 7: Edge Cases
# ============================================================================

fn test_ssl_config_minimal() raises:
    """Test 7.1: Minimal SSL configuration."""
    print("  test_ssl_config_minimal...", end="")

    var config = SSLConfig(SSLMode.require(), "", "", "", "")
    assert_equal(config.mode.to_string(), "require")
    assert_equal(config.cert_file, "")

    print(" ✅")


fn test_ssl_modes_all_unique() raises:
    """Test 7.2: All SSL modes are unique."""
    print("  test_ssl_modes_all_unique...", end="")

    var modes = List[String]()
    modes.append(SSLMode.disable().to_string())
    modes.append(SSLMode.allow().to_string())
    modes.append(SSLMode.prefer().to_string())
    modes.append(SSLMode.require().to_string())
    modes.append(SSLMode.verify_ca().to_string())
    modes.append(SSLMode.verify_full().to_string())

    # Check all are different
    for i in range(len(modes)):
        for j in range(i + 1, len(modes)):
            assert_true(modes[i] != modes[j])

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("SSL/TLS Infrastructure Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: SSL Mode Tests")
    test_ssl_mode_disable()
    test_ssl_mode_allow()
    test_ssl_mode_prefer()
    test_ssl_mode_require()
    test_ssl_mode_verify_ca()
    test_ssl_mode_verify_full()

    print("\nTest 2: SSL Configuration Tests")
    test_ssl_config_default()
    test_ssl_config_disabled()
    test_ssl_config_with_mode()
    test_ssl_config_with_verification()
    test_ssl_config_to_string()

    print("\nTest 3: SSL Status Tests")
    test_ssl_status_not_enabled()
    test_ssl_status_negotiated()
    test_ssl_status_verified()
    test_ssl_status_to_string()

    print("\nTest 4: SSL Request/Response Protocol")
    test_build_ssl_request()
    test_parse_ssl_response_supported()
    test_parse_ssl_response_not_supported()
    test_parse_ssl_response_invalid()

    print("\nTest 5: SSL Helper Functions")
    test_is_ssl_enabled_disable()
    test_is_ssl_enabled_require()
    test_should_fallback_allow()
    test_should_fallback_prefer()
    test_should_fallback_require()
    test_get_ssl_error_message()
    test_get_ssl_mode_description()

    print("\nTest 6: SSL Connection Info")
    test_ssl_connection_info_default()
    test_ssl_connection_info_custom()
    test_ssl_connection_info_to_string()

    print("\nTest 7: Edge Cases")
    test_ssl_config_minimal()
    test_ssl_modes_all_unique()

    print("\n" + "=" * 70)
    print("✅ All 30 tests passed!")
    print("=" * 70 + "\n")
