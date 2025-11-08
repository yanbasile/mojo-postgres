"""
PostgreSQL authentication implementation.

Supports:
- Cleartext password authentication (type 3)
- MD5 password authentication (type 5)

MD5 authentication format:
"md5" + md5(md5(password + username) + salt)
"""

from sys.ffi import external_call, DLHandle
from collections import List
from memory import UnsafePointer


# ============================================================================
# MD5 Hashing via OpenSSL
# ============================================================================

fn md5_hash(input: String) -> String:
    """
    Compute MD5 hash of input string using OpenSSL.

    Returns lowercase hexadecimal string (32 characters).
    """
    # MD5 produces 16 bytes (128 bits)
    var digest = UnsafePointer[UInt8].alloc(16)

    # Call OpenSSL MD5 function
    # unsigned char *MD5(const unsigned char *d, size_t n, unsigned char *md)
    var input_ptr = input._as_ptr()
    var input_len = len(input)

    _ = external_call["MD5", UnsafePointer[UInt8],
                     UnsafePointer[UInt8], Int, UnsafePointer[UInt8]](
        input_ptr, input_len, digest
    )

    # Convert to hex string
    var hex_chars = "0123456789abcdef"
    var result = String("")

    for i in range(16):
        var byte = digest[i]
        var high = Int(byte >> 4)
        var low = Int(byte & 0x0F)
        result += hex_chars[high]
        result += hex_chars[low]

    digest.free()
    return result


fn md5_hash_bytes(bytes: List[UInt8]) -> String:
    """Compute MD5 hash of raw bytes."""
    # Convert List[UInt8] to string for hashing
    var input = String("")
    for i in range(len(bytes)):
        input += chr(Int(bytes[i]))
    return md5_hash(input)


fn md5_password_postgres(password: String, username: String, salt: List[UInt8]) -> String:
    """
    Compute PostgreSQL MD5 password hash.

    Format: "md5" + md5(md5(password + username) + salt)

    Args:
        password: User's password
        username: PostgreSQL username
        salt: 4-byte salt from AuthenticationMD5Password message

    Returns:
        MD5 hash string starting with "md5" (35 characters total)
    """
    # Step 1: md5(password + username)
    var step1_input = password + username
    var step1_hash = md5_hash(step1_input)

    # Step 2: md5(step1_hash + salt)
    # Need to convert step1_hash to bytes and append salt
    var step2_input = List[UInt8]()

    # Add step1_hash as bytes
    for i in range(len(step1_hash)):
        step2_input.append(ord(step1_hash[i]))

    # Add salt bytes
    for i in range(len(salt)):
        step2_input.append(salt[i])

    var step2_hash = md5_hash_bytes(step2_input)

    # Step 3: Prepend "md5"
    return "md5" + step2_hash


# ============================================================================
# Authentication Type Constants
# ============================================================================

alias AUTH_OK = 0
alias AUTH_KERBEROS_V5 = 2
alias AUTH_CLEARTEXT_PASSWORD = 3
alias AUTH_MD5_PASSWORD = 5
alias AUTH_SCM_CREDENTIAL = 6
alias AUTH_GSS = 7
alias AUTH_SSPI = 9
alias AUTH_SASL = 10


fn get_auth_method_name(auth_type: Int) -> String:
    """Get human-readable name for authentication type."""
    if auth_type == AUTH_OK:
        return "AuthenticationOk"
    elif auth_type == AUTH_KERBEROS_V5:
        return "AuthenticationKerberosV5"
    elif auth_type == AUTH_CLEARTEXT_PASSWORD:
        return "AuthenticationCleartextPassword"
    elif auth_type == AUTH_MD5_PASSWORD:
        return "AuthenticationMD5Password"
    elif auth_type == AUTH_SCM_CREDENTIAL:
        return "AuthenticationSCMCredential"
    elif auth_type == AUTH_GSS:
        return "AuthenticationGSS"
    elif auth_type == AUTH_SSPI:
        return "AuthenticationSSPI"
    elif auth_type == AUTH_SASL:
        return "AuthenticationSASL"
    else:
        return "Unknown (" + String(auth_type) + ")"


fn is_auth_supported(auth_type: Int) -> Bool:
    """Check if authentication type is supported in Phase 1."""
    # We only support cleartext and MD5 in Phase 1
    return auth_type == AUTH_OK or auth_type == AUTH_CLEARTEXT_PASSWORD or auth_type == AUTH_MD5_PASSWORD
