"""
Document Intelligence Pipeline - Streamlit Dashboard
=====================================================
Main application entry point with navigation.
"""

import streamlit as st

st.set_page_config(
    page_title="Document Intelligence",
    page_icon="📄",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: 700;
        margin-bottom: 0.5rem;
    }
    .sub-header {
        font-size: 1.1rem;
        color: #666;
        margin-bottom: 2rem;
    }
    .metric-card {
        background: #f8f9fa;
        border-radius: 8px;
        padding: 1rem;
        text-align: center;
    }
    .stTabs [data-baseweb="tab-list"] {
        gap: 2rem;
    }
</style>
""", unsafe_allow_html=True)

# Header
st.markdown('<p class="main-header">📄 Document Intelligence Pipeline</p>', unsafe_allow_html=True)
st.markdown('<p class="sub-header">Classify, annotate, and search documents using Snowflake Cortex</p>', unsafe_allow_html=True)

# Get connection
from utils.snowflake_conn import get_connection, run_query, is_in_snowflake

conn = get_connection()
IN_SNOWFLAKE = is_in_snowflake()

if conn:
    # Dashboard metrics
    col1, col2, col3, col4, col5 = st.columns(5)
    
    # Get pipeline stats
    stats_query = """
    SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending,
        SUM(CASE WHEN status = 'PARSED' THEN 1 ELSE 0 END) as parsed,
        SUM(CASE WHEN status = 'ANNOTATED' THEN 1 ELSE 0 END) as annotated,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS
    """
    
    try:
        stats = run_query(stats_query)
        if stats is not None and len(stats) > 0:
            row = stats.iloc[0]
            col1.metric("Total Documents", int(row['TOTAL']))
            col2.metric("Pending", int(row['PENDING']))
            col3.metric("Parsed", int(row['PARSED']))
            col4.metric("Annotated", int(row['ANNOTATED']))
            col5.metric("Failed", int(row['FAILED']), delta_color="inverse")
        else:
            col1.metric("Total Documents", 0)
            col2.metric("Pending", 0)
            col3.metric("Parsed", 0)
            col4.metric("Annotated", 0)
            col5.metric("Failed", 0)
    except Exception as e:
        st.warning(f"Could not load stats: {e}")
    
    st.divider()
    
    # Quick actions
    st.subheader("Quick Actions")
    
    action_col1, action_col2, action_col3 = st.columns(3)
    
    with action_col1:
        st.markdown("### 🔍 Search Documents")
        st.write("Search across all annotated documents using semantic and keyword search.")
        if not IN_SNOWFLAKE:
            if st.button("Go to Search", type="primary", use_container_width=True):
                st.switch_page("pages/1_search.py")
        else:
            st.info("Navigate using the sidebar menu")
    
    with action_col2:
        st.markdown("### ⚙️ Run Pipeline")
        st.write("Process pending documents through ingestion and annotation.")
        if st.button("Run Pipeline", use_container_width=True):
            with st.spinner("Running pipeline..."):
                try:
                    result = run_query("CALL DOC_INTELLIGENCE.RAW.FULL_PIPELINE('Manual Upload', 5)")
                    if result is not None:
                        st.success(result.iloc[0, 0])
                        st.rerun()
                except Exception as e:
                    st.error(f"Pipeline error: {e}")
    
    with action_col3:
        st.markdown("### 📊 View Analytics")
        st.write("Explore document statistics and annotation insights.")
        if not IN_SNOWFLAKE:
            if st.button("View Analytics", use_container_width=True):
                st.switch_page("pages/4_analytics.py")
        else:
            st.info("Navigate using the sidebar menu")
    
    st.divider()
    
    # Recent documents
    st.subheader("Recent Documents")
    
    recent_query = """
    SELECT 
        d.document_id,
        d.file_name,
        d.status,
        c.category_name as category,
        d.discovered_at,
        d.annotated_at
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
    LEFT JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
    LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
    ORDER BY d.discovered_at DESC
    LIMIT 10
    """
    
    try:
        recent = run_query(recent_query)
        if recent is not None and len(recent) > 0:
            st.dataframe(
                recent,
                column_config={
                    "DOCUMENT_ID": st.column_config.NumberColumn("ID", width="small"),
                    "FILE_NAME": st.column_config.TextColumn("File Name", width="large"),
                    "STATUS": st.column_config.TextColumn("Status", width="small"),
                    "CATEGORY": st.column_config.TextColumn("Category", width="medium"),
                    "DISCOVERED_AT": st.column_config.DatetimeColumn("Discovered", width="medium"),
                    "ANNOTATED_AT": st.column_config.DatetimeColumn("Annotated", width="medium"),
                },
                hide_index=True,
                use_container_width=True
            )
        else:
            st.info("No documents found. Upload documents to the internal stage to get started.")
    except Exception as e:
        st.error(f"Could not load recent documents: {e}")

else:
    st.error("Could not connect to Snowflake. Please check your connection settings.")
    st.info("""
    **Setup Instructions:**
    1. Configure your Snowflake connection in `utils/snowflake_conn.py`
    2. Or set environment variables: `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`
    """)

# Sidebar
with st.sidebar:
    st.markdown("### Navigation")
    st.page_link("app.py", label="🏠 Home", icon="🏠")
    st.page_link("pages/1_search.py", label="🔍 Search")
    st.page_link("pages/2_document_viewer.py", label="📄 Document Viewer")
    st.page_link("pages/3_annotation_review.py", label="✅ Annotation Review")
    st.page_link("pages/4_analytics.py", label="📊 Analytics")
    st.page_link("pages/5_taxonomy_manager.py", label="🏷️ Taxonomy Manager")
    
    st.divider()
    st.markdown("### About")
    st.caption("Document Intelligence Pipeline powered by Snowflake Cortex")
