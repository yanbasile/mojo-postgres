"""
TimescaleDB-Aware Connection Pool

Extends the standard connection pool with TimescaleDB-specific features:
- Hypertable metadata caching
- Chunk statistics tracking
- Compression-aware connection management
- Continuous aggregate metadata

This pool automatically queries and caches TimescaleDB metadata to reduce
overhead for chunk-aware operations.

Features:
- Automatic metadata refresh
- Chunk statistics caching
- Compression info caching
- Continuous aggregate tracking
- TTL-based cache invalidation

Usage:
    from src.timescaledb.pool import TimescaleDBPool

    var pool = TimescaleDBPool("localhost", 5432, "db", "user", "pass")
    pool.set_pool_size(10, 50)
    pool.initialize()

    # Metadata is automatically cached
    var metadata = pool.get_hypertable_metadata("orderbook_data")
"""

from src.protocol.connection import PostgresConnection
from src.pool.connection_pool import ConnectionPool, PoolConfig
from src.timescaledb.metadata import (
    HypertableMetadata,
    ChunkInfo,
    MetadataCache,
    query_hypertable_metadata,
    query_chunk_info
)
from src.timescaledb.compression import CompressionInfo, query_compression_info
from src.timescaledb.continuous_aggregates import ContinuousAggregate, list_continuous_aggregates
from collections import List, Dict
from time import now


# ============================================================================
# TimescaleDB Pool
# ============================================================================

struct TimescaleDBPool:
    """
    Connection pool with TimescaleDB metadata caching.

    Extends ConnectionPool with automatic caching of:
    - Hypertable metadata (chunks, intervals, compression)
    - Compression settings and statistics
    - Continuous aggregates
    - Chunk information

    This reduces metadata queries and improves performance for
    chunk-aware operations.
    """
    var pool: ConnectionPool
    var metadata_cache: MetadataCache
    var compression_cache: Dict[String, CompressionInfo]
    var aggregate_cache: List[ContinuousAggregate]
    var cache_ttl_seconds: Int
    var last_aggregate_refresh: Int64

    fn __init__(
        inout self,
        host: String,
        port: Int,
        database: String,
        user: String,
        password: String,
        cache_ttl_seconds: Int = 300
    ):
        """
        Initialize TimescaleDB-aware connection pool.

        Args:
            host: PostgreSQL host
            port: PostgreSQL port
            database: Database name
            user: Username
            password: Password
            cache_ttl_seconds: Metadata cache TTL (default: 5 minutes)
        """
        self.pool = ConnectionPool(host, port, database, user, password)
        self.metadata_cache = MetadataCache(cache_ttl_seconds)
        self.compression_cache = Dict[String, CompressionInfo]()
        self.aggregate_cache = List[ContinuousAggregate]()
        self.cache_ttl_seconds = cache_ttl_seconds
        self.last_aggregate_refresh = 0

    fn configure(inout self, config: PoolConfig):
        """Configure the underlying connection pool."""
        self.pool.configure(config)

    fn set_pool_size(inout self, min_size: Int, max_size: Int):
        """Set connection pool size."""
        self.pool.set_pool_size(min_size, max_size)

    fn initialize(inout self) raises:
        """Initialize the connection pool."""
        self.pool.initialize()

    fn acquire(inout self) raises -> PostgresConnection:
        """Acquire a connection from the pool."""
        return self.pool.acquire()

    fn release(inout self, conn: PostgresConnection) raises:
        """Release a connection back to the pool."""
        self.pool.release(conn)

    fn close_all(inout self):
        """Close all connections in the pool."""
        self.pool.close_all()

    # ========================================================================
    # Hypertable Metadata Management
    # ========================================================================

    fn get_hypertable_metadata(
        inout self,
        table_name: String,
        schema_name: String = "public",
        force_refresh: Bool = False
    ) raises -> HypertableMetadata:
        """
        Get hypertable metadata with caching.

        Args:
            table_name: Name of the hypertable
            schema_name: Schema name (default: public)
            force_refresh: Force cache refresh (default: False)

        Returns:
            HypertableMetadata (from cache if available and fresh)

        Example:
            var metadata = pool.get_hypertable_metadata("orderbook_data")
            print("Chunks:", metadata.num_chunks)
        """
        # Check cache first
        if not force_refresh:
            var cached = self.metadata_cache.get_metadata(table_name)
            if cached.table_name != "" and not cached.is_stale(self.cache_ttl_seconds):
                return cached

        # Cache miss or stale - query database
        var conn = self.acquire()
        var metadata = query_hypertable_metadata(conn, table_name, schema_name)
        self.release(conn)

        # Update cache
        self.metadata_cache.set_metadata(table_name, metadata)

        return metadata

    fn get_chunk_info(
        inout self,
        table_name: String,
        schema_name: String = "public",
        force_refresh: Bool = False
    ) raises -> List[ChunkInfo]:
        """
        Get chunk information with caching.

        Args:
            table_name: Name of the hypertable
            schema_name: Schema name
            force_refresh: Force cache refresh

        Returns:
            List of ChunkInfo (from cache if available)

        Example:
            var chunks = pool.get_chunk_info("orderbook_data")
            print("Total chunks:", len(chunks))
        """
        # Check cache first
        if not force_refresh:
            var cached = self.metadata_cache.get_chunks(table_name)
            if len(cached) > 0:
                # Verify cache is not stale
                var metadata = self.metadata_cache.get_metadata(table_name)
                if metadata.table_name != "" and not metadata.is_stale(self.cache_ttl_seconds):
                    return cached

        # Cache miss or stale - query database
        var conn = self.acquire()
        var chunks = query_chunk_info(conn, table_name, schema_name)
        self.release(conn)

        # Update cache
        self.metadata_cache.set_chunks(table_name, chunks)

        return chunks

    fn invalidate_hypertable_cache(inout self, table_name: String):
        """
        Invalidate cached metadata for a hypertable.

        Call this after modifying the hypertable (e.g., compression, new chunks).

        Args:
            table_name: Name of the hypertable
        """
        self.metadata_cache.invalidate(table_name)

        if table_name in self.compression_cache:
            _ = self.compression_cache.pop(table_name)

    # ========================================================================
    # Compression Management
    # ========================================================================

    fn get_compression_info(
        inout self,
        table_name: String,
        schema_name: String = "public",
        force_refresh: Bool = False
    ) raises -> CompressionInfo:
        """
        Get compression information with caching.

        Args:
            table_name: Name of the hypertable
            schema_name: Schema name
            force_refresh: Force cache refresh

        Returns:
            CompressionInfo (from cache if available)

        Example:
            var info = pool.get_compression_info("orderbook_data")
            if info.compression_enabled:
                print("Compression ratio:", info.compression_ratio, "x")
        """
        # Check cache first
        if not force_refresh and table_name in self.compression_cache:
            return self.compression_cache[table_name]

        # Cache miss - query database
        var conn = self.acquire()
        var info = query_compression_info(conn, table_name, schema_name)
        self.release(conn)

        # Update cache
        self.compression_cache[table_name] = info

        return info

    # ========================================================================
    # Continuous Aggregate Management
    # ========================================================================

    fn get_continuous_aggregates(
        inout self,
        force_refresh: Bool = False
    ) raises -> List[ContinuousAggregate]:
        """
        Get list of continuous aggregates with caching.

        Args:
            force_refresh: Force cache refresh

        Returns:
            List of all continuous aggregates

        Example:
            var aggregates = pool.get_continuous_aggregates()
            for agg in aggregates:
                print(agg[].view_name)
        """
        var current_time = now() / 1_000_000_000

        # Check cache freshness
        if not force_refresh and len(self.aggregate_cache) > 0:
            var age = current_time - self.last_aggregate_refresh
            if age < self.cache_ttl_seconds:
                return self.aggregate_cache

        # Cache miss or stale - query database
        var conn = self.acquire()
        var aggregates = list_continuous_aggregates(conn)
        self.release(conn)

        # Update cache
        self.aggregate_cache = aggregates
        self.last_aggregate_refresh = current_time

        return aggregates

    # ========================================================================
    # Statistics
    # ========================================================================

    fn get_pool_stats(self) -> String:
        """
        Get pool statistics including cache statistics.

        Returns:
            String with pool and cache statistics

        Example:
            var stats = pool.get_pool_stats()
            print(stats)
        """
        var pool_stats = self.pool.get_stats()

        var stats = "TimescaleDB Pool Statistics:\n"
        stats += "  Pool: " + pool_stats.__str__() + "\n"
        stats += "  Metadata cache TTL: " + String(self.cache_ttl_seconds) + "s\n"
        stats += "  Cached hypertables: " + String(len(self.metadata_cache.cache)) + "\n"
        stats += "  Cached compression info: " + String(len(self.compression_cache)) + "\n"
        stats += "  Cached aggregates: " + String(len(self.aggregate_cache)) + "\n"

        return stats

    fn clear_all_caches(inout self):
        """
        Clear all metadata caches.

        Call this after major schema changes.
        """
        self.metadata_cache.clear()
        self.compression_cache = Dict[String, CompressionInfo]()
        self.aggregate_cache = List[ContinuousAggregate]()
        self.last_aggregate_refresh = 0


# ============================================================================
# Helper Functions
# ============================================================================

fn create_timescaledb_pool(
    host: String,
    port: Int,
    database: String,
    user: String,
    password: String,
    min_connections: Int = 5,
    max_connections: Int = 20,
    cache_ttl_seconds: Int = 300
) raises -> TimescaleDBPool:
    """
    Create and initialize a TimescaleDB pool with default settings.

    Args:
        host: PostgreSQL host
        port: PostgreSQL port
        database: Database name
        user: Username
        password: Password
        min_connections: Minimum pool size (default: 5)
        max_connections: Maximum pool size (default: 20)
        cache_ttl_seconds: Metadata cache TTL (default: 5 minutes)

    Returns:
        Initialized TimescaleDBPool

    Example:
        var pool = create_timescaledb_pool(
            "localhost", 5432, "mydb", "user", "pass",
            min_connections=10,
            max_connections=50
        )
    """
    var pool = TimescaleDBPool(host, port, database, user, password, cache_ttl_seconds)
    pool.set_pool_size(min_connections, max_connections)
    pool.initialize()

    return pool
