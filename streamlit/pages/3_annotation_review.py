"""
Annotation Review Page
======================
Review and approve/reject LLM annotations.
"""

import streamlit as st
from utils.snowflake_conn import get_connection, run_query

st.set_page_config(page_title="Annotation Review", page_icon="✅", layout="wide")

st.title("✅ Annotation Review")
st.caption("Review and approve LLM-generated annotations")

conn = get_connection()

if conn:
    # Filter options
    col1, col2, col3 = st.columns(3)
    
    with col1:
        status_filter = st.selectbox(
            "Review Status",
            options=["PENDING", "APPROVED", "REJECTED", "All"]
        )
    
    with col2:
        confidence_filter = st.slider(
            "Minimum Confidence",
            min_value=0.0,
            max_value=1.0,
            value=0.0,
            step=0.1
        )
    
    with col3:
        sort_order = st.selectbox(
            "Sort By",
            options=["Newest First", "Oldest First", "Lowest Confidence", "Highest Confidence"]
        )
    
    st.divider()
    
    # Build query
    where_clause = "WHERE 1=1"
    if status_filter != "All":
        where_clause += f" AND a.review_status = '{status_filter}'"
    if confidence_filter > 0:
        where_clause += f" AND a.confidence >= {confidence_filter}"
    
    order_clause = {
        "Newest First": "d.annotated_at DESC",
        "Oldest First": "d.annotated_at ASC",
        "Lowest Confidence": "a.confidence ASC",
        "Highest Confidence": "a.confidence DESC"
    }.get(sort_order, "d.annotated_at DESC")
    
    review_query = f"""
    SELECT 
        a.annotation_id,
        d.document_id,
        d.file_name,
        c.category_name as category,
        a.summary,
        a.tags,
        a.key_terms,
        a.entities,
        a.confidence,
        a.review_status,
        a.model_name,
        a.reviewed_by,
        a.reviewed_at,
        a.review_notes,
        d.annotated_at
    FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a
    JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON a.document_id = d.document_id
    LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
    {where_clause}
    ORDER BY {order_clause}
    LIMIT 50
    """
    
    annotations = run_query(review_query)
    
    if annotations is not None and len(annotations) > 0:
        # Stats
        st.markdown(f"**Showing {len(annotations)} annotations**")
        
        # Review cards
        for idx, row in annotations.iterrows():
            with st.container():
                # Header
                header_col1, header_col2, header_col3 = st.columns([3, 1, 1])
                
                with header_col1:
                    st.markdown(f"### 📄 {row['FILE_NAME']}")
                
                with header_col2:
                    status_emoji = {
                        'PENDING': '🟡',
                        'APPROVED': '✅',
                        'REJECTED': '❌',
                        'MODIFIED': '✏️'
                    }.get(row['REVIEW_STATUS'], '⚪')
                    st.markdown(f"**Status:** {status_emoji} {row['REVIEW_STATUS']}")
                
                with header_col3:
                    if row['CONFIDENCE']:
                        conf_color = "green" if row['CONFIDENCE'] >= 0.8 else "orange" if row['CONFIDENCE'] >= 0.5 else "red"
                        st.markdown(f"**Confidence:** :{conf_color}[{row['CONFIDENCE']:.0%}]")
                
                # Content
                content_col1, content_col2 = st.columns([2, 1])
                
                with content_col1:
                    st.markdown(f"**Category:** `{row['CATEGORY']}`" if row['CATEGORY'] else "No category")
                    st.markdown(f"**Summary:** {row['SUMMARY']}" if row['SUMMARY'] else "No summary")
                    
                    if row['TAGS']:
                        tags = row['TAGS'] if isinstance(row['TAGS'], list) else []
                        st.markdown(f"**Tags:** {', '.join([f'`{t}`' for t in tags])}")
                
                with content_col2:
                    st.markdown(f"**Model:** {row['MODEL_NAME']}")
                    st.markdown(f"**Annotated:** {row['ANNOTATED_AT']}")
                    if row['REVIEWED_BY']:
                        st.markdown(f"**Reviewed by:** {row['REVIEWED_BY']}")
                
                # Review actions
                if row['REVIEW_STATUS'] == 'PENDING':
                    action_col1, action_col2, action_col3, action_col4 = st.columns(4)
                    
                    with action_col1:
                        if st.button("✅ Approve", key=f"approve_{row['ANNOTATION_ID']}", use_container_width=True):
                            run_query(f"""
                                UPDATE DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS 
                                SET review_status = 'APPROVED',
                                    reviewed_by = CURRENT_USER(),
                                    reviewed_at = CURRENT_TIMESTAMP()
                                WHERE annotation_id = {row['ANNOTATION_ID']}
                            """)
                            st.success("Approved!")
                            st.rerun()
                    
                    with action_col2:
                        if st.button("❌ Reject", key=f"reject_{row['ANNOTATION_ID']}", use_container_width=True):
                            run_query(f"""
                                UPDATE DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS 
                                SET review_status = 'REJECTED',
                                    reviewed_by = CURRENT_USER(),
                                    reviewed_at = CURRENT_TIMESTAMP()
                                WHERE annotation_id = {row['ANNOTATION_ID']}
                            """)
                            st.warning("Rejected")
                            st.rerun()
                    
                    with action_col3:
                        if st.button("🔄 Re-annotate", key=f"reannotate_{row['ANNOTATION_ID']}", use_container_width=True):
                            with st.spinner("Re-annotating..."):
                                result = run_query(f"CALL DOC_INTELLIGENCE.PROCESSED.ANNOTATE_DOCUMENT({row['DOCUMENT_ID']})")
                                if result is not None:
                                    st.success("Re-annotated!")
                                    st.rerun()
                    
                    with action_col4:
                        if st.button("📄 View Doc", key=f"view_{row['ANNOTATION_ID']}", use_container_width=True):
                            st.session_state['selected_doc_id'] = row['DOCUMENT_ID']
                            st.switch_page("pages/2_document_viewer.py")
                
                st.divider()
        
        # Bulk actions
        st.subheader("Bulk Actions")
        bulk_col1, bulk_col2 = st.columns(2)
        
        with bulk_col1:
            if st.button("✅ Approve All High Confidence (≥80%)", use_container_width=True):
                result = run_query("""
                    UPDATE DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS 
                    SET review_status = 'APPROVED',
                        reviewed_by = CURRENT_USER(),
                        reviewed_at = CURRENT_TIMESTAMP()
                    WHERE review_status = 'PENDING' AND confidence >= 0.8
                """)
                st.success("Approved all high confidence annotations!")
                st.rerun()
        
        with bulk_col2:
            if st.button("🔍 Flag Low Confidence (<50%) for Review", use_container_width=True):
                # Just filters - already visible
                st.info("Use the confidence filter above to view low confidence annotations")
    
    else:
        st.info("No annotations found matching your filters.")

else:
    st.error("Could not connect to Snowflake")
