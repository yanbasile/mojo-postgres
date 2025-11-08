"""
Advanced Transaction Management Examples.

Demonstrates transaction features including savepoints, isolation levels,
and read-only transactions.

Features:
- BEGIN, COMMIT, ROLLBACK
- SAVEPOINT for partial rollback
- Transaction isolation levels
- Read-only transactions
- Nested transactions
- Error handling

Examples:
1. Basic transactions
2. Savepoints for partial rollback
3. Isolation levels
4. Read-only transactions
5. Nested transactions
6. Error handling and rollback
7. Banking transfer example

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'
"""

from src.protocol.connection import PostgresConnection
from src.protocol.transaction import (
    begin_transaction,
    commit_transaction,
    rollback_transaction,
    create_savepoint,
    rollback_to_savepoint,
    release_savepoint,
    begin_read_only_transaction,
    begin_transaction_with_isolation,
)


fn example1_basic_transactions() raises:
    """Example 1: Basic transaction operations."""
    print("=" * 70)
    print("Example 1: Basic Transactions")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    print("\n📝 Creating test table...")
    var _ = conn.query("DROP TABLE IF EXISTS accounts")
    var __ = conn.query("""
        CREATE TABLE accounts (
            id SERIAL PRIMARY KEY,
            name TEXT,
            balance DECIMAL(10,2)
        )
    """)

    # Insert test data
    var ___ = conn.query("INSERT INTO accounts (name, balance) VALUES ('Alice', 1000.00)")
    var ____ = conn.query("INSERT INTO accounts (name, balance) VALUES ('Bob', 500.00)")
    print("✅ Table created with test data")

    # Transaction example
    print("\n1️⃣  Successful transaction:")
    begin_transaction(conn)
    print("   Transaction started")

    var _____ = conn.query("UPDATE accounts SET balance = balance - 100 WHERE name = 'Alice'")
    print("   Deducted $100 from Alice")

    var ______ = conn.query("UPDATE accounts SET balance = balance + 100 WHERE name = 'Bob'")
    print("   Added $100 to Bob")

    commit_transaction(conn)
    print("   Transaction committed")

    # Check balances
    var result = conn.query("SELECT name, balance FROM accounts ORDER BY name")
    for row in range(result.row_count()):
        var name = result.get_string(row, 0)
        var balance = result.get_string(row, 1)
        print(f"   {name}: ${balance}")

    # Cleanup
    var _______ = conn.query("DROP TABLE accounts")

    conn.close()
    print("\n✅ Example 1 complete!\n")


fn example2_savepoints() raises:
    """Example 2: Savepoints for partial rollback."""
    print("=" * 70)
    print("Example 2: Savepoints")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    print("\n📝 Creating test table...")
    var _ = conn.query("DROP TABLE IF EXISTS users")
    var __ = conn.query("""
        CREATE TABLE users (
            id SERIAL PRIMARY KEY,
            name TEXT
        )
    """)

    print("\n🔖 Using savepoints:")

    # Start transaction
    begin_transaction(conn)
    print("   Transaction started")

    # Insert first user
    var ___ = conn.query("INSERT INTO users (name) VALUES ('Alice')")
    print("   Inserted Alice")

    # Create savepoint
    create_savepoint(conn, "sp1")
    print("   Created savepoint 'sp1'")

    # Insert second user
    var ____ = conn.query("INSERT INTO users (name) VALUES ('Bob')")
    print("   Inserted Bob")

    # Rollback to savepoint (removes Bob, keeps Alice)
    rollback_to_savepoint(conn, "sp1")
    print("   Rolled back to 'sp1' (Bob removed, Alice kept)")

    # Insert third user
    var _____ = conn.query("INSERT INTO users (name) VALUES ('Charlie')")
    print("   Inserted Charlie")

    # Commit transaction
    commit_transaction(conn)
    print("   Transaction committed")

    # Check results
    print("\n   Users in table:")
    var result = conn.query("SELECT name FROM users ORDER BY id")
    for row in range(result.row_count()):
        print(f"   - {result.get_string(row, 0)}")

    # Cleanup
    var ______ = conn.query("DROP TABLE users")

    conn.close()
    print("\n✅ Example 2 complete!\n")


fn example3_isolation_levels() raises:
    """Example 3: Transaction isolation levels."""
    print("=" * 70)
    print("Example 3: Isolation Levels")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    print("\n🔒 Transaction isolation levels:\n")

    # READ COMMITTED (default)
    print("1️⃣  READ COMMITTED (default):")
    print("   - Sees only committed changes")
    print("   - Prevents dirty reads")
    begin_transaction_with_isolation(conn, "READ COMMITTED")
    print("   Transaction started with READ COMMITTED")
    commit_transaction(conn)

    # REPEATABLE READ
    print("\n2️⃣  REPEATABLE READ:")
    print("   - Consistent snapshot")
    print("   - Prevents non-repeatable reads")
    begin_transaction_with_isolation(conn, "REPEATABLE READ")
    print("   Transaction started with REPEATABLE READ")
    commit_transaction(conn)

    # SERIALIZABLE
    print("\n3️⃣  SERIALIZABLE:")
    print("   - Highest isolation")
    print("   - Fully serialized execution")
    begin_transaction_with_isolation(conn, "SERIALIZABLE")
    print("   Transaction started with SERIALIZABLE")
    commit_transaction(conn)

    conn.close()
    print("\n✅ Example 3 complete!\n")


fn example4_read_only_transactions() raises:
    """Example 4: Read-only transactions."""
    print("=" * 70)
    print("Example 4: Read-Only Transactions")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test data
    print("\n📝 Creating test data...")
    var _ = conn.query("DROP TABLE IF EXISTS products")
    var __ = conn.query("""
        CREATE TABLE products (
            id SERIAL PRIMARY KEY,
            name TEXT,
            price DECIMAL(10,2)
        )
    """)
    var ___ = conn.query("INSERT INTO products (name, price) VALUES ('Widget', 19.99)")
    var ____ = conn.query("INSERT INTO products (name, price) VALUES ('Gadget', 29.99)")
    print("✅ Test data created")

    print("\n📖 Read-only transaction:")
    begin_read_only_transaction(conn)
    print("   Read-only transaction started")

    # Read data
    var result = conn.query("SELECT name, price FROM products")
    print(f"   Read {result.row_count()} products:")
    for row in range(result.row_count()):
        var name = result.get_string(row, 0)
        var price = result.get_string(row, 1)
        print(f"   - {name}: ${price}")

    commit_transaction(conn)
    print("   Transaction committed")

    print("\n💡 Benefits of read-only transactions:")
    print("   - More efficient (no transaction log writes)")
    print("   - Can't accidentally modify data")
    print("   - Good for long-running analytical queries")

    # Cleanup
    var _____ = conn.query("DROP TABLE products")

    conn.close()
    print("\n✅ Example 4 complete!\n")


fn example5_nested_transactions() raises:
    """Example 5: Nested transactions with savepoints."""
    print("=" * 70)
    print("Example 5: Nested Transactions")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    print("\n📝 Creating test table...")
    var _ = conn.query("DROP TABLE IF EXISTS logs")
    var __ = conn.query("""
        CREATE TABLE logs (
            id SERIAL PRIMARY KEY,
            message TEXT,
            level TEXT
        )
    """)

    print("\n🪆 Nested transactions:")

    # Outer transaction
    begin_transaction(conn)
    print("   Outer transaction started")

    var ___ = conn.query("INSERT INTO logs (message, level) VALUES ('System started', 'INFO')")
    print("   Logged: System started")

    # Inner transaction (savepoint)
    create_savepoint(conn, "inner1")
    print("   Inner transaction 1 started (savepoint)")

    var ____ = conn.query("INSERT INTO logs (message, level) VALUES ('Module A loaded', 'INFO')")
    print("   Logged: Module A loaded")

    # Nested inner transaction
    create_savepoint(conn, "inner2")
    print("   Inner transaction 2 started (savepoint)")

    var _____ = conn.query("INSERT INTO logs (message, level) VALUES ('Module B failed', 'ERROR')")
    print("   Logged: Module B failed")

    # Rollback inner2
    rollback_to_savepoint(conn, "inner2")
    print("   Rolled back inner transaction 2")

    # Commit inner1
    release_savepoint(conn, "inner1")
    print("   Committed inner transaction 1")

    # Commit outer
    commit_transaction(conn)
    print("   Committed outer transaction")

    # Check results
    print("\n   Logs in table:")
    var result = conn.query("SELECT message, level FROM logs ORDER BY id")
    for row in range(result.row_count()):
        print(f"   - [{result.get_string(row, 1)}] {result.get_string(row, 0)}")

    # Cleanup
    var ______ = conn.query("DROP TABLE logs")

    conn.close()
    print("\n✅ Example 5 complete!\n")


fn example6_error_handling() raises:
    """Example 6: Error handling and rollback."""
    print("=" * 70)
    print("Example 6: Error Handling")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create test table
    print("\n📝 Creating test table...")
    var _ = conn.query("DROP TABLE IF EXISTS inventory")
    var __ = conn.query("""
        CREATE TABLE inventory (
            id SERIAL PRIMARY KEY,
            product TEXT,
            quantity INT CHECK (quantity >= 0)
        )
    """)
    var ___ = conn.query("INSERT INTO inventory (product, quantity) VALUES ('Widget', 100)")
    print("✅ Table created with Widget (quantity: 100)")

    print("\n❌ Transaction with error:")

    begin_transaction(conn)
    print("   Transaction started")

    try:
        var ____ = conn.query("UPDATE inventory SET quantity = quantity - 50 WHERE product = 'Widget'")
        print("   Reduced quantity by 50 (now 50)")

        # This will violate CHECK constraint (quantity >= 0)
        var _____ = conn.query("UPDATE inventory SET quantity = quantity - 100 WHERE product = 'Widget'")
        print("   Attempted to reduce by 100 (would be -50)")

        commit_transaction(conn)
    except e:
        print(f"   Error occurred: {str(e)}")
        rollback_transaction(conn)
        print("   Transaction rolled back")

    # Check final state
    var result = conn.query("SELECT product, quantity FROM inventory")
    var product = result.get_string(0, 0)
    var quantity = result.get_int32(0, 1)
    print(f"\n   Final state: {product} = {quantity}")
    print("   (Rollback prevented invalid state)")

    # Cleanup
    var ______ = conn.query("DROP TABLE inventory")

    conn.close()
    print("\n✅ Example 6 complete!\n")


fn example7_banking_transfer() raises:
    """Example 7: Real-world banking transfer example."""
    print("=" * 70)
    print("Example 7: Banking Transfer (Real-World Example)")
    print("=" * 70)

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create accounts table
    print("\n📝 Setting up bank accounts...")
    var _ = conn.query("DROP TABLE IF EXISTS bank_accounts")
    var __ = conn.query("""
        CREATE TABLE bank_accounts (
            id SERIAL PRIMARY KEY,
            account_number TEXT UNIQUE,
            owner TEXT,
            balance DECIMAL(12,2) CHECK (balance >= 0)
        )
    """)

    var ___ = conn.query("INSERT INTO bank_accounts (account_number, owner, balance) VALUES ('ACC001', 'Alice', 5000.00)")
    var ____ = conn.query("INSERT INTO bank_accounts (account_number, owner, balance) VALUES ('ACC002', 'Bob', 3000.00)")
    print("✅ Accounts created")

    # Show initial balances
    print("\n💰 Initial balances:")
    var result1 = conn.query("SELECT owner, balance FROM bank_accounts ORDER BY owner")
    for row in range(result1.row_count()):
        print(f"   {result1.get_string(row, 0)}: ${result1.get_string(row, 1)}")

    # Perform transfer
    print("\n💸 Transferring $1,500 from Alice to Bob:")

    begin_transaction_with_isolation(conn, "SERIALIZABLE")
    print("   Transaction started (SERIALIZABLE)")

    try:
        # Debit from Alice
        var _____ = conn.query("UPDATE bank_accounts SET balance = balance - 1500.00 WHERE account_number = 'ACC001'")
        print("   Debited $1,500 from Alice")

        # Credit to Bob
        var ______ = conn.query("UPDATE bank_accounts SET balance = balance + 1500.00 WHERE account_number = 'ACC002'")
        print("   Credited $1,500 to Bob")

        # Verify transfer
        var result2 = conn.query("SELECT SUM(balance) FROM bank_accounts")
        var total = result2.get_string(0, 0)
        print(f"   Verified total balance: ${total}")

        commit_transaction(conn)
        print("   Transaction committed")
    except e:
        print(f"   Error: {str(e)}")
        rollback_transaction(conn)
        print("   Transaction rolled back")
        raise

    # Show final balances
    print("\n💰 Final balances:")
    var result3 = conn.query("SELECT owner, balance FROM bank_accounts ORDER BY owner")
    for row in range(result3.row_count()):
        print(f"   {result3.get_string(row, 0)}: ${result3.get_string(row, 1)}")

    # Cleanup
    var _______ = conn.query("DROP TABLE bank_accounts")

    conn.close()
    print("\n✅ Example 7 complete!\n")


fn main() raises:
    print("\n")
    print("🔥 Advanced Transaction Management Examples")
    print("ACID Transactions for Data Integrity")
    print("\n")

    # Run examples
    example1_basic_transactions()
    example2_savepoints()
    example3_isolation_levels()
    example4_read_only_transactions()
    example5_nested_transactions()
    example6_error_handling()
    example7_banking_transfer()

    print("=" * 70)
    print("🎉 All examples completed successfully!")
    print("=" * 70)
    print("\n💡 Key Takeaways:")
    print("   - Transactions ensure ACID properties")
    print("   - Savepoints allow partial rollback")
    print("   - Isolation levels control concurrency")
    print("   - Always handle errors with rollback")
    print("   - Use appropriate isolation for your use case")
    print("\n💡 Best Practices:")
    print("   - Keep transactions short")
    print("   - Use lowest isolation level that works")
    print("   - Always handle errors gracefully")
    print("   - Use savepoints for complex operations")
    print("   - Test concurrency scenarios")
    print("\n💡 Isolation Levels Guide:")
    print("   - READ COMMITTED: Default, good for most cases")
    print("   - REPEATABLE READ: For consistent reads")
    print("   - SERIALIZABLE: For critical operations (banking)")
    print("\n")
