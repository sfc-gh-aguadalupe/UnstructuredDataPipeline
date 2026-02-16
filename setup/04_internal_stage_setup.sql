/*
=============================================================================
Internal Stage Setup
=============================================================================
Creates an internal stage for manual document uploads.
Directory table is enabled for file discovery.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA RAW;

CREATE OR REPLACE STAGE INTERNAL_DOCUMENTS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage for manual document uploads';

-- Verify
SHOW STAGES LIKE 'INTERNAL_DOCUMENTS_STAGE' IN SCHEMA RAW;

-- Usage:
-- PUT file:///path/to/document.pdf @RAW.INTERNAL_DOCUMENTS_STAGE;
-- ALTER STAGE INTERNAL_DOCUMENTS_STAGE REFRESH;
-- SELECT * FROM DIRECTORY(@INTERNAL_DOCUMENTS_STAGE);
