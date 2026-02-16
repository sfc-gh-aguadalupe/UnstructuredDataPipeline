/*
=============================================================================
MILESTONE 7: Streamlit Dashboard
=============================================================================
Streamlit application for document search and management.

This milestone creates the UI components - no SQL deployment needed.
The Streamlit app connects to the existing Snowflake objects.

Files created:
- streamlit/app.py                    - Main dashboard
- streamlit/pages/1_search.py         - Document search
- streamlit/pages/2_document_viewer.py - Document details
- streamlit/pages/3_annotation_review.py - Review workflow
- streamlit/pages/4_analytics.py      - Statistics dashboard
- streamlit/pages/5_taxonomy_manager.py - Manage taxonomy
- streamlit/utils/snowflake_conn.py   - Connection utilities
- streamlit/utils/annotation_utils.py - Annotation helpers
- streamlit/utils/search_utils.py     - Search helpers
- streamlit/requirements.txt          - Python dependencies

=============================================================================
DEPLOYMENT OPTIONS
=============================================================================

OPTION 1: Streamlit in Snowflake (SiS)
--------------------------------------
1. Create a Streamlit app in Snowflake:
   - Go to Snowsight > Streamlit > + Streamlit App
   - Select DOC_INTELLIGENCE database
   - Copy contents of app.py into the editor
   - Add pages as separate files

2. Or use SQL:
*/

-- Create Streamlit app (requires appropriate privileges)
-- Note: Full Streamlit deployment typically done via Snowsight UI

/*
OPTION 2: Local Development
---------------------------
1. Install dependencies:
   cd streamlit
   pip install -r requirements.txt

2. Set environment variables:
   export SNOWFLAKE_ACCOUNT=your_account
   export SNOWFLAKE_USER=your_user
   export SNOWFLAKE_PASSWORD=your_password
   export SNOWFLAKE_WAREHOUSE=DOC_INTELLIGENCE_WH
   export SNOWFLAKE_DATABASE=DOC_INTELLIGENCE

3. Run the app:
   streamlit run app.py

=============================================================================
*/

-- Verify prerequisites
USE DATABASE DOC_INTELLIGENCE;

SELECT 'Prerequisites Check' as check_type;
SELECT COUNT(*) as categories FROM SEMANTIC.CATEGORIES;
SELECT COUNT(*) as tags FROM SEMANTIC.TAGS;
SELECT COUNT(*) as documents FROM RAW.DOCUMENTS;
SELECT COUNT(*) as annotations FROM PROCESSED.ANNOTATIONS;

SHOW CORTEX SEARCH SERVICES IN SCHEMA PROCESSED;
