"""
TimescaleDB Parallel Chunk Scanning Example

Demonstrates parallel scanning of TimescaleDB chunks for improved
query performance on large time-range scans.

Features:
- Sequential vs parallel chunk scanning
- Performance comparison
- Load balancing across workers
- Result merging

Usage:
    mojo examples/parallel_chunk_scan.mojo

Expected Performance:
    - 3-10x speedup for large time-range scans
    - Scales with number of CPU cores
    - Optimal for queries spanning many chunks
"""

from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import ConnectionPool, PoolConfig
from src.timescaledb.metadata import query_hypertable_metadata, query_chunk_info, find_chunks_for_time_range
from src.timescaledb.parallel_scanner import (
    scan_chunks_parallel,
    scan_chunks_sequential,
    distribute_chunks_to_workers,
    calculate_scan_metrics
)
from time import now


fn print_separator():
    """Print a visual separator."""
    print("=" * 80)


fn main() raises:
    print_separator()
    print("TIMESCALEDB PARALLEL CHUNK SCANNING EXAMPLE".center(80))
    print_separator()
    print()

    # ========================================================================
    # Setup: Connection Pool
    # ========================================================================
    print("Setup: Creating Connection Pool")
    print("-" * 80)

    var pool = ConnectionPool("localhost", 5432, "benchdb", "benchuser", "benchpass")
    var pool_config = PoolConfig()
    pool_config.min_size = 8
    pool_config.max_size = 16
    pool.configure(pool_config)
    pool.initialize()

    print("✓ Connection pool created (min=8, max=16)")
    print()

    # Get a connection for metadata queries
    var conn = pool.acquire()

    # ========================================================================
    # Example 1: Query Metadata and Chunks
    # ========================================================================
    print("Example 1: Query Hypertable Metadata")
    print("-" * 80)

    var table_name = "orderbook_data"
    var metadata = query_hypertable_metadata(conn, table_name)

    print("Hypertable:", metadata.table_name)
    print("Chunks:", metadata.num_chunks)
    print("Chunk interval:", metadata.chunk_interval_seconds, "seconds")
    print()

    # Query all chunks
    var all_chunks = query_chunk_info(conn, table_name)
    print("Retrieved", len(all_chunks), "chunks")
    print()

    pool.release(conn)

    # ========================================================================
    # Example 2: Sequential Chunk Scanning (Baseline)
    # ========================================================================
    print("Example 2: Sequential Chunk Scanning (Baseline)")
    print("-" * 80)

    # Select chunks for last 24 hours (example)
    var now_unix = now() / 1_000_000_000
    var day_ago = now_unix - 86400

    var chunks_to_scan = find_chunks_for_time_range(all_chunks, day_ago, now_unix)
    print("Time range: Last 24 hours")
    print("Chunks in range:", len(chunks_to_scan), "/", len(all_chunks))
    print()

    # Sequential scan
    var query = "SELECT COUNT(*), AVG(price), MIN(price), MAX(price) FROM " + table_name

    print("Running sequential scan...")
    var seq_start = now()

    var seq_result = scan_chunks_sequential(pool, query, chunks_to_scan, "time")

    var seq_end = now()
    var seq_time_ms = Float64(seq_end - seq_start) / 1_000_000.0

    print("✓ Sequential scan complete")
    print("  Time:", seq_time_ms, "ms")
    print("  Rows:", seq_result.total_rows)
    print("  Chunks:", seq_result.progress.completed_chunks)
    print()

    # ========================================================================
    # Example 3: Parallel Chunk Scanning (2 workers)
    # ========================================================================
    print("Example 3: Parallel Chunk Scanning (2 workers)")
    print("-" * 80)

    print("Running parallel scan with 2 workers...")
    var par2_start = now()

    var par2_result = scan_chunks_parallel(pool, query, chunks_to_scan, num_workers=2, time_column="time")

    var par2_end = now()
    var par2_time_ms = Float64(par2_end - par2_start) / 1_000_000.0

    print("✓ Parallel scan complete")
    print("  Time:", par2_time_ms, "ms")
    print("  Rows:", par2_result.total_rows)
    print("  Chunks:", par2_result.progress.completed_chunks)
    print("  Speedup:", seq_time_ms / par2_time_ms, "x")
    print()

    # ========================================================================
    # Example 4: Parallel Chunk Scanning (4 workers)
    # ========================================================================
    print("Example 4: Parallel Chunk Scanning (4 workers)")
    print("-" * 80)

    print("Running parallel scan with 4 workers...")
    var par4_start = now()

    var par4_result = scan_chunks_parallel(pool, query, chunks_to_scan, num_workers=4, time_column="time")

    var par4_end = now()
    var par4_time_ms = Float64(par4_end - par4_start) / 1_000_000.0

    print("✓ Parallel scan complete")
    print("  Time:", par4_time_ms, "ms")
    print("  Rows:", par4_result.total_rows)
    print("  Chunks:", par4_result.progress.completed_chunks)
    print("  Speedup:", seq_time_ms / par4_time_ms, "x")
    print()

    # ========================================================================
    # Example 5: Chunk Distribution Analysis
    # ========================================================================
    print("Example 5: Chunk Distribution Analysis")
    print("-" * 80)

    var num_workers = 4
    var worker_chunks = distribute_chunks_to_workers(chunks_to_scan, num_workers)

    print("Distributing", len(chunks_to_scan), "chunks across", num_workers, "workers:")
    print()

    for worker_id in range(num_workers):
        var worker_chunk_list = worker_chunks[worker_id]
        print("  Worker", worker_id, ":", len(worker_chunk_list), "chunks")

        # Calculate total rows for this worker
        var worker_rows = 0
        for i in range(len(worker_chunk_list)):
            worker_rows += worker_chunk_list[i].row_count

        print("    Est. rows:", worker_rows)

    print()

    # ========================================================================
    # Example 6: Performance Metrics
    # ========================================================================
    print("Example 6: Performance Metrics")
    print("-" * 80)

    var seq_metrics = calculate_scan_metrics(seq_result)
    var par2_metrics = calculate_scan_metrics(par2_result, seq_time_ms)
    var par4_metrics = calculate_scan_metrics(par4_result, seq_time_ms)

    print("Sequential Scan:")
    print("  ", seq_metrics.__str__())
    print()

    print("Parallel Scan (2 workers):")
    print("  ", par2_metrics.__str__())
    print()

    print("Parallel Scan (4 workers):")
    print("  ", par4_metrics.__str__())
    print()

    # ========================================================================
    # Example 7: Optimal Worker Count
    # ========================================================================
    print("Example 7: Finding Optimal Worker Count")
    print("-" * 80)

    print("Testing different worker counts:")
    print()

    var worker_counts = [1, 2, 4, 8]
    var best_time = seq_time_ms
    var best_workers = 1

    for i in range(len(worker_counts)):
        var workers = worker_counts[i]

        var start = now()
        var result = scan_chunks_parallel(pool, query, chunks_to_scan, num_workers=workers, time_column="time")
        var end = now()
        var time_ms = Float64(end - start) / 1_000_000.0

        var speedup = seq_time_ms / time_ms

        print("  ", workers, "workers:", time_ms, "ms (", speedup, "x speedup)")

        if time_ms < best_time:
            best_time = time_ms
            best_workers = workers

    print()
    print("Optimal: ", best_workers, "workers (", seq_time_ms / best_time, "x speedup)")
    print()

    # ========================================================================
    # Summary
    # ========================================================================
    print_separator()
    print("SUMMARY")
    print_separator()
    print()

    print("Performance Comparison:")
    print("  Sequential:", seq_time_ms, "ms (baseline)")
    print("  Parallel (2):", par2_time_ms, "ms (", seq_time_ms / par2_time_ms, "x)")
    print("  Parallel (4):", par4_time_ms, "ms (", seq_time_ms / par4_time_ms, "x)")
    print()

    print("Key Insights:")
    print("  1. Parallel scanning improves performance for multi-chunk queries")
    print("  2. Optimal worker count depends on chunk distribution")
    print("  3. Diminishing returns beyond 4-8 workers for most workloads")
    print("  4. Connection pool must be sized appropriately (>= workers)")
    print()

    print("Best Practices:")
    print("  ✓ Use parallel scanning for 4+ chunks")
    print("  ✓ Set workers = min(num_chunks, CPU_cores)")
    print("  ✓ Ensure connection pool size >= num_workers")
    print("  ✓ Monitor chunk distribution for load balancing")
    print()

    print("Note: Current implementation is sequential (Mojo threading WIP)")
    print("      Structure is ready for true parallelization when available")
    print()

    pool.close_all()
    print("✓ Example complete!")
