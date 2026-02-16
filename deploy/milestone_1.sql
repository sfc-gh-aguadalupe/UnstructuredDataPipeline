/*
=============================================================================
MILESTONE 1: Database & Stage Setup
=============================================================================
Creates:
- Database and schemas
- Warehouse
- External stage (S3) with directory table
- Internal stage with directory table
- Ingestion sources configuration table
=============================================================================
*/

-- Load configuration
!source ../config/settings.sql

-- =============================================================================
-- CREATE DATABASE
-- =============================================================================
CREATE DATABASE IF NOT EXISTS IDENTIFIER($database_name);
USE DATABASE IDENTIFIER($database_name);

-- =============================================================================
-- CREATE SCHEMAS
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($schema_raw);
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($schema_processed);
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($schema_semantic);
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($schema_analytics);

-- =============================================================================
-- CREATE WAREHOUSE
-- =============================================================================
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($warehouse_name)
    WAREHOUSE_SIZE = $warehouse_size
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- =============================================================================
-- CREATE EXTERNAL STAGE (S3)
-- Uncomment and modify if using S3 external stage
-- =============================================================================
/*
CREATE OR REPLACE STAGE IDENTIFIER($schema_raw || '.S3_DOCUMENTS_STAGE')
    URL = $s3_bucket_url
    STORAGE_INTEGRATION = IDENTIFIER($storage_integration_name)
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'External stage for S3 document ingestion';

-- Refresh directory table
ALTER STAGE IDENTIFIER($schema_raw || '.S3_DOCUMENTS_STAGE') REFRESH;
*/

-- =============================================================================
-- CREATE INTERNAL STAGE
-- =============================================================================
USE SCHEMA IDENTIFIER($schema_raw);

CREATE OR REPLACE STAGE INTERNAL_DOCUMENTS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for manual document uploads';

-- =============================================================================
-- CREATE INGESTION SOURCES CONFIGURATION TABLE
-- =============================================================================
CREATE OR REPLACE TABLE RAW.INGESTION_SOURCES (
    source_id INT AUTOINCREMENT PRIMARY KEY,
    source_name VARCHAR(255) NOT NULL UNIQUE,
    source_type VARCHAR(50) NOT NULL,           -- 'EXTERNAL' or 'INTERNAL'
    stage_path VARCHAR(500) NOT NULL,           -- Full stage reference
    is_active BOOLEAN DEFAULT TRUE,
    description VARCHAR(1000),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- REGISTER INGESTION SOURCES
-- =============================================================================
-- Register internal stage
INSERT INTO RAW.INGESTION_SOURCES (source_name, source_type, stage_path, description)
VALUES (
    'Manual Upload',
    'INTERNAL',
    '@RAW.INTERNAL_DOCUMENTS_STAGE',
    'Internal stage for manually uploaded documents'
);

-- Uncomment to register S3 external stage after creating it
/*
INSERT INTO RAW.INGESTION_SOURCES (source_name, source_type, stage_path, description)
VALUES (
    'S3 Documents',
    'EXTERNAL',
    '@RAW.S3_DOCUMENTS_STAGE',
    'External S3 stage for production document ingestion'
);
*/

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SHOW SCHEMAS IN DATABASE IDENTIFIER($database_name);
SHOW STAGES IN SCHEMA RAW;
SELECT * FROM RAW.INGESTION_SOURCES;

SELECT 'Milestone 1 complete: Database & Stages created' AS status;
