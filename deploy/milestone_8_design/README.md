# Milestone 8: Advanced Semantic Model - Design Document

## Executive Summary

This document outlines three architectural options for integrating an **enterprise ontology** (managed in AnzoGraph) with the **Snowflake Cortex annotation pipeline**. The goal is to use the customer's existing ontology to constrain and guide LLM-based document classification.

**Key Requirement**: The enterprise ontology in AnzoGraph must remain the source of truth. We need a seamless integration that doesn't require rebuilding the ontology in relational tables.

---

## Current State

### Existing Pipeline (Milestones 1-7)

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Documents      │────▶│  Cortex COMPLETE │────▶│  Annotations    │
│  (Snowflake)    │     │  (claude-3-5)    │     │  (Snowflake)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Flat Taxonomy       │
                    │  (Snowflake Tables)  │
                    │  - CATEGORIES        │
                    │  - TAGS              │
                    │  - GLOSSARY          │
                    └──────────────────────┘
```

### Target State (Milestone 8)

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Documents      │────▶│  Cortex COMPLETE │────▶│  Annotations    │
│  (Snowflake)    │     │  (claude-3-5)    │     │  (Snowflake)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Enterprise Ontology │
                    │  (AnzoGraph)         │
                    │  - Hierarchical      │
                    │  - Relationships     │
                    │  - SKOS/OWL/RDF      │
                    └──────────────────────┘
```

---

## Technical Context

### AnzoGraph Capabilities

AnzoGraph is Cambridge Semantics' massively parallel graph database that:
- Stores RDF/OWL/SKOS ontologies natively
- Exposes standard **SPARQL 1.1 endpoints** (HTTP GET/POST)
- Supports **JSON-LD export** via CONSTRUCT queries
- Handles deep hierarchies and complex relationships efficiently

**Endpoint Example:**
```
https://anzograph.customer.com:7070/sparql
```

### Snowflake Cortex Requirements

The annotation pipeline needs ontology data to:
1. **Build prompts** - Inject available categories/tags into LLM prompts
2. **Validate outputs** - Ensure LLM responses match valid ontology classes
3. **Store traceability** - Link annotations back to ontology IRIs

---

## Integration Options

### Option 1: Real-Time External Function (Direct SPARQL Queries)

Query AnzoGraph's SPARQL endpoint directly from Snowflake during annotation.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        REAL-TIME INTEGRATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐     ┌───────────────────┐     ┌───────────────────────┐  │
│  │   AnzoGraph   │◄───▶│ Snowflake         │────▶│   Cortex COMPLETE     │  │
│  │   SPARQL      │     │ External Function │     │                       │  │
│  │   Endpoint    │     │ (Python UDF)      │     │   LLM Annotation      │  │
│  └───────────────┘     └───────────────────┘     └───────────────────────┘  │
│         ▲                      │                                            │
│         │                      │                                            │
│    Live Query              JSON Response                                    │
│    per annotation          transformed to                                   │
│                            prompt text                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Implementation Components

1. **Network Rule** - Allow Snowflake to reach AnzoGraph endpoint
2. **External Access Integration** - Configure egress permissions
3. **Secret** - Store AnzoGraph credentials securely
4. **Python UDF** - Execute SPARQL queries and return results

#### Sample SPARQL Query

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX ent: <https://customer.com/ontology#>

SELECT ?class ?label ?description ?parent ?parentLabel
WHERE {
    ?class a rdfs:Class ;
           rdfs:label ?label .
    OPTIONAL { ?class rdfs:comment ?description }
    OPTIONAL { 
        ?class rdfs:subClassOf ?parent .
        ?parent rdfs:label ?parentLabel 
    }
}
ORDER BY ?parent ?label
```

#### Pros

| Benefit | Description |
|---------|-------------|
| Always Current | Every annotation uses the latest ontology state |
| No Data Duplication | AnzoGraph is the single source of truth |
| Simple Architecture | No sync jobs or cache management |
| Immediate Updates | Ontology changes reflected instantly |

#### Cons

| Drawback | Description |
|----------|-------------|
| Latency | 100-500ms added per annotation for SPARQL query |
| Dependency | Annotation fails if AnzoGraph is unavailable |
| Network Costs | Egress charges for external calls |
| Rate Limits | May need throttling for batch annotation |

#### Best For

- Small to medium ontologies (< 1,000 classes)
- Frequently changing ontologies
- Low annotation volume (< 1,000 docs/day)
- Environments where ontology freshness is critical

---

### Option 2: Scheduled Cache with JSON-LD (Recommended)

Periodically export ontology from AnzoGraph and cache in Snowflake as JSON-LD.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CACHED INTEGRATION                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐                          ┌───────────────────────────┐   │
│  │   AnzoGraph   │    Scheduled Export      │   Cortex COMPLETE         │   │
│  │   (Master)    │ ─────────────────────┐   │                           │   │
│  │               │    (hourly/daily)    │   │   LLM Annotation          │   │
│  └───────────────┘                      │   └───────────────────────────┘   │
│                                         │              ▲                    │
│                                         ▼              │                    │
│                              ┌──────────────────────┐  │                    │
│                              │  Snowflake Cache     │──┘                    │
│                              │  (VARIANT column)    │                       │
│                              │                      │                       │
│                              │  - JSON-LD format    │                       │
│                              │  - Full hierarchy    │                       │
│                              │  - Versioned         │                       │
│                              └──────────────────────┘                       │
│                                         │                                   │
│                                         ▼                                   │
│                              ┌──────────────────────┐                       │
│                              │  Transform Function  │                       │
│                              │  JSON-LD → NL Prompt │                       │
│                              └──────────────────────┘                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Implementation Components

1. **Cache Table** - Store JSON-LD exports with versioning
2. **Refresh Procedure** - Python stored proc to query AnzoGraph
3. **Scheduled Task** - Automate periodic refresh
4. **Transform View/Function** - Convert JSON-LD to prompt text

#### Data Model

```sql
CREATE TABLE SEMANTIC.ONTOLOGY_CACHE (
    cache_id INT AUTOINCREMENT PRIMARY KEY,
    export_format VARCHAR(20),           -- 'JSON-LD', 'TURTLE', 'N-QUADS'
    ontology_data VARIANT,               -- Full JSON-LD document
    graph_uri VARCHAR(500),              -- Source graph in AnzoGraph
    sparql_query VARCHAR(4000),          -- Query used to generate export
    class_count INT,                     -- Number of classes exported
    relationship_count INT,              -- Number of relationships
    exported_at TIMESTAMP_NTZ,
    expires_at TIMESTAMP_NTZ,
    is_current BOOLEAN DEFAULT TRUE,
    checksum VARCHAR(64)                 -- Detect changes
);
```

#### Sample JSON-LD Cache Content

```json
{
  "@context": {
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "skos": "http://www.w3.org/2004/02/skos/core#",
    "ent": "https://customer.com/ontology#"
  },
  "@graph": [
    {
      "@id": "ent:LegalDocument",
      "@type": "rdfs:Class",
      "rdfs:label": "Legal Document",
      "rdfs:comment": "Documents with legal implications or requirements"
    },
    {
      "@id": "ent:Contract",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:LegalDocument"},
      "rdfs:label": "Contract",
      "rdfs:comment": "A legally binding agreement between parties",
      "ent:suggestedTags": ["Requires-Signature", "Legal-Review-Required"]
    },
    {
      "@id": "ent:NDA",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Contract"},
      "rdfs:label": "Non-Disclosure Agreement",
      "rdfs:comment": "Agreement establishing confidentiality between parties",
      "skos:altLabel": ["Confidentiality Agreement", "Secrecy Agreement"],
      "ent:suggestedTags": ["Confidential", "Contains-PII"]
    }
  ]
}
```

#### Pros

| Benefit | Description |
|---------|-------------|
| Performance | No latency during annotation (cached locally) |
| Resilience | Annotation continues even if AnzoGraph is down |
| JSON-LD Preserved | Native format maintained for compliance |
| Versioning | Can compare ontology versions over time |
| Auditability | Full traceability to source |

#### Cons

| Drawback | Description |
|----------|-------------|
| Staleness | Cache may be behind AnzoGraph (configurable lag) |
| Storage | Duplicate data in Snowflake |
| Sync Complexity | Need to manage refresh jobs |
| Transform Logic | Need to convert JSON-LD to prompt text |

#### Best For

- Large ontologies (1,000+ classes)
- Stable ontologies (changes daily/weekly, not hourly)
- High annotation volume (batch processing)
- Production environments requiring resilience

---

### Option 3: Hybrid - Live Queries with Local Enrichment

Combine AnzoGraph queries with Snowflake-managed prompt enhancements.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HYBRID INTEGRATION                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐                      ┌───────────────────────────────┐   │
│  │   AnzoGraph   │    Structure         │   Snowflake                   │   │
│  │   (Master)    │ ──────────────────▶  │   ONTOLOGY_ENHANCEMENTS       │   │
│  │               │    (classes,         │                               │   │
│  │  - Classes    │     hierarchy)       │   - Few-shot examples         │   │
│  │  - Hierarchy  │                      │   - Custom descriptions       │   │
│  │  - Relations  │                      │   - Prompt templates          │   │
│  └───────────────┘                      │   - Local refinements         │   │
│                                         └───────────────────────────────┘   │
│                                                    │                        │
│                                                    ▼                        │
│                                         ┌───────────────────────────────┐   │
│                                         │   Merged Prompt               │   │
│                                         │                               │   │
│                                         │   AnzoGraph structure         │   │
│                                         │   + Snowflake examples        │   │
│                                         │   + Custom descriptions       │   │
│                                         └───────────────────────────────┘   │
│                                                    │                        │
│                                                    ▼                        │
│                                         ┌───────────────────────────────┐   │
│                                         │   Cortex COMPLETE             │   │
│                                         └───────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Implementation Components

1. **Lightweight Sync** - Pull class IRIs and labels from AnzoGraph
2. **Enhancement Table** - Store local additions (examples, descriptions)
3. **Merge Function** - Combine AnzoGraph structure with local data

#### Data Model

```sql
-- Lightweight reference to AnzoGraph (not duplicating ontology)
CREATE TABLE SEMANTIC.ONTOLOGY_ENHANCEMENTS (
    class_iri VARCHAR(500) PRIMARY KEY,     -- Reference to AnzoGraph IRI
    custom_description VARCHAR(2000),       -- LLM-optimized description
    few_shot_examples VARIANT,              -- JSON array of examples
    prompt_template VARCHAR(4000),          -- Custom prompt snippet
    suggested_tags ARRAY,                   -- Override/enhance tags
    is_active BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP_NTZ,
    enhanced_by VARCHAR(100),
    enhanced_at TIMESTAMP_NTZ
);
```

#### Pros

| Benefit | Description |
|---------|-------------|
| Flexibility | Can customize prompts without changing ontology |
| Best of Both | AnzoGraph for structure, Snowflake for tuning |
| Few-Shot Learning | Add examples that improve LLM accuracy |
| Domain Adaptation | Refine descriptions for specific use cases |

#### Cons

| Drawback | Description |
|----------|-------------|
| Complexity | Two systems to manage |
| Sync Issues | Enhancements may reference deleted classes |
| Maintenance | Need to keep enhancements aligned with ontology |
| Governance | Unclear which system is authoritative for what |

#### Best For

- Organizations with ML/prompt engineering teams
- Need to tune LLM performance iteratively
- Ontology is stable but prompt quality needs improvement
- Want to A/B test different prompt strategies

---

## Comparison Matrix

| Criteria | Option 1: Real-Time | Option 2: Cached | Option 3: Hybrid |
|----------|---------------------|------------------|------------------|
| **AnzoGraph as Source of Truth** | Yes | Yes | Partial |
| **Annotation Latency** | +100-500ms | None | +50-100ms |
| **Resilience (AnzoGraph down)** | Fails | Works | Partial |
| **Data Freshness** | Real-time | Configurable lag | Mixed |
| **Implementation Complexity** | Medium | Medium | High |
| **Operational Complexity** | Low | Medium | High |
| **JSON-LD Preservation** | No (parsed) | Yes (cached) | No |
| **Prompt Customization** | Limited | Limited | Full |
| **Storage Overhead** | None | Medium | Low |
| **Best For** | Small/dynamic ontology | Large/stable ontology | ML tuning |

---

## Recommendation

For most enterprise deployments, **Option 2 (Scheduled Cache with JSON-LD)** provides the best balance:

1. **AnzoGraph remains the master** - No ontology duplication or management overhead
2. **JSON-LD format preserved** - Meets compliance and traceability requirements
3. **Production resilient** - Annotation continues even during AnzoGraph maintenance
4. **Performance optimized** - No external calls during annotation
5. **Auditable** - Full version history of ontology exports

### Suggested Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Refresh Frequency | Every 4 hours | Balance freshness vs. load |
| Cache Retention | 7 days | Allow rollback if needed |
| Export Format | JSON-LD | Native format, standard |
| Validation | On refresh | Ensure export completeness |

---

## Proof of Concept: JSON-LD Cache Experiment (DEPLOYED)

A working proof-of-concept for **Option 2 (Scheduled Cache)** has been deployed to Snowflake. This experiment is **isolated** in the `EXPERIMENT` schema and does not affect the existing pipeline.

**Status:** DEPLOYED AND TESTED

---

### Deployed Components

#### Schema

```
DOC_INTELLIGENCE.EXPERIMENT
```

#### Tables

| Table | Purpose |
|-------|---------|
| `ONTOLOGY_CACHE` | Stores JSON-LD ontologies with versioning |
| `EXPERIMENT_ANNOTATIONS` | Stores ontology-based annotation results |
| `EXPERIMENT_COMPARISON` | Comparison between flat and ontology methods |

#### Functions

| Function | Purpose |
|----------|---------|
| `GET_ONTOLOGY_CLASSES(ontology_name)` | Extracts all classes from JSON-LD |
| `GET_ONTOLOGY_HIERARCHY(ontology_name)` | Builds hierarchical text for LLM prompts |
| `GET_TAG_GROUPS(ontology_name)` | Extracts tag groups with exclusivity rules |
| `BUILD_ONTOLOGY_PROMPT(doc_text, ontology_name)` | Generates complete LLM prompt from JSON-LD |

#### Procedures

| Procedure | Purpose |
|-----------|---------|
| `ANNOTATE_WITH_ONTOLOGY(doc_id, ontology_name)` | Annotates a document using the ontology |
| `COMPARE_ANNOTATION_METHODS(doc_id, ontology_name)` | Compares flat vs ontology results |

#### Loaded Ontology

| Property | Value |
|----------|-------|
| Name | `EnterpriseDocumentOntology` |
| Version | `1.0.0` |
| Classes | 21 |
| Tag Groups | 3 |
| Source | AnzoGraph (Simulated) |

---

### Sample Ontology Structure

```
Document (root)
├── Legal Document [Tags: Legal-Review-Required]
│   ├── Contract [Tags: Legal-Review-Required, Requires-Signature]
│   │   ├── NDA (Also known as: Confidentiality Agreement, CDA) [Tags: Confidential, Contains-PII]
│   │   ├── MSA (Also known as: Framework Agreement) [Tags: Vendor-Related]
│   │   ├── SOW (Also known as: Work Order) [Tags: Vendor-Related, Financial-Data]
│   │   └── Employment Agreement (Also known as: Offer Letter) [Tags: Confidential, HR-Related]
│   └── Policy [Tags: Internal]
│       ├── Security Policy (Also known as: InfoSec Policy) [Tags: Internal, SOC2]
│       ├── HR Policy [Tags: Internal, HR-Related]
│       └── Privacy Policy (Also known as: GDPR Policy) [Tags: GDPR, Contains-PII]
├── Financial Document [Tags: Financial-Data]
│   ├── Quarterly Report (Also known as: 10-Q) [Tags: Financial-Data, Investor-Relations]
│   └── Annual Report (Also known as: 10-K) [Tags: Financial-Data, Public]
├── Technical Document [Tags: Internal]
│   ├── PRD (Also known as: Requirements Doc) [Tags: Internal, Draft]
│   ├── Architecture Document (Also known as: Design Doc) [Tags: Internal, Technical]
│   └── API Documentation (Also known as: API Docs) [Tags: Technical, Customer-Facing]
└── Healthcare Document [Tags: HIPAA, Restricted]
    ├── Medical Record (Also known as: Patient Record) [Tags: HIPAA, Confidential]
    └── BAA (Also known as: HIPAA BAA) [Tags: HIPAA, Legal-Review-Required]
```

### Tag Groups (Mutual Exclusivity Rules)

| Group | Rule | Options |
|-------|------|---------|
| Confidentiality Level | Select ONE | Public, Internal, Confidential, Restricted |
| Document Status | Select ONE | Draft, Under-Review, Final, Archived |
| Compliance Framework | Select ALL that apply | HIPAA, GDPR, SOC2, PCI-DSS |

---

## Step-by-Step Testing Guide

### Prerequisites

1. Access to Snowflake account with `DOC_INTELLIGENCE` database
2. Documents already processed through the main pipeline (status = ANNOTATED)
3. Connection configured (e.g., `uswest2demo`)

### Step 1: Verify Deployment

```sql
-- Check schema exists
SHOW SCHEMAS IN DATABASE DOC_INTELLIGENCE;

-- Check tables exist
SELECT table_name 
FROM DOC_INTELLIGENCE.INFORMATION_SCHEMA.TABLES 
WHERE table_schema = 'EXPERIMENT';
```

Expected output:
```
TABLE_NAME
------------------------
EXPERIMENT_COMPARISON
ONTOLOGY_CACHE
EXPERIMENT_ANNOTATIONS
```

### Step 2: Verify Ontology is Loaded

```sql
-- Check ontology cache
SELECT 
    ontology_name, 
    version, 
    class_count, 
    source_system,
    is_current 
FROM DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE;
```

Expected output:
```
ONTOLOGY_NAME               | VERSION | CLASS_COUNT | SOURCE_SYSTEM         | IS_CURRENT
----------------------------+---------+-------------+-----------------------+-----------
EnterpriseDocumentOntology  | 1.0.0   | 21          | AnzoGraph (Simulated) | True
```

### Step 3: View the Generated Hierarchy

```sql
-- See how JSON-LD is transformed into LLM prompt text
SELECT DOC_INTELLIGENCE.EXPERIMENT.GET_ONTOLOGY_HIERARCHY('EnterpriseDocumentOntology') 
AS category_hierarchy;
```

This shows the hierarchical category list that will be injected into LLM prompts.

### Step 4: View Tag Groups

```sql
-- See tag groups with mutual exclusivity rules
SELECT DOC_INTELLIGENCE.EXPERIMENT.GET_TAG_GROUPS('EnterpriseDocumentOntology') 
AS tag_groups;
```

Expected output:
```
Compliance Framework (select all that apply): HIPAA, GDPR, SOC2, PCI-DSS
Confidentiality Level (select ONE): Public, Internal, Confidential, Restricted
Document Status (select ONE): Draft, Under-Review, Final, Archived
```

### Step 5: Check Available Documents

```sql
-- List documents available for annotation
SELECT 
    document_id, 
    file_name, 
    status 
FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
WHERE status IN ('PARSED', 'ANNOTATED', 'COMPLETED');
```

### Step 6: Annotate a Document with Ontology

```sql
-- Annotate the NDA document (document_id = 3)
CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(3, 'EnterpriseDocumentOntology');
```

Expected output:
```
Successfully annotated document 3 using ontology EnterpriseDocumentOntology
```

### Step 7: View Annotation Results

```sql
-- View the ontology-based annotation
SELECT 
    document_id,
    category_path,
    category_label,
    tags,
    confidence,
    summary
FROM DOC_INTELLIGENCE.EXPERIMENT.EXPERIMENT_ANNOTATIONS
WHERE document_id = 3;
```

Expected result for NDA:
```
CATEGORY_PATH: Legal Document > Contract > Non-Disclosure Agreement
CATEGORY_LABEL: Non-Disclosure Agreement
TAGS: ["Confidential", "Contains-PII", "Legal-Review-Required", "Requires-Signature", "Final"]
CONFIDENCE: 0.98
```

### Step 8: Annotate Additional Documents

```sql
-- Annotate MSA
CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(2, 'EnterpriseDocumentOntology');

-- Annotate Quarterly Report
CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(5, 'EnterpriseDocumentOntology');

-- Annotate Security Policy
CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(6, 'EnterpriseDocumentOntology');

-- Annotate PRD
CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(4, 'EnterpriseDocumentOntology');
```

### Step 9: View All Results Summary

```sql
-- Summary of all ontology annotations
SELECT 
    d.file_name,
    e.category_path,
    e.category_label,
    e.confidence,
    ARRAY_TO_STRING(e.tags, ', ') as tags
FROM DOC_INTELLIGENCE.EXPERIMENT.EXPERIMENT_ANNOTATIONS e
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON e.document_id = d.document_id
ORDER BY e.document_id;
```

### Expected Test Results

| Document | Category Path | Confidence |
|----------|---------------|------------|
| msa_riverside_cloudmed.txt | Legal Document > Contract > Master Service Agreement | 95% |
| nda_acme_techstart.txt | Legal Document > Contract > Non-Disclosure Agreement | 98% |
| prd_datasync_v3.txt | Technical Document > Product Requirements Document | 95% |
| quarterly_report_nexgen_q4_2024.txt | Financial Document > Quarterly Report | 95% |
| security_policy_globex.txt | Legal Document > Policy > Security Policy | 95% |

---

## How It Works: The Workflow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    JSON-LD ONTOLOGY ANNOTATION WORKFLOW                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────┐                                                            │
│  │  ONTOLOGY_CACHE  │ ◄─── JSON-LD stored in VARIANT column                      │
│  │  (JSON-LD)       │      Contains @graph with classes, hierarchies, synonyms   │
│  └────────┬─────────┘                                                            │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐       │
│  │  GET_ONTOLOGY_HIERARCHY()                                             │       │
│  │                                                                       │       │
│  │  1. LATERAL FLATTEN on json_ld:"@graph"                              │       │
│  │  2. Extract @id, rdfs:label, rdfs:subClassOf, skos:altLabel          │       │
│  │  3. Recursive CTE to build parent→child tree                         │       │
│  │  4. LISTAGG to create indented text hierarchy                        │       │
│  └────────┬─────────────────────────────────────────────────────────────┘       │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐       │
│  │  BUILD_ONTOLOGY_PROMPT(doc_text, ontology_name)                       │       │
│  │                                                                       │       │
│  │  Constructs prompt with:                                              │       │
│  │  - Instructions (select MOST SPECIFIC category)                       │       │
│  │  - Category hierarchy (from GET_ONTOLOGY_HIERARCHY)                   │       │
│  │  - Tag groups with exclusivity rules (from GET_TAG_GROUPS)           │       │
│  │  - Document text (first 50,000 chars)                                │       │
│  │  - JSON output format specification                                   │       │
│  └────────┬─────────────────────────────────────────────────────────────┘       │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────┐       │
│  │  ANNOTATE_WITH_ONTOLOGY(doc_id, ontology_name)                        │       │
│  │                                                                       │       │
│  │  1. Load document chunks from DOCUMENT_CHUNKS                         │       │
│  │  2. Build prompt using BUILD_ONTOLOGY_PROMPT                          │       │
│  │  3. Call SNOWFLAKE.CORTEX.COMPLETE('claude-3-5-sonnet', prompt)      │       │
│  │  4. Parse JSON response                                               │       │
│  │  5. Store in EXPERIMENT_ANNOTATIONS                                   │       │
│  └────────┬─────────────────────────────────────────────────────────────┘       │
│           │                                                                      │
│           ▼                                                                      │
│  ┌──────────────────┐                                                            │
│  │ EXPERIMENT_      │ ◄─── Results with:                                         │
│  │ ANNOTATIONS      │      - category_path (hierarchical)                        │
│  │                  │      - category_label (most specific)                      │
│  │                  │      - tags (respecting exclusivity)                       │
│  │                  │      - summary, key_terms, entities                        │
│  └──────────────────┘                                                            │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Differences: Flat vs Ontology Annotation

| Aspect | Flat Model (Milestones 1-7) | Ontology Model (Milestone 8) |
|--------|------------------------------|-------------------------------|
| Categories | 10 flat options | 21 hierarchical classes |
| Structure | Single level | Multi-level (Document > Legal > Contract > NDA) |
| Output | `category: "Contract"` | `category_path: "Legal Document > Contract > NDA"` |
| Synonyms | Not supported | `skos:altLabel` included in prompt |
| Suggested Tags | Manual | Per-class suggestions from ontology |
| Tag Rules | None | Mutual exclusivity enforced |
| Source | Snowflake tables | JSON-LD (from AnzoGraph) |

---

## Extending the Ontology

To add new document types:

```sql
-- 1. Export current ontology
SELECT json_ld FROM DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE 
WHERE ontology_name = 'EnterpriseDocumentOntology' AND is_current = TRUE;

-- 2. Modify JSON-LD (add new class to @graph array):
-- {
--   "@id": "ent:NewDocumentType",
--   "@type": "rdfs:Class",
--   "rdfs:subClassOf": {"@id": "ent:ParentClass"},
--   "rdfs:label": "New Document Type",
--   "rdfs:comment": "Description here",
--   "skos:altLabel": ["Synonym1", "Synonym2"],
--   "ent:suggestedTags": ["Tag1", "Tag2"]
-- }

-- 3. Insert new version
INSERT INTO DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE (
    ontology_name, version, description, source_system, json_ld, class_count, is_current
)
VALUES (
    'EnterpriseDocumentOntology',
    '1.1.0',
    'Added new document type',
    'AnzoGraph (Simulated)',
    PARSE_JSON('<modified JSON-LD>'),
    22,
    TRUE
);

-- 4. Mark old version as not current
UPDATE DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE 
SET is_current = FALSE 
WHERE version = '1.0.0';
```

---

## Streamlit Demo App

A dedicated Streamlit app has been created to showcase the ontology functionality interactively.

**Location:** `deploy/milestone_8_design/streamlit_app/`

### Features

| Page | Description |
|------|-------------|
| **Overview** | Architecture diagram, metrics, key concepts |
| **Hierarchy** | Visualize class hierarchy from JSON-LD |
| **Tag Groups** | View mutual exclusivity rules |
| **Annotate** | Run LLM annotation on documents |
| **Results** | View annotations with confidence scores |

### Deploy to Snowflake

```sql
-- Create stage for Streamlit files
CREATE OR REPLACE STAGE DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE);

-- Create the Streamlit app
CREATE OR REPLACE STREAMLIT DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_ANNOTATION_DEMO
  ROOT_LOCATION = '@DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE/ontology_app'
  MAIN_FILE = '/ontology_app.py'
  QUERY_WAREHOUSE = DOC_INTELLIGENCE_WH
  COMMENT = 'Milestone 8: Ontology-Based Document Annotation Demo';
```

Upload the app file:
```bash
snow stage copy deploy/milestone_8_design/streamlit_app/ontology_app.py \
  @DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE/ontology_app/ \
  --connection uswest2demo
```

See [streamlit_app/README.md](streamlit_app/README.md) for full deployment instructions.

---

## Next Steps

1. **Customer Review** - Present options and gather feedback
2. **Run Experiment** - Demo the proof-of-concept with customer
3. **Select Option** - Confirm architectural direction
4. **AnzoGraph Access** - Obtain endpoint URL, credentials, sample SPARQL
5. **Production Implementation** - Full integration with AnzoGraph

---

## Open Questions for Customer

1. What is the approximate size of the enterprise ontology? (classes, relationships)
2. How frequently does the ontology change? (hourly, daily, weekly)
3. Is there an existing SPARQL query that exports the relevant subset?
4. Are there specific ontology standards in use? (OWL, SKOS, custom)
5. What is the expected annotation volume? (documents per day)
6. Are there compliance requirements for ontology traceability?

---

## Appendix: Technical References

### AnzoGraph Documentation
- [AnzoGraph Architecture](https://docs.cambridgesemantics.com/anzo/v5.3/userdoc/anzograph-architecture.htm)
- [SPARQL Endpoints](https://docs.cambridgesemantics.com/anzograph/v2.2/userdoc/azg-endpoints.htm)
- [JSON-LD Loading](https://docs.cambridgesemantics.com/anzograph/v2.5/userdoc/faq.htm)

### Snowflake Documentation
- [External Network Access](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)
- [External Functions](https://docs.snowflake.com/en/sql-reference/external-functions)
- [VARIANT Data Type](https://docs.snowflake.com/en/sql-reference/data-types-semistructured)

### Standards
- [JSON-LD Specification](https://json-ld.org/)
- [SPARQL 1.1 Protocol](https://www.w3.org/TR/sparql11-protocol/)
- [RDF Graph Store Protocol](https://www.w3.org/TR/sparql11-http-rdf-update/)

---

*Document Version: 1.0*  
*Last Updated: February 2026*  
*Status: Draft - Pending Customer Review*
