/*
=============================================================================
MILESTONE 6: Cortex Search Service
=============================================================================
Creates hybrid search capabilities:
- SEARCHABLE_DOCUMENTS view (flattened for search)
- SEARCH_FACETS view (filter counts)
- DOCUMENT_SEARCH_SERVICE (Cortex Search)

Prerequisites: Milestones 1-5 completed
=============================================================================
*/

-- =============================================================================
-- 1. Searchable Documents View
-- =============================================================================
USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA PROCESSED;

CREATE OR REPLACE VIEW SEARCHABLE_DOCUMENTS AS
SELECT 
    -- Document identifiers
    d.document_id,
    c.chunk_id,
    c.chunk_index,
    
    -- Searchable text content
    c.chunk_text,
    
    -- Document metadata
    d.file_name,
    d.file_path,
    d.file_extension,
    d.file_url,
    d.file_size_bytes,
    d.page_count,
    d.word_count,
    
    -- Classification (for faceted filtering)
    cat.category_name AS category,
    
    -- Tags as string for filtering
    ARRAY_TO_STRING(a.tags, ', ') AS tags,
    
    -- Annotation content
    a.summary,
    ARRAY_TO_STRING(a.key_terms, ', ') AS key_terms,
    a.confidence AS annotation_confidence,
    
    -- Entities flattened for search
    ARRAY_TO_STRING(a.entities:people, ', ') AS people,
    ARRAY_TO_STRING(a.entities:organizations, ', ') AS organizations,
    ARRAY_TO_STRING(a.entities:locations, ', ') AS locations,
    
    -- Source info
    src.source_name,
    src.source_type,
    
    -- Timestamps
    d.discovered_at,
    d.parsed_at,
    d.annotated_at,
    
    -- Review status
    a.review_status

FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS c
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON c.document_id = d.document_id
LEFT JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES cat ON a.category_id = cat.category_id
LEFT JOIN DOC_INTELLIGENCE.RAW.INGESTION_SOURCES src ON d.source_id = src.source_id
WHERE d.status IN ('PARSED', 'ANNOTATED', 'COMPLETED');

COMMENT ON VIEW SEARCHABLE_DOCUMENTS IS 'Flattened view for Cortex Search Service - joins chunks with annotations';

-- =============================================================================
-- 2. Search Facets View
-- =============================================================================
CREATE OR REPLACE VIEW SEARCH_FACETS AS
SELECT 
    'category' AS facet_type,
    category AS facet_value,
    COUNT(*) AS doc_count
FROM SEARCHABLE_DOCUMENTS
WHERE category IS NOT NULL
GROUP BY category

UNION ALL

SELECT 
    'file_extension' AS facet_type,
    file_extension AS facet_value,
    COUNT(DISTINCT document_id) AS doc_count
FROM SEARCHABLE_DOCUMENTS
WHERE file_extension IS NOT NULL
GROUP BY file_extension

UNION ALL

SELECT 
    'source_type' AS facet_type,
    source_type AS facet_value,
    COUNT(DISTINCT document_id) AS doc_count
FROM SEARCHABLE_DOCUMENTS
WHERE source_type IS NOT NULL
GROUP BY source_type

UNION ALL

SELECT 
    'review_status' AS facet_type,
    review_status AS facet_value,
    COUNT(DISTINCT document_id) AS doc_count
FROM SEARCHABLE_DOCUMENTS
WHERE review_status IS NOT NULL
GROUP BY review_status;

COMMENT ON VIEW SEARCH_FACETS IS 'Aggregated facet counts for search UI filters';

-- =============================================================================
-- 3. Cortex Search Service
-- =============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE PROCESSED.DOCUMENT_SEARCH_SERVICE
    ON chunk_text
    ATTRIBUTES category, tags, file_extension, source_type, review_status, file_name, summary, key_terms, people, organizations, locations
    WAREHOUSE = DOC_INTELLIGENCE_WH
    TARGET_LAG = '1 hour'
    AS (
        SELECT 
            -- Primary search field
            chunk_text,
            
            -- Filterable attributes
            category,
            tags,
            file_extension,
            source_type,
            review_status,
            
            -- Displayable metadata
            document_id,
            chunk_id,
            chunk_index,
            file_name,
            file_path,
            file_url,
            summary,
            key_terms,
            people,
            organizations,
            locations,
            annotation_confidence,
            discovered_at,
            annotated_at
            
        FROM DOC_INTELLIGENCE.PROCESSED.SEARCHABLE_DOCUMENTS
    );

COMMENT ON CORTEX SEARCH SERVICE PROCESSED.DOCUMENT_SEARCH_SERVICE IS 
    'Hybrid semantic + lexical search service for document discovery';

-- =============================================================================
-- Verification
-- =============================================================================
SHOW CORTEX SEARCH SERVICES IN SCHEMA PROCESSED;
SELECT COUNT(*) as searchable_rows FROM SEARCHABLE_DOCUMENTS;
SELECT * FROM SEARCH_FACETS ORDER BY facet_type, doc_count DESC;
