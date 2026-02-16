/*
=============================================================================
Run Annotation Procedure
=============================================================================
Batch annotates all parsed documents.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE PROCESSED.RUN_ANNOTATION(MAX_DOCS INT DEFAULT 10)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    doc_id INT;
    annotate_result VARCHAR;
    processed_count INT DEFAULT 0;
    success_count INT DEFAULT 0;
    limit_count INT;
BEGIN
    limit_count := MAX_DOCS;
    
    FOR record IN (
        SELECT document_id 
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
        WHERE status = 'PARSED' 
        ORDER BY parsed_at 
        LIMIT 50
    ) DO
        doc_id := record.document_id;
        CALL DOC_INTELLIGENCE.PROCESSED.ANNOTATE_DOCUMENT(:doc_id) INTO :annotate_result;
        processed_count := processed_count + 1;
        
        IF (annotate_result LIKE 'Successfully%') THEN
            success_count := success_count + 1;
        END IF;
        
        IF (processed_count >= limit_count) THEN
            EXIT;
        END IF;
    END FOR;
    
    RETURN 'Annotation complete: ' || success_count || '/' || processed_count || ' documents annotated successfully.';
END;
$$;

-- Usage:
-- CALL PROCESSED.RUN_ANNOTATION(10);
