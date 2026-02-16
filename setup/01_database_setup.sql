/*
=============================================================================
Database Setup
=============================================================================
Creates the DOC_INTELLIGENCE database and schemas.
=============================================================================
*/

CREATE DATABASE IF NOT EXISTS DOC_INTELLIGENCE;

USE DATABASE DOC_INTELLIGENCE;

CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS PROCESSED;
CREATE SCHEMA IF NOT EXISTS SEMANTIC;
CREATE SCHEMA IF NOT EXISTS ANALYTICS;

-- Verify
SHOW SCHEMAS IN DATABASE DOC_INTELLIGENCE;
