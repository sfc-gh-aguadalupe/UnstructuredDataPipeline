/*
=============================================================================
Raw Documents Table
=============================================================================
Registry of all documents discovered from ingestion sources.
Tracks document lifecycle from discovery through annotation.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE DOCUMENTS (
    document_id INT AUTOINCREMENT PRIMARY KEY,
    source_id INT NOT NULL REFERENCES INGESTION_SOURCES(source_id),
    -- File info
    file_path VARCHAR(1000) NOT NULL,
    file_name VARCHAR(500),
    file_extension VARCHAR(20),
    file_size_bytes INT,
    file_url VARCHAR(2000),
    file_md5 VARCHAR(64),
    -- Processing status
    status VARCHAR(50) DEFAULT 'PENDING',   -- PENDING, PROCESSING, PARSED, ANNOTATED, COMPLETED, FAILED
    error_message VARCHAR(4000),
    -- Timestamps
    discovered_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    parsed_at TIMESTAMP_NTZ,
    annotated_at TIMESTAMP_NTZ,
    -- Document metadata (populated after parsing)
    page_count INT,
    word_count INT,
    language VARCHAR(10),
    -- Constraints
    UNIQUE (source_id, file_path)
);

COMMENT ON TABLE DOCUMENTS IS 'Registry of all documents discovered from ingestion sources';

-- Helper views
CREATE OR REPLACE VIEW DOCUMENT_STATUS_SUMMARY AS
SELECT 
    status,
    COUNT(*) as document_count,
    MIN(discovered_at) as oldest_document,
    MAX(discovered_at) as newest_document
FROM DOCUMENTS
GROUP BY status
ORDER BY 
    CASE status 
        WHEN 'PENDING' THEN 1 
        WHEN 'PROCESSING' THEN 2 
        WHEN 'PARSED' THEN 3
        WHEN 'ANNOTATED' THEN 4
        WHEN 'COMPLETED' THEN 5 
        WHEN 'FAILED' THEN 6 
    END;

CREATE OR REPLACE VIEW PIPELINE_STATUS AS
SELECT 
    status,
    COUNT(*)::INT as doc_count,
    ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) as pct
FROM DOCUMENTS
GROUP BY status;

-- Verify
DESC TABLE DOCUMENTS;
