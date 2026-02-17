# Ontology-Based Document Annotation Demo

A Streamlit application showcasing Milestone 8: JSON-LD ontology-based document annotation.

## Features

| Page | Description |
|------|-------------|
| **Overview** | Architecture diagram, metrics, and key concepts |
| **Hierarchy** | Visualize ontology class hierarchy from JSON-LD |
| **Tag Groups** | View mutual exclusivity rules embedded in ontology |
| **Annotate** | Run LLM annotation with ontology context |
| **Results** | View all annotations with confidence scores |

## Screenshots

### Overview Page
- Metrics: class count, tag groups, annotations, average confidence
- Architecture diagram showing data flow
- Key concepts explanation

### Hierarchy Page
- Tree visualization from `GET_ONTOLOGY_HIERARCHY()` function
- Raw class table with labels, descriptions, and synonyms

### Tag Groups Page
- Visual cards for each tag group
- Highlights mutual exclusivity constraints
- Raw JSON-LD view

### Annotate Page
- Document selector with preview
- One-click annotation with ontology context
- Results displayed immediately

### Results Page
- Summary metrics and charts
- Detailed annotations with reasoning

## Deployment to Snowflake (Streamlit in Snowflake)

### Prerequisites

1. Milestone 8 components deployed to `DOC_INTELLIGENCE.EXPERIMENT` schema
2. Ontology loaded into `ONTOLOGY_CACHE` table
3. Appropriate permissions for Streamlit creation

### Step 1: Create the Streamlit App

```sql
-- Connect to Snowflake
USE ROLE DOC_INTELLIGENCE_ADMIN;
USE DATABASE DOC_INTELLIGENCE;
USE SCHEMA EXPERIMENT;
USE WAREHOUSE DOC_INTELLIGENCE_WH;

-- Create the Streamlit app
CREATE OR REPLACE STREAMLIT ONTOLOGY_ANNOTATION_DEMO
  ROOT_LOCATION = '@DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE/ontology_app'
  MAIN_FILE = '/ontology_app.py'
  QUERY_WAREHOUSE = DOC_INTELLIGENCE_WH
  COMMENT = 'Milestone 8: Ontology-Based Document Annotation Demo';
```

### Step 2: Create Stage and Upload File

```sql
-- Create stage for Streamlit files
CREATE OR REPLACE STAGE DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE);

-- Upload the app file (using SnowCLI)
-- snow stage copy ontology_app.py @DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE/ontology_app/ --connection uswest2demo
```

Or using PUT command:
```sql
PUT file:///path/to/ontology_app.py @DOC_INTELLIGENCE.EXPERIMENT.STREAMLIT_STAGE/ontology_app/
  AUTO_COMPRESS = FALSE
  OVERWRITE = TRUE;
```

### Step 3: Grant Access

```sql
-- Grant access to view the app
GRANT USAGE ON STREAMLIT DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_ANNOTATION_DEMO 
  TO ROLE DOC_INTELLIGENCE_USER;
```

### Step 4: Access the App

1. Go to Snowsight
2. Navigate to: **Projects** > **Streamlit**
3. Find `ONTOLOGY_ANNOTATION_DEMO`
4. Click to open

Or direct URL:
```
https://<account>.snowflakecomputing.com/streamlit/DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_ANNOTATION_DEMO
```

## Local Testing (Not Recommended)

This app is designed for Snowflake's Streamlit in Snowflake (SiS) environment. Local testing requires additional setup:

```bash
# Create conda environment
conda create -n ontology-demo python=3.10
conda activate ontology-demo

# Install dependencies
pip install streamlit pandas snowflake-snowpark-python

# Run (will fail without active Snowflake session)
streamlit run ontology_app.py
```

**Note:** Local execution will show an error because `get_active_session()` only works in SiS.

## Required Permissions

The app needs access to:

```sql
-- Tables
SELECT ON DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE
SELECT ON DOC_INTELLIGENCE.EXPERIMENT.EXPERIMENT_ANNOTATIONS
SELECT ON DOC_INTELLIGENCE.RAW.DOCUMENTS
SELECT ON DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CONTENT

-- Functions
USAGE ON FUNCTION DOC_INTELLIGENCE.EXPERIMENT.GET_ONTOLOGY_HIERARCHY(VARCHAR)
USAGE ON FUNCTION DOC_INTELLIGENCE.EXPERIMENT.GET_TAG_GROUPS(VARCHAR)

-- Procedures
USAGE ON PROCEDURE DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(VARCHAR, VARCHAR)
```

## App Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    STREAMLIT APP COMPONENTS                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────────┐                                             │
│   │   Sidebar    │  - Ontology selector                        │
│   │              │  - Navigation radio buttons                 │
│   └──────────────┘                                             │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐ │
│   │                     Main Content                          │ │
│   │                                                          │ │
│   │  📊 Overview  │ 🌳 Hierarchy │ 🏷️ Tags │ ✨ Annotate │ 📋│ │
│   │                                                          │ │
│   │  Cached queries to:                                      │ │
│   │  - ONTOLOGY_CACHE (JSON-LD)                             │ │
│   │  - GET_ONTOLOGY_HIERARCHY() function                    │ │
│   │  - GET_TAG_GROUPS() function                            │ │
│   │  - ANNOTATE_WITH_ONTOLOGY() procedure                   │ │
│   │  - EXPERIMENT_ANNOTATIONS table                         │ │
│   │                                                          │ │
│   └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Failed to get Snowflake session" | App must run in SiS environment |
| No ontologies shown | Check ONTOLOGY_CACHE has data |
| Annotation fails | Verify CORTEX.COMPLETE is available |
| Permission denied | Check role has required GRANTs |

## Related Components

- **Schema:** `DOC_INTELLIGENCE.EXPERIMENT`
- **Ontology Table:** `ONTOLOGY_CACHE`
- **Results Table:** `EXPERIMENT_ANNOTATIONS`
- **Functions:** `GET_ONTOLOGY_HIERARCHY()`, `GET_TAG_GROUPS()`
- **Procedure:** `ANNOTATE_WITH_ONTOLOGY()`

See the main [Milestone 8 README](../README.md) for full deployment details.
