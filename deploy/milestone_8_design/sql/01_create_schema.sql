/*
=============================================================================
MILESTONE 8 EXPERIMENT: Create Isolated Schema
=============================================================================
Creates a separate schema for the JSON-LD ontology experiment.
This keeps the experiment isolated from the production pipeline.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- Create isolated experiment schema
CREATE SCHEMA IF NOT EXISTS EXPERIMENT;

COMMENT ON SCHEMA EXPERIMENT IS 'Isolated schema for Milestone 8 JSON-LD ontology experiment';

-- Verify
SHOW SCHEMAS LIKE 'EXPERIMENT' IN DATABASE DOC_INTELLIGENCE;

SELECT 'Schema EXPERIMENT created successfully' AS status;
