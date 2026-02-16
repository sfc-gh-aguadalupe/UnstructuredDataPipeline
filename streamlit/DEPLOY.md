# Deploying Streamlit App to Snowflake

## Option 1: Snow CLI (Recommended)

### Step 1: Deploy with one command

```bash
cd streamlit
snow streamlit deploy --connection <your_connection> --database DOC_INTELLIGENCE --schema RAW --warehouse DOC_INTELLIGENCE_WH --replace
```

This command:
- Uploads all files (app.py, environment.yml, pages/, utils/)
- Creates the Streamlit app in Snowflake
- Uses the `snowflake.yml` configuration

### Step 2: Get the app URL

```bash
snow streamlit get-url DOC_INTELLIGENCE_APP --connection <your_connection> --database DOC_INTELLIGENCE --schema RAW
```

Or open directly:
```bash
snow streamlit deploy --connection <your_connection> --database DOC_INTELLIGENCE --schema RAW --warehouse DOC_INTELLIGENCE_WH --replace --open
```

---

## Option 2: Snow CLI (Step by Step)

### Step 1: Upload files to stage

```bash
# Create stage and upload all files
snow object stage create DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE --connection <your_connection>

# Upload files
snow object stage copy app.py @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/ --connection <your_connection> --overwrite
snow object stage copy environment.yml @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/ --connection <your_connection> --overwrite
snow object stage copy pages/ @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/pages/ --connection <your_connection> --overwrite --recursive
snow object stage copy utils/ @DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE/utils/ --connection <your_connection> --overwrite --recursive
```

### Step 2: Create Streamlit app via SQL

```bash
snow sql -q "CREATE OR REPLACE STREAMLIT DOC_INTELLIGENCE.RAW.DOC_INTELLIGENCE_APP ROOT_LOCATION = '@DOC_INTELLIGENCE.RAW.STREAMLIT_STAGE' MAIN_FILE = 'app.py' QUERY_WAREHOUSE = DOC_INTELLIGENCE_WH" --connection <your_connection>
```

### Step 3: Verify deployment

```bash
snow sql -q "SHOW STREAMLITS IN SCHEMA DOC_INTELLIGENCE.RAW" --connection <your_connection>
```

---

## Option 3: Snowsight UI

1. Go to **Snowsight** > **Projects** > **Streamlit**
2. Click **+ Streamlit App**
3. Configure:
   - Database: `DOC_INTELLIGENCE`
   - Schema: `RAW`
   - Warehouse: `DOC_INTELLIGENCE_WH`
   - App name: `DOC_INTELLIGENCE_APP`
4. Upload files from `streamlit/` folder in the editor
5. Click **Run**

---

## Option 4: Local Development

Run the app locally while connected to Snowflake:

```bash
cd streamlit

# Set environment variables
export SNOWFLAKE_ACCOUNT=your_account
export SNOWFLAKE_USER=your_user
export SNOWFLAKE_PASSWORD=your_password

# Or use .streamlit/secrets.toml:
# [connections.snowflake]
# account = "your_account"
# user = "your_user"
# password = "your_password"
# warehouse = "DOC_INTELLIGENCE_WH"
# database = "DOC_INTELLIGENCE"

# Install dependencies
pip install -r requirements.txt

# Run
streamlit run app.py
```

---

## Files Structure

```
streamlit/
├── app.py                 # Main application (entry point)
├── environment.yml        # SiS dependencies (conda format)
├── snowflake.yml          # Snow CLI configuration
├── requirements.txt       # Local pip dependencies
├── DEPLOY.md              # This file
├── pages/
│   ├── 1_search.py
│   ├── 2_document_viewer.py
│   ├── 3_annotation_review.py
│   ├── 4_analytics.py
│   └── 5_taxonomy_manager.py
└── utils/
    ├── snowflake_conn.py
    ├── annotation_utils.py
    └── search_utils.py
```

---

## Troubleshooting

### Certificate errors with Snow CLI
If you encounter certificate validation errors:
```bash
# Try with insecure mode (not recommended for production)
snow streamlit deploy --connection <your_connection> --replace

# Or use Snowsight UI as alternative
```

### Connection issues
Verify your connection:
```bash
snow connection test --connection <your_connection>
```

### Missing dependencies in SiS
Edit `environment.yml` to add required packages from the Snowflake Anaconda channel.
