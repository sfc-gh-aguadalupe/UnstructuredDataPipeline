/*
=============================================================================
Parse Document Procedure
=============================================================================
Parses a single document using AI_PARSE_DOCUMENT and chunks the text.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE PROCESSED.PARSE_DOCUMENT(DOC_ID INT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_file_url VARCHAR;
    v_file_ext VARCHAR;
    parsed_content VARIANT;
    full_text VARCHAR DEFAULT '';
    chunk_size INT DEFAULT 4000;
    chunk_overlap INT DEFAULT 200;
    text_length INT;
    chunk_start INT DEFAULT 0;
    chunk_idx INT DEFAULT 0;
    current_chunk VARCHAR;
BEGIN
    -- Get document info
    SELECT file_url, file_extension INTO :v_file_url, :v_file_ext
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS WHERE document_id = :DOC_ID;
    
    IF (v_file_url IS NULL) THEN
        RETURN 'Error: Document not found';
    END IF;
    
    -- Update status to PROCESSING
    UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS SET status = 'PROCESSING' WHERE document_id = :DOC_ID;
    
    BEGIN
        -- Parse document based on type
        IF (v_file_ext IN ('pdf', 'png', 'jpg', 'jpeg', 'tiff', 'docx')) THEN
            -- Use AI_PARSE_DOCUMENT for supported formats
            SELECT SNOWFLAKE.CORTEX.PARSE_DOCUMENT(:v_file_url, {'mode': 'LAYOUT'}) INTO :parsed_content;
            
            -- Extract full text from parsed content
            SELECT LISTAGG(value:text::VARCHAR, CHR(10) || CHR(10)) WITHIN GROUP (ORDER BY INDEX)
            INTO :full_text
            FROM TABLE(FLATTEN(input => :parsed_content, path => 'content'));
        ELSE
            full_text := 'Unsupported file type: ' || v_file_ext;
        END IF;
        
        -- Delete existing chunks for re-processing
        DELETE FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS WHERE document_id = :DOC_ID;
        
        -- Chunk the text
        text_length := NVL(LENGTH(full_text), 0);
        
        WHILE (chunk_start < text_length) DO
            current_chunk := SUBSTR(full_text, chunk_start + 1, chunk_size);
            
            INSERT INTO DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS (document_id, chunk_index, chunk_text, char_start, char_end)
            VALUES (:DOC_ID, :chunk_idx, :current_chunk, :chunk_start, :chunk_start + LENGTH(:current_chunk));
            
            chunk_start := chunk_start + chunk_size - chunk_overlap;
            chunk_idx := chunk_idx + 1;
        END WHILE;
        
        -- Update document status and metadata
        UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS 
        SET status = 'PARSED',
            parsed_at = CURRENT_TIMESTAMP(),
            word_count = ARRAY_SIZE(SPLIT(full_text, ' '))
        WHERE document_id = :DOC_ID;
        
        RETURN 'Successfully parsed document ' || DOC_ID || ' into ' || chunk_idx || ' chunks';
        
    EXCEPTION
        WHEN OTHER THEN
            UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS 
            SET status = 'FAILED', error_message = SQLERRM
            WHERE document_id = :DOC_ID;
            RETURN 'Error parsing document: ' || SQLERRM;
    END;
END;
$$;

-- Usage:
-- CALL PROCESSED.PARSE_DOCUMENT(1);
