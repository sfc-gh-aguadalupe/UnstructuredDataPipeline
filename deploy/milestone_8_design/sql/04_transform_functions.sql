/*
=============================================================================
MILESTONE 8 EXPERIMENT: Transform Functions
=============================================================================
Functions to parse JSON-LD ontology and transform into LLM prompt text.

These functions demonstrate how to:
1. Extract classes from JSON-LD @graph
2. Build hierarchy from rdfs:subClassOf
3. Include synonyms from skos:altLabel
4. Generate natural language prompt text
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA EXPERIMENT;

-- =============================================================================
-- GET_ONTOLOGY_CLASSES: Extract flattened class list from JSON-LD
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

-- =============================================================================
-- GET_ONTOLOGY_HIERARCHY: Build hierarchical text representation
-- =============================================================================
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
        -- Root level (no parent or parent is Document)
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
        
        -- Children
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
        WHERE h.depth < 5  -- Prevent infinite loops
    )
    SELECT LISTAGG(
        REPEAT('  ', depth) || '- ' || class_label || 
        CASE WHEN description IS NOT NULL THEN ': ' || description ELSE '' END ||
        CASE WHEN synonyms IS NOT NULL AND synonyms != '' THEN ' (Also known as: ' || synonyms || ')' ELSE '' END ||
        CASE WHEN suggested_tags IS NOT NULL AND suggested_tags != '' THEN ' [Suggested tags: ' || suggested_tags || ']' ELSE '' END,
        CHR(10)
    ) WITHIN GROUP (ORDER BY path)
    FROM hierarchy
    WHERE class_label != 'Document'  -- Skip root
$$;

-- =============================================================================
-- GET_TAG_GROUPS: Extract tag groups with mutual exclusivity info
-- =============================================================================
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

-- =============================================================================
-- BUILD_ONTOLOGY_PROMPT: Main function to build LLM prompt from JSON-LD
-- =============================================================================
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
-- Test the functions
-- =============================================================================

-- Test: Get all classes from ontology
-- SELECT * FROM TABLE(EXPERIMENT.GET_ONTOLOGY_CLASSES('EnterpriseDocumentOntology'));

-- Test: Get hierarchy as text
-- SELECT EXPERIMENT.GET_ONTOLOGY_HIERARCHY('EnterpriseDocumentOntology');

-- Test: Get tag groups
-- SELECT EXPERIMENT.GET_TAG_GROUPS('EnterpriseDocumentOntology');

-- Test: Build full prompt (with sample text)
-- SELECT EXPERIMENT.BUILD_ONTOLOGY_PROMPT('This is a sample NDA document...', 'EnterpriseDocumentOntology');

SELECT 'Transform functions created successfully' AS status;
