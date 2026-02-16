/*
=============================================================================
External Stage Setup (S3)
=============================================================================
Creates an external stage pointing to S3 for document ingestion.
Requires a storage integration to be created first.

Prerequisites:
1. Create storage integration (requires ACCOUNTADMIN):
   
   CREATE STORAGE INTEGRATION s3_doc_integration
     TYPE = EXTERNAL_STAGE
     STORAGE_PROVIDER = 'S3'
     ENABLED = TRUE
     STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account>:role/<role>'
     STORAGE_ALLOWED_LOCATIONS = ('s3://your-bucket/documents/');

2. Update the URL and STORAGE_INTEGRATION below.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA RAW;

-- Uncomment and modify after creating storage integration
/*
CREATE OR REPLACE STAGE S3_DOCUMENTS_STAGE
    URL = 's3://your-bucket/documents/'
    STORAGE_INTEGRATION = s3_doc_integration
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'External stage for S3 document ingestion';

-- Refresh directory table to index files
ALTER STAGE S3_DOCUMENTS_STAGE REFRESH;

-- Verify
SHOW STAGES LIKE 'S3_DOCUMENTS_STAGE' IN SCHEMA RAW;
SELECT * FROM DIRECTORY(@S3_DOCUMENTS_STAGE) LIMIT 10;
*/
