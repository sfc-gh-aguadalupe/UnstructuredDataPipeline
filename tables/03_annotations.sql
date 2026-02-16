/*
=============================================================================
Annotations Table
=============================================================================
Stores LLM-generated document annotations constrained by the semantic model.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA PROCESSED;

CREATE OR REPLACE TABLE ANNOTATIONS (
    annotation_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL REFERENCES RAW.DOCUMENTS(document_id),
    -- Classification (from semantic model)
    category_id INT REFERENCES SEMANTIC.CATEGORIES(category_id),
    tags ARRAY,                             -- Array of tag names
    -- Extracted content
    summary VARCHAR(4000),
    key_terms ARRAY,
    entities VARIANT,                       -- JSON: {people:[], organizations:[], dates:[], locations:[]}
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

COMMENT ON TABLE ANNOTATIONS IS 'LLM-generated document annotations constrained by semantic model';

-- Verify
DESC TABLE ANNOTATIONS;
