/*
=============================================================================
Document Intelligence Pipeline - Configuration Settings
=============================================================================
Modify these variables to customize your deployment.
These settings are used across all deployment scripts.
=============================================================================
*/

-- =============================================================================
-- DATABASE CONFIGURATION
-- =============================================================================
SET database_name = 'DOC_INTELLIGENCE';
SET warehouse_name = 'DOC_INTELLIGENCE_WH';
SET warehouse_size = 'MEDIUM';

-- =============================================================================
-- SCHEMA NAMES
-- =============================================================================
SET schema_raw = 'RAW';
SET schema_processed = 'PROCESSED';
SET schema_semantic = 'SEMANTIC';
SET schema_analytics = 'ANALYTICS';

-- =============================================================================
-- EXTERNAL STAGE CONFIGURATION (S3)
-- =============================================================================
-- Set these if using S3 external stage
SET s3_bucket_url = 's3://your-bucket/documents/';
SET storage_integration_name = 'your_storage_integration';

-- =============================================================================
-- INTERNAL STAGE CONFIGURATION
-- =============================================================================
SET internal_stage_name = 'INTERNAL_DOCUMENTS_STAGE';

-- =============================================================================
-- CORTEX SEARCH CONFIGURATION
-- =============================================================================
SET search_service_name = 'DOCUMENT_SEARCH_SERVICE';
SET target_lag = '1 hour';
SET embedding_model = 'snowflake-arctic-embed-l-v2.0';

-- =============================================================================
-- LLM CONFIGURATION
-- =============================================================================
SET annotation_model = 'claude-sonnet-4-5';
SET annotation_temperature = 0;
SET annotation_max_tokens = 2000;

-- =============================================================================
-- PROCESSING CONFIGURATION
-- =============================================================================
SET chunk_size = 4000;          -- Characters per chunk
SET chunk_overlap = 200;        -- Overlap between chunks
SET parse_mode = 'LAYOUT';      -- AI_PARSE_DOCUMENT mode

-- =============================================================================
-- DISPLAY CURRENT SETTINGS
-- =============================================================================
SELECT 
    $database_name AS database_name,
    $warehouse_name AS warehouse_name,
    $warehouse_size AS warehouse_size,
    $target_lag AS search_target_lag,
    $annotation_model AS llm_model;
