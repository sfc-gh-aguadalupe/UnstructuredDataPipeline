/*
=============================================================================
Document Vectors Table
=============================================================================
Stores vector embeddings for semantic search.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA PROCESSED;

CREATE OR REPLACE TABLE DOCUMENT_VECTORS (
    vector_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL REFERENCES RAW.DOCUMENTS(document_id),
    chunk_id INT REFERENCES DOCUMENT_CHUNKS(chunk_id),
    -- Embedding (snowflake-arctic-embed-l-v2.0 = 1024 dimensions)
    embedding VECTOR(FLOAT, 1024),
    -- Model info
    embedding_model VARCHAR(100),
    -- Timestamps
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE DOCUMENT_VECTORS IS 'Vector embeddings for semantic search';

-- Verify
DESC TABLE DOCUMENT_VECTORS;
