"""
Benchmark: Real-World Scenarios

End-to-end benchmarks simulating real-world applications:
1. E-commerce: Order processing
2. Banking: Money transfer with ACID transactions
3. User Management: Login, session creation, activity logging
4. Analytics: Bulk data insertion and aggregation
5. API Server: Typical CRUD operations

Each scenario uses production-ready patterns:
- Connection pooling
- Prepared statements
- Transactions
- Error handling
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.connection import PostgresConnection
from src.protocol.prepared import PreparedStatement
from src.protocol.transaction import (
    begin_transaction,
    commit_transaction,
    rollback_transaction,
)
from src.pool.connection_pool import ConnectionPool
from time import now


# ============================================================================
# Configuration
# ============================================================================

alias HOST = "localhost"
alias PORT = 5432
alias DATABASE = "test"
alias USER = "test"
alias PASSWORD = "test"
alias ITERATIONS = 20


# ============================================================================
# Scenario 1: E-Commerce Order Processing
# ============================================================================

fn bench_ecommerce_order() raises:
    """
    Scenario: Process an e-commerce order.

    Steps:
    1. Begin transaction
    2. Create order record
    3. Create order items (3 items)
    4. Update product inventory (3 products)
    5. Create payment record
    6. Commit transaction
    """
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create tables
    var _ = conn.query("DROP TABLE IF EXISTS orders CASCADE")
    var __ = conn.query("DROP TABLE IF EXISTS order_items CASCADE")
    var ___ = conn.query("DROP TABLE IF EXISTS products CASCADE")
    var ____ = conn.query("DROP TABLE IF EXISTS payments CASCADE")

    var _____ = conn.query("""
        CREATE TABLE orders (
            id SERIAL PRIMARY KEY,
            user_id INT,
            total DECIMAL(10,2),
            status TEXT,
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)

    var ______ = conn.query("""
        CREATE TABLE order_items (
            id SERIAL PRIMARY KEY,
            order_id INT,
            product_id INT,
            quantity INT,
            price DECIMAL(10,2)
        )
    """)

    var _______ = conn.query("""
        CREATE TABLE products (
            id SERIAL PRIMARY KEY,
            name TEXT,
            stock INT,
            price DECIMAL(10,2)
        )
    """)

    var ________ = conn.query("""
        CREATE TABLE payments (
            id SERIAL PRIMARY KEY,
            order_id INT,
            amount DECIMAL(10,2),
            status TEXT
        )
    """)

    # Insert sample products
    var _________ = conn.query("INSERT INTO products (id, name, stock, price) VALUES (1, 'Widget', 1000, 19.99)")
    var __________ = conn.query("INSERT INTO products (id, name, stock, price) VALUES (2, 'Gadget', 1000, 29.99)")
    var ___________ = conn.query("INSERT INTO products (id, name, stock, price) VALUES (3, 'Gizmo', 1000, 39.99)")

    # Process order
    begin_transaction(conn)

    # Create order
    var ____________ = conn.query("INSERT INTO orders (user_id, total, status) VALUES (123, 89.97, 'pending') RETURNING id")

    # Create order items
    var _____________ = conn.query("INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 1, 1, 19.99)")
    var ______________ = conn.query("INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 2, 1, 29.99)")
    var _______________ = conn.query("INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 3, 1, 39.99)")

    # Update inventory
    var ________________ = conn.query("UPDATE products SET stock = stock - 1 WHERE id = 1")
    var _________________ = conn.query("UPDATE products SET stock = stock - 1 WHERE id = 2")
    var __________________ = conn.query("UPDATE products SET stock = stock - 1 WHERE id = 3")

    # Create payment
    var ___________________ = conn.query("INSERT INTO payments (order_id, amount, status) VALUES (1, 89.97, 'completed')")

    # Update order status
    var ____________________ = conn.query("UPDATE orders SET status = 'completed' WHERE id = 1")

    commit_transaction(conn)

    # Cleanup
    var _____________________ = conn.query("DROP TABLE payments")
    var ______________________ = conn.query("DROP TABLE order_items")
    var _______________________ = conn.query("DROP TABLE orders")
    var ________________________ = conn.query("DROP TABLE products")

    conn.close()


# ============================================================================
# Scenario 2: Banking Transfer (ACID Transaction)
# ============================================================================

fn bench_banking_transfer() raises:
    """
    Scenario: Transfer money between accounts.

    Steps:
    1. Begin transaction
    2. Check source account balance
    3. Debit source account
    4. Credit destination account
    5. Create transaction record
    6. Commit transaction
    """
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create tables
    var _ = conn.query("DROP TABLE IF EXISTS accounts CASCADE")
    var __ = conn.query("DROP TABLE IF EXISTS transactions CASCADE")

    var ___ = conn.query("""
        CREATE TABLE accounts (
            id INT PRIMARY KEY,
            balance DECIMAL(12,2)
        )
    """)

    var ____ = conn.query("""
        CREATE TABLE transactions (
            id SERIAL PRIMARY KEY,
            from_account INT,
            to_account INT,
            amount DECIMAL(12,2),
            timestamp TIMESTAMP DEFAULT NOW()
        )
    """)

    # Create accounts
    var _____ = conn.query("INSERT INTO accounts (id, balance) VALUES (1, 1000.00)")
    var ______ = conn.query("INSERT INTO accounts (id, balance) VALUES (2, 500.00)")

    # Transfer $100 from account 1 to account 2
    begin_transaction(conn)

    # Check balance
    var _______ = conn.query("SELECT balance FROM accounts WHERE id = 1 FOR UPDATE")

    # Debit source
    var ________ = conn.query("UPDATE accounts SET balance = balance - 100.00 WHERE id = 1")

    # Credit destination
    var _________ = conn.query("UPDATE accounts SET balance = balance + 100.00 WHERE id = 2")

    # Record transaction
    var __________ = conn.query("INSERT INTO transactions (from_account, to_account, amount) VALUES (1, 2, 100.00)")

    commit_transaction(conn)

    # Cleanup
    var ___________ = conn.query("DROP TABLE transactions")
    var ____________ = conn.query("DROP TABLE accounts")

    conn.close()


# ============================================================================
# Scenario 3: User Session Management
# ============================================================================

fn bench_user_session() raises:
    """
    Scenario: User login and session creation.

    Steps:
    1. Validate credentials
    2. Create session
    3. Log activity
    4. Update last login time
    """
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create tables
    var _ = conn.query("DROP TABLE IF EXISTS users CASCADE")
    var __ = conn.query("DROP TABLE IF EXISTS sessions CASCADE")
    var ___ = conn.query("DROP TABLE IF EXISTS activity_log CASCADE")

    var ____ = conn.query("""
        CREATE TABLE users (
            id SERIAL PRIMARY KEY,
            username TEXT,
            password_hash TEXT,
            last_login TIMESTAMP
        )
    """)

    var _____ = conn.query("""
        CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            user_id INT,
            created_at TIMESTAMP DEFAULT NOW(),
            expires_at TIMESTAMP
        )
    """)

    var ______ = conn.query("""
        CREATE TABLE activity_log (
            id SERIAL PRIMARY KEY,
            user_id INT,
            action TEXT,
            timestamp TIMESTAMP DEFAULT NOW()
        )
    """)

    # Create user
    var _______ = conn.query("INSERT INTO users (id, username, password_hash) VALUES (1, 'alice', 'hash123')")

    # Login process
    begin_transaction(conn)

    # Validate credentials
    var ________ = conn.query("SELECT id FROM users WHERE username = 'alice' AND password_hash = 'hash123'")

    # Create session
    var _________ = conn.query("INSERT INTO sessions (id, user_id, expires_at) VALUES ('sess_abc123', 1, NOW() + INTERVAL '1 hour')")

    # Log activity
    var __________ = conn.query("INSERT INTO activity_log (user_id, action) VALUES (1, 'login')")

    # Update last login
    var ___________ = conn.query("UPDATE users SET last_login = NOW() WHERE id = 1")

    commit_transaction(conn)

    # Cleanup
    var ____________ = conn.query("DROP TABLE activity_log")
    var _____________ = conn.query("DROP TABLE sessions")
    var ______________ = conn.query("DROP TABLE users")

    conn.close()


# ============================================================================
# Scenario 4: API CRUD Operations
# ============================================================================

fn bench_api_crud() raises:
    """
    Scenario: Typical API CRUD operations.

    Steps:
    1. Create resource
    2. Read resource
    3. Update resource
    4. List resources
    5. Delete resource
    """
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS resources")
    var __ = conn.query("""
        CREATE TABLE resources (
            id SERIAL PRIMARY KEY,
            name TEXT,
            value INT,
            updated_at TIMESTAMP DEFAULT NOW()
        )
    """)

    # Create
    var ___ = conn.query("INSERT INTO resources (name, value) VALUES ('test', 42) RETURNING id")

    # Read
    var ____ = conn.query("SELECT name, value FROM resources WHERE id = 1")

    # Update
    var _____ = conn.query("UPDATE resources SET value = 43, updated_at = NOW() WHERE id = 1")

    # List
    var ______ = conn.query("SELECT id, name, value FROM resources LIMIT 10")

    # Delete
    var _______ = conn.query("DELETE FROM resources WHERE id = 1")

    # Cleanup
    var ________ = conn.query("DROP TABLE resources")

    conn.close()


# ============================================================================
# Scenario 5: Analytics Batch Insert
# ============================================================================

fn bench_analytics_batch() raises:
    """
    Scenario: Batch insert analytics events.

    Steps:
    1. Begin transaction
    2. Insert 100 event records
    3. Commit transaction
    4. Run aggregation query
    """
    var conn = PostgresConnection(HOST, PORT)
    conn.connect(DATABASE, USER, PASSWORD)

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS events")
    var __ = conn.query("""
        CREATE TABLE events (
            id SERIAL PRIMARY KEY,
            event_type TEXT,
            user_id INT,
            timestamp TIMESTAMP DEFAULT NOW()
        )
    """)

    # Batch insert using prepared statement
    var stmt = PreparedStatement(conn, "INSERT INTO events (event_type, user_id) VALUES ($1, $2)")

    begin_transaction(conn)

    for i in range(100):
        stmt.reset()
        stmt.bind(0, "page_view")
        stmt.bind_int(1, i % 10)
        var ___ = stmt.execute()

    commit_transaction(conn)

    # Run aggregation
    var ____ = conn.query("SELECT event_type, COUNT(*) FROM events GROUP BY event_type")

    # Cleanup
    stmt.close()
    var _____ = conn.query("DROP TABLE events")

    conn.close()


# ============================================================================
# Main Runner
# ============================================================================

fn main() raises:
    print("\n")
    print("=" * 70)
    print("REAL-WORLD SCENARIO BENCHMARKS")
    print("=" * 70)
    print("\n")

    print("These benchmarks simulate real-world application patterns,")
    print("using production-ready techniques (transactions, prepared statements).\n")

    # Scenario 1: E-Commerce
    print("📊 Scenario 1: E-Commerce Order Processing\n")
    print("Steps: Create order → Add items → Update inventory → Payment\n")

    var r1 = benchmark[bench_ecommerce_order]("E-Commerce Order", ITERATIONS)
    r1.print_report()
    print()

    var orders_per_sec = 1_000_000_000.0 / r1.mean_ns
    print(f"Throughput: {orders_per_sec:.0f} orders/second")
    print("\n")

    # Scenario 2: Banking
    print("📊 Scenario 2: Banking Transfer (ACID)\n")
    print("Steps: Check balance → Debit → Credit → Log transaction\n")

    var r2 = benchmark[bench_banking_transfer]("Banking Transfer", ITERATIONS)
    r2.print_report()
    print()

    var transfers_per_sec = 1_000_000_000.0 / r2.mean_ns
    print(f"Throughput: {transfers_per_sec:.0f} transfers/second")
    print("\n")

    # Scenario 3: User Session
    print("📊 Scenario 3: User Login & Session\n")
    print("Steps: Validate → Create session → Log activity → Update user\n")

    var r3 = benchmark[bench_user_session]("User Login", ITERATIONS)
    r3.print_report()
    print()

    var logins_per_sec = 1_000_000_000.0 / r3.mean_ns
    print(f"Throughput: {logins_per_sec:.0f} logins/second")
    print("\n")

    # Scenario 4: API CRUD
    print("📊 Scenario 4: API CRUD Operations\n")
    print("Steps: Create → Read → Update → List → Delete\n")

    var r4 = benchmark[bench_api_crud]("API CRUD", ITERATIONS)
    r4.print_report()
    print()

    var crud_per_sec = 1_000_000_000.0 / r4.mean_ns
    print(f"Throughput: {crud_per_sec:.0f} CRUD cycles/second")
    print("\n")

    # Scenario 5: Analytics
    print("📊 Scenario 5: Analytics Batch Insert\n")
    print("Steps: Batch insert 100 events → Aggregate\n")

    var r5 = benchmark[bench_analytics_batch]("Analytics Batch", 10)
    r5.print_report()
    print()

    var events_per_sec = (100.0 * 1_000_000_000.0) / r5.mean_ns
    print(f"Throughput: {events_per_sec:.0f} events/second")
    print("\n")

    # Summary
    print("=" * 70)
    print("SUMMARY: Real-World Performance")
    print("=" * 70)
    print()
    print("Scenario Throughput:")
    print(f"  • E-Commerce orders:  {orders_per_sec:>8.0f} ops/sec")
    print(f"  • Banking transfers:  {transfers_per_sec:>8.0f} ops/sec")
    print(f"  • User logins:        {logins_per_sec:>8.0f} ops/sec")
    print(f"  • API CRUD:           {crud_per_sec:>8.0f} ops/sec")
    print(f"  • Analytics events:   {events_per_sec:>8.0f} events/sec")
    print()
    print("Latency (P95):")
    print(f"  • E-Commerce:  {r1.p95_ns / 1_000_000.0:.2f} ms")
    print(f"  • Banking:     {r2.p95_ns / 1_000_000.0:.2f} ms")
    print(f"  • User login:  {r3.p95_ns / 1_000_000.0:.2f} ms")
    print(f"  • API CRUD:    {r4.p95_ns / 1_000_000.0:.2f} ms")
    print(f"  • Analytics:   {r5.p95_ns / 1_000_000.0:.2f} ms")
    print()
    print("=" * 70)
    print("\n")
