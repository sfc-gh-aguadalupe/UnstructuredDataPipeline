/*
=============================================================================
Document Intelligence Pipeline - Reset Data Script
=============================================================================
This script empties all data tables while preserving the database structure,
procedures, and configurations. Use this to re-run the test pipeline fresh.

Safe to run multiple times - does not drop any objects.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- ============================================================================
-- STEP 1: SUSPEND CORTEX SEARCH SERVICE
-- ============================================================================
-- The search service will be recreated after new data is loaded

ALTER CORTEX SEARCH SERVICE IF EXISTS PROCESSED.DOCUMENT_SEARCH_SERVICE SUSPEND;

-- ============================================================================
-- STEP 2: CLEAR PROCESSED DATA (in dependency order)
-- ============================================================================

-- Clear annotations
TRUNCATE TABLE IF EXISTS PROCESSED.ANNOTATIONS;

-- Clear document vectors
TRUNCATE TABLE IF EXISTS PROCESSED.DOCUMENT_VECTORS;

-- Clear document chunks
TRUNCATE TABLE IF EXISTS PROCESSED.DOCUMENT_CHUNKS;

-- ============================================================================
-- STEP 3: CLEAR RAW DATA
-- ============================================================================

-- Clear documents registry
TRUNCATE TABLE IF EXISTS RAW.DOCUMENTS;

-- ============================================================================
-- STEP 4: CLEAR ANALYTICS DATA (if exists)
-- ============================================================================

TRUNCATE TABLE IF EXISTS ANALYTICS.SEARCH_LOGS;
TRUNCATE TABLE IF EXISTS ANALYTICS.PIPELINE_METRICS;

-- ============================================================================
-- STEP 5: CLEAR FILES FROM INTERNAL STAGE (Optional)
-- ============================================================================
-- Uncomment the line below to also remove uploaded files from the stage
-- This will require re-uploading test documents

-- REMOVE @RAW.INTERNAL_DOCUMENTS_STAGE;

-- ============================================================================
-- STEP 6: RESUME CORTEX SEARCH SERVICE
-- ============================================================================
-- Resume the service - it will rebuild when new data is available

ALTER CORTEX SEARCH SERVICE IF EXISTS PROCESSED.DOCUMENT_SEARCH_SERVICE RESUME;

-- ============================================================================
-- VERIFICATION: Check tables are empty
-- ============================================================================

SELECT 'DOCUMENTS' as table_name, COUNT(*) as row_count FROM RAW.DOCUMENTS
UNION ALL
SELECT 'DOCUMENT_CHUNKS', COUNT(*) FROM PROCESSED.DOCUMENT_CHUNKS
UNION ALL
SELECT 'ANNOTATIONS', COUNT(*) FROM PROCESSED.ANNOTATIONS
UNION ALL
SELECT 'DOCUMENT_VECTORS', COUNT(*) FROM PROCESSED.DOCUMENT_VECTORS;

-- ============================================================================
-- VERIFICATION: Check stage still has files (if not cleared)
-- ============================================================================

-- LIST @RAW.INTERNAL_DOCUMENTS_STAGE;

-- ============================================================================
-- NEXT STEPS
-- ============================================================================
/*
After running this reset script, you can re-run the pipeline:

1. If you cleared the stage, re-upload test documents:
   
   PUT file:///path/to/tests/sample_documents/* @RAW.INTERNAL_DOCUMENTS_STAGE AUTO_COMPRESS=FALSE;

2. Register documents from stage:
   
   CALL RAW.REGISTER_NEW_DOCUMENTS('INTERNAL');

3. Run ingestion (parse documents):
   
   CALL PROCESSED.RUN_INGESTION();

4. Run annotation:
   
   CALL PROCESSED.RUN_ANNOTATION();

5. Or run the full pipeline in one call:
   
   CALL PROCESSED.RUN_FULL_PIPELINE();

6. Verify results:
   
   SELECT d.file_name, c.category_name, a.confidence, a.summary
   FROM RAW.DOCUMENTS d
   JOIN PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
   JOIN SEMANTIC.CATEGORIES c ON a.category_id = c.category_id;
*/
