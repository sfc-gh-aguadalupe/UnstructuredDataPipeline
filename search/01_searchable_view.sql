/*
=============================================================================
Searchable Documents View
=============================================================================
Creates a flattened view joining documents, chunks, and annotations
for use with Cortex Search Service.
=============================================================================
*/

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

-- Verify
SELECT COUNT(*) as total_rows FROM SEARCHABLE_DOCUMENTS;
DESC VIEW SEARCHABLE_DOCUMENTS;
