/*
=============================================================================
Basic Semantic Model Tables
=============================================================================
Creates flat taxonomy tables for document classification:
- CATEGORIES - Single-label document classification
- TAGS - Multi-label document tagging
- GLOSSARY - Domain vocabulary for LLM context
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA SEMANTIC;

-- =============================================================================
-- CATEGORIES (flat - single classification per document)
-- =============================================================================
CREATE OR REPLACE TABLE CATEGORIES (
    category_id INT AUTOINCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE CATEGORIES IS 'Flat list of document categories for single-label classification';

-- =============================================================================
-- TAGS (flat - multiple tags per document)
-- =============================================================================
CREATE OR REPLACE TABLE TAGS (
    tag_id INT AUTOINCREMENT PRIMARY KEY,
    tag_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE TAGS IS 'Flat list of tags for multi-label document annotation';

-- =============================================================================
-- GLOSSARY (domain vocabulary)
-- =============================================================================
CREATE OR REPLACE TABLE GLOSSARY (
    term_id INT AUTOINCREMENT PRIMARY KEY,
    term VARCHAR(200) NOT NULL UNIQUE,
    definition VARCHAR(2000),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE GLOSSARY IS 'Domain-specific vocabulary to guide LLM annotation';

-- Verify
SHOW TABLES IN SCHEMA SEMANTIC;
