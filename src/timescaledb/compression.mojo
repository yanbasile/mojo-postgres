"""
TimescaleDB Compression Support

Provides utilities for working with TimescaleDB compression features:
- Detecting compressed chunks
- Querying compression settings
- Compression-aware query optimization
- Compression statistics

TimescaleDB compression uses dictionary encoding and other techniques to
achieve 50-90% storage reduction while maintaining query performance.

Features:
- Compression info queries
- Compressed chunk detection
- Compression statistics
- Query optimization for compressed data

Usage:
    from src.timescaledb.compression import query_compression_info, get_compression_stats

    var info = query_compression_info(conn, "orderbook_data")
    if info.compression_enabled:
        print("Compression:", info.compression_ratio, "x")
"""

from src.protocol.connection import PostgresConnection
from src.timescaledb.metadata import HypertableMetadata, ChunkInfo
from collections import List


# ============================================================================
# Data Structures
# ============================================================================

@value
struct CompressionInfo:
    """Information about hypertable compression settings."""
    var table_name: String
    var compression_enabled: Bool
    var segmentby_columns: List[String]  # Columns used for segmentation
    var orderby_columns: List[String]    # Columns used for ordering
    var compressed_chunks: Int
    var uncompressed_chunks: Int
    var total_chunks: Int
    var compression_ratio: Float64       # Actual compression ratio achieved

    fn __init__(inout self):
        """Initialize empty compression info."""
        self.table_name = ""
        self.compression_enabled = False
        self.segmentby_columns = List[String]()
        self.orderby_columns = List[String]()
        self.compressed_chunks = 0
        self.uncompressed_chunks = 0
        self.total_chunks = 0
        self.compression_ratio = 1.0

    fn __str__(self) -> String:
        """String representation."""
        return (
            "CompressionInfo(" +
            self.table_name + ", " +
            ("enabled" if self.compression_enabled else "disabled") + ", " +
            String(self.compressed_chunks) + "/" + String(self.total_chunks) + " compressed, " +
            String(self.compression_ratio) + "x ratio)"
        )


@value
struct CompressionStats:
    """Statistics about compression effectiveness."""
    var uncompressed_size_bytes: Int64
    var compressed_size_bytes: Int64
    var compression_ratio: Float64
    var storage_saved_bytes: Int64
    var storage_saved_percent: Float64

    fn __init__(inout self):
        """Initialize empty stats."""
        self.uncompressed_size_bytes = 0
        self.compressed_size_bytes = 0
        self.compression_ratio = 1.0
        self.storage_saved_bytes = 0
        self.storage_saved_percent = 0.0

    fn __str__(self) -> String:
        """String representation."""
        return (
            "CompressionStats(" +
            String(self.compression_ratio) + "x ratio, " +
            String(self.storage_saved_percent) + "% saved, " +
            String(self.storage_saved_bytes) + " bytes saved)"
        )


# ============================================================================
# Compression Queries
# ============================================================================

fn query_compression_info(
    inout conn: PostgresConnection,
    table_name: String,
    schema_name: String = "public"
) raises -> CompressionInfo:
    """
    Query compression information for a hypertable.

    Args:
        conn: PostgreSQL connection
        table_name: Name of the hypertable
        schema_name: Schema name (default: public)

    Returns:
        CompressionInfo with compression settings and statistics

    Example:
        var info = query_compression_info(conn, "orderbook_data")
        if info.compression_enabled:
            print("Compression ratio:", info.compression_ratio, "x")
    """
    var info = CompressionInfo()
    info.table_name = table_name

    # Query compression settings
    var settings_query = """
        SELECT
            attname,
            segmentby_column_index,
            orderby_column_index
        FROM timescaledb_information.compression_settings
        WHERE hypertable_schema = '""" + schema_name + """'
            AND hypertable_name = '""" + table_name + """'
        ORDER BY attname
    """

    try:
        var settings_result = conn.query(settings_query)

        if settings_result.row_count() > 0:
            info.compression_enabled = True

            # Parse segmentby and orderby columns
            for i in range(settings_result.row_count()):
                var col_name = settings_result.get_value(i, 0)
                var segmentby = settings_result.get_value(i, 1)
                var orderby = settings_result.get_value(i, 2)

                if len(segmentby) > 0 and segmentby != "":
                    info.segmentby_columns.append(col_name)

                if len(orderby) > 0 and orderby != "":
                    info.orderby_columns.append(col_name)

    except:
        # Compression not configured
        info.compression_enabled = False

    # Query chunk compression statistics
    var chunks_query = """
        SELECT
            COUNT(*) FILTER (WHERE compression_status = 'Compressed') as compressed,
            COUNT(*) FILTER (WHERE compression_status = 'Uncompressed') as uncompressed,
            COUNT(*) as total
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = '""" + schema_name + """'
            AND hypertable_name = '""" + table_name + """'
    """

    var chunks_result = conn.query(chunks_query)
    if chunks_result.row_count() > 0:
        var compressed_str = chunks_result.get_value(0, 0)
        info.compressed_chunks = int(compressed_str) if len(compressed_str) > 0 else 0

        var uncompressed_str = chunks_result.get_value(0, 1)
        info.uncompressed_chunks = int(uncompressed_str) if len(uncompressed_str) > 0 else 0

        var total_str = chunks_result.get_value(0, 2)
        info.total_chunks = int(total_str) if len(total_str) > 0 else 0

    # Calculate compression ratio
    var stats = get_compression_stats(conn, table_name, schema_name)
    info.compression_ratio = stats.compression_ratio

    return info


fn get_compression_stats(
    inout conn: PostgresConnection,
    table_name: String,
    schema_name: String = "public"
) raises -> CompressionStats:
    """
    Get compression statistics for a hypertable.

    Args:
        conn: PostgreSQL connection
        table_name: Name of the hypertable
        schema_name: Schema name

    Returns:
        CompressionStats with size and ratio information

    Example:
        var stats = get_compression_stats(conn, "orderbook_data")
        print("Saved", stats.storage_saved_percent, "% storage")
    """
    var stats = CompressionStats()

    # Query size statistics
    var size_query = """
        SELECT
            before_compression_total_bytes,
            after_compression_total_bytes
        FROM timescaledb_information.hypertable_compression_stats
        WHERE hypertable_schema = '""" + schema_name + """'
            AND hypertable_name = '""" + table_name + """'
    """

    try:
        var result = conn.query(size_query)

        if result.row_count() > 0:
            var before_str = result.get_value(0, 0)
            stats.uncompressed_size_bytes = int(before_str) if len(before_str) > 0 else 0

            var after_str = result.get_value(0, 1)
            stats.compressed_size_bytes = int(after_str) if len(after_str) > 0 else 0

            # Calculate ratio and savings
            if stats.compressed_size_bytes > 0:
                stats.compression_ratio = Float64(stats.uncompressed_size_bytes) / Float64(stats.compressed_size_bytes)
                stats.storage_saved_bytes = stats.uncompressed_size_bytes - stats.compressed_size_bytes
                stats.storage_saved_percent = (Float64(stats.storage_saved_bytes) / Float64(stats.uncompressed_size_bytes)) * 100.0

    except:
        # No compression stats available
        pass

    return stats


fn get_compressed_chunks(chunks: List[ChunkInfo]) -> List[ChunkInfo]:
    """
    Filter list of chunks to only compressed ones.

    Args:
        chunks: List of all chunks

    Returns:
        List of only compressed chunks

    Example:
        var compressed = get_compressed_chunks(all_chunks)
        print("Compressed chunks:", len(compressed))
    """
    var compressed = List[ChunkInfo]()

    for i in range(len(chunks)):
        var chunk = chunks[i]
        if chunk.is_compressed:
            compressed.append(chunk)

    return compressed


# ============================================================================
# Compression Operations
# ============================================================================

fn enable_compression(
    inout conn: PostgresConnection,
    table_name: String,
    segmentby: String = "",
    orderby: String = "time DESC",
    schema_name: String = "public"
) raises:
    """
    Enable compression on a hypertable.

    Args:
        conn: PostgreSQL connection
        table_name: Name of the hypertable
        segmentby: Comma-separated list of segment-by columns (e.g., "symbol")
        orderby: ORDER BY clause for compression (default: "time DESC")
        schema_name: Schema name

    Example:
        enable_compression(conn, "orderbook_data", segmentby="symbol", orderby="time DESC")
    """
    var alter_query = "ALTER TABLE " + schema_name + "." + table_name + " SET ("

    # Build compression options
    var options = "timescaledb.compress"

    if len(segmentby) > 0:
        options += ", timescaledb.compress_segmentby = '" + segmentby + "'"

    if len(orderby) > 0:
        options += ", timescaledb.compress_orderby = '" + orderby + "'"

    alter_query += options + ")"

    _ = conn.query(alter_query)


fn compress_chunk(
    inout conn: PostgresConnection,
    chunk_name: String,
    schema_name: String = "_timescaledb_internal"
) raises:
    """
    Compress a specific chunk.

    Args:
        conn: PostgreSQL connection
        chunk_name: Name of the chunk (e.g., "_hyper_1_2_chunk")
        schema_name: Schema of the chunk (usually _timescaledb_internal)

    Example:
        compress_chunk(conn, "_hyper_1_2_chunk")
    """
    var compress_query = "SELECT compress_chunk('" + schema_name + "." + chunk_name + "')"
    _ = conn.query(compress_query)


fn compress_old_chunks(
    inout conn: PostgresConnection,
    table_name: String,
    older_than_interval: String = "7 days",
    schema_name: String = "public"
) raises -> Int:
    """
    Compress all chunks older than a specified interval.

    Args:
        conn: PostgreSQL connection
        table_name: Name of the hypertable
        older_than_interval: PostgreSQL interval (e.g., "7 days", "1 month")
        schema_name: Schema name

    Returns:
        Number of chunks compressed

    Example:
        var num_compressed = compress_old_chunks(conn, "orderbook_data", "7 days")
        print("Compressed", num_compressed, "chunks")
    """
    var compress_query = """
        SELECT count(compress_chunk(i))
        FROM show_chunks('""" + schema_name + "." + table_name + """', older_than => INTERVAL '""" + older_than_interval + """') i
    """

    var result = conn.query(compress_query)

    if result.row_count() > 0:
        var count_str = result.get_value(0, 0)
        return int(count_str) if len(count_str) > 0 else 0

    return 0


fn decompress_chunk(
    inout conn: PostgresConnection,
    chunk_name: String,
    schema_name: String = "_timescaledb_internal"
) raises:
    """
    Decompress a specific chunk.

    Args:
        conn: PostgreSQL connection
        chunk_name: Name of the chunk
        schema_name: Schema of the chunk

    Example:
        decompress_chunk(conn, "_hyper_1_2_chunk")
    """
    var decompress_query = "SELECT decompress_chunk('" + schema_name + "." + chunk_name + "')"
    _ = conn.query(decompress_query)


# ============================================================================
# Compression-Aware Query Optimization
# ============================================================================

fn should_use_compression_optimization(info: CompressionInfo) -> Bool:
    """
    Determine if compression-aware optimization should be used.

    Args:
        info: Compression info for the hypertable

    Returns:
        True if optimization is beneficial

    Criteria:
        - Compression is enabled
        - At least 50% of chunks are compressed
        - Has segmentby or orderby columns
    """
    if not info.compression_enabled:
        return False

    if info.total_chunks == 0:
        return False

    var compression_pct = Float64(info.compressed_chunks) / Float64(info.total_chunks)
    if compression_pct < 0.5:
        return False

    return len(info.segmentby_columns) > 0 or len(info.orderby_columns) > 0


fn optimize_query_for_compression(
    query: String,
    info: CompressionInfo
) -> String:
    """
    Optimize query for compressed data.

    For compressed data:
    - Use segmentby columns in WHERE clauses
    - Order by orderby columns for better performance
    - Avoid decompression where possible

    Args:
        query: Original SQL query
        info: Compression info

    Returns:
        Optimized query

    Note:
        This is a simplified optimizer. Full implementation would:
        - Parse query AST
        - Add hints for segmentby column filters
        - Reorder JOINs to leverage compression
        - Add appropriate ORDER BY clauses
    """
    if not should_use_compression_optimization(info):
        return query

    # For now, return original query
    # Full implementation would rewrite based on compression settings
    # Example optimizations:
    # - Add segmentby column to WHERE if not present
    # - Add ORDER BY for orderby columns
    # - Use chunk-specific queries for compressed chunks

    return query


fn estimate_compression_benefit(
    uncompressed_size: Int,
    compression_ratio: Float64
) -> Int:
    """
    Estimate storage benefit from compression.

    Args:
        uncompressed_size: Size before compression (bytes)
        compression_ratio: Expected compression ratio (e.g., 3.0 for 3x)

    Returns:
        Estimated bytes saved

    Example:
        var benefit = estimate_compression_benefit(1_000_000_000, 5.0)
        print("Will save approximately", benefit, "bytes")
    """
    var compressed_size = Float64(uncompressed_size) / compression_ratio
    return uncompressed_size - int(compressed_size)
