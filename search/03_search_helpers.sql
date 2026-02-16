/*
=============================================================================
Search Helper Procedures
=============================================================================
Utility procedures for searching documents via Cortex Search Service.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

-- =============================================================================
-- Basic Search Procedure
-- =============================================================================
CREATE OR REPLACE PROCEDURE PROCESSED.SEARCH_DOCUMENTS(
    QUERY_TEXT VARCHAR,
    MAX_RESULTS INT DEFAULT 10,
    CATEGORY_FILTER VARCHAR DEFAULT NULL,
    FILE_TYPE_FILTER VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    document_id INT,
    chunk_id INT,
    file_name VARCHAR,
    category VARCHAR,
    chunk_text VARCHAR,
    summary VARCHAR,
    score FLOAT
)
LANGUAGE SQL
AS
$$
DECLARE
    filter_obj VARIANT;
    result_set RESULTSET;
BEGIN
    -- Build filter object
    filter_obj := OBJECT_CONSTRUCT();
    
    IF (CATEGORY_FILTER IS NOT NULL) THEN
        filter_obj := OBJECT_INSERT(filter_obj, '@eq', OBJECT_CONSTRUCT('category', CATEGORY_FILTER));
    END IF;
    
    IF (FILE_TYPE_FILTER IS NOT NULL) THEN
        filter_obj := OBJECT_INSERT(filter_obj, '@eq', OBJECT_CONSTRUCT('file_extension', FILE_TYPE_FILTER));
    END IF;

    -- Execute search using SEARCH function
    result_set := (
        SELECT 
            document_id::INT as document_id,
            chunk_id::INT as chunk_id,
            file_name::VARCHAR as file_name,
            category::VARCHAR as category,
            LEFT(chunk_text, 500)::VARCHAR as chunk_text,
            summary::VARCHAR as summary,
            _relevance_score::FLOAT as score
        FROM TABLE(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
                OBJECT_CONSTRUCT(
                    'query', QUERY_TEXT,
                    'columns', ARRAY_CONSTRUCT('document_id', 'chunk_id', 'file_name', 'category', 'chunk_text', 'summary'),
                    'limit', MAX_RESULTS
                )
            )
        )
    );
    
    RETURN TABLE(result_set);
END;
$$;

-- =============================================================================
-- Search with Filters View Helper
-- =============================================================================
CREATE OR REPLACE VIEW PROCESSED.SEARCH_FACETS AS
SELECT 
    'category' AS facet_type,
    category AS facet_value,
    COUNT(*) AS doc_count
FROM PROCESSED.SEARCHABLE_DOCUMENTS
WHERE category IS NOT NULL
GROUP BY category

UNION ALL

SELECT 
    'file_extension' AS facet_type,
    file_extension AS facet_value,
    COUNT(DISTINCT document_id) AS doc_count
FROM PROCESSED.SEARCHABLE_DOCUMENTS
WHERE file_extension IS NOT NULL
GROUP BY file_extension

UNION ALL

SELECT 
    'source_type' AS facet_type,
    source_type AS facet_value,
    COUNT(DISTINCT document_id) AS doc_count
FROM PROCESSED.SEARCHABLE_DOCUMENTS
WHERE source_type IS NOT NULL
GROUP BY source_type

UNION ALL

SELECT 
    'review_status' AS facet_type,
    review_status AS facet_value,
    COUNT(DISTINCT document_id) AS doc_count
FROM PROCESSED.SEARCHABLE_DOCUMENTS
WHERE review_status IS NOT NULL
GROUP BY review_status;

COMMENT ON VIEW PROCESSED.SEARCH_FACETS IS 'Aggregated facet counts for search UI filters';

-- Verify
SELECT * FROM PROCESSED.SEARCH_FACETS ORDER BY facet_type, doc_count DESC;
