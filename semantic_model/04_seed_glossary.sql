/*
=============================================================================
Seed Glossary
=============================================================================
Domain vocabulary matching test document content.
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA SEMANTIC;

-- Clear existing
TRUNCATE TABLE GLOSSARY;

INSERT INTO GLOSSARY (term, definition) VALUES
    -- Legal/Contract terms
    ('NDA', 'Non-Disclosure Agreement - a legal contract establishing confidentiality obligations between parties'),
    ('MSA', 'Master Service Agreement - an overarching contract that establishes terms for ongoing business relationships'),
    ('SOW', 'Statement of Work - a document defining specific work to be performed under an MSA'),
    ('SLA', 'Service Level Agreement - defines expected service performance metrics and remedies'),
    ('Indemnification', 'A contractual obligation where one party agrees to compensate another for certain damages or losses'),
    ('Force Majeure', 'A contract clause that frees parties from liability due to extraordinary events beyond control'),
    
    -- Financial terms
    ('ARR', 'Annual Recurring Revenue - the yearly value of subscription-based revenue'),
    ('MRR', 'Monthly Recurring Revenue - the monthly value of subscription-based revenue'),
    ('EBITDA', 'Earnings Before Interest, Taxes, Depreciation, and Amortization'),
    ('YoY', 'Year-over-Year - comparison of metrics between the current and previous year'),
    ('QoQ', 'Quarter-over-Quarter - comparison of metrics between consecutive quarters'),
    ('Gross Margin', 'Revenue minus cost of goods sold, expressed as a percentage'),
    ('Free Cash Flow', 'Operating cash flow minus capital expenditures'),
    ('RPO', 'Remaining Performance Obligations - contracted revenue not yet recognized'),
    
    -- Technology terms
    ('API', 'Application Programming Interface - a set of protocols for building software applications'),
    ('SaaS', 'Software as a Service - cloud-based software delivery model'),
    ('CDC', 'Change Data Capture - a technique to track and capture data changes'),
    ('ETL', 'Extract, Transform, Load - a data integration process'),
    ('SDK', 'Software Development Kit - tools for building applications'),
    ('SSO', 'Single Sign-On - authentication allowing one login for multiple systems'),
    ('MFA', 'Multi-Factor Authentication - security requiring multiple verification methods'),
    
    -- Compliance terms
    ('HIPAA', 'Health Insurance Portability and Accountability Act - US healthcare data privacy law'),
    ('GDPR', 'General Data Protection Regulation - EU data privacy law'),
    ('SOC 2', 'Service Organization Control 2 - a security compliance framework'),
    ('PII', 'Personally Identifiable Information - data that can identify an individual'),
    ('PHI', 'Protected Health Information - health data protected under HIPAA'),
    ('BAA', 'Business Associate Agreement - HIPAA-required contract for handling PHI'),
    
    -- Business terms
    ('ROI', 'Return on Investment - measure of profitability relative to cost'),
    ('KPI', 'Key Performance Indicator - metric for measuring success'),
    ('NRR', 'Net Revenue Retention - measures revenue retained from existing customers including expansion'),
    ('GRR', 'Gross Revenue Retention - measures revenue retained excluding expansion'),
    ('CAC', 'Customer Acquisition Cost - cost to acquire a new customer'),
    ('LTV', 'Lifetime Value - total revenue expected from a customer relationship'),
    
    -- HR terms
    ('PTO', 'Paid Time Off - compensated leave from work'),
    ('FMLA', 'Family and Medical Leave Act - US law providing job-protected leave'),
    ('401k', 'A tax-advantaged retirement savings plan offered by employers'),
    ('COBRA', 'Consolidated Omnibus Budget Reconciliation Act - allows continuation of health coverage');

-- Verify
SELECT * FROM GLOSSARY ORDER BY term;
