# Document Intelligence Pipeline

A Snowflake Cortex-powered pipeline for document classification, annotation, and semantic search with enterprise ontology support.

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
┌─────────────────┐     ┌──────────────────┐
│    Streamlit    │     │  Ontology Demo   │  (Milestone 8)
│    Dashboard    │     │    Streamlit     │
└─────────────────┘     └──────────────────┘
```

## Features

- **Dual Ingestion Sources**: S3 external stage or internal stage
- **Document Parsing**: PARSE_DOCUMENT for PDF, images, DOCX, and more
- **LLM Annotation**: Classification and tagging using Cortex COMPLETE (claude-sonnet-4-5)
- **Semantic Model**: Taxonomy-constrained annotations (categories, tags, glossary)
- **Hybrid Search**: Cortex Search Service with semantic + lexical search
- **Faceted Filtering**: Filter by category, file type, source, review status
- **Dashboard**: Streamlit app for search, review, and analytics
- **Enterprise Ontology** (Milestone 8): JSON-LD ontology support with hierarchical classification

## Project Structure

```
doc-intelligence-pipeline/
├── config/                       # Environment settings
│   └── settings.sql
├── setup/                        # Database, stages, warehouse setup
│   ├── 01_database_setup.sql
│   ├── 02_warehouse_setup.sql
│   ├── 03_external_stage_setup.sql
│   ├── 04_internal_stage_setup.sql
│   └── 05_ingestion_sources.sql
├── semantic_model/               # Taxonomy, tags, glossary
│   ├── 01_basic_tables.sql
│   ├── 02_seed_categories.sql
│   ├── 03_seed_tags.sql
│   └── 04_seed_glossary.sql
├── tables/                       # Document and annotation tables
│   ├── 01_raw_documents.sql
│   ├── 02_processed_chunks.sql
│   ├── 03_annotations.sql
│   └── 04_vectors.sql
├── procedures/                   # Stored procedures for pipeline
│   ├── 01_register_new_documents.sql
│   ├── 02_parse_document.sql
│   ├── 03_run_ingestion.sql
│   ├── 04_build_annotation_prompt.sql
│   ├── 05_annotate_document.sql
│   ├── 06_run_annotation.sql
│   └── 07_full_pipeline.sql
├── search/                       # Cortex Search Service
│   ├── 01_searchable_view.sql
│   ├── 02_cortex_search_service.sql
│   └── 03_search_helpers.sql
├── streamlit/                    # Main dashboard application
│   ├── app.py
│   ├── environment.yml
│   ├── requirements.txt
│   ├── snowflake.yml
│   ├── DEPLOY.md
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
├── tests/                        # Test files
│   └── README.md
├── deploy/                       # Deployment scripts by milestone
│   ├── deploy_all.sql
│   ├── deploy_streamlit.sql
│   ├── milestone_1.sql           # Database & infrastructure
│   ├── milestone_2.sql           # Semantic model (flat taxonomy)
│   ├── milestone_3.sql           # Document tables
│   ├── milestone_4.sql           # Ingestion pipeline
│   ├── milestone_5.sql           # Annotation engine
│   ├── milestone_6.sql           # Cortex Search
│   ├── milestone_7.sql           # Streamlit dashboard
│   └── milestone_8_design/       # Enterprise ontology (JSON-LD)
│       ├── README.md             # Full design document
│       ├── EXECUTIVE_SUMMARY.md
│       ├── sql/
│       │   ├── 01_create_schema.sql
│       │   ├── 02_ontology_tables.sql
│       │   ├── 03_sample_ontology.sql
│       │   ├── 04_transform_functions.sql
│       │   ├── 05_annotate_procedure.sql
│       │   ├── 06_demo_queries.sql
│       │   └── deploy_experiment.sql
│       └── streamlit_app/
│           ├── ontology_app.py   # Ontology demo Streamlit app
│           ├── environment.yml
│           └── README.md
├── cleanup.sql                   # Database cleanup script
└── reset_data.sql                # Data reset script
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
| 8 | Enterprise Ontology | ✅ | JSON-LD ontology with hierarchical taxonomy |

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

### 5. Deploy Streamlit Dashboard
```bash
# Deploy main dashboard to Snowflake
cd streamlit
snow streamlit deploy --connection <connection_name>
```

## Milestone 8: Enterprise Ontology (JSON-LD)

Milestone 8 introduces enterprise ontology support using JSON-LD format. This enables:

- **Hierarchical Classification**: Documents classified into a tree structure (e.g., `Legal Document > Contract > NDA`)
- **Tag Groups with Mutual Exclusivity**: Rules like "select ONE confidentiality level" or "select ALL applicable compliance frameworks"
- **Synonym Support**: Alternative labels for categories (e.g., NDA = "Confidentiality Agreement")
- **JSON-LD Format**: Native semantic web format for ontology storage and exchange

### Deploy Milestone 8 Experiment
```sql
-- Deploy the experiment schema and components
!source deploy/milestone_8_design/sql/deploy_experiment.sql
```

### Deploy Ontology Demo App
```bash
# Upload the ontology demo Streamlit app
snow object stage copy deploy/milestone_8_design/streamlit_app/ontology_app.py \
    @DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE/ontology_app/ \
    --overwrite --connection <connection_name>
```

### Ontology Demo Features

The Milestone 8 Streamlit app (`ONTOLOGY_ANNOTATION_DEMO`) showcases:

| Page | Description |
|------|-------------|
| Ontology Browser | Explore class hierarchy, synonyms, and suggested tags |
| Tag Groups | View mutual exclusivity rules for tag selection |
| Annotate Documents | Run ontology-based annotation on documents |
| Results | View hierarchical classification results |
| Compare Methods | Side-by-side comparison of flat vs ontology annotation |

### Sample Ontology Structure

```
Document (root)
├── Legal Document
│   ├── Contract
│   │   ├── NDA (Confidentiality Agreement)
│   │   ├── MSA (Framework Agreement)
│   │   ├── SOW (Work Order)
│   │   └── Employment Agreement
│   └── Policy
│       ├── Security Policy
│       ├── HR Policy
│       └── Privacy Policy
├── Financial Document
│   ├── Quarterly Report (10-Q)
│   └── Annual Report (10-K)
├── Technical Document
│   ├── PRD (Requirements Doc)
│   ├── Architecture Document
│   └── API Documentation
└── Healthcare Document
    ├── Medical Record
    └── BAA (HIPAA BAA)
```

### Annotate with Ontology
```sql
-- Annotate a document using the enterprise ontology
CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(3, 'EnterpriseDocumentOntology');

-- View results with hierarchical path
SELECT 
    d.file_name,
    e.category_path,
    e.category_label,
    e.confidence,
    e.tags
FROM DOC_INTELLIGENCE.EXPERIMENT.EXPERIMENT_ANNOTATIONS e
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON e.document_id = d.document_id;
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
| `EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(doc_id, ontology)` | Ontology-based annotation (M8) |

### Document Status Flow
```
PENDING → PROCESSING → PARSED → ANNOTATED → COMPLETED
                ↓                    ↓
              FAILED              FAILED
```

### Streamlit Apps

#### Main Dashboard (`streamlit/`)
| Page | Description |
|------|-------------|
| Home | Dashboard with metrics and quick actions |
| Search | Semantic + keyword search with filters |
| Document Viewer | View document content and annotations |
| Annotation Review | Approve/reject LLM annotations |
| Analytics | Processing stats and insights |
| Taxonomy Manager | Manage categories, tags, glossary |

#### Ontology Demo (`deploy/milestone_8_design/streamlit_app/`)
| Page | Description |
|------|-------------|
| Ontology Browser | Explore JSON-LD ontology hierarchy |
| Tag Groups | View tag group rules and exclusivity |
| Annotate | Run ontology-based document annotation |
| Results | View annotation results with hierarchy |
| Compare | Flat vs ontology annotation comparison |

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

## Schemas

| Schema | Purpose |
|--------|---------|
| `RAW` | Raw document storage and ingestion |
| `PROCESSED` | Parsed content, chunks, and annotations |
| `SEMANTIC` | Taxonomy tables (categories, tags, glossary) |
| `EXPERIMENT` | Milestone 8 ontology experiment (isolated) |

## Requirements

- Snowflake account with Cortex access
- SNOWFLAKE.CORTEX_USER database role (or equivalent)
- Storage integration (for S3 external stage - optional)
- Snow CLI (for deployment)

## Configuration

Edit `config/settings.sql` to customize:
- Database and schema names
- Warehouse size
- S3 bucket path (for external stage)
- Target lag for search service

## Useful Commands

```bash
# Deploy Streamlit app
snow streamlit deploy --connection <connection_name>

# Upload files to stage
snow object stage copy <file> @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ \
    --overwrite --connection <connection_name>

# List stage contents
snow object stage list @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ \
    --connection <connection_name>
```

## License

Internal use only.
