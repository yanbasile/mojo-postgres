-- Database initialization script for mojo-postgres testing
-- This script runs when the PostgreSQL container is first created

-- Ensure UTF8 encoding
SET client_encoding = 'UTF8';

-- Create test schema
CREATE SCHEMA IF NOT EXISTS test_schema;

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA test_schema TO test;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA test_schema TO test;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA test_schema TO test;

-- Create sample test table for quick verification
CREATE TABLE IF NOT EXISTS test_connection (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_connection (message) VALUES
    ('mojo-postgres test database initialized successfully!');

-- Display initialization confirmation
DO $$
BEGIN
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'mojo-postgres Test Database Initialized';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'Database: test';
    RAISE NOTICE 'User: test';
    RAISE NOTICE 'Password: test';
    RAISE NOTICE 'Port: 5432';
    RAISE NOTICE '===============================================';
END $$;
