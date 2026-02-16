/*
=============================================================================
Build Annotation Prompt Function
=============================================================================
Constructs the LLM prompt for document annotation with taxonomy constraints.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;

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
' || LEFT(doc_text, 200000) || '

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

-- Usage:
-- SELECT PROCESSED.BUILD_ANNOTATION_PROMPT('doc text', 'categories', 'tags', 'glossary');
