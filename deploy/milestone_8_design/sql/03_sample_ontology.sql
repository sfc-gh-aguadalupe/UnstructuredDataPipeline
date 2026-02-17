/*
=============================================================================
MILESTONE 8 EXPERIMENT: Sample JSON-LD Ontology
=============================================================================
Inserts a sample hierarchical ontology in JSON-LD format.
This simulates what would be exported from AnzoGraph.

The ontology includes:
- Hierarchical categories (rdfs:subClassOf)
- Synonyms (skos:altLabel)
- Suggested tags (custom property)
- Rich descriptions (rdfs:comment)
- Tag groups with mutual exclusivity
=============================================================================
*/

USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA EXPERIMENT;

-- Clear existing cache for fresh insert
DELETE FROM ONTOLOGY_CACHE WHERE ontology_name = 'EnterpriseDocumentOntology';

-- Insert sample JSON-LD ontology
INSERT INTO ONTOLOGY_CACHE (
    ontology_name,
    version,
    description,
    source_system,
    graph_uri,
    json_ld,
    class_count,
    property_count,
    is_current
)
SELECT
    'EnterpriseDocumentOntology',
    '1.0.0',
    'Hierarchical document classification ontology for enterprise documents',
    'AnzoGraph (Simulated)',
    'https://customer.com/ontology/documents',
    PARSE_JSON($${
  "@context": {
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "skos": "http://www.w3.org/2004/02/skos/core#",
    "owl": "http://www.w3.org/2002/07/owl#",
    "ent": "https://customer.com/ontology#",
    "xsd": "http://www.w3.org/2001/XMLSchema#"
  },
  "@graph": [
    {
      "@id": "ent:Document",
      "@type": "rdfs:Class",
      "rdfs:label": "Document",
      "rdfs:comment": "Root class for all enterprise documents"
    },
    
    {
      "@id": "ent:LegalDocument",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Document"},
      "rdfs:label": "Legal Document",
      "rdfs:comment": "Documents with legal implications, agreements, or regulatory requirements",
      "ent:suggestedTags": ["Legal-Review-Required"]
    },
    {
      "@id": "ent:Contract",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:LegalDocument"},
      "rdfs:label": "Contract",
      "rdfs:comment": "Legally binding agreements between two or more parties establishing rights and obligations",
      "ent:suggestedTags": ["Legal-Review-Required", "Requires-Signature"]
    },
    {
      "@id": "ent:NDA",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Contract"},
      "rdfs:label": "Non-Disclosure Agreement",
      "rdfs:comment": "Agreement establishing confidentiality obligations between parties regarding proprietary or sensitive information",
      "skos:altLabel": ["Confidentiality Agreement", "Secrecy Agreement", "CDA"],
      "ent:suggestedTags": ["Confidential", "Contains-PII", "Legal-Review-Required"],
      "ent:typicalEntities": ["parties", "effective_date", "term_length", "governing_law"]
    },
    {
      "@id": "ent:MSA",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Contract"},
      "rdfs:label": "Master Service Agreement",
      "rdfs:comment": "Overarching contract establishing general terms for ongoing business relationship and future service orders",
      "skos:altLabel": ["Master Services Agreement", "Framework Agreement", "Umbrella Agreement"],
      "ent:suggestedTags": ["Legal-Review-Required", "Vendor-Related"],
      "ent:relatedClasses": ["ent:SOW"]
    },
    {
      "@id": "ent:SOW",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Contract"},
      "rdfs:label": "Statement of Work",
      "rdfs:comment": "Document defining specific work to be performed, deliverables, timelines, and costs under a master agreement",
      "skos:altLabel": ["Work Order", "Service Order", "Project Scope"],
      "ent:suggestedTags": ["Vendor-Related", "Financial-Data"],
      "ent:relatedClasses": ["ent:MSA"]
    },
    {
      "@id": "ent:EmploymentAgreement",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Contract"},
      "rdfs:label": "Employment Agreement",
      "rdfs:comment": "Contract between employer and employee defining terms of employment",
      "skos:altLabel": ["Employment Contract", "Offer Letter", "Job Contract"],
      "ent:suggestedTags": ["Confidential", "Contains-PII", "HR-Related"]
    },
    
    {
      "@id": "ent:Policy",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:LegalDocument"},
      "rdfs:label": "Policy",
      "rdfs:comment": "Internal rules, guidelines, and standards governing organizational behavior and processes",
      "ent:suggestedTags": ["Internal"]
    },
    {
      "@id": "ent:SecurityPolicy",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Policy"},
      "rdfs:label": "Security Policy",
      "rdfs:comment": "Policies governing information security, access control, and data protection",
      "skos:altLabel": ["InfoSec Policy", "Cybersecurity Policy"],
      "ent:suggestedTags": ["Internal", "SOC2", "Restricted"]
    },
    {
      "@id": "ent:HRPolicy",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Policy"},
      "rdfs:label": "HR Policy",
      "rdfs:comment": "Human resources policies including conduct, benefits, leave, and workplace guidelines",
      "skos:altLabel": ["Human Resources Policy", "Employee Policy", "Workplace Policy"],
      "ent:suggestedTags": ["Internal", "HR-Related"]
    },
    {
      "@id": "ent:PrivacyPolicy",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Policy"},
      "rdfs:label": "Privacy Policy",
      "rdfs:comment": "Policies governing collection, use, and protection of personal data",
      "skos:altLabel": ["Data Privacy Policy", "GDPR Policy"],
      "ent:suggestedTags": ["GDPR", "Contains-PII", "Customer-Facing"]
    },
    
    {
      "@id": "ent:FinancialDocument",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Document"},
      "rdfs:label": "Financial Document",
      "rdfs:comment": "Documents containing financial data, reports, projections, or investor communications",
      "ent:suggestedTags": ["Financial-Data", "Restricted"]
    },
    {
      "@id": "ent:QuarterlyReport",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:FinancialDocument"},
      "rdfs:label": "Quarterly Report",
      "rdfs:comment": "Financial performance report covering a three-month fiscal period",
      "skos:altLabel": ["Q1 Report", "Q2 Report", "Q3 Report", "Q4 Report", "10-Q"],
      "ent:suggestedTags": ["Financial-Data", "Investor-Relations", "Executive-Summary"]
    },
    {
      "@id": "ent:AnnualReport",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:FinancialDocument"},
      "rdfs:label": "Annual Report",
      "rdfs:comment": "Comprehensive yearly report on company performance, strategy, and financial position",
      "skos:altLabel": ["10-K", "Year-End Report", "Yearly Report"],
      "ent:suggestedTags": ["Financial-Data", "Investor-Relations", "Executive-Summary", "Public"]
    },
    {
      "@id": "ent:BudgetDocument",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:FinancialDocument"},
      "rdfs:label": "Budget Document",
      "rdfs:comment": "Financial planning documents including budgets, forecasts, and resource allocation",
      "skos:altLabel": ["Budget Plan", "Financial Forecast", "Cost Projection"],
      "ent:suggestedTags": ["Financial-Data", "Internal", "Restricted"]
    },
    
    {
      "@id": "ent:TechnicalDocument",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Document"},
      "rdfs:label": "Technical Document",
      "rdfs:comment": "Documents describing technical specifications, architecture, or implementation details",
      "ent:suggestedTags": ["Internal"]
    },
    {
      "@id": "ent:PRD",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:TechnicalDocument"},
      "rdfs:label": "Product Requirements Document",
      "rdfs:comment": "Document specifying product features, requirements, and acceptance criteria",
      "skos:altLabel": ["PRD", "Requirements Doc", "Product Spec", "Feature Spec"],
      "ent:suggestedTags": ["Internal", "Draft"]
    },
    {
      "@id": "ent:ArchitectureDoc",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:TechnicalDocument"},
      "rdfs:label": "Architecture Document",
      "rdfs:comment": "Technical documentation describing system architecture, design decisions, and component interactions",
      "skos:altLabel": ["Design Doc", "Technical Design", "System Architecture", "HLD"],
      "ent:suggestedTags": ["Internal", "Technical"]
    },
    {
      "@id": "ent:APIDocumentation",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:TechnicalDocument"},
      "rdfs:label": "API Documentation",
      "rdfs:comment": "Documentation describing API endpoints, parameters, authentication, and usage examples",
      "skos:altLabel": ["API Docs", "API Reference", "Developer Docs"],
      "ent:suggestedTags": ["Technical", "Customer-Facing"]
    },
    
    {
      "@id": "ent:HealthcareDocument",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Document"},
      "rdfs:label": "Healthcare Document",
      "rdfs:comment": "Documents related to healthcare, medical records, or health compliance",
      "ent:suggestedTags": ["HIPAA", "Contains-PHI", "Restricted"]
    },
    {
      "@id": "ent:MedicalRecord",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:HealthcareDocument"},
      "rdfs:label": "Medical Record",
      "rdfs:comment": "Patient health information and medical history documentation",
      "skos:altLabel": ["Patient Record", "Health Record", "PHI Document"],
      "ent:suggestedTags": ["HIPAA", "Contains-PHI", "Confidential", "Restricted"]
    },
    {
      "@id": "ent:BAA",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:HealthcareDocument"},
      "rdfs:label": "Business Associate Agreement",
      "rdfs:comment": "HIPAA-required agreement with vendors who handle protected health information",
      "skos:altLabel": ["BAA", "HIPAA BAA", "Business Associate Contract"],
      "ent:suggestedTags": ["HIPAA", "Legal-Review-Required", "Vendor-Related"]
    },
    
    {
      "@id": "ent:TagGroup_Confidentiality",
      "@type": "ent:TagGroup",
      "rdfs:label": "Confidentiality Level",
      "rdfs:comment": "Mutually exclusive tags for document confidentiality classification",
      "ent:isMutuallyExclusive": true,
      "ent:tags": ["Public", "Internal", "Confidential", "Restricted"]
    },
    {
      "@id": "ent:TagGroup_Status",
      "@type": "ent:TagGroup",
      "rdfs:label": "Document Status",
      "rdfs:comment": "Mutually exclusive tags for document lifecycle status",
      "ent:isMutuallyExclusive": true,
      "ent:tags": ["Draft", "Under-Review", "Final", "Archived"]
    },
    {
      "@id": "ent:TagGroup_Compliance",
      "@type": "ent:TagGroup",
      "rdfs:label": "Compliance Framework",
      "rdfs:comment": "Non-exclusive tags for applicable compliance frameworks",
      "ent:isMutuallyExclusive": false,
      "ent:tags": ["HIPAA", "GDPR", "SOC2", "PCI-DSS"]
    }
  ]
}$$),
    22,  -- class_count
    8,   -- property_count
    TRUE;

-- Verify insert
SELECT 
    ontology_name,
    version,
    class_count,
    imported_at,
    is_current
FROM ONTOLOGY_CACHE
WHERE ontology_name = 'EnterpriseDocumentOntology';

-- Preview the JSON-LD structure
SELECT 
    json_ld:"@context" as context,
    ARRAY_SIZE(json_ld:"@graph") as graph_size
FROM ONTOLOGY_CACHE
WHERE is_current = TRUE;

SELECT 'Sample JSON-LD ontology inserted successfully' AS status;
