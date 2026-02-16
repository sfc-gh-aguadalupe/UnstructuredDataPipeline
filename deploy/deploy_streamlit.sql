/*
=============================================================================
Deploy Streamlit App to Snowflake
=============================================================================
This script creates the Streamlit app after files are uploaded via Snow CLI.

Prerequisite: Upload files using Snow CLI first:
  snow streamlit deploy -c <connection> --database DOC_INTELLIGENCE --schema RAW --warehouse DOC_INTELLIGENCE_WH --replace
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- ============================================================================
-- OPTION 1: Deploy via Snow CLI (Recommended)
-- ============================================================================
/*
From terminal, run:

cd streamlit
snow streamlit deploy \
    --connection <your_connection> \
    --database DOC_INTELLIGENCE \
    --schema RAW \
    --warehouse DOC_INTELLIGENCE_WH \
    --replace \
    --open

This uploads files and creates the app in one command.
*/

-- ============================================================================
-- OPTION 2: Manual Stage Upload + SQL Creation
-- ============================================================================

-- Step 1: Create stage for Streamlit files
CREATE STAGE IF NOT EXISTS RAW.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Streamlit application files';

-- Step 2: Upload files via Snow CLI
/*
snow object stage copy app.py @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/ -c <connection> --overwrite
snow object stage copy environment.yml @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/ -c <connection> --overwrite
snow object stage copy pages/ @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/pages/ -c <connection> --overwrite --recursive
snow object stage copy utils/ @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/utils/ -c <connection> --overwrite --recursive
*/

-- Step 3: Verify files are uploaded
LIST @RAW.STREAMLIT_STAGE;

-- Step 4: Create the Streamlit app
CREATE OR REPLACE STREAMLIT RAW.DOC_INTELLIGENCE_APP
    ROOT_LOCATION = '@DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = DOC_INTELLIGENCE_WH
    COMMENT = 'Document Intelligence Pipeline - Search, classify, and annotate documents';

-- ============================================================================
-- POST-DEPLOYMENT
-- ============================================================================

-- Grant access to users/roles (adjust as needed)
-- GRANT USAGE ON STREAMLIT RAW.DOC_INTELLIGENCE_APP TO ROLE <your_role>;

-- Get app details
DESCRIBE STREAMLIT RAW.DOC_INTELLIGENCE_APP;

-- List all Streamlit apps
SHOW STREAMLITS IN SCHEMA RAW;

-- ============================================================================
-- Cleanup (if needed)
-- ============================================================================

-- DROP STREAMLIT IF EXISTS RAW.DOC_INTELLIGENCE_APP;
-- DROP STAGE IF EXISTS RAW.STREAMLIT_STAGE;
