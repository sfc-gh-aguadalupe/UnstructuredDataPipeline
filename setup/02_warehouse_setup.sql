/*
=============================================================================
Warehouse Setup
=============================================================================
Creates the processing warehouse for the document pipeline.
=============================================================================
*/

CREATE WAREHOUSE IF NOT EXISTS DOC_INTELLIGENCE_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- Grant usage if needed
-- GRANT USAGE ON WAREHOUSE DOC_INTELLIGENCE_WH TO ROLE <your_role>;
