/*
=============================================================================
MILESTONE 8 EXPERIMENT: Ontology Tables
=============================================================================
Creates tables for storing JSON-LD ontology cache and experiment annotations.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA EXPERIMENT;

-- =============================================================================
-- ONTOLOGY_CACHE: Stores JSON-LD exports (simulating AnzoGraph cache)
-- =============================================================================
CREATE OR REPLACE TABLE ONTOLOGY_CACHE (
    cache_id INT AUTOINCREMENT PRIMARY KEY,
    ontology_name VARCHAR(200) NOT NULL,
    version VARCHAR(50) NOT NULL,
    description VARCHAR(1000),
    source_system VARCHAR(100) DEFAULT 'AnzoGraph',   -- Where this came from
    graph_uri VARCHAR(500),                           -- Source graph IRI
    json_ld VARIANT NOT NULL,                         -- Full JSON-LD document
    class_count INT,                                  -- Number of classes
    property_count INT,                               -- Number of properties
    imported_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    imported_by VARCHAR(100) DEFAULT CURRENT_USER(),
    expires_at TIMESTAMP_NTZ,
    is_current BOOLEAN DEFAULT TRUE,
    checksum VARCHAR(64)                              -- For change detection
);

COMMENT ON TABLE ONTOLOGY_CACHE IS 'Cached JSON-LD ontology exports from AnzoGraph';

-- =============================================================================
-- ONTOLOGY_CLASSES_VIEW: Flattened view of classes from JSON-LD
-- =============================================================================
-- This will be created after we have data, using LATERAL FLATTEN

-- =============================================================================
-- EXPERIMENT_ANNOTATIONS: Stores annotations made with JSON-LD ontology
-- =============================================================================
CREATE OR REPLACE TABLE EXPERIMENT_ANNOTATIONS (
    annotation_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL,                         -- FK to RAW.DOCUMENTS
    ontology_name VARCHAR(200),                       -- Which ontology was used
    ontology_version VARCHAR(50),
    
    -- Classification results (may be hierarchical)
    category_iri VARCHAR(500),                        -- Full IRI from ontology
    category_label VARCHAR(200),                      -- Human-readable label
    parent_category_label VARCHAR(200),               -- Parent in hierarchy
    category_path VARCHAR(1000),                      -- Full path: "Legal > Contract > NDA"
    
    -- Standard annotation fields
    tags ARRAY,
    summary VARCHAR(4000),
    key_terms ARRAY,
    entities VARIANT,
    confidence FLOAT,
    
    -- Metadata
    model_name VARCHAR(100),
    prompt_tokens INT,
    completion_tokens INT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- For comparison
    matched_existing_category VARCHAR(200),           -- Mapped to SEMANTIC.CATEGORIES
    classification_method VARCHAR(50) DEFAULT 'JSONLD_ONTOLOGY'
);

COMMENT ON TABLE EXPERIMENT_ANNOTATIONS IS 'Annotations created using JSON-LD ontology experiment';

-- =============================================================================
-- EXPERIMENT_COMPARISON: Side-by-side comparison of flat vs hierarchical
-- =============================================================================
CREATE OR REPLACE TABLE EXPERIMENT_COMPARISON (
    comparison_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL,
    file_name VARCHAR(500),
    
    -- Flat taxonomy result (existing approach)
    flat_category VARCHAR(200),
    flat_tags ARRAY,
    flat_confidence FLOAT,
    
    -- JSON-LD ontology result (new approach)
    ontology_category_path VARCHAR(1000),
    ontology_category_label VARCHAR(200),
    ontology_tags ARRAY,
    ontology_confidence FLOAT,
    
    -- Analysis
    categories_match BOOLEAN,
    tags_overlap_pct FLOAT,
    notes VARCHAR(2000),
    
    compared_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE EXPERIMENT_COMPARISON IS 'Comparison results between flat taxonomy and JSON-LD ontology approaches';

-- Verify tables created
SHOW TABLES IN SCHEMA EXPERIMENT;

SELECT 'Ontology tables created successfully' AS status;
