/*
=============================================================================
Register New Documents Procedure
=============================================================================
Scans the directory table for a source and registers new documents.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE RAW.REGISTER_NEW_DOCUMENTS(SOURCE_NAME VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    src_id INT;
    rows_inserted INT DEFAULT 0;
BEGIN
    -- Get source configuration
    SELECT source_id INTO :src_id
    FROM DOC_INTELLIGENCE.RAW.INGESTION_SOURCES 
    WHERE source_name = :SOURCE_NAME AND is_active = TRUE;
    
    IF (src_id IS NULL) THEN
        RETURN 'Error: Source not found or inactive';
    END IF;
    
    -- Register new documents from directory table
    INSERT INTO DOC_INTELLIGENCE.RAW.DOCUMENTS (source_id, file_path, file_name, file_extension, file_size_bytes, file_url)
    SELECT 
        :src_id,
        dir.RELATIVE_PATH,
        SPLIT_PART(dir.RELATIVE_PATH, '/', -1),
        LOWER(SPLIT_PART(SPLIT_PART(dir.RELATIVE_PATH, '/', -1), '.', -1)),
        dir.SIZE,
        dir.FILE_URL
    FROM DIRECTORY(@DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE) dir
    LEFT JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS doc 
        ON doc.file_path = dir.RELATIVE_PATH 
        AND doc.source_id = :src_id
    WHERE doc.document_id IS NULL;
    
    rows_inserted := SQLROWCOUNT;
    
    RETURN 'Registered ' || rows_inserted || ' new documents from ' || SOURCE_NAME;
END;
$$;

-- Usage:
-- CALL RAW.REGISTER_NEW_DOCUMENTS('Manual Upload');
