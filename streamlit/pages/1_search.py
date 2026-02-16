"""
Search Page
===========
Semantic and faceted search for documents.
"""

import streamlit as st
from utils.snowflake_conn import get_connection, run_query

st.set_page_config(page_title="Search Documents", page_icon="🔍", layout="wide")

st.title("🔍 Document Search")
st.caption("Search across all documents using semantic and keyword matching")

conn = get_connection()

if conn:
    # Search input
    col1, col2 = st.columns([3, 1])
    
    with col1:
        search_query = st.text_input(
            "Search query",
            placeholder="Enter keywords or natural language query...",
            label_visibility="collapsed"
        )
    
    with col2:
        search_btn = st.button("🔍 Search", type="primary", use_container_width=True)
    
    # Filters
    with st.expander("🎛️ Filters", expanded=False):
        filter_col1, filter_col2, filter_col3, filter_col4 = st.columns(4)
        
        # Load filter options
        categories = run_query("SELECT category_name FROM DOC_INTELLIGENCE.SEMANTIC.CATEGORIES WHERE is_active = TRUE ORDER BY category_name")
        
        with filter_col1:
            category_filter = st.selectbox(
                "Category",
                options=["All"] + (categories['CATEGORY_NAME'].tolist() if categories is not None else [])
            )
        
        with filter_col2:
            file_type_filter = st.selectbox(
                "File Type",
                options=["All", "pdf", "docx", "txt", "png", "jpg"]
            )
        
        with filter_col3:
            source_filter = st.selectbox(
                "Source",
                options=["All", "INTERNAL", "EXTERNAL"]
            )
        
        with filter_col4:
            max_results = st.slider("Max Results", min_value=5, max_value=50, value=10)
    
    st.divider()
    
    # Execute search
    if search_query and (search_btn or search_query):
        with st.spinner("Searching..."):
            # Build filter conditions
            filter_conditions = []
            if category_filter != "All":
                filter_conditions.append(f"'@eq': {{'category': '{category_filter}'}}")
            if file_type_filter != "All":
                filter_conditions.append(f"'@eq': {{'file_extension': '{file_type_filter}'}}")
            
            # Escape query for SQL
            safe_query = search_query.replace("'", "''")
            
            search_sql = f"""
            SELECT 
                document_id::INT as document_id,
                chunk_id::INT as chunk_id,
                file_name::VARCHAR as file_name,
                category::VARCHAR as category,
                LEFT(chunk_text::VARCHAR, 300) as preview,
                summary::VARCHAR as summary,
                tags::VARCHAR as tags,
                file_url::VARCHAR as file_url
            FROM TABLE(
                SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'DOC_INTELLIGENCE.PROCESSED.DOCUMENT_SEARCH_SERVICE',
                    {{
                        'query': '{safe_query}',
                        'columns': ['document_id', 'chunk_id', 'file_name', 'category', 'chunk_text', 'summary', 'tags', 'file_url'],
                        'limit': {max_results}
                    }}
                )
            )
            """
            
            results = run_query(search_sql)
            
            if results is not None and len(results) > 0:
                st.success(f"Found {len(results)} results")
                
                # Display results
                for idx, row in results.iterrows():
                    with st.container():
                        col1, col2 = st.columns([4, 1])
                        
                        with col1:
                            st.markdown(f"### 📄 {row['FILE_NAME']}")
                            
                            # Tags
                            tag_col1, tag_col2 = st.columns(2)
                            with tag_col1:
                                if row['CATEGORY']:
                                    st.markdown(f"**Category:** `{row['CATEGORY']}`")
                            with tag_col2:
                                if row['TAGS']:
                                    st.markdown(f"**Tags:** {row['TAGS']}")
                            
                            # Summary
                            if row['SUMMARY']:
                                st.markdown(f"**Summary:** {row['SUMMARY']}")
                            
                            # Preview
                            st.markdown("**Preview:**")
                            st.markdown(f"> {row['PREVIEW']}...")
                        
                        with col2:
                            st.markdown("")
                            st.markdown("")
                            if st.button("View Details", key=f"view_{idx}", use_container_width=True):
                                st.session_state['selected_doc_id'] = row['DOCUMENT_ID']
                                st.switch_page("pages/2_document_viewer.py")
                        
                        st.divider()
            else:
                st.info("No results found. Try a different query or adjust filters.")
    
    elif not search_query:
        # Show recent documents when no search
        st.subheader("Recent Annotated Documents")
        
        recent_sql = """
        SELECT 
            d.document_id,
            d.file_name,
            c.category_name as category,
            a.summary,
            ARRAY_TO_STRING(a.tags, ', ') as tags,
            d.annotated_at
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
        JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
        LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
        WHERE d.status = 'ANNOTATED'
        ORDER BY d.annotated_at DESC
        LIMIT 20
        """
        
        recent = run_query(recent_sql)
        
        if recent is not None and len(recent) > 0:
            st.dataframe(
                recent,
                column_config={
                    "DOCUMENT_ID": st.column_config.NumberColumn("ID", width="small"),
                    "FILE_NAME": st.column_config.TextColumn("File Name", width="large"),
                    "CATEGORY": st.column_config.TextColumn("Category", width="medium"),
                    "SUMMARY": st.column_config.TextColumn("Summary", width="large"),
                    "TAGS": st.column_config.TextColumn("Tags", width="medium"),
                    "ANNOTATED_AT": st.column_config.DatetimeColumn("Annotated", width="medium"),
                },
                hide_index=True,
                use_container_width=True
            )
        else:
            st.info("No annotated documents yet. Run the pipeline to process documents.")

else:
    st.error("Could not connect to Snowflake")
