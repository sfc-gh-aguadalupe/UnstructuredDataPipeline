/*
=============================================================================
MILESTONE 8 EXPERIMENT: Full Deployment Script
=============================================================================
Deploys the complete JSON-LD ontology experiment.

Run this script to set up the entire experiment in one go.
=============================================================================
*/

-- =============================================================================
-- STEP 1: Create Isolated Schema
-- =============================================================================
USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

CREATE SCHEMA IF NOT EXISTS EXPERIMENT;
COMMENT ON SCHEMA EXPERIMENT IS 'Isolated schema for Milestone 8 JSON-LD ontology experiment';

USE SCHEMA EXPERIMENT;

-- =============================================================================
-- STEP 2: Create Ontology Tables
-- =============================================================================

CREATE OR REPLACE TABLE ONTOLOGY_CACHE (
    cache_id INT AUTOINCREMENT PRIMARY KEY,
    ontology_name VARCHAR(200) NOT NULL,
    version VARCHAR(50) NOT NULL,
    description VARCHAR(1000),
    source_system VARCHAR(100) DEFAULT 'AnzoGraph',
    graph_uri VARCHAR(500),
    json_ld VARIANT NOT NULL,
    class_count INT,
    property_count INT,
    imported_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    imported_by VARCHAR(100) DEFAULT CURRENT_USER(),
    expires_at TIMESTAMP_NTZ,
    is_current BOOLEAN DEFAULT TRUE,
    checksum VARCHAR(64)
);

CREATE OR REPLACE TABLE EXPERIMENT_ANNOTATIONS (
    annotation_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL,
    ontology_name VARCHAR(200),
    ontology_version VARCHAR(50),
    category_iri VARCHAR(500),
    category_label VARCHAR(200),
    parent_category_label VARCHAR(200),
    category_path VARCHAR(1000),
    tags ARRAY,
    summary VARCHAR(4000),
    key_terms ARRAY,
    entities VARIANT,
    confidence FLOAT,
    model_name VARCHAR(100),
    prompt_tokens INT,
    completion_tokens INT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    matched_existing_category VARCHAR(200),
    classification_method VARCHAR(50) DEFAULT 'JSONLD_ONTOLOGY'
);

CREATE OR REPLACE TABLE EXPERIMENT_COMPARISON (
    comparison_id INT AUTOINCREMENT PRIMARY KEY,
    document_id INT NOT NULL,
    file_name VARCHAR(500),
    flat_category VARCHAR(200),
    flat_tags ARRAY,
    flat_confidence FLOAT,
    ontology_category_path VARCHAR(1000),
    ontology_category_label VARCHAR(200),
    ontology_tags ARRAY,
    ontology_confidence FLOAT,
    categories_match BOOLEAN,
    tags_overlap_pct FLOAT,
    notes VARCHAR(2000),
    compared_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- STEP 3: Create Transform Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION GET_ONTOLOGY_CLASSES(ontology_name_param VARCHAR)
RETURNS TABLE (
    class_iri VARCHAR,
    class_label VARCHAR,
    parent_iri VARCHAR,
    description VARCHAR,
    synonyms ARRAY,
    suggested_tags ARRAY
)
LANGUAGE SQL
AS
$$
    SELECT 
        f.value:"@id"::VARCHAR as class_iri,
        f.value:"rdfs:label"::VARCHAR as class_label,
        f.value:"rdfs:subClassOf":"@id"::VARCHAR as parent_iri,
        f.value:"rdfs:comment"::VARCHAR as description,
        f.value:"skos:altLabel"::ARRAY as synonyms,
        f.value:"ent:suggestedTags"::ARRAY as suggested_tags
    FROM EXPERIMENT.ONTOLOGY_CACHE c,
    LATERAL FLATTEN(input => c.json_ld:"@graph") f
    WHERE c.ontology_name = ontology_name_param
      AND c.is_current = TRUE
      AND f.value:"@type"::VARCHAR IN ('rdfs:Class', 'owl:Class')
$$;

CREATE OR REPLACE FUNCTION GET_ONTOLOGY_HIERARCHY(ontology_name_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    WITH RECURSIVE classes AS (
        SELECT 
            f.value:"@id"::VARCHAR as class_iri,
            f.value:"rdfs:label"::VARCHAR as class_label,
            f.value:"rdfs:subClassOf":"@id"::VARCHAR as parent_iri,
            f.value:"rdfs:comment"::VARCHAR as description,
            ARRAY_TO_STRING(f.value:"skos:altLabel"::ARRAY, ', ') as synonyms,
            ARRAY_TO_STRING(f.value:"ent:suggestedTags"::ARRAY, ', ') as suggested_tags
        FROM EXPERIMENT.ONTOLOGY_CACHE c,
        LATERAL FLATTEN(input => c.json_ld:"@graph") f
        WHERE c.ontology_name = ontology_name_param
          AND c.is_current = TRUE
          AND f.value:"@type"::VARCHAR IN ('rdfs:Class', 'owl:Class')
    ),
    hierarchy AS (
        SELECT 
            class_iri,
            class_label,
            parent_iri,
            description,
            synonyms,
            suggested_tags,
            0 as depth,
            class_label as path
        FROM classes
        WHERE parent_iri IS NULL 
           OR parent_iri = 'ent:Document'
           OR class_iri = 'ent:Document'
        
        UNION ALL
        
        SELECT 
            c.class_iri,
            c.class_label,
            c.parent_iri,
            c.description,
            c.synonyms,
            c.suggested_tags,
            h.depth + 1,
            h.path || ' > ' || c.class_label
        FROM classes c
        JOIN hierarchy h ON c.parent_iri = h.class_iri
        WHERE h.depth < 5
    )
    SELECT LISTAGG(
        REPEAT('  ', depth) || '- ' || class_label || 
        CASE WHEN description IS NOT NULL THEN ': ' || description ELSE '' END ||
        CASE WHEN synonyms IS NOT NULL AND synonyms != '' THEN ' (Also known as: ' || synonyms || ')' ELSE '' END ||
        CASE WHEN suggested_tags IS NOT NULL AND suggested_tags != '' THEN ' [Suggested tags: ' || suggested_tags || ']' ELSE '' END,
        CHR(10)
    ) WITHIN GROUP (ORDER BY path)
    FROM hierarchy
    WHERE class_label != 'Document'
$$;

CREATE OR REPLACE FUNCTION GET_TAG_GROUPS(ontology_name_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT LISTAGG(
        f.value:"rdfs:label"::VARCHAR || 
        CASE WHEN f.value:"ent:isMutuallyExclusive"::BOOLEAN THEN ' (select ONE)' ELSE ' (select all that apply)' END ||
        ': ' || ARRAY_TO_STRING(f.value:"ent:tags"::ARRAY, ', '),
        CHR(10)
    ) WITHIN GROUP (ORDER BY f.value:"rdfs:label"::VARCHAR)
    FROM EXPERIMENT.ONTOLOGY_CACHE c,
    LATERAL FLATTEN(input => c.json_ld:"@graph") f
    WHERE c.ontology_name = ontology_name_param
      AND c.is_current = TRUE
      AND f.value:"@type"::VARCHAR = 'ent:TagGroup'
$$;

CREATE OR REPLACE FUNCTION BUILD_ONTOLOGY_PROMPT(
    doc_text VARCHAR,
    ontology_name_param VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
'You are a document classification assistant using a hierarchical ontology. Analyze the document and return a JSON response.

INSTRUCTIONS:
1. Select the MOST SPECIFIC category from the CATEGORY HIERARCHY below
2. Follow the hierarchy path (e.g., "Legal Document > Contract > NDA")
3. Use synonyms to help identify document types
4. Select ALL applicable tags, respecting mutual exclusivity rules
5. Write a 2-3 sentence summary
6. Extract key terms (up to 10)
7. Extract named entities (people, organizations, dates, locations)
8. Provide a confidence score (0.0 to 1.0)

CATEGORY HIERARCHY (select the most specific applicable category):
' || EXPERIMENT.GET_ONTOLOGY_HIERARCHY(ontology_name_param) || '

TAG GROUPS:
' || EXPERIMENT.GET_TAG_GROUPS(ontology_name_param) || '

DOCUMENT TEXT:
' || LEFT(doc_text, 50000) || '

Respond with ONLY valid JSON in this exact format:
{
  "category_path": "<Parent > Child > MostSpecific>",
  "category": "<most_specific_category_name>",
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
-- STEP 4: Create Annotation Procedures
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
    SELECT COUNT(*) INTO :doc_count FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
    WHERE document_id = :DOC_ID AND status IN ('PARSED', 'ANNOTATED', 'COMPLETED');
    
    IF (doc_count = 0) THEN
        RETURN 'Error: Document not found or not yet parsed';
    END IF;
    
    SELECT version INTO :v_version
    FROM EXPERIMENT.ONTOLOGY_CACHE
    WHERE ontology_name = :ONTOLOGY_NAME AND is_current = TRUE;
    
    IF (v_version IS NULL) THEN
        RETURN 'Error: Ontology not found: ' || ONTOLOGY_NAME;
    END IF;
    
    SELECT LISTAGG(chunk_text, CHR(10) || CHR(10)) WITHIN GROUP (ORDER BY chunk_index)
    INTO :doc_text
    FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS
    WHERE document_id = :DOC_ID;
    
    IF (doc_text IS NULL OR LENGTH(doc_text) = 0) THEN
        RETURN 'Error: No text content found for document';
    END IF;
    
    prompt := EXPERIMENT.BUILD_ONTOLOGY_PROMPT(doc_text, ONTOLOGY_NAME);
    
    BEGIN
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'claude-3-5-sonnet',
            :prompt,
            {'temperature': 0, 'max_tokens': 2000}
        ) INTO :llm_response;
        
        llm_response := REGEXP_REPLACE(llm_response, '^```json\\s*', '');
        llm_response := REGEXP_REPLACE(llm_response, '\\s*```$', '');
        llm_response := TRIM(llm_response);
        
        parsed_response := TRY_PARSE_JSON(llm_response);
        
        IF (parsed_response IS NULL) THEN
            RETURN 'Error: Failed to parse LLM response: ' || LEFT(llm_response, 500);
        END IF;
        
        category_label := parsed_response:category::VARCHAR;
        category_path := parsed_response:category_path::VARCHAR;
        v_confidence := NVL(parsed_response:confidence::FLOAT, 0.5);
        
        DELETE FROM EXPERIMENT.EXPERIMENT_ANNOTATIONS 
        WHERE document_id = :DOC_ID AND ontology_name = :ONTOLOGY_NAME;
        
        INSERT INTO EXPERIMENT.EXPERIMENT_ANNOTATIONS (
            document_id, ontology_name, ontology_version, category_label, category_path,
            tags, summary, key_terms, entities, confidence, model_name
        )
        VALUES (
            :DOC_ID, :ONTOLOGY_NAME, :v_version, :category_label, :category_path,
            parsed_response:tags, parsed_response:summary::VARCHAR,
            parsed_response:key_terms, parsed_response:entities, :v_confidence, 'claude-3-5-sonnet'
        );
        
        RETURN 'Successfully annotated document ' || DOC_ID || ' as "' || category_path || 
               '" with confidence ' || v_confidence || ' using ontology ' || ONTOLOGY_NAME;
        
    EXCEPTION
        WHEN OTHER THEN
            RETURN 'Error annotating document: ' || SQLERRM;
    END;
END;
$$;

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
BEGIN
    SELECT file_name INTO :v_file_name
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS WHERE document_id = :DOC_ID;
    
    SELECT c.category_name, a.tags, a.confidence
    INTO :v_flat_category, :v_flat_tags, :v_flat_confidence
    FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a
    JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
    WHERE a.document_id = :DOC_ID;
    
    CALL EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(:DOC_ID, :ONTOLOGY_NAME);
    
    SELECT category_path, category_label, tags, confidence
    INTO :v_ontology_path, :v_ontology_category, :v_ontology_tags, :v_ontology_confidence
    FROM EXPERIMENT.EXPERIMENT_ANNOTATIONS
    WHERE document_id = :DOC_ID AND ontology_name = :ONTOLOGY_NAME;
    
    DELETE FROM EXPERIMENT.EXPERIMENT_COMPARISON WHERE document_id = :DOC_ID;
    
    INSERT INTO EXPERIMENT.EXPERIMENT_COMPARISON (
        document_id, file_name, flat_category, flat_tags, flat_confidence,
        ontology_category_path, ontology_category_label, ontology_tags, ontology_confidence, categories_match
    )
    VALUES (
        :DOC_ID, :v_file_name, :v_flat_category, :v_flat_tags, :v_flat_confidence,
        :v_ontology_path, :v_ontology_category, :v_ontology_tags, :v_ontology_confidence,
        LOWER(:v_flat_category) = LOWER(:v_ontology_category)
    );
    
    RETURN 'Comparison complete for document ' || DOC_ID || CHR(10) ||
           'Flat: ' || NVL(v_flat_category, 'N/A') || ' (conf: ' || NVL(v_flat_confidence::VARCHAR, 'N/A') || ')' || CHR(10) ||
           'Ontology: ' || NVL(v_ontology_path, 'N/A') || ' (conf: ' || NVL(v_ontology_confidence::VARCHAR, 'N/A') || ')';
           
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error comparing methods: ' || SQLERRM;
END;
$$;

-- =============================================================================
-- STEP 5: Insert Sample JSON-LD Ontology
-- =============================================================================

DELETE FROM ONTOLOGY_CACHE WHERE ontology_name = 'EnterpriseDocumentOntology';

INSERT INTO ONTOLOGY_CACHE (
    ontology_name, version, description, source_system, graph_uri, json_ld, class_count, property_count, is_current
)
SELECT
    'EnterpriseDocumentOntology',
    '1.0.0',
    'Hierarchical document classification ontology for enterprise documents',
    'AnzoGraph (Simulated)',
    'https://customer.com/ontology/documents',
    PARSE_JSON($${
  "@context": {
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "skos": "http://www.w3.org/2004/02/skos/core#",
    "owl": "http://www.w3.org/2002/07/owl#",
    "ent": "https://customer.com/ontology#",
    "xsd": "http://www.w3.org/2001/XMLSchema#"
  },
  "@graph": [
    {"@id": "ent:Document", "@type": "rdfs:Class", "rdfs:label": "Document", "rdfs:comment": "Root class for all enterprise documents"},
    {"@id": "ent:LegalDocument", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Document"}, "rdfs:label": "Legal Document", "rdfs:comment": "Documents with legal implications, agreements, or regulatory requirements", "ent:suggestedTags": ["Legal-Review-Required"]},
    {"@id": "ent:Contract", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:LegalDocument"}, "rdfs:label": "Contract", "rdfs:comment": "Legally binding agreements between two or more parties", "ent:suggestedTags": ["Legal-Review-Required", "Requires-Signature"]},
    {"@id": "ent:NDA", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Contract"}, "rdfs:label": "Non-Disclosure Agreement", "rdfs:comment": "Agreement establishing confidentiality obligations between parties", "skos:altLabel": ["Confidentiality Agreement", "Secrecy Agreement", "CDA"], "ent:suggestedTags": ["Confidential", "Contains-PII", "Legal-Review-Required"]},
    {"@id": "ent:MSA", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Contract"}, "rdfs:label": "Master Service Agreement", "rdfs:comment": "Overarching contract establishing general terms for ongoing business relationship", "skos:altLabel": ["Master Services Agreement", "Framework Agreement"], "ent:suggestedTags": ["Legal-Review-Required", "Vendor-Related"]},
    {"@id": "ent:SOW", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Contract"}, "rdfs:label": "Statement of Work", "rdfs:comment": "Document defining specific work, deliverables, timelines, and costs", "skos:altLabel": ["Work Order", "Service Order"], "ent:suggestedTags": ["Vendor-Related", "Financial-Data"]},
    {"@id": "ent:EmploymentAgreement", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Contract"}, "rdfs:label": "Employment Agreement", "rdfs:comment": "Contract between employer and employee", "skos:altLabel": ["Employment Contract", "Offer Letter"], "ent:suggestedTags": ["Confidential", "Contains-PII", "HR-Related"]},
    {"@id": "ent:Policy", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:LegalDocument"}, "rdfs:label": "Policy", "rdfs:comment": "Internal rules and guidelines governing organizational behavior", "ent:suggestedTags": ["Internal"]},
    {"@id": "ent:SecurityPolicy", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Policy"}, "rdfs:label": "Security Policy", "rdfs:comment": "Policies governing information security and data protection", "skos:altLabel": ["InfoSec Policy", "Cybersecurity Policy"], "ent:suggestedTags": ["Internal", "SOC2", "Restricted"]},
    {"@id": "ent:HRPolicy", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Policy"}, "rdfs:label": "HR Policy", "rdfs:comment": "Human resources policies including conduct and benefits", "skos:altLabel": ["Human Resources Policy", "Employee Policy"], "ent:suggestedTags": ["Internal", "HR-Related"]},
    {"@id": "ent:PrivacyPolicy", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Policy"}, "rdfs:label": "Privacy Policy", "rdfs:comment": "Policies governing collection and protection of personal data", "skos:altLabel": ["Data Privacy Policy", "GDPR Policy"], "ent:suggestedTags": ["GDPR", "Contains-PII", "Customer-Facing"]},
    {"@id": "ent:FinancialDocument", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Document"}, "rdfs:label": "Financial Document", "rdfs:comment": "Documents containing financial data or investor communications", "ent:suggestedTags": ["Financial-Data", "Restricted"]},
    {"@id": "ent:QuarterlyReport", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:FinancialDocument"}, "rdfs:label": "Quarterly Report", "rdfs:comment": "Financial performance report covering a three-month period", "skos:altLabel": ["Q1 Report", "Q2 Report", "10-Q"], "ent:suggestedTags": ["Financial-Data", "Investor-Relations", "Executive-Summary"]},
    {"@id": "ent:AnnualReport", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:FinancialDocument"}, "rdfs:label": "Annual Report", "rdfs:comment": "Comprehensive yearly report on company performance", "skos:altLabel": ["10-K", "Year-End Report"], "ent:suggestedTags": ["Financial-Data", "Investor-Relations", "Public"]},
    {"@id": "ent:TechnicalDocument", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Document"}, "rdfs:label": "Technical Document", "rdfs:comment": "Documents describing technical specifications or architecture", "ent:suggestedTags": ["Internal"]},
    {"@id": "ent:PRD", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:TechnicalDocument"}, "rdfs:label": "Product Requirements Document", "rdfs:comment": "Document specifying product features and requirements", "skos:altLabel": ["PRD", "Requirements Doc", "Product Spec"], "ent:suggestedTags": ["Internal", "Draft"]},
    {"@id": "ent:ArchitectureDoc", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:TechnicalDocument"}, "rdfs:label": "Architecture Document", "rdfs:comment": "Technical documentation describing system architecture", "skos:altLabel": ["Design Doc", "Technical Design", "HLD"], "ent:suggestedTags": ["Internal", "Technical"]},
    {"@id": "ent:APIDocumentation", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:TechnicalDocument"}, "rdfs:label": "API Documentation", "rdfs:comment": "Documentation describing API endpoints and usage", "skos:altLabel": ["API Docs", "API Reference"], "ent:suggestedTags": ["Technical", "Customer-Facing"]},
    {"@id": "ent:HealthcareDocument", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:Document"}, "rdfs:label": "Healthcare Document", "rdfs:comment": "Documents related to healthcare or medical compliance", "ent:suggestedTags": ["HIPAA", "Contains-PHI", "Restricted"]},
    {"@id": "ent:MedicalRecord", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:HealthcareDocument"}, "rdfs:label": "Medical Record", "rdfs:comment": "Patient health information documentation", "skos:altLabel": ["Patient Record", "Health Record"], "ent:suggestedTags": ["HIPAA", "Contains-PHI", "Confidential", "Restricted"]},
    {"@id": "ent:BAA", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "ent:HealthcareDocument"}, "rdfs:label": "Business Associate Agreement", "rdfs:comment": "HIPAA-required agreement with PHI-handling vendors", "skos:altLabel": ["BAA", "HIPAA BAA"], "ent:suggestedTags": ["HIPAA", "Legal-Review-Required", "Vendor-Related"]},
    {"@id": "ent:TagGroup_Confidentiality", "@type": "ent:TagGroup", "rdfs:label": "Confidentiality Level", "rdfs:comment": "Mutually exclusive confidentiality tags", "ent:isMutuallyExclusive": true, "ent:tags": ["Public", "Internal", "Confidential", "Restricted"]},
    {"@id": "ent:TagGroup_Status", "@type": "ent:TagGroup", "rdfs:label": "Document Status", "rdfs:comment": "Mutually exclusive document lifecycle tags", "ent:isMutuallyExclusive": true, "ent:tags": ["Draft", "Under-Review", "Final", "Archived"]},
    {"@id": "ent:TagGroup_Compliance", "@type": "ent:TagGroup", "rdfs:label": "Compliance Framework", "rdfs:comment": "Non-exclusive compliance framework tags", "ent:isMutuallyExclusive": false, "ent:tags": ["HIPAA", "GDPR", "SOC2", "PCI-DSS"]}
  ]
}$$),
    21, 8, TRUE;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT 'Milestone 8 Experiment deployed successfully!' AS status;

-- Show what was created
SHOW TABLES IN SCHEMA EXPERIMENT;
SHOW FUNCTIONS IN SCHEMA EXPERIMENT;
SHOW PROCEDURES IN SCHEMA EXPERIMENT;

-- Test hierarchy generation
SELECT EXPERIMENT.GET_ONTOLOGY_HIERARCHY('EnterpriseDocumentOntology') AS category_hierarchy;
