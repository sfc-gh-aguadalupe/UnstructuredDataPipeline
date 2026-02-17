/*
=============================================================================
MILESTONE 8 EXPERIMENT: Annotate with Ontology Procedure
=============================================================================
New annotation procedure that uses JSON-LD ontology instead of flat tables.
This demonstrates the full integration pattern.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA EXPERIMENT;

-- =============================================================================
-- ANNOTATE_WITH_ONTOLOGY: Annotate document using JSON-LD ontology
-- =============================================================================
CREATE OR REPLACE PROCEDURE ANNOTATE_WITH_ONTOLOGY(
    DOC_ID INT,
    ONTOLOGY_NAME VARCHAR DEFAULT 'EnterpriseDocumentOntology'
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    doc_text VARCHAR;
    prompt VARCHAR;
    llm_response VARCHAR;
    parsed_response VARIANT;
    category_label VARCHAR;
    category_path VARCHAR;
    v_confidence FLOAT;
    v_version VARCHAR;
    doc_count INT;
BEGIN
    -- Check document exists and is parsed
    SELECT COUNT(*) INTO :doc_count FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
    WHERE document_id = :DOC_ID AND status IN ('PARSED', 'ANNOTATED', 'COMPLETED');
    
    IF (doc_count = 0) THEN
        RETURN 'Error: Document not found or not yet parsed';
    END IF;
    
    -- Get ontology version
    SELECT version INTO :v_version
    FROM EXPERIMENT.ONTOLOGY_CACHE
    WHERE ontology_name = :ONTOLOGY_NAME AND is_current = TRUE;
    
    IF (v_version IS NULL) THEN
        RETURN 'Error: Ontology not found: ' || ONTOLOGY_NAME;
    END IF;
    
    -- Get document text from chunks
    SELECT LISTAGG(chunk_text, CHR(10) || CHR(10)) WITHIN GROUP (ORDER BY chunk_index)
    INTO :doc_text
    FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS
    WHERE document_id = :DOC_ID;
    
    IF (doc_text IS NULL OR LENGTH(doc_text) = 0) THEN
        RETURN 'Error: No text content found for document';
    END IF;
    
    -- Build prompt using ontology
    prompt := EXPERIMENT.BUILD_ONTOLOGY_PROMPT(doc_text, ONTOLOGY_NAME);
    
    BEGIN
        -- Call Cortex LLM (Claude 3.5 Sonnet)
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'claude-3-5-sonnet',
            :prompt,
            {'temperature': 0, 'max_tokens': 2000}
        ) INTO :llm_response;
        
        -- Parse JSON response - extract from potential markdown code block
        llm_response := REGEXP_REPLACE(llm_response, '^```json\\s*', '');
        llm_response := REGEXP_REPLACE(llm_response, '\\s*```$', '');
        llm_response := TRIM(llm_response);
        
        parsed_response := TRY_PARSE_JSON(llm_response);
        
        IF (parsed_response IS NULL) THEN
            RETURN 'Error: Failed to parse LLM response: ' || LEFT(llm_response, 500);
        END IF;
        
        -- Extract classification results
        category_label := parsed_response:category::VARCHAR;
        category_path := parsed_response:category_path::VARCHAR;
        v_confidence := NVL(parsed_response:confidence::FLOAT, 0.5);
        
        -- Delete existing experiment annotation for this document
        DELETE FROM EXPERIMENT.EXPERIMENT_ANNOTATIONS 
        WHERE document_id = :DOC_ID AND ontology_name = :ONTOLOGY_NAME;
        
        -- Insert experiment annotation
        INSERT INTO EXPERIMENT.EXPERIMENT_ANNOTATIONS (
            document_id,
            ontology_name,
            ontology_version,
            category_label,
            category_path,
            tags,
            summary,
            key_terms,
            entities,
            confidence,
            model_name
        )
        VALUES (
            :DOC_ID,
            :ONTOLOGY_NAME,
            :v_version,
            :category_label,
            :category_path,
            parsed_response:tags,
            parsed_response:summary::VARCHAR,
            parsed_response:key_terms,
            parsed_response:entities,
            :v_confidence,
            'claude-3-5-sonnet'
        );
        
        RETURN 'Successfully annotated document ' || DOC_ID || 
               ' as "' || category_path || 
               '" with confidence ' || v_confidence ||
               ' using ontology ' || ONTOLOGY_NAME;
        
    EXCEPTION
        WHEN OTHER THEN
            RETURN 'Error annotating document: ' || SQLERRM;
    END;
END;
$$;

-- =============================================================================
-- COMPARE_ANNOTATION_METHODS: Compare flat vs ontology annotation
-- =============================================================================
CREATE OR REPLACE PROCEDURE COMPARE_ANNOTATION_METHODS(
    DOC_ID INT,
    ONTOLOGY_NAME VARCHAR DEFAULT 'EnterpriseDocumentOntology'
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_file_name VARCHAR;
    v_flat_category VARCHAR;
    v_flat_tags ARRAY;
    v_flat_confidence FLOAT;
    v_ontology_path VARCHAR;
    v_ontology_category VARCHAR;
    v_ontology_tags ARRAY;
    v_ontology_confidence FLOAT;
    existing_count INT;
BEGIN
    -- Get document info
    SELECT file_name INTO :v_file_name
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS
    WHERE document_id = :DOC_ID;
    
    -- Get existing flat annotation (if exists)
    SELECT 
        c.category_name,
        a.tags,
        a.confidence
    INTO :v_flat_category, :v_flat_tags, :v_flat_confidence
    FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a
    JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
    WHERE a.document_id = :DOC_ID;
    
    -- Run ontology-based annotation
    CALL EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(:DOC_ID, :ONTOLOGY_NAME);
    
    -- Get ontology annotation result
    SELECT 
        category_path,
        category_label,
        tags,
        confidence
    INTO :v_ontology_path, :v_ontology_category, :v_ontology_tags, :v_ontology_confidence
    FROM EXPERIMENT.EXPERIMENT_ANNOTATIONS
    WHERE document_id = :DOC_ID AND ontology_name = :ONTOLOGY_NAME;
    
    -- Delete existing comparison for this document
    DELETE FROM EXPERIMENT.EXPERIMENT_COMPARISON WHERE document_id = :DOC_ID;
    
    -- Insert comparison record
    INSERT INTO EXPERIMENT.EXPERIMENT_COMPARISON (
        document_id,
        file_name,
        flat_category,
        flat_tags,
        flat_confidence,
        ontology_category_path,
        ontology_category_label,
        ontology_tags,
        ontology_confidence,
        categories_match
    )
    VALUES (
        :DOC_ID,
        :v_file_name,
        :v_flat_category,
        :v_flat_tags,
        :v_flat_confidence,
        :v_ontology_path,
        :v_ontology_category,
        :v_ontology_tags,
        :v_ontology_confidence,
        LOWER(:v_flat_category) = LOWER(:v_ontology_category)
    );
    
    RETURN 'Comparison complete for document ' || DOC_ID || CHR(10) ||
           'Flat taxonomy: ' || NVL(v_flat_category, 'N/A') || ' (confidence: ' || NVL(v_flat_confidence::VARCHAR, 'N/A') || ')' || CHR(10) ||
           'Ontology: ' || NVL(v_ontology_path, 'N/A') || ' (confidence: ' || NVL(v_ontology_confidence::VARCHAR, 'N/A') || ')';
           
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error comparing methods: ' || SQLERRM;
END;
$$;

SELECT 'Annotation procedures created successfully' AS status;
