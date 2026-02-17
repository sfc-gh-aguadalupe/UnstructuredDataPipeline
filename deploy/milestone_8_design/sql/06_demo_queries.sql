/*
=============================================================================
MILESTONE 8 EXPERIMENT: Demo Queries
=============================================================================
Example queries to demonstrate and test the JSON-LD ontology integration.
Run these after deploying scripts 01-05.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- =============================================================================
-- 1. EXPLORE THE CACHED ONTOLOGY
-- =============================================================================

-- View cached ontology metadata
SELECT 
    ontology_name,
    version,
    description,
    class_count,
    property_count,
    imported_at,
    is_current
FROM EXPERIMENT.ONTOLOGY_CACHE;

-- View the raw JSON-LD context
SELECT 
    ontology_name,
    json_ld:"@context" as jsonld_context
FROM EXPERIMENT.ONTOLOGY_CACHE
WHERE is_current = TRUE;

-- Count items in the @graph
SELECT 
    ontology_name,
    ARRAY_SIZE(json_ld:"@graph") as graph_items
FROM EXPERIMENT.ONTOLOGY_CACHE
WHERE is_current = TRUE;

-- =============================================================================
-- 2. EXTRACT CLASSES FROM JSON-LD
-- =============================================================================

-- View all classes with their hierarchy
SELECT 
    class_iri,
    class_label,
    parent_iri,
    description,
    synonyms,
    suggested_tags
FROM TABLE(EXPERIMENT.GET_ONTOLOGY_CLASSES('EnterpriseDocumentOntology'))
ORDER BY parent_iri NULLS FIRST, class_label;

-- Count classes by depth (root vs children)
SELECT 
    CASE WHEN parent_iri IS NULL THEN 'Root' ELSE 'Child' END as level,
    COUNT(*) as class_count
FROM TABLE(EXPERIMENT.GET_ONTOLOGY_CLASSES('EnterpriseDocumentOntology'))
GROUP BY 1;

-- =============================================================================
-- 3. VIEW GENERATED HIERARCHY TEXT
-- =============================================================================

-- This is what gets injected into the LLM prompt
SELECT EXPERIMENT.GET_ONTOLOGY_HIERARCHY('EnterpriseDocumentOntology') as hierarchy_prompt;

-- View tag groups
SELECT EXPERIMENT.GET_TAG_GROUPS('EnterpriseDocumentOntology') as tag_groups_prompt;

-- =============================================================================
-- 4. PREVIEW FULL PROMPT (without document)
-- =============================================================================

-- Preview the prompt structure with sample text
SELECT EXPERIMENT.BUILD_ONTOLOGY_PROMPT(
    'This is a sample Non-Disclosure Agreement between Acme Corp and TechStart Inc...',
    'EnterpriseDocumentOntology'
) as full_prompt;

-- =============================================================================
-- 5. ANNOTATE A DOCUMENT WITH ONTOLOGY
-- =============================================================================

-- List available parsed documents
SELECT 
    d.document_id,
    d.file_name,
    d.status,
    c.category_name as current_category,
    a.confidence as current_confidence
FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
LEFT JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
WHERE d.status IN ('PARSED', 'ANNOTATED', 'COMPLETED')
ORDER BY d.document_id;

-- Annotate a specific document with ontology (replace DOC_ID)
-- CALL EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(1, 'EnterpriseDocumentOntology');

-- =============================================================================
-- 6. COMPARE FLAT VS ONTOLOGY ANNOTATION
-- =============================================================================

-- Run comparison for a document (replace DOC_ID)
-- CALL EXPERIMENT.COMPARE_ANNOTATION_METHODS(1, 'EnterpriseDocumentOntology');

-- View comparison results
SELECT 
    document_id,
    file_name,
    flat_category,
    flat_confidence,
    ontology_category_path,
    ontology_category_label,
    ontology_confidence,
    categories_match,
    compared_at
FROM EXPERIMENT.EXPERIMENT_COMPARISON
ORDER BY compared_at DESC;

-- =============================================================================
-- 7. BATCH ANNOTATE ALL DOCUMENTS (for demo)
-- =============================================================================

-- Annotate all parsed documents with ontology
/*
DECLARE
    doc_cursor CURSOR FOR 
        SELECT document_id 
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
        WHERE status IN ('PARSED', 'ANNOTATED', 'COMPLETED');
    v_doc_id INT;
    v_result VARCHAR;
BEGIN
    FOR record IN doc_cursor DO
        v_doc_id := record.document_id;
        CALL EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(v_doc_id, 'EnterpriseDocumentOntology');
    END FOR;
    RETURN 'Batch annotation complete';
END;
*/

-- =============================================================================
-- 8. ANALYZE RESULTS
-- =============================================================================

-- View all experiment annotations
SELECT 
    ea.document_id,
    d.file_name,
    ea.category_path,
    ea.category_label,
    ea.tags,
    ea.confidence,
    ea.ontology_name,
    ea.created_at
FROM EXPERIMENT.EXPERIMENT_ANNOTATIONS ea
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON ea.document_id = d.document_id
ORDER BY ea.created_at DESC;

-- Compare category granularity: flat vs hierarchical
SELECT 
    d.file_name,
    c.category_name as flat_category,
    ea.category_path as ontology_path,
    ea.category_label as ontology_specific_category,
    CASE 
        WHEN ea.category_path LIKE '%>%' THEN 'More Specific'
        ELSE 'Same Level'
    END as granularity_improvement
FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
LEFT JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
LEFT JOIN EXPERIMENT.EXPERIMENT_ANNOTATIONS ea ON d.document_id = ea.document_id
WHERE d.status IN ('ANNOTATED', 'COMPLETED')
ORDER BY d.file_name;

-- Tag analysis: which suggested tags were actually applied?
SELECT 
    ea.document_id,
    d.file_name,
    ea.category_label,
    ea.tags as applied_tags,
    cls.suggested_tags as ontology_suggested_tags
FROM EXPERIMENT.EXPERIMENT_ANNOTATIONS ea
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON ea.document_id = d.document_id
LEFT JOIN TABLE(EXPERIMENT.GET_ONTOLOGY_CLASSES('EnterpriseDocumentOntology')) cls
    ON LOWER(cls.class_label) = LOWER(ea.category_label)
ORDER BY ea.document_id;

-- =============================================================================
-- 9. CLEANUP (if needed)
-- =============================================================================

-- Clear experiment annotations (keep ontology)
-- TRUNCATE TABLE EXPERIMENT.EXPERIMENT_ANNOTATIONS;
-- TRUNCATE TABLE EXPERIMENT.EXPERIMENT_COMPARISON;

-- Drop entire experiment schema (full reset)
-- DROP SCHEMA EXPERIMENT CASCADE;

SELECT 'Demo queries ready to run' AS status;
