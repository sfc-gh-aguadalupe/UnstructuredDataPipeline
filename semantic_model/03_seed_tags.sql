/*
=============================================================================
Seed Tags
=============================================================================
Tags matching test document content.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA SEMANTIC;

-- Clear existing
TRUNCATE TABLE TAGS;

INSERT INTO TAGS (tag_name, description) VALUES
    -- Confidentiality tags
    ('Confidential', 'Contains sensitive or confidential information'),
    ('Public', 'Approved for public distribution'),
    ('Internal', 'For internal use only'),
    ('Restricted', 'Highly restricted access required'),
    
    -- Status tags
    ('Draft', 'Document is in draft status'),
    ('Final', 'Document is finalized and approved'),
    ('Archived', 'Historical document, no longer active'),
    ('Under-Review', 'Document is currently under review'),
    
    -- Compliance tags
    ('HIPAA', 'Related to HIPAA healthcare compliance'),
    ('GDPR', 'Related to GDPR data privacy compliance'),
    ('SOC2', 'Related to SOC 2 security compliance'),
    ('PCI-DSS', 'Related to payment card data security'),
    
    -- Content type tags
    ('Legal-Review-Required', 'Requires or has undergone legal review'),
    ('Contains-PII', 'Contains personally identifiable information'),
    ('Contains-PHI', 'Contains protected health information'),
    ('Financial-Data', 'Contains financial figures or projections'),
    
    -- Business area tags
    ('Executive-Summary', 'Contains executive summary or overview'),
    ('Investor-Relations', 'Related to investor communications'),
    ('Customer-Facing', 'Intended for customer distribution'),
    ('Vendor-Related', 'Related to vendor or supplier relationships');

-- Verify
SELECT * FROM TAGS ORDER BY tag_id;
