/*
=============================================================================
Seed Categories
=============================================================================
Document categories matching test documents.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA SEMANTIC;

-- Clear existing
TRUNCATE TABLE CATEGORIES;

INSERT INTO CATEGORIES (category_name, description) VALUES
    ('Contract', 'Legal agreements including NDAs, MSAs, SOWs, and service contracts'),
    ('Policy', 'Internal policies including HR, security, IT, and compliance policies'),
    ('Financial Report', 'Financial documents including quarterly reports, annual reports, and investor communications'),
    ('Technical Document', 'Technical specifications, PRDs, architecture documents, and API documentation'),
    ('HR Document', 'Human resources documents including handbooks, offer letters, and employee records'),
    ('Marketing Material', 'Marketing content including presentations, brochures, and case studies'),
    ('Research', 'Research papers, white papers, and analytical studies'),
    ('Correspondence', 'Business communications including emails, memos, and letters'),
    ('Proposal', 'Business proposals, RFP responses, and quotes'),
    ('Other', 'Documents that do not fit other categories');

-- Verify
SELECT * FROM CATEGORIES ORDER BY category_id;
