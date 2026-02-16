/*
=============================================================================
MILESTONE 3: Document Storage Tables
=============================================================================
Creates:
- RAW.DOCUMENTS - Document registry and metadata
- PROCESSED.DOCUMENT_CHUNKS - Parsed and chunked content
- PROCESSED.ANNOTATIONS - LLM-generated annotations
- PROCESSED.DOCUMENT_VECTORS - Vector embeddings for search
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- =============================================================================
-- RAW.DOCUMENTS - Document registry
-- =============================================================================
CREATE OR REPLACE TABLE RAW.DOCUMENTS (
    document_id INT AUTOINCREMENT PRIMARY KEY,
    source_id INT NOT NULL REFERENCES RAW.INGESTION_SOURCES(source_id),
    file_path VARCHAR(1000) NOT NULL,
    file_name VARCHAR(500),
    file_extension VARCHAR(20),
    file_size_bytes INT,
    file_url VARCHAR(2000),
    file_md5 VARCHAR(64),
    -- Processing status
    status VARCHAR(50) DEFAULT 'PENDING',  -- PENDING, PROCESSING, PARSED, ANNOTATED, COMPLETED, FAILED
    error_message VARCHAR(4000),
    -- Timestamps
    discovered_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    parsed_at TIMESTAMP_NTZ,
    annotated_at TIMESTAMP_NTZ,
    -- Metadata
    page_count INT,
    word_count INT,
    language VARCHAR(10),
    -- Constraints
    UNIQUE (source_id, file_path)
);

COMMENT ON TABLE RAW.DOCUMENTS IS 'Registry of all documents discovered from ingestion sources';

-- Index for status queries
CREATE OR REPLACE INDEX idx_documents_status ON RAW.DOCUMENTS(status);

-- =============================================================================
-- PROCESSED.DOCUMENT_CHUNKS - Parsed content chunks
-- =============================================================================
CREATE OR REPLACE TABLE PROCESSED.DOCUMENT_CHUNKS (
    chunk_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL REFERENCES RAW.DOCUMENTS(document_id),
    chunk_index INT NOT NULL,
    chunk_text VARCHAR(16777216),  -- Up to 16MB per chunk
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

COMMENT ON TABLE PROCESSED.DOCUMENT_CHUNKS IS 'Parsed document content split into searchable chunks';

-- =============================================================================
-- PROCESSED.ANNOTATIONS - LLM-generated annotations
-- =============================================================================
CREATE OR REPLACE TABLE PROCESSED.ANNOTATIONS (
    annotation_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL REFERENCES RAW.DOCUMENTS(document_id),
    -- Classification
    category_id INT REFERENCES SEMANTIC.CATEGORIES(category_id),
    tags ARRAY,  -- Array of tag_ids
    -- Extracted content
    summary VARCHAR(4000),
    key_terms ARRAY,
    entities VARIANT,  -- JSON: {people:[], organizations:[], dates:[], locations:[], etc.}
    -- Quality metrics
    confidence FLOAT,
    -- Model info
    model_name VARCHAR(100),
    model_version VARCHAR(50),
    prompt_tokens INT,
    completion_tokens INT,
    -- Review workflow
    review_status VARCHAR(50) DEFAULT 'PENDING',  -- PENDING, APPROVED, REJECTED, MODIFIED
    reviewed_by VARCHAR(100),
    reviewed_at TIMESTAMP_NTZ,
    review_notes VARCHAR(2000),
    -- Timestamps
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE PROCESSED.ANNOTATIONS IS 'LLM-generated document annotations constrained by semantic model';

-- =============================================================================
-- PROCESSED.DOCUMENT_VECTORS - Vector embeddings
-- =============================================================================
CREATE OR REPLACE TABLE PROCESSED.DOCUMENT_VECTORS (
    vector_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL REFERENCES RAW.DOCUMENTS(document_id),
    chunk_id INT REFERENCES PROCESSED.DOCUMENT_CHUNKS(chunk_id),
    -- Embedding
    embedding VECTOR(FLOAT, 1024),  -- snowflake-arctic-embed-l-v2.0 dimension
    -- Model info
    embedding_model VARCHAR(100),
    -- Timestamps
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE PROCESSED.DOCUMENT_VECTORS IS 'Vector embeddings for semantic search';

-- =============================================================================
-- HELPER VIEW: Document status overview
-- =============================================================================
CREATE OR REPLACE VIEW RAW.DOCUMENT_STATUS_SUMMARY AS
SELECT 
    status,
    COUNT(*) as document_count,
    MIN(discovered_at) as oldest_document,
    MAX(discovered_at) as newest_document
FROM RAW.DOCUMENTS
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

-- =============================================================================
-- HELPER VIEW: Full document view with annotations
-- =============================================================================
CREATE OR REPLACE VIEW PROCESSED.DOCUMENTS_WITH_ANNOTATIONS AS
SELECT 
    d.document_id,
    d.file_name,
    d.file_extension,
    d.file_size_bytes,
    d.status,
    d.page_count,
    s.source_name,
    s.source_type,
    c.category_name,
    a.tags,
    a.summary,
    a.key_terms,
    a.confidence,
    a.review_status,
    d.discovered_at,
    d.parsed_at,
    d.annotated_at
FROM RAW.DOCUMENTS d
JOIN RAW.INGESTION_SOURCES s ON d.source_id = s.source_id
LEFT JOIN PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
LEFT JOIN SEMANTIC.CATEGORIES c ON a.category_id = c.category_id;

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SHOW TABLES IN SCHEMA RAW;
SHOW TABLES IN SCHEMA PROCESSED;

SELECT 'Milestone 3 complete: Document Storage Tables created' AS status;
