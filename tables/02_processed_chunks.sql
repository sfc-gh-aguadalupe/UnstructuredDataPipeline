/*
=============================================================================
Document Chunks Table
=============================================================================
Stores parsed document content split into searchable chunks.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA PROCESSED;

CREATE OR REPLACE TABLE DOCUMENT_CHUNKS (
    chunk_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL REFERENCES RAW.DOCUMENTS(document_id),
    chunk_index INT NOT NULL,
    chunk_text VARCHAR(16777216),           -- Up to 16MB per chunk
    -- Location info
    page_start INT,
    page_end INT,
    char_start INT,
    char_end INT,
    -- Chunk metadata
    token_count INT,
    -- Timestamps
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    -- Constraints
    UNIQUE (document_id, chunk_index)
);

COMMENT ON TABLE DOCUMENT_CHUNKS IS 'Parsed document content split into searchable chunks';

-- Verify
DESC TABLE DOCUMENT_CHUNKS;
