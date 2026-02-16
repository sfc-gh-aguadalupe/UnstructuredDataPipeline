/*
=============================================================================
Run Ingestion Procedure
=============================================================================
Full ingestion pipeline for a source:
1. Refresh directory table
2. Register new documents
3. Parse pending documents
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE RAW.RUN_INGESTION(SOURCE_NAME VARCHAR, MAX_DOCS INT DEFAULT 10)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    register_result VARCHAR;
    doc_id INT;
    parse_result VARCHAR;
    processed_count INT DEFAULT 0;
    limit_count INT;
BEGIN
    limit_count := MAX_DOCS;
    
    -- Refresh directory table
    ALTER STAGE DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE REFRESH;
    
    -- Register new documents
    CALL DOC_INTELLIGENCE.RAW.REGISTER_NEW_DOCUMENTS(:SOURCE_NAME) INTO :register_result;
    
    -- Parse pending documents
    FOR record IN (
        SELECT document_id 
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
        WHERE status = 'PENDING' 
        ORDER BY discovered_at 
        LIMIT 10
    ) DO
        doc_id := record.document_id;
        CALL DOC_INTELLIGENCE.PROCESSED.PARSE_DOCUMENT(:doc_id) INTO :parse_result;
        processed_count := processed_count + 1;
        IF (processed_count >= limit_count) THEN
            EXIT;
        END IF;
    END FOR;
    
    RETURN register_result || '. Processed ' || processed_count || ' documents.';
END;
$$;

-- Usage:
-- CALL RAW.RUN_INGESTION('Manual Upload', 10);
