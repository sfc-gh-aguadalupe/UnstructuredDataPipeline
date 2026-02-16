"""
Document Viewer Page
====================
View document details, chunks, and annotations.
"""

import json
import streamlit as st
from utils.snowflake_conn import get_connection, run_query

st.set_page_config(page_title="Document Viewer", page_icon="📄", layout="wide")

st.title("📄 Document Viewer")

conn = get_connection()

if conn:
    # Document selector
    col1, col2 = st.columns([3, 1])
    
    with col1:
        # Get document list
        docs = run_query("""
            SELECT document_id, file_name, status 
            FROM DOC_INTELLIGENCE.RAW.DOCUMENTS 
            ORDER BY discovered_at DESC 
            LIMIT 100
        """)
        
        if docs is not None and len(docs) > 0:
            doc_options = {f"{row['FILE_NAME']} (ID: {row['DOCUMENT_ID']})": row['DOCUMENT_ID'] 
                          for _, row in docs.iterrows()}
            
            # Check for pre-selected document
            default_idx = 0
            if 'selected_doc_id' in st.session_state:
                for i, (label, doc_id) in enumerate(doc_options.items()):
                    if doc_id == st.session_state['selected_doc_id']:
                        default_idx = i
                        break
            
            selected_label = st.selectbox(
                "Select Document",
                options=list(doc_options.keys()),
                index=default_idx
            )
            selected_doc_id = doc_options[selected_label]
        else:
            st.warning("No documents found")
            st.stop()
    
    with col2:
        st.markdown("")
        st.markdown("")
        if st.button("🔄 Refresh", use_container_width=True):
            st.rerun()
    
    st.divider()
    
    if selected_doc_id:
        # Load document details
        doc_query = f"""
        SELECT 
            d.*,
            c.category_name,
            a.summary,
            a.tags,
            a.key_terms,
            a.entities,
            a.confidence,
            a.review_status,
            a.model_name
        FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
        LEFT JOIN DOC_INTELLIGENCE.PROCESSED.ANNOTATIONS a ON d.document_id = a.document_id
        LEFT JOIN DOC_INTELLIGENCE.SEMANTIC.CATEGORIES c ON a.category_id = c.category_id
        WHERE d.document_id = {selected_doc_id}
        """
        
        doc = run_query(doc_query)
        
        if doc is not None and len(doc) > 0:
            row = doc.iloc[0]
            
            # Document header
            col1, col2, col3 = st.columns([2, 1, 1])
            
            with col1:
                st.subheader(row['FILE_NAME'])
                st.caption(f"Path: {row['FILE_PATH']}")
            
            with col2:
                status_color = {
                    'PENDING': '🟡',
                    'PROCESSING': '🔵',
                    'PARSED': '🟢',
                    'ANNOTATED': '✅',
                    'FAILED': '🔴'
                }.get(row['STATUS'], '⚪')
                st.metric("Status", f"{status_color} {row['STATUS']}")
            
            with col3:
                if row['CATEGORY_NAME']:
                    st.metric("Category", row['CATEGORY_NAME'])
            
            # Tabs for different views
            tab1, tab2, tab3, tab4 = st.tabs(["📝 Annotation", "📖 Content", "ℹ️ Metadata", "🔧 Actions"])
            
            with tab1:
                if row['SUMMARY']:
                    st.markdown("### Summary")
                    st.info(row['SUMMARY'])
                    
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        st.markdown("### Tags")
                        # Debug: show raw value and type
                        st.caption(f"DEBUG: type={type(row['TAGS'])}, value={repr(row['TAGS'])[:100]}")
                        tags_raw = row['TAGS']
                        tags = []
                        if tags_raw is not None:
                            if isinstance(tags_raw, list):
                                tags = tags_raw
                            elif isinstance(tags_raw, str):
                                try:
                                    tags = json.loads(tags_raw)
                                except json.JSONDecodeError:
                                    tags = []
                            else:
                                # Try string conversion then parse
                                try:
                                    tags = json.loads(str(tags_raw))
                                except:
                                    tags = []
                        if tags:
                            for tag in tags:
                                st.markdown(f"- `{tag}`")
                        else:
                            st.caption("No tags")
                        
                        st.markdown("### Key Terms")
                        if row['KEY_TERMS']:
                            terms_raw = row['KEY_TERMS']
                            if isinstance(terms_raw, list):
                                terms = terms_raw
                            elif isinstance(terms_raw, str):
                                try:
                                    terms = json.loads(terms_raw)
                                except json.JSONDecodeError:
                                    terms = []
                            else:
                                terms = []
                            if terms:
                                st.write(", ".join([f"`{t}`" for t in terms]))
                        else:
                            st.caption("No key terms")
                    
                    with col2:
                        st.markdown("### Entities")
                        if row['ENTITIES']:
                            entities_raw = row['ENTITIES']
                            if isinstance(entities_raw, dict):
                                entities = entities_raw
                            elif isinstance(entities_raw, str):
                                try:
                                    entities = json.loads(entities_raw)
                                except json.JSONDecodeError:
                                    entities = {}
                            else:
                                entities = {}
                            for entity_type, values in entities.items():
                                if values:
                                    st.markdown(f"**{entity_type.title()}:** {', '.join(values)}")
                        else:
                            st.caption("No entities extracted")
                        
                        st.markdown("### Confidence")
                        if row['CONFIDENCE']:
                            st.progress(float(row['CONFIDENCE']))
                            st.caption(f"{float(row['CONFIDENCE']):.1%}")
                else:
                    st.info("Document has not been annotated yet.")
                    if st.button("Run Annotation"):
                        with st.spinner("Annotating..."):
                            result = run_query(f"CALL DOC_INTELLIGENCE.PROCESSED.ANNOTATE_DOCUMENT({selected_doc_id})")
                            if result is not None:
                                st.success(result.iloc[0, 0])
                                st.rerun()
            
            with tab2:
                # Load chunks
                chunks = run_query(f"""
                    SELECT chunk_index, chunk_text, char_start, char_end
                    FROM DOC_INTELLIGENCE.PROCESSED.DOCUMENT_CHUNKS
                    WHERE document_id = {selected_doc_id}
                    ORDER BY chunk_index
                """)
                
                if chunks is not None and len(chunks) > 0:
                    st.markdown(f"**{len(chunks)} chunks**")
                    
                    for _, chunk in chunks.iterrows():
                        with st.expander(f"Chunk {chunk['CHUNK_INDEX'] + 1} (chars {chunk['CHAR_START']}-{chunk['CHAR_END']})"):
                            st.text(chunk['CHUNK_TEXT'])
                else:
                    st.info("Document has not been parsed yet.")
                    if st.button("Parse Document"):
                        with st.spinner("Parsing..."):
                            result = run_query(f"CALL DOC_INTELLIGENCE.PROCESSED.PARSE_DOCUMENT({selected_doc_id})")
                            if result is not None:
                                st.success(result.iloc[0, 0])
                                st.rerun()
            
            with tab3:
                col1, col2 = st.columns(2)
                
                with col1:
                    st.markdown("### File Information")
                    st.write(f"**Extension:** {row['FILE_EXTENSION']}")
                    st.write(f"**Size:** {row['FILE_SIZE_BYTES']:,} bytes" if row['FILE_SIZE_BYTES'] else "N/A")
                    st.write(f"**Word Count:** {row['WORD_COUNT']:,}" if row['WORD_COUNT'] else "N/A")
                    st.write(f"**Page Count:** {row['PAGE_COUNT']}" if row['PAGE_COUNT'] else "N/A")
                
                with col2:
                    st.markdown("### Timestamps")
                    st.write(f"**Discovered:** {row['DISCOVERED_AT']}")
                    st.write(f"**Parsed:** {row['PARSED_AT']}" if row['PARSED_AT'] else "Not parsed")
                    st.write(f"**Annotated:** {row['ANNOTATED_AT']}" if row['ANNOTATED_AT'] else "Not annotated")
                
                if row['ERROR_MESSAGE']:
                    st.markdown("### Error")
                    st.error(row['ERROR_MESSAGE'])
            
            with tab4:
                st.markdown("### Document Actions")
                
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    if st.button("🔄 Re-parse Document", use_container_width=True):
                        with st.spinner("Re-parsing..."):
                            result = run_query(f"CALL DOC_INTELLIGENCE.PROCESSED.PARSE_DOCUMENT({selected_doc_id})")
                            if result is not None:
                                st.success(result.iloc[0, 0])
                                st.rerun()
                
                with col2:
                    if st.button("🏷️ Re-annotate Document", use_container_width=True):
                        with st.spinner("Re-annotating..."):
                            result = run_query(f"CALL DOC_INTELLIGENCE.PROCESSED.ANNOTATE_DOCUMENT({selected_doc_id})")
                            if result is not None:
                                st.success(result.iloc[0, 0])
                                st.rerun()
                
                with col3:
                    if row['FILE_URL']:
                        st.link_button("📥 Download Original", row['FILE_URL'], use_container_width=True)

else:
    st.error("Could not connect to Snowflake")
