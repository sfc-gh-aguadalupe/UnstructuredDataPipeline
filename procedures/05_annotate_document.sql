/*
=============================================================================
Annotate Document Procedure
=============================================================================
Annotates a single document using Cortex LLM with taxonomy constraints.
Uses Claude 4.5 Sonnet (claude-sonnet-4-5) for annotation.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

CREATE OR REPLACE PROCEDURE PROCESSED.ANNOTATE_DOCUMENT(DOC_ID INT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    doc_text VARCHAR;
    categories_list VARCHAR;
    tags_list VARCHAR;
    glossary_text VARCHAR;
    prompt VARCHAR;
    llm_response VARCHAR;
    parsed_response VARIANT;
    category_name VARCHAR;
    cat_id INT;
    v_confidence FLOAT;
    doc_count INT;
BEGIN
    -- Check document exists and is parsed
    SELECT COUNT(*) INTO :doc_count FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
    WHERE document_id = :DOC_ID AND status IN ('PARSED', 'ANNOTATED');
    
    IF (doc_count = 0) THEN
        RETURN 'Error: Document not found or not yet parsed';
    END IF;
    
    -- Get document text from chunks
    SELECT LISTAGG(chunk_text, CHR(10) || CHR(10)) WITHIN GROUP (ORDER BY chunk_index)
    INTO :doc_text
    FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS
    WHERE document_id = :DOC_ID;
    
    IF (doc_text IS NULL OR LENGTH(doc_text) = 0) THEN
        RETURN 'Error: No text content found for document';
    END IF;
    
    -- Get categories from semantic model
    SELECT LISTAGG(category_name || ': ' || NVL(description, ''), CHR(10)) WITHIN GROUP (ORDER BY category_id)
    INTO :categories_list
    FROM DOC_INTELLIGENCE.SEMANTIC.CATEGORIES
    WHERE is_active = TRUE;
    
    -- Get tags from semantic model
    SELECT LISTAGG(tag_name, ', ') WITHIN GROUP (ORDER BY tag_id)
    INTO :tags_list
    FROM DOC_INTELLIGENCE.SEMANTIC.TAGS
    WHERE is_active = TRUE;
    
    -- Get glossary from semantic model
    SELECT LISTAGG(term || ': ' || NVL(definition, ''), CHR(10)) WITHIN GROUP (ORDER BY term_id)
    INTO :glossary_text
    FROM DOC_INTELLIGENCE.SEMANTIC.GLOSSARY
    WHERE is_active = TRUE;
    
    -- Build prompt using helper function
    prompt := DOC_INTELLIGENCE.PROCESSED.BUILD_ANNOTATION_PROMPT(
        doc_text, categories_list, tags_list, glossary_text
    );
    
    BEGIN
        -- Call Cortex LLM (Claude 4.5 Sonnet)
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'claude-sonnet-4-5',
            :prompt,
            {'temperature': 0, 'max_tokens': 2000}
        ) INTO :llm_response;
        
        -- Parse JSON response - extract from potential markdown code block
        llm_response := REGEXP_REPLACE(llm_response, '^```json\\s*', '');
        llm_response := REGEXP_REPLACE(llm_response, '\\s*```$', '');
        llm_response := TRIM(llm_response);
        
        parsed_response := TRY_PARSE_JSON(llm_response);
        
        IF (parsed_response IS NULL) THEN
            UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS 
            SET status = 'FAILED', error_message = 'Failed to parse LLM response: ' || LEFT(llm_response, 500)
            WHERE document_id = :DOC_ID;
            RETURN 'Error: Failed to parse LLM response';
        END IF;
        
        -- Get category ID from semantic model
        category_name := parsed_response:category::VARCHAR;
        SELECT category_id INTO :cat_id
        FROM DOC_INTELLIGENCE.SEMANTIC.CATEGORIES
        WHERE LOWER(category_name) = LOWER(:category_name);
        
        -- Get confidence
        v_confidence := NVL(parsed_response:confidence::FLOAT, 0.5);
        
        -- Delete existing annotation for re-processing
        DELETE FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS WHERE document_id = :DOC_ID;
        
        -- Insert annotation
        INSERT INTO DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS (
            document_id,
            category_id,
            tags,
            summary,
            key_terms,
            entities,
            confidence,
            model_name
        )
        VALUES (
            :DOC_ID,
            :cat_id,
            parsed_response:tags,
            parsed_response:summary::VARCHAR,
            parsed_response:key_terms,
            parsed_response:entities,
            :v_confidence,
            'claude-sonnet-4-5'
        );
        
        -- Update document status
        UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS 
        SET status = 'ANNOTATED', annotated_at = CURRENT_TIMESTAMP()
        WHERE document_id = :DOC_ID;
        
        RETURN 'Successfully annotated document ' || DOC_ID || ' as "' || category_name || '" with confidence ' || v_confidence;
        
    EXCEPTION
        WHEN OTHER THEN
            UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS 
            SET status = 'FAILED', error_message = SQLERRM
            WHERE document_id = :DOC_ID;
            RETURN 'Error annotating document: ' || SQLERRM;
    END;
END;
$$;

-- Usage:
-- CALL PROCESSED.ANNOTATE_DOCUMENT(1);
