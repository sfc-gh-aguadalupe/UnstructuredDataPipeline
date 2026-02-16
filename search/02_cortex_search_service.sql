/*
=============================================================================
Cortex Search Service
=============================================================================
Creates a hybrid search service combining:
- Semantic search (vector similarity via embeddings)
- Lexical search (keyword matching)
- Faceted filtering (category, tags, file_extension, etc.)
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

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

-- Verify service was created
SHOW CORTEX SEARCH SERVICES IN SCHEMA PROCESSED;

-- Check service status
DESCRIBE CORTEX SEARCH SERVICE PROCESSED.DOCUMENT_SEARCH_SERVICE;
