"""
Snowflake Connection Utilities
==============================
Handles Snowflake connection for Streamlit app.
Supports both Streamlit in Snowflake (SiS) and local execution.
"""

import streamlit as st
import pandas as pd

# Detect if running in Snowflake
_IN_SNOWFLAKE = None
_SESSION = None

def _is_running_in_snowflake():
    """Check if running in Streamlit in Snowflake."""
    global _IN_SNOWFLAKE
    if _IN_SNOWFLAKE is None:
        try:
            from snowflake.snowpark.context import get_active_session
            _IN_SNOWFLAKE = True
        except ImportError:
            _IN_SNOWFLAKE = False
    return _IN_SNOWFLAKE


@st.cache_resource
def get_session():
    """Get Snowflake session - works in SiS."""
    global _SESSION
    if _SESSION is None:
        try:
            from snowflake.snowpark.context import get_active_session
            _SESSION = get_active_session()
        except Exception:
            _SESSION = None
    return _SESSION


@st.cache_resource
def get_connection():
    """Get Snowflake connection - works both in SiS and locally."""
    import os
    
    # Method 1: Streamlit in Snowflake (native session)
    if _is_running_in_snowflake():
        session = get_session()
        if session:
            return session
    
    # Method 2: Streamlit connection API (works in SiS and locally with secrets)
    try:
        conn = st.connection("snowflake")
        return conn
    except Exception:
        pass
    
    # Method 3: Fall back to snowflake-connector-python (local only)
    try:
        import snowflake.connector
        
        conn = snowflake.connector.connect(
            account=os.getenv("SNOWFLAKE_ACCOUNT", ""),
            user=os.getenv("SNOWFLAKE_USER", ""),
            password=os.getenv("SNOWFLAKE_PASSWORD", ""),
            warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "DOC_INTELLIGENCE_WH"),
            database=os.getenv("SNOWFLAKE_DATABASE", "DOC_INTELLIGENCE"),
            schema=os.getenv("SNOWFLAKE_SCHEMA", "RAW"),
            role=os.getenv("SNOWFLAKE_ROLE", "")
        )
        return conn
    except Exception as e:
        st.error(f"Connection failed: {e}")
        return None


def run_query(query: str, params: dict = None):
    """Execute a query and return results as DataFrame."""
    conn = get_connection()
    if conn is None:
        return pd.DataFrame()
    
    try:
        # Snowpark Session (SiS)
        if hasattr(conn, 'sql'):
            result = conn.sql(query)
            return result.to_pandas()
        # Streamlit connection
        elif hasattr(conn, 'query'):
            return conn.query(query, params=params)
        # Native connector
        else:
            cursor = conn.cursor()
            cursor.execute(query, params)
            columns = [desc[0] for desc in cursor.description] if cursor.description else []
            data = cursor.fetchall()
            cursor.close()
            return pd.DataFrame(data, columns=columns)
    except Exception as e:
        st.error(f"Query failed: {e}")
        return pd.DataFrame()


def call_procedure(procedure: str, *args):
    """Call a stored procedure."""
    args_str = ", ".join([f"'{a}'" if isinstance(a, str) else str(a) for a in args])
    query = f"CALL {procedure}({args_str})"
    return run_query(query)


def search_documents(query_text: str, limit: int = 10, filters: dict = None):
    """Search documents using Cortex Search Service."""
    
    # Escape single quotes in query
    safe_query = query_text.replace("'", "''")
    
    search_query = f"""
    SELECT 
        document_id,
        chunk_id,
        file_name,
        category,
        chunk_text,
        summary,
        tags,
        file_url
    FROM TABLE(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
            {{
                'query': '{safe_query}',
                'columns': ['document_id', 'chunk_id', 'file_name', 'category', 'chunk_text', 'summary', 'tags', 'file_url'],
                'limit': {limit}
            }}
        )
    )
    """
    
    return run_query(search_query)


def is_in_snowflake():
    """Public method to check execution environment."""
    return _is_running_in_snowflake()
