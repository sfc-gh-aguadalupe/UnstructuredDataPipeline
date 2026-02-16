/*
=============================================================================
Document Intelligence Pipeline - Master Deployment Script
=============================================================================
This script deploys all milestones in sequence.
Run individual milestone scripts for incremental deployment.
=============================================================================
*/

-- Load configuration
!source ../config/settings.sql

-- =============================================================================
-- MILESTONE 1: Database & Stage Setup
-- =============================================================================
!source milestone_1.sql

-- =============================================================================
-- MILESTONE 2: Basic Semantic Model
-- =============================================================================
!source milestone_2.sql

-- =============================================================================
-- MILESTONE 3: Document Storage Tables
-- =============================================================================
!source milestone_3.sql

-- =============================================================================
-- MILESTONE 4: Document Ingestion Pipeline
-- =============================================================================
!source milestone_4.sql

-- =============================================================================
-- MILESTONE 5: Annotation Engine
-- =============================================================================
!source milestone_5.sql

-- =============================================================================
-- MILESTONE 6: Cortex Search Service
-- =============================================================================
!source milestone_6.sql

-- =============================================================================
-- MILESTONE 7: Streamlit Dashboard
-- Note: Streamlit app requires separate deployment via Snowsight
-- =============================================================================
-- See streamlit/ folder for application code

-- =============================================================================
-- MILESTONE 8: Advanced Semantic Model (Optional)
-- =============================================================================
-- Uncomment to deploy advanced taxonomy features
-- !source milestone_8.sql

-- =============================================================================
-- DEPLOYMENT COMPLETE
-- =============================================================================
SELECT 'Document Intelligence Pipeline deployment complete!' AS status;
