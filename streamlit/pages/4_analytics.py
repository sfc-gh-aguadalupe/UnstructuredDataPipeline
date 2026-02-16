"""
Analytics Page
==============
Document and annotation statistics dashboard.
"""

import streamlit as st
from utils.snowflake_conn import get_connection, run_query

st.set_page_config(page_title="Analytics", page_icon="📊", layout="wide")

st.title("📊 Analytics Dashboard")
st.caption("Document processing and annotation insights")

conn = get_connection()

if conn:
    # Overview metrics
    st.subheader("Pipeline Overview")
    
    metrics_query = """
    SELECT 
        COUNT(*) as total_docs,
        SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending,
        SUM(CASE WHEN status = 'PARSED' THEN 1 ELSE 0 END) as parsed,
        SUM(CASE WHEN status = 'ANNOTATED' THEN 1 ELSE 0 END) as annotated,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed,
        AVG(word_count) as avg_words,
        SUM(file_size_bytes) / 1024 / 1024 as total_size_mb
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS
    """
    
    metrics = run_query(metrics_query)
    
    if metrics is not None and len(metrics) > 0:
        row = metrics.iloc[0]
        
        col1, col2, col3, col4, col5, col6 = st.columns(6)
        col1.metric("Total Documents", int(row['TOTAL_DOCS']))
        col2.metric("Pending", int(row['PENDING']))
        col3.metric("Parsed", int(row['PARSED']))
        col4.metric("Annotated", int(row['ANNOTATED']))
        col5.metric("Failed", int(row['FAILED']))
        col6.metric("Total Size", f"{row['TOTAL_SIZE_MB']:.1f} MB" if row['TOTAL_SIZE_MB'] else "0 MB")
    
    st.divider()
    
    # Charts
    chart_col1, chart_col2 = st.columns(2)
    
    with chart_col1:
        st.subheader("Documents by Category")
        
        category_query = """
        SELECT 
            COALESCE(c.category_name, 'Uncategorized') as category,
            COUNT(*) as count
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
        LEFT JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
        LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
        GROUP BY c.category_name
        ORDER BY count DESC
        """
        
        categories = run_query(category_query)
        
        if categories is not None and len(categories) > 0:
            st.bar_chart(categories.set_index('CATEGORY')['COUNT'])
        else:
            st.info("No category data available")
    
    with chart_col2:
        st.subheader("Documents by File Type")
        
        filetype_query = """
        SELECT 
            COALESCE(file_extension, 'unknown') as file_type,
            COUNT(*) as count
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS
        GROUP BY file_extension
        ORDER BY count DESC
        """
        
        filetypes = run_query(filetype_query)
        
        if filetypes is not None and len(filetypes) > 0:
            st.bar_chart(filetypes.set_index('FILE_TYPE')['COUNT'])
        else:
            st.info("No file type data available")
    
    st.divider()
    
    # Annotation quality
    st.subheader("Annotation Quality")
    
    quality_col1, quality_col2 = st.columns(2)
    
    with quality_col1:
        st.markdown("### Confidence Distribution")
        
        confidence_query = """
        SELECT 
            CASE 
                WHEN confidence >= 0.9 THEN '90-100%'
                WHEN confidence >= 0.8 THEN '80-90%'
                WHEN confidence >= 0.7 THEN '70-80%'
                WHEN confidence >= 0.6 THEN '60-70%'
                WHEN confidence >= 0.5 THEN '50-60%'
                ELSE 'Below 50%'
            END as confidence_range,
            COUNT(*) as count
        FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS
        GROUP BY confidence_range
        ORDER BY confidence_range DESC
        """
        
        confidence = run_query(confidence_query)
        
        if confidence is not None and len(confidence) > 0:
            st.bar_chart(confidence.set_index('CONFIDENCE_RANGE')['COUNT'])
        else:
            st.info("No confidence data available")
    
    with quality_col2:
        st.markdown("### Review Status")
        
        review_query = """
        SELECT 
            review_status,
            COUNT(*) as count
        FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS
        GROUP BY review_status
        ORDER BY count DESC
        """
        
        reviews = run_query(review_query)
        
        if reviews is not None and len(reviews) > 0:
            st.bar_chart(reviews.set_index('REVIEW_STATUS')['COUNT'])
        else:
            st.info("No review data available")
    
    st.divider()
    
    # Processing timeline
    st.subheader("Processing Timeline")
    
    timeline_query = """
    SELECT 
        DATE_TRUNC('day', discovered_at) as date,
        COUNT(*) as discovered,
        SUM(CASE WHEN parsed_at IS NOT NULL THEN 1 ELSE 0 END) as parsed,
        SUM(CASE WHEN annotated_at IS NOT NULL THEN 1 ELSE 0 END) as annotated
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS
    WHERE discovered_at >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY DATE_TRUNC('day', discovered_at)
    ORDER BY date
    """
    
    timeline = run_query(timeline_query)
    
    if timeline is not None and len(timeline) > 0:
        st.line_chart(timeline.set_index('DATE')[['DISCOVERED', 'PARSED', 'ANNOTATED']])
    else:
        st.info("No timeline data available")
    
    st.divider()
    
    # Tag usage
    st.subheader("Most Common Tags")
    
    tags_query = """
    SELECT 
        t.value::VARCHAR as tag,
        COUNT(*) as usage_count
    FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a,
    LATERAL FLATTEN(input => a.tags) t
    GROUP BY t.value
    ORDER BY usage_count DESC
    LIMIT 15
    """
    
    tags = run_query(tags_query)
    
    if tags is not None and len(tags) > 0:
        st.bar_chart(tags.set_index('TAG')['USAGE_COUNT'])
    else:
        st.info("No tag data available")
    
    st.divider()
    
    # Entity extraction summary
    st.subheader("Extracted Entities Summary")
    
    entity_col1, entity_col2, entity_col3, entity_col4 = st.columns(4)
    
    with entity_col1:
        st.markdown("**Top People**")
        people_query = """
        SELECT p.value::VARCHAR as name, COUNT(*) as cnt
        FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a,
        LATERAL FLATTEN(input => a.entities:people) p
        GROUP BY p.value ORDER BY cnt DESC LIMIT 5
        """
        people = run_query(people_query)
        if people is not None and len(people) > 0:
            for _, r in people.iterrows():
                st.write(f"- {r['NAME']} ({r['CNT']})")
        else:
            st.caption("No data")
    
    with entity_col2:
        st.markdown("**Top Organizations**")
        orgs_query = """
        SELECT o.value::VARCHAR as name, COUNT(*) as cnt
        FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a,
        LATERAL FLATTEN(input => a.entities:organizations) o
        GROUP BY o.value ORDER BY cnt DESC LIMIT 5
        """
        orgs = run_query(orgs_query)
        if orgs is not None and len(orgs) > 0:
            for _, r in orgs.iterrows():
                st.write(f"- {r['NAME']} ({r['CNT']})")
        else:
            st.caption("No data")
    
    with entity_col3:
        st.markdown("**Top Locations**")
        locs_query = """
        SELECT l.value::VARCHAR as name, COUNT(*) as cnt
        FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a,
        LATERAL FLATTEN(input => a.entities:locations) l
        GROUP BY l.value ORDER BY cnt DESC LIMIT 5
        """
        locs = run_query(locs_query)
        if locs is not None and len(locs) > 0:
            for _, r in locs.iterrows():
                st.write(f"- {r['NAME']} ({r['CNT']})")
        else:
            st.caption("No data")
    
    with entity_col4:
        st.markdown("**Date Mentions**")
        dates_query = """
        SELECT d.value::VARCHAR as date_val, COUNT(*) as cnt
        FROM DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a,
        LATERAL FLATTEN(input => a.entities:dates) d
        GROUP BY d.value ORDER BY cnt DESC LIMIT 5
        """
        dates = run_query(dates_query)
        if dates is not None and len(dates) > 0:
            for _, r in dates.iterrows():
                st.write(f"- {r['DATE_VAL']} ({r['CNT']})")
        else:
            st.caption("No data")

else:
    st.error("Could not connect to Snowflake")
