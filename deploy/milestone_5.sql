/*
=============================================================================
MILESTONE 5: Annotation Engine
=============================================================================
Creates:
- PROCESSED.ANNOTATE_DOCUMENT - LLM-based annotation with taxonomy constraints
- PROCESSED.RUN_ANNOTATION - Batch annotate parsed documents
- Helper functions for prompt building
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- =============================================================================
-- BUILD_ANNOTATION_PROMPT: Helper function to construct LLM prompt
-- =============================================================================
CREATE OR REPLACE FUNCTION PROCESSED.BUILD_ANNOTATION_PROMPT(
    doc_text VARCHAR,
    categories_list VARCHAR,
    tags_list VARCHAR,
    glossary_text VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
'You are a document classification assistant. Analyze the document and return a JSON response.

INSTRUCTIONS:
1. Select exactly ONE category from the CATEGORIES list
2. Select ALL applicable tags from the TAGS list
3. Write a 2-3 sentence summary
4. Extract key terms (up to 10)
5. Extract named entities (people, organizations, dates, locations)
6. Provide a confidence score (0.0 to 1.0) for your classification

AVAILABLE CATEGORIES (select exactly one):
' || categories_list || '

AVAILABLE TAGS (select all that apply):
' || tags_list || '

DOMAIN GLOSSARY (use for context):
' || glossary_text || '

DOCUMENT TEXT:
' || LEFT(doc_text, 50000) || '

Respond with ONLY valid JSON in this exact format:
{
  "category": "<category_name>",
  "tags": ["<tag1>", "<tag2>"],
  "summary": "<2-3 sentence summary>",
  "key_terms": ["<term1>", "<term2>"],
  "entities": {
    "people": ["<name1>"],
    "organizations": ["<org1>"],
    "dates": ["<date1>"],
    "locations": ["<location1>"]
  },
  "confidence": <0.0-1.0>
}'
$$;

-- =============================================================================
-- ANNOTATE_DOCUMENT: Annotate a single document using Cortex LLM
-- =============================================================================
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
BEGIN
    -- Check document exists and is parsed
    SELECT COUNT(*) INTO :cat_id FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
    WHERE document_id = :DOC_ID AND status IN ('PARSED', 'ANNOTATED');
    
    IF (cat_id = 0) THEN
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
    
    -- Get categories
    SELECT LISTAGG(category_name || ': ' || NVL(description, ''), CHR(10)) WITHIN GROUP (ORDER BY category_id)
    INTO :categories_list
    FROM DOC_INTELLIGENCE.SEMANTIC.CATEGORIES
    WHERE is_active = TRUE;
    
    -- Get tags
    SELECT LISTAGG(tag_name, ', ') WITHIN GROUP (ORDER BY tag_id)
    INTO :tags_list
    FROM DOC_INTELLIGENCE.SEMANTIC.TAGS
    WHERE is_active = TRUE;
    
    -- Get glossary
    SELECT LISTAGG(term || ': ' || NVL(definition, ''), CHR(10)) WITHIN GROUP (ORDER BY term_id)
    INTO :glossary_text
    FROM DOC_INTELLIGENCE.SEMANTIC.GLOSSARY
    WHERE is_active = TRUE;
    
    -- Build prompt
    prompt := DOC_INTELLIGENCE.PROCESSED.BUILD_ANNOTATION_PROMPT(
        doc_text, categories_list, tags_list, glossary_text
    );
    
    BEGIN
        -- Call Cortex LLM
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
        
        -- Get category ID
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

-- =============================================================================
-- RUN_ANNOTATION: Batch annotate all parsed documents
-- =============================================================================
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

-- =============================================================================
-- FULL_PIPELINE: Run ingestion + annotation in one call
-- =============================================================================
CREATE OR REPLACE PROCEDURE RAW.FULL_PIPELINE(SOURCE_NAME VARCHAR, MAX_DOCS INT DEFAULT 10)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    ingest_result VARCHAR;
    annotate_result VARCHAR;
BEGIN
    -- Run ingestion
    CALL DOC_INTELLIGENCE.RAW.RUN_INGESTION(:SOURCE_NAME, :MAX_DOCS) INTO :ingest_result;
    
    -- Run annotation
    CALL DOC_INTELLIGENCE.PROCESSED.RUN_ANNOTATION(:MAX_DOCS) INTO :annotate_result;
    
    RETURN ingest_result || ' | ' || annotate_result;
END;
$$;

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SHOW PROCEDURES IN SCHEMA DOC_INTELLIGENCE.PROCESSED;

SELECT 'Milestone 5 complete: Annotation Engine created' AS status;
