/*
=============================================================================
Full Pipeline Procedure
=============================================================================
Runs the complete pipeline: ingestion + parsing + annotation.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE RAW.FULL_PIPELINE(SOURCE_NAME VARCHAR, MAX_DOCS INT DEFAULT 10)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    ingest_result VARCHAR;
    annotate_result VARCHAR;
BEGIN
    -- Run ingestion (discover, register, parse)
    CALL DOC_INTELLIGENCE.RAW.RUN_INGESTION(:SOURCE_NAME, :MAX_DOCS) INTO :ingest_result;
    
    -- Run annotation
    CALL DOC_INTELLIGENCE.PROCESSED.RUN_ANNOTATION(:MAX_DOCS) INTO :annotate_result;
    
    RETURN ingest_result || ' | ' || annotate_result;
END;
$$;

-- Usage:
-- CALL RAW.FULL_PIPELINE('Manual Upload', 5);
