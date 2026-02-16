/*
=============================================================================
Ingestion Sources Configuration
=============================================================================
Creates a configuration table to manage document ingestion sources.
Supports both external (S3) and internal stages.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE INGESTION_SOURCES (
    source_id INT AUTOINCREMENT PRIMARY KEY,
    source_name VARCHAR(255) NOT NULL UNIQUE,
    source_type VARCHAR(50) NOT NULL,           -- 'EXTERNAL' or 'INTERNAL'
    stage_path VARCHAR(500) NOT NULL,           -- Full stage reference (e.g., @RAW.INTERNAL_DOCUMENTS_STAGE)
    is_active BOOLEAN DEFAULT TRUE,
    description VARCHAR(1000),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE INGESTION_SOURCES IS 'Configuration table for document ingestion sources';

-- Register internal stage
INSERT INTO INGESTION_SOURCES (source_name, source_type, stage_path, description)
VALUES (
    'Manual Upload',
    'INTERNAL',
    '@DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE',
    'Internal stage for manually uploaded documents'
);

-- Uncomment to register S3 external stage (after creating it)
/*
INSERT INTO INGESTION_SOURCES (source_name, source_type, stage_path, description)
VALUES (
    'S3 Documents',
    'EXTERNAL',
    '@DOC_INTELLIGENCE.RAW.S3_DOCUMENTS_STAGE',
    'External S3 stage for production document ingestion'
);
*/

-- Verify
SELECT * FROM INGESTION_SOURCES;
