# Testing the Document Intelligence Pipeline

This guide walks you through testing the pipeline end-to-end using sample documents.

## Test Documents

The `tests/sample_documents/` folder contains 6 sample documents representing different document types:

| File | Type | Expected Category | Key Content |
|------|------|-------------------|-------------|
| `nda_acme_techstart.txt` | Legal Contract | Contract | NDA between Acme Corp and TechStart Inc |
| `msa_riverside_cloudmed.txt` | Service Agreement | Contract | Healthcare MSA with HIPAA requirements |
| `security_policy_globex.txt` | Security Policy | Policy | Information security policy with compliance |
| `employee_handbook_summit.txt` | HR Handbook | HR Document | Employee policies, benefits, conduct |
| `quarterly_report_nexgen_q4_2024.txt` | Financial Report | Financial Report | Q4 earnings, revenue breakdown, guidance |
| `prd_datasync_v3.txt` | Technical PRD | Technical Document | Product requirements with specifications |

---

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
│  6. Call SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5')         │
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
│  model_name: "claude-sonnet-4-5"                           │
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

---

## Quick Start Testing

### Step 0: Load Semantic Model (REQUIRED)

**Important**: The semantic model MUST be loaded before running the pipeline. The annotation process depends on these tables to constrain the LLM output.

```sql
-- Connect to Snowflake and run:
USE DATABASE DOC_INTELLIGENCE;
```

#### 0.1 Load Categories (10 items)

```sql
-- Clear and reload categories
TRUNCATE TABLE SEMANTIC.CATEGORIES;
INSERT INTO SEMANTIC.CATEGORIES (category_name, description) VALUES
    ('Contract', 'Legal agreements including NDAs, MSAs, SOWs, and service contracts'),
    ('Policy', 'Internal policies including HR, security, IT, and compliance policies'),
    ('Financial Report', 'Financial documents including quarterly reports, annual reports'),
    ('Technical Document', 'Technical specifications, PRDs, architecture documents'),
    ('HR Document', 'Human resources documents including handbooks, employee records'),
    ('Marketing Material', 'Marketing content including presentations, brochures'),
    ('Research', 'Research papers, white papers, and analytical studies'),
    ('Correspondence', 'Business communications including emails, memos, letters'),
    ('Proposal', 'Business proposals, RFP responses, and quotes'),
    ('Other', 'Documents that do not fit other categories');
```

#### 0.2 Load Tags (20 items)

```sql
-- Clear and reload tags
TRUNCATE TABLE SEMANTIC.TAGS;
INSERT INTO SEMANTIC.TAGS (tag_name, description) VALUES
    -- Classification tags
    ('Confidential', 'Contains sensitive business information'),
    ('Public', 'Approved for public distribution'),
    ('Internal', 'For internal use only'),
    ('Restricted', 'Limited access, need-to-know basis'),
    -- Status tags
    ('Draft', 'Work in progress, not finalized'),
    ('Final', 'Approved and finalized version'),
    ('Archived', 'Historical document, no longer active'),
    ('Under-Review', 'Currently being reviewed or edited'),
    -- Compliance tags
    ('HIPAA', 'Contains healthcare data subject to HIPAA'),
    ('GDPR', 'Contains EU personal data subject to GDPR'),
    ('SOC2', 'Relevant to SOC 2 compliance'),
    ('PCI-DSS', 'Contains payment card data'),
    -- Content tags
    ('Legal-Review-Required', 'Needs legal department review'),
    ('Contains-PII', 'Contains personally identifiable information'),
    ('Contains-PHI', 'Contains protected health information'),
    ('Financial-Data', 'Contains financial metrics or data'),
    ('Executive-Summary', 'Contains executive-level summary'),
    ('Investor-Relations', 'Relevant to investors and shareholders'),
    ('Customer-Facing', 'Intended for customer communication'),
    ('Vendor-Related', 'Related to vendor or supplier relationships');
```

#### 0.3 Load Glossary (24 terms)

```sql
-- Clear and reload glossary
TRUNCATE TABLE SEMANTIC.GLOSSARY;
INSERT INTO SEMANTIC.GLOSSARY (term, definition) VALUES
    -- Legal terms
    ('NDA', 'Non-Disclosure Agreement - a legal contract establishing confidentiality between parties'),
    ('MSA', 'Master Service Agreement - an overarching contract that establishes terms for future transactions'),
    ('SOW', 'Statement of Work - a document defining project-specific work activities and deliverables'),
    ('SLA', 'Service Level Agreement - defines expected service performance and remedies for failures'),
    ('Indemnification', 'Contractual obligation to compensate for harm or loss'),
    -- Financial terms
    ('ARR', 'Annual Recurring Revenue - predictable yearly revenue from subscriptions'),
    ('EBITDA', 'Earnings Before Interest, Taxes, Depreciation, and Amortization'),
    ('YoY', 'Year over Year - comparing a metric to the same period in the previous year'),
    ('Gross Margin', 'Revenue minus cost of goods sold, expressed as percentage of revenue'),
    ('Free Cash Flow', 'Cash generated after accounting for capital expenditures'),
    -- Technical terms
    ('API', 'Application Programming Interface - allows software systems to communicate'),
    ('SaaS', 'Software as a Service - cloud-based software delivery model'),
    ('CDC', 'Change Data Capture - tracking and capturing database changes'),
    ('SDK', 'Software Development Kit - tools for building applications'),
    ('SSO', 'Single Sign-On - authentication allowing one login for multiple systems'),
    ('MFA', 'Multi-Factor Authentication - requiring multiple verification methods'),
    -- Compliance terms
    ('HIPAA', 'Health Insurance Portability and Accountability Act - US healthcare privacy law'),
    ('GDPR', 'General Data Protection Regulation - EU data privacy regulation'),
    ('SOC 2', 'Service Organization Control 2 - security compliance framework'),
    ('PII', 'Personally Identifiable Information - data that can identify an individual'),
    ('PHI', 'Protected Health Information - health data protected under HIPAA'),
    ('BAA', 'Business Associate Agreement - HIPAA-required agreement for handling PHI'),
    -- HR terms
    ('PTO', 'Paid Time Off - combined vacation, sick, and personal leave'),
    ('401k', '401(k) - US employer-sponsored retirement savings plan');
```

#### 0.4 Verify Semantic Model is Loaded

```sql
-- Verify all three tables have data
SELECT 'CATEGORIES' as table_name, COUNT(*) as row_count FROM SEMANTIC.CATEGORIES WHERE is_active = TRUE
UNION ALL
SELECT 'TAGS', COUNT(*) FROM SEMANTIC.TAGS WHERE is_active = TRUE
UNION ALL
SELECT 'GLOSSARY', COUNT(*) FROM SEMANTIC.GLOSSARY WHERE is_active = TRUE;
```

Expected output:
```
TABLE_NAME  | ROW_COUNT
------------|----------
CATEGORIES  | 10
TAGS        | 20
GLOSSARY    | 24
```

**If any table shows 0 rows, the annotation step will fail or produce poor results.**

---

### Step 1: Upload Test Documents to Stage

From your local machine, upload the test documents:

```bash
# Using Snow CLI (recommended)
snow object stage copy tests/sample_documents/ @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ \
    --connection <connection_name> \
    --overwrite \
    --recursive
```

Or upload individual files:

```bash
snow object stage copy tests/sample_documents/nda_acme_techstart.txt @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ -c <connection_name> --overwrite
snow object stage copy tests/sample_documents/msa_riverside_cloudmed.txt @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ -c <connection_name> --overwrite
snow object stage copy tests/sample_documents/security_policy_globex.txt @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ -c <connection_name> --overwrite
snow object stage copy tests/sample_documents/employee_handbook_summit.txt @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ -c <connection_name> --overwrite
snow object stage copy tests/sample_documents/quarterly_report_nexgen_q4_2024.txt @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ -c <connection_name> --overwrite
snow object stage copy tests/sample_documents/prd_datasync_v3.txt @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE/ -c <connection_name> --overwrite
```

### Step 2: Refresh Directory Table

```sql
ALTER STAGE DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE REFRESH;

-- Verify files are visible
SELECT * FROM DIRECTORY(@DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE);
```

Expected output: 6 files listed with their paths and sizes.

### Step 3: Run the Full Pipeline

```sql
-- Process all documents through the pipeline
CALL DOC_INTELLIGENCE.RAW.FULL_PIPELINE('Manual Upload', 10);
```

This will:
1. Register new documents from the stage
2. Parse each document into chunks
3. Annotate documents using Claude 4.5 Sonnet with taxonomy constraints

### Step 4: Verify Results

```sql
-- Check document status
SELECT 
    document_id,
    file_name,
    status,
    word_count,
    discovered_at,
    annotated_at
FROM DOC_INTELLIGENCE.RAW.DOCUMENTS
ORDER BY document_id;

-- Check annotations with semantic model validation
SELECT 
    d.file_name,
    c.category_name,
    a.summary,
    a.tags,
    a.confidence
FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON a.document_id = d.document_id
LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id;

-- Check chunks created
SELECT 
    d.file_name,
    COUNT(*) as chunk_count,
    SUM(LENGTH(c.chunk_text)) as total_chars
FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS c
JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON c.document_id = d.document_id
GROUP BY d.file_name;
```

---

## Step-by-Step Testing (Manual)

If you want to test each step individually:

### Test 1: Document Registration

```sql
-- Register documents from stage
CALL DOC_INTELLIGENCE.RAW.REGISTER_NEW_DOCUMENTS('Manual Upload');

-- Verify
SELECT document_id, file_name, status FROM DOC_INTELLIGENCE.RAW.DOCUMENTS;
```

Expected: 6 documents with status = 'PENDING'

### Test 2: Document Parsing

```sql
-- Parse a single document
CALL DOC_INTELLIGENCE.PROCESSED.PARSE_DOCUMENT(1);

-- Check chunks
SELECT chunk_index, LEFT(chunk_text, 100) as preview
FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS
WHERE document_id = 1
ORDER BY chunk_index;
```

Expected: Document status changes to 'PARSED', chunks created.

### Test 3: Document Annotation

```sql
-- Annotate a single document
CALL DOC_INTELLIGENCE.PROCESSED.ANNOTATE_DOCUMENT(1);

-- Check annotation
SELECT 
    c.category_name,
    a.summary,
    a.tags,
    a.key_terms,
    a.entities,
    a.confidence
FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a
LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
WHERE a.document_id = 1;
```

Expected: Document categorized, summary generated, tags assigned.

### Test 4: Search Documents

The Cortex Search Service provides hybrid search (semantic + lexical) with faceted filtering.

**Important**: `SEARCH_PREVIEW` is a scalar function that returns JSON, not a table function. Use `PARSE_JSON` and `LATERAL FLATTEN` to extract results.

#### 4.1 Basic Semantic Search

```sql
-- Search for contract-related content
SELECT 
    result.value:file_name::VARCHAR as file_name,
    result.value:category::VARCHAR as category,
    LEFT(result.value:chunk_text::VARCHAR, 200) as preview
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            '{"query": "confidential information non-disclosure", "columns": ["file_name", "category", "chunk_text"], "limit": 5}'
        )
    ):results AS results
), LATERAL FLATTEN(input => results) AS result;
```

#### 4.2 Search with Category Filter (Faceted Search)

```sql
-- Search only within Contract documents
SELECT 
    result.value:file_name::VARCHAR as file_name,
    result.value:category::VARCHAR as category,
    result.value:summary::VARCHAR as summary,
    LEFT(result.value:chunk_text::VARCHAR, 150) as preview
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            '{"query": "liability indemnification", "columns": ["file_name", "category", "summary", "chunk_text"], "filter": {"@eq": {"category": "Contract"}}, "limit": 5}'
        )
    ):results AS results
), LATERAL FLATTEN(input => results) AS result;
```

#### 4.3 Search Financial Documents

```sql
-- Search for financial metrics
SELECT 
    result.value:file_name::VARCHAR as file_name,
    result.value:category::VARCHAR as category,
    result.value:summary::VARCHAR as summary
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            '{"query": "quarterly revenue earnings growth", "columns": ["file_name", "category", "summary"], "filter": {"@eq": {"category": "Financial Report"}}, "limit": 5}'
        )
    ):results AS results
), LATERAL FLATTEN(input => results) AS result;
```

#### 4.4 Search Technical Documents

```sql
-- Search for API specifications
SELECT 
    result.value:file_name::VARCHAR as file_name,
    result.value:category::VARCHAR as category,
    LEFT(result.value:chunk_text::VARCHAR, 200) as preview
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            '{"query": "API endpoint REST authentication", "columns": ["file_name", "category", "chunk_text"], "filter": {"@eq": {"category": "Technical Document"}}, "limit": 5}'
        )
    ):results AS results
), LATERAL FLATTEN(input => results) AS result;
```

#### 4.5 Search with Multiple Filters

```sql
-- Search with category and file extension filter
SELECT 
    result.value:file_name::VARCHAR as file_name,
    result.value:category::VARCHAR as category,
    result.value:tags::VARCHAR as tags,
    result.value:summary::VARCHAR as summary
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            '{"query": "employee benefits vacation policy", "columns": ["file_name", "category", "tags", "summary"], "filter": {"@and": [{"@eq": {"category": "HR Document"}}, {"@eq": {"file_extension": "txt"}}]}, "limit": 5}'
        )
    ):results AS results
), LATERAL FLATTEN(input => results) AS result;
```

#### 4.6 Search Across All Documents (No Filter)

```sql
-- Broad search across all document types
SELECT 
    result.value:document_id::INT as document_id,
    result.value:file_name::VARCHAR as file_name,
    result.value:category::VARCHAR as category,
    result.value:chunk_index::INT as chunk_index,
    LEFT(result.value:chunk_text::VARCHAR, 100) as preview
FROM (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            '{"query": "compliance requirements regulations", "columns": ["document_id", "file_name", "category", "chunk_index", "chunk_text"], "limit": 10}'
        )
    ):results AS results
), LATERAL FLATTEN(input => results) AS result;
```

#### 4.7 Check Search Service Status

```sql
-- Verify the search service is running
SHOW CORTEX SEARCH SERVICES IN SCHEMA DOC_INTELLIGENCE.PROCESSED;

-- Check the underlying view has data
SELECT COUNT(*) as total_chunks FROM DOC_INTELLIGENCE.PROCESSED.SEARCHABLE_DOCUMENTS;

-- View sample data in the searchable view
SELECT * FROM DOC_INTELLIGENCE.PROCESSED.SEARCHABLE_DOCUMENTS LIMIT 5;
```

#### Search Tips

| Tip | Description |
|-----|-------------|
| **Natural language** | Use natural questions like "What are the payment terms?" |
| **Keywords** | Include specific terms from your glossary for better matches |
| **Filters** | Use category filters to narrow results to specific document types |
| **Chunk context** | Results return chunks, not full documents - check chunk_index for position |
| **Target lag** | Search index updates based on service target_lag (default: 1 hour) |

---

## Expected Classification Results

After running the pipeline, you should see:

| Document | Expected Category | Expected Tags |
|----------|-------------------|---------------|
| nda_acme_techstart.txt | Contract | Confidential, Legal-Review-Required |
| msa_riverside_cloudmed.txt | Contract | Confidential, HIPAA, Contains-PHI |
| security_policy_globex.txt | Policy | Internal, SOC2, GDPR |
| employee_handbook_summit.txt | HR Document | Internal, Final |
| quarterly_report_nexgen_q4_2024.txt | Financial Report | Public, Financial-Data, Investor-Relations |
| prd_datasync_v3.txt | Technical Document | Internal, Draft |

---

## Customizing the Semantic Model

### Adding a New Category

```sql
INSERT INTO DOC_INTELLIGENCE.SEMANTIC.CATEGORIES (category_name, description)
VALUES ('Meeting Notes', 'Notes and minutes from meetings and discussions');
```

### Adding New Tags

```sql
INSERT INTO DOC_INTELLIGENCE.SEMANTIC.TAGS (tag_name, description)
VALUES 
    ('Urgent', 'Time-sensitive document requiring immediate attention'),
    ('Board-Level', 'Relevant to board of directors');
```

### Adding Glossary Terms

```sql
INSERT INTO DOC_INTELLIGENCE.SEMANTIC.GLOSSARY (term, definition)
VALUES ('IPO', 'Initial Public Offering - the first sale of stock by a company to the public');
```

After updating the semantic model, all future annotations will use the new options.

---

## Troubleshooting

### Documents not appearing in directory table

```sql
-- Refresh the stage
ALTER STAGE DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE REFRESH;

-- List files directly
LIST @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE;
```

### Parsing fails

```sql
-- Check error message
SELECT file_name, status, error_message 
FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
WHERE status = 'FAILED';

-- Retry parsing
UPDATE DOC_INTELLIGENCE.RAW.DOCUMENTS SET status = 'PENDING', error_message = NULL WHERE status = 'FAILED';
CALL DOC_INTELLIGENCE.RAW.RUN_INGESTION('Manual Upload', 10);
```

### Annotation fails

```sql
-- Check if chunks exist
SELECT document_id, COUNT(*) as chunks 
FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS 
GROUP BY document_id;

-- Re-run annotation
CALL DOC_INTELLIGENCE.PROCESSED.RUN_ANNOTATION(10);
```

### Search returns no results

```sql
-- Check if Cortex Search Service is active
SHOW CORTEX SEARCH SERVICES IN SCHEMA DOC_INTELLIGENCE.PROCESSED;

-- Check searchable view has data
SELECT COUNT(*) FROM DOC_INTELLIGENCE.PROCESSED.SEARCHABLE_DOCUMENTS;

-- Wait for index refresh (target lag is 1 hour, but typically faster)
```

---

## Cleanup

To reset and start fresh:

```sql
-- Delete all data (keeps schema)
TRUNCATE TABLE DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS;
TRUNCATE TABLE DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS;
TRUNCATE TABLE DOC_INTELLIGENCE.PROCESSED.DOCUMENT_VECTORS;
TRUNCATE TABLE DOC_INTELLIGENCE.RAW.DOCUMENTS;

-- Remove files from stage
REMOVE @DOC_INTELLIGENCE.RAW.INTERNAL_DOCUMENTS_STAGE;
```

---

## Running the Streamlit Dashboard

After processing documents, test the UI:

```bash
cd streamlit
pip install -r requirements.txt

# Set connection (if running locally)
export SNOWFLAKE_ACCOUNT=your_account
export SNOWFLAKE_USER=your_user
export SNOWFLAKE_PASSWORD=your_password

streamlit run app.py
```

Then:
1. **Home**: Check pipeline metrics show 6 documents
2. **Search**: Search for "confidential" or "revenue"
3. **Document Viewer**: Select a document and view annotation
4. **Analytics**: View category distribution chart
