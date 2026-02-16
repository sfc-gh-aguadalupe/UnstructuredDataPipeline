# Document Intelligence Pipeline

A Snowflake Cortex-powered pipeline for document classification, annotation, and semantic search.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  S3 / Internal  │────▶│ Directory Table  │────▶│ AI_PARSE_DOC()  │
│     Stage       │     └──────────────────┘     └────────┬────────┘
└─────────────────┘                                       │
                                                          ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Cortex Search   │◀────│   Annotations    │◀────│ CORTEX.COMPLETE │
│    Service      │     │   (LLM-based)    │     │  + Taxonomy     │
└────────┬────────┘     └──────────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│    Streamlit    │
│    Dashboard    │
└─────────────────┘
```

## Features

- **Dual Ingestion Sources**: S3 external stage or internal stage
- **Document Parsing**: PARSE_DOCUMENT for PDF, images, DOCX, and more
- **LLM Annotation**: Classification and tagging using Cortex COMPLETE (claude-sonnet-4-5)
- **Semantic Model**: Taxonomy-constrained annotations (categories, tags, glossary)
- **Hybrid Search**: Cortex Search Service with semantic + lexical search
- **Faceted Filtering**: Filter by category, file type, source, review status
- **Dashboard**: Streamlit app for search, review, and analytics

## Project Structure

```
doc-intelligence-pipeline/
├── config/                 # Environment settings
│   └── settings.sql
├── setup/                  # Database, stages, warehouse setup
│   ├── 01_database_setup.sql
│   ├── 02_warehouse_setup.sql
│   ├── 03_external_stage_setup.sql
│   ├── 04_internal_stage_setup.sql
│   └── 05_ingestion_sources.sql
├── semantic_model/         # Taxonomy, tags, glossary
│   ├── 01_basic_tables.sql
│   ├── 02_seed_categories.sql
│   ├── 03_seed_tags.sql
│   └── 04_seed_glossary.sql
├── tables/                 # Document and annotation tables
│   ├── 01_raw_documents.sql
│   ├── 02_processed_chunks.sql
│   ├── 03_annotations.sql
│   └── 04_vectors.sql
├── procedures/             # Stored procedures for pipeline
│   ├── 01_register_new_documents.sql
│   ├── 02_parse_document.sql
│   ├── 03_run_ingestion.sql
│   ├── 04_build_annotation_prompt.sql
│   ├── 05_annotate_document.sql
│   ├── 06_run_annotation.sql
│   └── 07_full_pipeline.sql
├── search/                 # Cortex Search Service
│   ├── 01_searchable_view.sql
│   ├── 02_cortex_search_service.sql
│   └── 03_search_helpers.sql
├── analytics/              # Metrics and reporting views (Milestone 8)
├── streamlit/              # Dashboard application
│   ├── app.py
│   ├── requirements.txt
│   ├── pages/
│   │   ├── 1_search.py
│   │   ├── 2_document_viewer.py
│   │   ├── 3_annotation_review.py
│   │   ├── 4_analytics.py
│   │   └── 5_taxonomy_manager.py
│   └── utils/
│       ├── snowflake_conn.py
│       ├── annotation_utils.py
│       └── search_utils.py
└── deploy/                 # Deployment scripts by milestone
    ├── deploy_all.sql
    └── milestone_1-8.sql
```

## Milestones

| # | Milestone | Status | Description |
|---|-----------|--------|-------------|
| 0 | Repository Setup | ✅ | Project structure and deployment framework |
| 1 | Database & Stages | ✅ | Infrastructure with dual ingestion sources |
| 2 | Basic Semantic Model | ✅ | Flat taxonomy (categories, tags, glossary) |
| 3 | Document Tables | ✅ | Storage for documents, chunks, annotations |
| 4 | Ingestion Pipeline | ✅ | Document discovery, parsing, chunking |
| 5 | Annotation Engine | ✅ | LLM-based classification with Cortex |
| 6 | Cortex Search | ✅ | Hybrid search service with facets |
| 7 | Streamlit Dashboard | ✅ | UI for search, review, analytics |
| 8 | Advanced Semantic | ⏳ | Hierarchical taxonomy, relationships |

## Quick Start

### 1. Deploy Infrastructure
```sql
-- Run from Snowflake worksheet
!source deploy/milestone_1.sql
!source deploy/milestone_2.sql
!source deploy/milestone_3.sql
!source deploy/milestone_4.sql
!source deploy/milestone_5.sql
!source deploy/milestone_6.sql
```

### 2. Upload Documents
```bash
# Using Snow CLI
snow object stage copy /path/to/document.pdf @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ \
    --connection <connection_name> \
    --overwrite
```

```sql
-- Refresh directory table
ALTER STAGE DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE REFRESH;
```

### 3. Run Pipeline
```sql
-- Process documents through full pipeline
CALL DOC_INTELLIGENCE.RAW.FULL_PIPELINE('Manual Upload', 10);
```

### 4. Search Documents
```sql
-- Search using Cortex Search Service
SELECT * FROM TABLE(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
        {'query': 'contract terms', 'columns': ['file_name', 'summary', 'category'], 'limit': 10}
    )
);
```

### 5. Run Streamlit App
```bash
cd streamlit
pip install -r requirements.txt
streamlit run app.py
```

## Key Components

### Procedures

| Procedure | Description |
|-----------|-------------|
| `RAW.REGISTER_NEW_DOCUMENTS(source)` | Scan directory table and register new files |
| `PROCESSED.PARSE_DOCUMENT(doc_id)` | Parse document and create chunks |
| `PROCESSED.ANNOTATE_DOCUMENT(doc_id)` | Classify and annotate using LLM |
| `RAW.RUN_INGESTION(source, max)` | Full ingestion pipeline |
| `PROCESSED.RUN_ANNOTATION(max)` | Batch annotation |
| `RAW.FULL_PIPELINE(source, max)` | Complete end-to-end pipeline |

### Document Status Flow
```
PENDING → PROCESSING → PARSED → ANNOTATED → COMPLETED
                ↓                    ↓
              FAILED              FAILED
```

### Streamlit Pages

| Page | Description |
|------|-------------|
| Home | Dashboard with metrics and quick actions |
| Search | Semantic + keyword search with filters |
| Document Viewer | View document content and annotations |
| Annotation Review | Approve/reject LLM annotations |
| Analytics | Processing stats and insights |
| Taxonomy Manager | Manage categories, tags, glossary |

## How the Semantic Model Works in Annotation

The semantic model is the core mechanism that **constrains** the LLM to produce consistent, controlled annotations. Instead of letting the LLM freely generate categories and tags, we force it to select from our predefined taxonomy.

### The Three Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SEMANTIC MODEL                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   CATEGORIES    │  │      TAGS       │  │         GLOSSARY            │  │
│  │   (10 items)    │  │   (20 items)    │  │        (24 terms)           │  │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────────────────┤  │
│  │ • Contract      │  │ • Confidential  │  │ NDA: Non-Disclosure...      │  │
│  │ • Policy        │  │ • Public        │  │ MSA: Master Service...      │  │
│  │ • Financial Rep │  │ • HIPAA         │  │ HIPAA: Health Insurance...  │  │
│  │ • Technical Doc │  │ • GDPR          │  │ ARR: Annual Recurring...    │  │
│  │ • HR Document   │  │ • SOC2          │  │ API: Application Program... │  │
│  │ • ...           │  │ • ...           │  │ ...                         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
│                                                                              │
│  Single-select         Multi-select          Domain vocabulary               │
│  (pick exactly one)    (pick all that apply) (helps LLM understand context) │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### How It's Injected Into the LLM Prompt

The `BUILD_ANNOTATION_PROMPT` function constructs a prompt that includes all three components:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        LLM PROMPT STRUCTURE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  "You are a document classification assistant..."                           │
│                                                                              │
│  INSTRUCTIONS:                                                               │
│  1. Select exactly ONE category from the CATEGORIES list                    │
│  2. Select ALL applicable tags from the TAGS list        ◄── CONSTRAINTS    │
│  3. Write a 2-3 sentence summary                                            │
│  4. Extract key terms (up to 10)                                            │
│  5. Extract named entities                                                   │
│  6. Provide a confidence score (0.0 to 1.0)                                 │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ AVAILABLE CATEGORIES (loaded from SEMANTIC.CATEGORIES):               │  │
│  │ - Contract: Legal agreements including NDAs, MSAs, SOWs...            │  │
│  │ - Policy: Internal policies including HR, security, IT...             │  │
│  │ - Financial Report: Financial documents including quarterly...        │  │
│  │ - Technical Document: Technical specifications, PRDs...               │  │
│  │ - HR Document: Human resources documents including handbooks...       │  │
│  │ ...                                                                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ AVAILABLE TAGS (loaded from SEMANTIC.TAGS):                           │  │
│  │ Confidential, Public, Internal, Restricted, Draft, Final, HIPAA,      │  │
│  │ GDPR, SOC2, Legal-Review-Required, Contains-PII, Financial-Data...    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ DOMAIN GLOSSARY (loaded from SEMANTIC.GLOSSARY):                      │  │
│  │ NDA: Non-Disclosure Agreement - a legal contract establishing...      │  │
│  │ MSA: Master Service Agreement - an overarching contract...            │  │
│  │ HIPAA: Health Insurance Portability and Accountability Act...         │  │
│  │ ...                                                                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  DOCUMENT TEXT:                                                              │
│  [First 50,000 characters of the parsed document]                           │
│                                                                              │
│  Respond with ONLY valid JSON in this exact format:                         │
│  {                                                                           │
│    "category": "<category_name>",                                           │
│    "tags": ["<tag1>", "<tag2>"],                                            │
│    "summary": "...",                                                         │
│    ...                                                                       │
│  }                                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### The Annotation Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Document   │     │  Semantic Model  │     │   LLM Prompt    │
│   Chunks    │     │    (loaded)      │     │   (assembled)   │
└──────┬──────┘     └────────┬─────────┘     └────────┬────────┘
       │                     │                        │
       │                     │                        │
       ▼                     ▼                        ▼
┌──────────────────────────────────────────────────────────────┐
│                  ANNOTATE_DOCUMENT Procedure                  │
│                                                               │
│  1. Load document text from DOCUMENT_CHUNKS                   │
│  2. Load categories from SEMANTIC.CATEGORIES                  │
│  3. Load tags from SEMANTIC.TAGS                              │
│  4. Load glossary from SEMANTIC.GLOSSARY                      │
│  5. Build constrained prompt using BUILD_ANNOTATION_PROMPT    │
│  6. Call SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5')       │
│  7. Parse JSON response                                       │
│  8. Map category name → category_id (validate against table)  │
│  9. Store annotation in PROCESSED.ANNOTATIONS                 │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    ANNOTATIONS Table                          │
│                                                               │
│  document_id: 1                                               │
│  category_id: 101  ───────► FK to SEMANTIC.CATEGORIES         │
│  tags: ["Confidential", "Legal-Review-Required"]              │
│  summary: "This is a mutual non-disclosure agreement..."      │
│  key_terms: ["confidential information", "trade secrets"...]  │
│  entities: {people: [...], organizations: [...], ...}         │
│  confidence: 0.92                                             │
│  model_name: "claude-sonnet-4-5"                              │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Why This Approach?

| Benefit | Explanation |
|---------|-------------|
| **Consistency** | Every document gets categorized using the same vocabulary |
| **Validation** | Category names are validated against the database (invalid = rejected) |
| **Searchability** | Faceted search works because categories/tags are predictable |
| **Domain Alignment** | Glossary helps LLM understand industry-specific terms correctly |
| **Auditability** | You can trace exactly what options the LLM was given |
| **Extensibility** | Add new categories/tags to the tables, and all future annotations use them |

### Example: How Glossary Helps

Without glossary:
- LLM sees "NDA" in document
- Might not know what it means
- Could misclassify as "Correspondence" or "Other"

With glossary:
- LLM sees "NDA: Non-Disclosure Agreement - a legal contract establishing confidentiality"
- Understands this is a legal document
- Correctly classifies as "Contract"

### Customizing the Semantic Model

```sql
-- Add a new category
INSERT INTO DOC_INTELLIGENCE.SEMANTIC.CATEGORIES (category_name, description)
VALUES ('Meeting Notes', 'Notes and minutes from meetings and discussions');

-- Add new tags
INSERT INTO DOC_INTELLIGENCE.SEMANTIC.TAGS (tag_name, description)
VALUES ('Urgent', 'Time-sensitive document requiring immediate attention');

-- Add glossary terms
INSERT INTO DOC_INTELLIGENCE.SEMANTIC.GLOSSARY (term, definition)
VALUES ('IPO', 'Initial Public Offering - the first sale of stock by a company to the public');
```

After updating the semantic model, all future annotations will automatically use the new options.

## Requirements

- Snowflake account with Cortex access
- SNOWFLAKE.CORTEX_USER database role (or equivalent)
- Storage integration (for S3 external stage - optional)

## Configuration

Edit `config/settings.sql` to customize:
- Database and schema names
- Warehouse size
- S3 bucket path (for external stage)
- Target lag for search service

## License

Internal use only.
