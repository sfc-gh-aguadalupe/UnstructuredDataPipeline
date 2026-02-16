/*
=============================================================================
Document Intelligence Pipeline - Cleanup Script
=============================================================================
This script removes all objects created by the Document Intelligence Pipeline.

WARNING: This will permanently delete all data, procedures, and configurations!

Usage Options:
  1. Full cleanup (removes everything including database and warehouse)
  2. Partial cleanup (keeps database/warehouse, removes only data and objects)

Run the sections you need based on your cleanup requirements.
=============================================================================
*/

-- ============================================================================
-- SECTION 1: DROP CORTEX SEARCH SERVICE
-- ============================================================================
-- Must be dropped before the underlying view/table

DROP CORTEX SEARCH SERVICE IF EXISTS DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE;

-- ============================================================================
-- SECTION 2: DROP VIEWS
-- ============================================================================

DROP VIEW IF EXISTS DOC_INTELLIGENCE.PROCESSED.SEARCHABLE_DOCUMENTS;

-- ============================================================================
-- SECTION 3: DROP STORED PROCEDURES
-- ============================================================================

-- Main pipeline procedures
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.RUN_FULL_PIPELINE();
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.RUN_ANNOTATION(INT);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.RUN_ANNOTATION();
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.ANNOTATE_DOCUMENT(INT);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.BUILD_ANNOTATION_PROMPT(VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.RUN_INGESTION(VARCHAR);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.RUN_INGESTION();
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.PARSE_DOCUMENT(INT);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.RAW.REGISTER_NEW_DOCUMENTS(VARCHAR);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.RAW.REGISTER_NEW_DOCUMENTS();

-- Search helper procedures
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.SEARCH_DOCUMENTS(VARCHAR, INT);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.SEARCH_BY_CATEGORY(VARCHAR, INT);
DROP PROCEDURE IF EXISTS DOC_INTELLIGENCE.PROCESSED.SEARCH_BY_TAG(VARCHAR, INT);

-- ============================================================================
-- SECTION 4: DROP FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS DOC_INTELLIGENCE.PROCESSED.BUILD_ANNOTATION_PROMPT(VARCHAR, VARCHAR, VARCHAR, VARCHAR);

-- ============================================================================
-- SECTION 5: DROP TABLES (in dependency order)
-- ============================================================================

-- Analytics tables
DROP TABLE IF EXISTS DOC_INTELLIGENCE.ANALYTICS.SEARCH_LOGS;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.ANALYTICS.PIPELINE_METRICS;

-- Processed schema tables
DROP TABLE IF EXISTS DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.PROCESSED.DOCUMENT_VECTORS;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS;

-- Semantic model tables
DROP TABLE IF EXISTS DOC_INTELLIGENCE.SEMANTIC.GLOSSARY;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.SEMANTIC.TAGS;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.SEMANTIC.CATEGORIES;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.SEMANTIC.CATEGORY_HIERARCHY;

-- Raw schema tables
DROP TABLE IF EXISTS DOC_INTELLIGENCE.RAW.INGESTION_SOURCES;
DROP TABLE IF EXISTS DOC_INTELLIGENCE.RAW.DOCUMENTS;

-- ============================================================================
-- SECTION 6: DROP STAGES
-- ============================================================================

DROP STAGE IF EXISTS DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE;
DROP STAGE IF EXISTS DOC_INTELLIGENCE.RAW.EXTERNAL_DOCUMENTS_STAGE;

-- ============================================================================
-- SECTION 7: DROP SCHEMAS
-- ============================================================================

DROP SCHEMA IF EXISTS DOC_INTELLIGENCE.ANALYTICS;
DROP SCHEMA IF EXISTS DOC_INTELLIGENCE.PROCESSED;
DROP SCHEMA IF EXISTS DOC_INTELLIGENCE.SEMANTIC;
DROP SCHEMA IF EXISTS DOC_INTELLIGENCE.RAW;

-- ============================================================================
-- SECTION 8: DROP DATABASE (CAUTION!)
-- ============================================================================
-- Uncomment the line below to drop the entire database

-- DROP DATABASE IF EXISTS DOC_INTELLIGENCE;

-- ============================================================================
-- SECTION 9: DROP WAREHOUSE (CAUTION!)
-- ============================================================================
-- Uncomment the line below to drop the warehouse

-- DROP WAREHOUSE IF EXISTS DOC_INTELLIGENCE_WH;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify cleanup was successful

-- Check if database still exists
-- SHOW DATABASES LIKE 'DOC_INTELLIGENCE';

-- Check if warehouse still exists  
-- SHOW WAREHOUSES LIKE 'DOC_INTELLIGENCE_WH';

-- ============================================================================
-- QUICK CLEANUP (Copy-paste friendly single statement versions)
-- ============================================================================

/*
-- To drop everything in one go (WARNING: Irreversible!):

DROP CORTEX SEARCH SERVICE IF EXISTS DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE;
DROP DATABASE IF EXISTS DOC_INTELLIGENCE;
DROP WAREHOUSE IF EXISTS DOC_INTELLIGENCE_WH;

*/

/*
-- To reset data only (keeps structure):

TRUNCATE TABLE IF EXISTS DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS;
TRUNCATE TABLE IF EXISTS DOC_INTELLIGENCE.PROCESSED.DOCUMENT_VECTORS;
TRUNCATE TABLE IF EXISTS DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS;
TRUNCATE TABLE IF EXISTS DOC_INTELLIGENCE.RAW.DOCUMENTS;

*/
