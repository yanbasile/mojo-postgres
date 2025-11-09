"""
TimescaleDB Hypertable Metadata Management

Provides structures and functions to query and cache TimescaleDB hypertable
metadata for optimization purposes.

Features:
- Hypertable metadata discovery
- Chunk information queries
- Metadata caching with TTL
- Compression status tracking
- Partition information

Usage:
    from src.timescaledb.metadata import HypertableMetadata, query_hypertable_metadata

    var metadata = query_hypertable_metadata(conn, "orderbook_data")
    print("Hypertable:", metadata.table_name)
    print("Chunks:", len(metadata.chunks))
    print("Compression:", metadata.compression_enabled)
"""

from src.protocol.connection import PostgresConnection
from collections import List, Dict
from time import now


# ============================================================================
# Data Structures
# ============================================================================

@value
struct ChunkInfo:
    """Information about a single TimescaleDB chunk."""
    var chunk_name: String
    var chunk_schema: String
    var range_start_unix: Int64  # Unix timestamp (seconds)
    var range_end_unix: Int64    # Unix timestamp (seconds)
    var is_compressed: Bool
    var row_count: Int
    var total_bytes: Int

    fn __init__(inout self):
        """Initialize empty ChunkInfo."""
        self.chunk_name = ""
        self.chunk_schema = "public"
        self.range_start_unix = 0
        self.range_end_unix = 0
        self.is_compressed = False
        self.row_count = 0
        self.total_bytes = 0

    fn __str__(self) -> String:
        """String representation."""
        return (
            "ChunkInfo(" +
            self.chunk_name + ", " +
            String(self.range_start_unix) + "-" +
            String(self.range_end_unix) + ", " +
            ("compressed" if self.is_compressed else "uncompressed") + ", " +
            String(self.row_count) + " rows)"
        )

    fn contains_timestamp(self, timestamp_unix: Int64) -> Bool:
        """Check if chunk contains the given timestamp."""
        return timestamp_unix >= self.range_start_unix and timestamp_unix < self.range_end_unix

    fn overlaps_range(self, start: Int64, end: Int64) -> Bool:
        """Check if chunk overlaps with the given time range."""
        return not (self.range_end_unix <= start or self.range_start_unix >= end)


@value
struct HypertableMetadata:
    """Metadata for a TimescaleDB hypertable."""
    var table_name: String
    var schema_name: String
    var time_column: String
    var chunk_interval_seconds: Int
    var compression_enabled: Bool
    var num_chunks: Int
    var total_size_bytes: Int
    var last_updated: Int64  # Unix timestamp when metadata was fetched

    fn __init__(inout self):
        """Initialize empty metadata."""
        self.table_name = ""
        self.schema_name = "public"
        self.time_column = "time"
        self.chunk_interval_seconds = 3600  # Default: 1 hour
        self.compression_enabled = False
        self.num_chunks = 0
        self.total_size_bytes = 0
        self.last_updated = 0

    fn __str__(self) -> String:
        """String representation."""
        return (
            "HypertableMetadata(" +
            self.schema_name + "." + self.table_name + ", " +
            "time_col=" + self.time_column + ", " +
            "chunks=" + String(self.num_chunks) + ", " +
            "interval=" + String(self.chunk_interval_seconds) + "s, " +
            ("compressed" if self.compression_enabled else "uncompressed") + ")"
        )

    fn is_stale(self, ttl_seconds: Int = 300) -> Bool:
        """Check if metadata is stale (older than TTL)."""
        var current_time = now() / 1_000_000_000  # Convert nanoseconds to seconds
        return (current_time - self.last_updated) > ttl_seconds


struct MetadataCache:
    """Cache for hypertable metadata to reduce database queries."""
    var cache: Dict[String, HypertableMetadata]
    var chunk_cache: Dict[String, List[ChunkInfo]]
    var ttl_seconds: Int

    fn __init__(inout self, ttl_seconds: Int = 300):
        """Initialize cache with TTL (default: 5 minutes)."""
        self.cache = Dict[String, HypertableMetadata]()
        self.chunk_cache = Dict[String, List[ChunkInfo]]()
        self.ttl_seconds = ttl_seconds

    fn get_metadata(self, table_name: String) -> HypertableMetadata:
        """Get cached metadata if available and not stale."""
        if table_name in self.cache:
            var metadata = self.cache[table_name]
            if not metadata.is_stale(self.ttl_seconds):
                return metadata
        return HypertableMetadata()

    fn set_metadata(inout self, table_name: String, metadata: HypertableMetadata):
        """Cache metadata for a table."""
        self.cache[table_name] = metadata

    fn get_chunks(self, table_name: String) -> List[ChunkInfo]:
        """Get cached chunk list if available."""
        if table_name in self.chunk_cache:
            return self.chunk_cache[table_name]
        return List[ChunkInfo]()

    fn set_chunks(inout self, table_name: String, chunks: List[ChunkInfo]):
        """Cache chunk list for a table."""
        self.chunk_cache[table_name] = chunks

    fn invalidate(inout self, table_name: String):
        """Invalidate cache for a table."""
        if table_name in self.cache:
            _ = self.cache.pop(table_name)
        if table_name in self.chunk_cache:
            _ = self.chunk_cache.pop(table_name)

    fn clear(inout self):
        """Clear entire cache."""
        self.cache = Dict[String, HypertableMetadata]()
        self.chunk_cache = Dict[String, List[ChunkInfo]]()


# ============================================================================
# Metadata Queries
# ============================================================================

fn query_hypertable_metadata(
    inout conn: PostgresConnection,
    table_name: String,
    schema_name: String = "public"
) raises -> HypertableMetadata:
    """
    Query TimescaleDB metadata for a hypertable.

    Args:
        conn: PostgreSQL connection
        table_name: Name of the hypertable
        schema_name: Schema name (default: public)

    Returns:
        HypertableMetadata with information about the hypertable

    Raises:
        Error if table is not a hypertable or query fails

    Example:
        var metadata = query_hypertable_metadata(conn, "orderbook_data")
        print("Chunks:", metadata.num_chunks)
    """
    var metadata = HypertableMetadata()
    metadata.table_name = table_name
    metadata.schema_name = schema_name
    metadata.last_updated = now() / 1_000_000_000

    # Query TimescaleDB metadata tables
    var query = """
        SELECT
            h.table_name,
            h.schema_name,
            d.column_name as time_column,
            d.interval_length / 1000000 as chunk_interval_seconds,
            COALESCE(c.compression_enabled, false) as compression_enabled
        FROM timescaledb_information.hypertables h
        JOIN timescaledb_information.dimensions d ON d.hypertable_name = h.table_name
        LEFT JOIN (
            SELECT hypertable_name, true as compression_enabled
            FROM timescaledb_information.compression_settings
            GROUP BY hypertable_name
        ) c ON c.hypertable_name = h.table_name
        WHERE h.table_name = '""" + table_name + """'
            AND h.schema_name = '""" + schema_name + """'
    """

    var result = conn.query(query)

    if result.row_count() == 0:
        raise Error("Table '" + schema_name + "." + table_name + "' is not a hypertable")

    # Parse result
    metadata.time_column = result.get_value(0, 2)
    var interval_str = result.get_value(0, 3)
    metadata.chunk_interval_seconds = int(interval_str) if len(interval_str) > 0 else 3600
    var compression_str = result.get_value(0, 4)
    metadata.compression_enabled = compression_str == "t" or compression_str == "true"

    # Query chunk count and total size
    var stats_query = """
        SELECT
            COUNT(*) as num_chunks,
            COALESCE(SUM(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name))), 0) as total_size
        FROM timescaledb_information.chunks
        WHERE hypertable_name = '""" + table_name + """'
            AND hypertable_schema = '""" + schema_name + """'
    """

    var stats_result = conn.query(stats_query)
    if stats_result.row_count() > 0:
        var num_chunks_str = stats_result.get_value(0, 0)
        metadata.num_chunks = int(num_chunks_str) if len(num_chunks_str) > 0 else 0
        var size_str = stats_result.get_value(0, 1)
        metadata.total_size_bytes = int(size_str) if len(size_str) > 0 else 0

    return metadata


fn query_chunk_info(
    inout conn: PostgresConnection,
    table_name: String,
    schema_name: String = "public"
) raises -> List[ChunkInfo]:
    """
    Query information about all chunks for a hypertable.

    Args:
        conn: PostgreSQL connection
        table_name: Name of the hypertable
        schema_name: Schema name (default: public)

    Returns:
        List of ChunkInfo for each chunk

    Example:
        var chunks = query_chunk_info(conn, "orderbook_data")
        for chunk in chunks:
            print(chunk[].chunk_name, chunk[].range_start_unix)
    """
    var chunks = List[ChunkInfo]()

    # Query chunk information
    var query = """
        SELECT
            c.chunk_name,
            c.chunk_schema,
            EXTRACT(EPOCH FROM c.range_start)::bigint as range_start_unix,
            EXTRACT(EPOCH FROM c.range_end)::bigint as range_end_unix,
            COALESCE(cs.compression_status = 'Compressed', false) as is_compressed,
            COALESCE(t.n_live_tup, 0) as row_count,
            pg_total_relation_size(format('%I.%I', c.chunk_schema, c.chunk_name)) as total_bytes
        FROM timescaledb_information.chunks c
        LEFT JOIN timescaledb_information.chunk_compression_settings cs
            ON cs.chunk_schema = c.chunk_schema AND cs.chunk_name = c.chunk_name
        LEFT JOIN pg_stat_user_tables t
            ON t.schemaname = c.chunk_schema AND t.relname = c.chunk_name
        WHERE c.hypertable_name = '""" + table_name + """'
            AND c.hypertable_schema = '""" + schema_name + """'
        ORDER BY c.range_start
    """

    var result = conn.query(query)

    for i in range(result.row_count()):
        var chunk = ChunkInfo()
        chunk.chunk_name = result.get_value(i, 0)
        chunk.chunk_schema = result.get_value(i, 1)

        var start_str = result.get_value(i, 2)
        chunk.range_start_unix = int(start_str) if len(start_str) > 0 else 0

        var end_str = result.get_value(i, 3)
        chunk.range_end_unix = int(end_str) if len(end_str) > 0 else 0

        var compressed_str = result.get_value(i, 4)
        chunk.is_compressed = compressed_str == "t" or compressed_str == "true"

        var row_count_str = result.get_value(i, 5)
        chunk.row_count = int(row_count_str) if len(row_count_str) > 0 else 0

        var bytes_str = result.get_value(i, 6)
        chunk.total_bytes = int(bytes_str) if len(bytes_str) > 0 else 0

        chunks.append(chunk)

    return chunks


fn find_chunks_for_time_range(
    chunks: List[ChunkInfo],
    start_unix: Int64,
    end_unix: Int64
) -> List[ChunkInfo]:
    """
    Find chunks that overlap with the given time range.

    This is used for chunk pruning - only query chunks that contain relevant data.

    Args:
        chunks: List of all chunks
        start_unix: Start of time range (Unix timestamp)
        end_unix: End of time range (Unix timestamp)

    Returns:
        List of chunks that overlap with the time range

    Example:
        var now = time.now() / 1_000_000_000
        var one_hour_ago = now - 3600
        var relevant_chunks = find_chunks_for_time_range(chunks, one_hour_ago, now)
    """
    var relevant_chunks = List[ChunkInfo]()

    for i in range(len(chunks)):
        var chunk = chunks[i]
        if chunk.overlaps_range(start_unix, end_unix):
            relevant_chunks.append(chunk)

    return relevant_chunks


fn estimate_chunk_scan_cost(chunk: ChunkInfo) -> Float64:
    """
    Estimate the cost of scanning a chunk.

    Cost is based on:
    - Number of rows (higher = more expensive)
    - Compression status (compressed = more expensive)
    - Total size (larger = more expensive)

    Returns:
        Cost estimate (higher = more expensive)
    """
    var base_cost = Float64(chunk.row_count)

    # Compressed chunks are more expensive to scan
    if chunk.is_compressed:
        base_cost *= 1.5

    # Add size-based cost (bytes / 1MB)
    var size_cost = Float64(chunk.total_bytes) / 1_000_000.0

    return base_cost + size_cost
