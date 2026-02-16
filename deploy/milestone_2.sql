/*
=============================================================================
MILESTONE 2: Basic Semantic Model (Flat Taxonomy)
=============================================================================
Creates:
- Categories table (flat list for document classification)
- Tags table (flat list for multi-label annotation)
- Glossary table (domain terms with definitions)
- Initial seed data
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA SEMANTIC;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- =============================================================================
-- CATEGORIES TABLE (Flat - single classification per document)
-- =============================================================================
CREATE OR REPLACE TABLE SEMANTIC.CATEGORIES (
    category_id INT AUTOINCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE SEMANTIC.CATEGORIES IS 'Flat list of document categories for single-label classification';

-- =============================================================================
-- TAGS TABLE (Flat - multiple tags per document)
-- =============================================================================
CREATE OR REPLACE TABLE SEMANTIC.TAGS (
    tag_id INT AUTOINCREMENT PRIMARY KEY,
    tag_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE SEMANTIC.TAGS IS 'Flat list of tags for multi-label document annotation';

-- =============================================================================
-- GLOSSARY TABLE (Domain vocabulary)
-- =============================================================================
CREATE OR REPLACE TABLE SEMANTIC.GLOSSARY (
    term_id INT AUTOINCREMENT PRIMARY KEY,
    term VARCHAR(200) NOT NULL UNIQUE,
    definition VARCHAR(2000),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE SEMANTIC.GLOSSARY IS 'Domain-specific vocabulary to guide LLM annotation';

-- =============================================================================
-- SEED CATEGORIES (Customize for your domain)
-- =============================================================================
INSERT INTO SEMANTIC.CATEGORIES (category_name, description) VALUES
    ('Contract', 'Legal agreements, NDAs, service contracts, licenses'),
    ('Policy', 'Internal policies, procedures, guidelines'),
    ('Report', 'Business reports, analysis documents, summaries'),
    ('Correspondence', 'Emails, letters, memos, communications'),
    ('Technical', 'Technical documentation, specifications, manuals'),
    ('Financial', 'Financial statements, invoices, budgets'),
    ('HR', 'Human resources documents, employee records'),
    ('Marketing', 'Marketing materials, presentations, brochures'),
    ('Research', 'Research papers, studies, white papers'),
    ('Other', 'Documents that do not fit other categories');

-- =============================================================================
-- SEED TAGS (Customize for your domain)
-- =============================================================================
INSERT INTO SEMANTIC.TAGS (tag_name, description) VALUES
    ('Confidential', 'Contains sensitive or confidential information'),
    ('Public', 'Approved for public distribution'),
    ('Internal', 'For internal use only'),
    ('Draft', 'Document is in draft status'),
    ('Final', 'Document is finalized'),
    ('Archived', 'Historical document, no longer active'),
    ('Compliance', 'Related to regulatory compliance'),
    ('Legal-Review', 'Requires or has undergone legal review'),
    ('Urgent', 'Time-sensitive document'),
    ('Reference', 'Reference material for other work');

-- =============================================================================
-- SEED GLOSSARY (Customize for your domain)
-- =============================================================================
INSERT INTO SEMANTIC.GLOSSARY (term, definition) VALUES
    ('NDA', 'Non-Disclosure Agreement - a legal contract establishing confidentiality'),
    ('SLA', 'Service Level Agreement - defines expected service performance'),
    ('MSA', 'Master Service Agreement - overarching contract for ongoing services'),
    ('SOW', 'Statement of Work - detailed description of work to be performed'),
    ('PII', 'Personally Identifiable Information - data that can identify an individual'),
    ('GDPR', 'General Data Protection Regulation - EU data privacy law'),
    ('ROI', 'Return on Investment - measure of profitability'),
    ('KPI', 'Key Performance Indicator - metric for measuring success'),
    ('EOL', 'End of Life - product or service discontinuation'),
    ('SOP', 'Standard Operating Procedure - documented routine process');

-- =============================================================================
-- VERIFICATION
-- =============================================================================
SELECT 'Categories' as table_name, COUNT(*) as row_count FROM SEMANTIC.CATEGORIES
UNION ALL
SELECT 'Tags', COUNT(*) FROM SEMANTIC.TAGS
UNION ALL
SELECT 'Glossary', COUNT(*) FROM SEMANTIC.GLOSSARY;

SELECT 'Milestone 2 complete: Basic Semantic Model created' AS status;
