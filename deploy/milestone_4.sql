/*
=============================================================================
MILESTONE 4: Document Ingestion Pipeline
=============================================================================
Creates:
- PROCEDURES.DISCOVER_DOCUMENTS - Find new documents in stages
- PROCEDURES.PARSE_DOCUMENT - Parse using AI_PARSE_DOCUMENT
- PROCEDURES.CHUNK_TEXT - Split large text into chunks
- PROCEDURES.INGEST_DOCUMENT - Process single document
- PROCEDURES.RUN_INGESTION - Batch process all pending documents
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- =============================================================================
-- DISCOVER_DOCUMENTS: Find new documents from a source's directory table
-- =============================================================================
CREATE OR REPLACE PROCEDURE RAW.DISCOVER_DOCUMENTS(SOURCE_NAME VARCHAR)
RETURNS TABLE (file_path VARCHAR, file_name VARCHAR, file_size INT, last_modified TIMESTAMP_NTZ)
LANGUAGE SQL
AS
$$
DECLARE
    stage_path VARCHAR;
    src_id INT;
    result RESULTSET;
BEGIN
    -- Get source configuration
    SELECT source_id, stage_path INTO :src_id, :stage_path
    FROM RAW.INGESTION_SOURCES 
    WHERE source_name = :SOURCE_NAME AND is_active = TRUE;
    
    IF (src_id IS NULL) THEN
        RETURN TABLE(SELECT NULL::VARCHAR, NULL::VARCHAR, NULL::INT, NULL::TIMESTAMP_NTZ WHERE 1=0);
    END IF;
    
    -- Find files not yet registered
    result := (
        SELECT 
            dir.RELATIVE_PATH as file_path,
            SPLIT_PART(dir.RELATIVE_PATH, '/', -1) as file_name,
            dir.SIZE as file_size,
            dir.LAST_MODIFIED as last_modified
        FROM DIRECTORY(@DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE) dir
        LEFT JOIN RAW.DOCUMENTS doc 
            ON doc.file_path = dir.RELATIVE_PATH 
            AND doc.source_id = :src_id
        WHERE doc.document_id IS NULL
        ORDER BY dir.LAST_MODIFIED DESC
    );
    
    RETURN TABLE(result);
END;
$$;

-- =============================================================================
-- REGISTER_NEW_DOCUMENTS: Register discovered documents into DOCUMENTS table
-- =============================================================================
CREATE OR REPLACE PROCEDURE RAW.REGISTER_NEW_DOCUMENTS(SOURCE_NAME VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    stage_path VARCHAR;
    src_id INT;
    rows_inserted INT DEFAULT 0;
BEGIN
    -- Get source configuration
    SELECT source_id, stage_path INTO :src_id, :stage_path
    FROM RAW.INGESTION_SOURCES 
    WHERE source_name = :SOURCE_NAME AND is_active = TRUE;
    
    IF (src_id IS NULL) THEN
        RETURN 'Error: Source not found or inactive';
    END IF;
    
    -- Register new documents
    INSERT INTO RAW.DOCUMENTS (source_id, file_path, file_name, file_extension, file_size_bytes, file_url)
    SELECT 
        :src_id,
        dir.RELATIVE_PATH,
        SPLIT_PART(dir.RELATIVE_PATH, '/', -1),
        LOWER(SPLIT_PART(SPLIT_PART(dir.RELATIVE_PATH, '/', -1), '.', -1)),
        dir.SIZE,
        dir.FILE_URL
    FROM DIRECTORY(@DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE) dir
    LEFT JOIN RAW.DOCUMENTS doc 
        ON doc.file_path = dir.RELATIVE_PATH 
        AND doc.source_id = :src_id
    WHERE doc.document_id IS NULL;
    
    rows_inserted := SQLROWCOUNT;
    
    RETURN 'Registered ' || rows_inserted || ' new documents from ' || SOURCE_NAME;
END;
$$;

-- =============================================================================
-- PARSE_DOCUMENT: Parse a single document using AI_PARSE_DOCUMENT
-- =============================================================================
CREATE OR REPLACE PROCEDURE PROCESSED.PARSE_DOCUMENT(DOC_ID INT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    file_url VARCHAR;
    file_ext VARCHAR;
    parsed_content VARIANT;
    full_text VARCHAR;
    chunk_size INT DEFAULT 4000;
    chunk_overlap INT DEFAULT 200;
    text_length INT;
    chunk_start INT DEFAULT 0;
    chunk_idx INT DEFAULT 0;
    current_chunk VARCHAR;
BEGIN
    -- Get document info
    SELECT file_url, file_extension INTO :file_url, :file_ext
    FROM RAW.DOCUMENTS WHERE document_id = :DOC_ID;
    
    IF (file_url IS NULL) THEN
        RETURN 'Error: Document not found';
    END IF;
    
    -- Update status to PROCESSING
    UPDATE RAW.DOCUMENTS SET status = 'PROCESSING' WHERE document_id = :DOC_ID;
    
    BEGIN
        -- Parse document based on type
        IF (file_ext IN ('pdf', 'png', 'jpg', 'jpeg', 'tiff', 'docx')) THEN
            -- Use AI_PARSE_DOCUMENT for supported formats
            SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
                :file_url,
                {'mode': 'LAYOUT'}
            ) INTO :parsed_content;
            
            -- Extract full text from parsed content
            SELECT LISTAGG(value:text::VARCHAR, '\n\n') WITHIN GROUP (ORDER BY INDEX)
            INTO :full_text
            FROM TABLE(FLATTEN(input => :parsed_content, path => 'content'));
            
        ELSE
            -- For text files, read directly (simplified)
            full_text := 'Unsupported file type: ' || file_ext;
        END IF;
        
        -- Delete existing chunks for re-processing
        DELETE FROM PROCESSED.DOCUMENT_CHUNKS WHERE document_id = :DOC_ID;
        
        -- Chunk the text
        text_length := LENGTH(full_text);
        
        WHILE (chunk_start < text_length) DO
            current_chunk := SUBSTR(full_text, chunk_start + 1, chunk_size);
            
            INSERT INTO PROCESSED.DOCUMENT_CHUNKS (document_id, chunk_index, chunk_text, char_start, char_end)
            VALUES (:DOC_ID, :chunk_idx, :current_chunk, :chunk_start, :chunk_start + LENGTH(:current_chunk));
            
            chunk_start := chunk_start + chunk_size - chunk_overlap;
            chunk_idx := chunk_idx + 1;
        END WHILE;
        
        -- Update document status and metadata
        UPDATE RAW.DOCUMENTS 
        SET status = 'PARSED',
            parsed_at = CURRENT_TIMESTAMP(),
            word_count = ARRAY_SIZE(SPLIT(full_text, ' '))
        WHERE document_id = :DOC_ID;
        
        RETURN 'Successfully parsed document ' || DOC_ID || ' into ' || chunk_idx || ' chunks';
        
    EXCEPTION
        WHEN OTHER THEN
            UPDATE RAW.DOCUMENTS 
            SET status = 'FAILED',
                error_message = SQLERRM
            WHERE document_id = :DOC_ID;
            RETURN 'Error parsing document: ' || SQLERRM;
    END;
END;
$$;

-- =============================================================================
-- PROCESS_PENDING_DOCUMENTS: Process all pending documents
-- =============================================================================
CREATE OR REPLACE PROCEDURE RAW.PROCESS_PENDING_DOCUMENTS(MAX_DOCS INT DEFAULT 10)
RETURNS TABLE (document_id INT, file_name VARCHAR, result VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    doc_cursor CURSOR FOR 
        SELECT document_id, file_name 
        FROM RAW.DOCUMENTS 
        WHERE status = 'PENDING' 
        ORDER BY discovered_at 
        LIMIT :MAX_DOCS;
    doc_id INT;
    doc_name VARCHAR;
    parse_result VARCHAR;
    results ARRAY DEFAULT ARRAY_CONSTRUCT();
BEGIN
    FOR record IN doc_cursor DO
        doc_id := record.document_id;
        doc_name := record.file_name;
        
        CALL PROCESSED.PARSE_DOCUMENT(:doc_id) INTO :parse_result;
        
        results := ARRAY_APPEND(results, OBJECT_CONSTRUCT(
            'document_id', doc_id,
            'file_name', doc_name,
            'result', parse_result
        ));
    END FOR;
    
    RETURN TABLE(
        SELECT 
            value:document_id::INT as document_id,
            value:file_name::VARCHAR as file_name,
            value:result::VARCHAR as result
        FROM TABLE(FLATTEN(input => results))
    );
END;
$$;

-- =============================================================================
-- RUN_INGESTION: Full ingestion pipeline for a source
-- =============================================================================
CREATE OR REPLACE PROCEDURE RAW.RUN_INGESTION(SOURCE_NAME VARCHAR, MAX_DOCS INT DEFAULT 10)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    register_result VARCHAR;
    processed_count INT DEFAULT 0;
BEGIN
    -- Step 1: Refresh directory table
    ALTER STAGE DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE REFRESH;
    
    -- Step 2: Register new documents
    CALL RAW.REGISTER_NEW_DOCUMENTS(:SOURCE_NAME) INTO :register_result;
    
    -- Step 3: Process pending documents
    SELECT COUNT(*) INTO :processed_count
    FROM TABLE(RAW.PROCESS_PENDING_DOCUMENTS(:MAX_DOCS));
    
    RETURN register_result || '. Processed ' || processed_count || ' documents.';
END;
$$;

-- =============================================================================
-- HELPER: Get pipeline status
-- =============================================================================
CREATE OR REPLACE PROCEDURE RAW.GET_PIPELINE_STATUS()
RETURNS TABLE (status VARCHAR, count INT, pct FLOAT)
LANGUAGE SQL
AS
$$
BEGIN
    RETURN TABLE(
        SELECT 
            status,
            COUNT(*) as count,
            ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct
        FROM RAW.DOCUMENTS
        GROUP BY status
        ORDER BY 
            CASE status 
                WHEN 'PENDING' THEN 1 
                WHEN 'PROCESSING' THEN 2 
                WHEN 'PARSED' THEN 3
                WHEN 'ANNOTATED' THEN 4
                WHEN 'COMPLETED' THEN 5 
                WHEN 'FAILED' THEN 6 
            END
    );
END;
$$;

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SHOW PROCEDURES IN DATABASE DOC_INTELLIGENCE;

SELECT 'Milestone 4 complete: Document Ingestion Pipeline created' AS status;
