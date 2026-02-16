"""
Taxonomy Manager Page
=====================
Manage categories, tags, and glossary terms.
"""

import streamlit as st
from utils.snowflake_conn import get_connection, run_query

st.set_page_config(page_title="Taxonomy Manager", page_icon="🏷️", layout="wide")

st.title("🏷️ Taxonomy Manager")
st.caption("Manage categories, tags, and domain glossary")

conn = get_connection()

if conn:
    tab1, tab2, tab3 = st.tabs(["📁 Categories", "🏷️ Tags", "📖 Glossary"])
    
    # ==========================================================================
    # CATEGORIES TAB
    # ==========================================================================
    with tab1:
        st.subheader("Document Categories")
        st.caption("Single-label classification options for documents")
        
        # Load categories
        categories = run_query("""
            SELECT category_id, category_name, description, is_active, created_at
            FROM DOC_INTELLIGENCE.SEMANTIC.CATEGORIES
            ORDER BY category_name
        """)
        
        if categories is not None and len(categories) > 0:
            # Display as editable dataframe
            st.dataframe(
                categories,
                column_config={
                    "CATEGORY_ID": st.column_config.NumberColumn("ID", width="small"),
                    "CATEGORY_NAME": st.column_config.TextColumn("Category", width="medium"),
                    "DESCRIPTION": st.column_config.TextColumn("Description", width="large"),
                    "IS_ACTIVE": st.column_config.CheckboxColumn("Active", width="small"),
                    "CREATED_AT": st.column_config.DatetimeColumn("Created", width="medium"),
                },
                hide_index=True,
                use_container_width=True
            )
        
        # Add new category
        st.markdown("### Add New Category")
        
        add_col1, add_col2 = st.columns([1, 2])
        
        with add_col1:
            new_cat_name = st.text_input("Category Name", key="new_cat_name")
        
        with add_col2:
            new_cat_desc = st.text_input("Description", key="new_cat_desc")
        
        if st.button("➕ Add Category", use_container_width=False):
            if new_cat_name:
                try:
                    run_query(f"""
                        INSERT INTO DOC_INTELLIGENCE.SEMANTIC.CATEGORIES (category_name, description)
                        VALUES ('{new_cat_name}', '{new_cat_desc}')
                    """)
                    st.success(f"Added category: {new_cat_name}")
                    st.rerun()
                except Exception as e:
                    st.error(f"Error: {e}")
            else:
                st.warning("Please enter a category name")
    
    # ==========================================================================
    # TAGS TAB
    # ==========================================================================
    with tab2:
        st.subheader("Document Tags")
        st.caption("Multi-label tagging options for documents")
        
        # Load tags
        tags = run_query("""
            SELECT tag_id, tag_name, description, is_active, created_at
            FROM DOC_INTELLIGENCE.SEMANTIC.TAGS
            ORDER BY tag_name
        """)
        
        if tags is not None and len(tags) > 0:
            st.dataframe(
                tags,
                column_config={
                    "TAG_ID": st.column_config.NumberColumn("ID", width="small"),
                    "TAG_NAME": st.column_config.TextColumn("Tag", width="medium"),
                    "DESCRIPTION": st.column_config.TextColumn("Description", width="large"),
                    "IS_ACTIVE": st.column_config.CheckboxColumn("Active", width="small"),
                    "CREATED_AT": st.column_config.DatetimeColumn("Created", width="medium"),
                },
                hide_index=True,
                use_container_width=True
            )
        
        # Add new tag
        st.markdown("### Add New Tag")
        
        add_col1, add_col2 = st.columns([1, 2])
        
        with add_col1:
            new_tag_name = st.text_input("Tag Name", key="new_tag_name")
        
        with add_col2:
            new_tag_desc = st.text_input("Description", key="new_tag_desc")
        
        if st.button("➕ Add Tag", use_container_width=False):
            if new_tag_name:
                try:
                    run_query(f"""
                        INSERT INTO DOC_INTELLIGENCE.SEMANTIC.TAGS (tag_name, description)
                        VALUES ('{new_tag_name}', '{new_tag_desc}')
                    """)
                    st.success(f"Added tag: {new_tag_name}")
                    st.rerun()
                except Exception as e:
                    st.error(f"Error: {e}")
            else:
                st.warning("Please enter a tag name")
    
    # ==========================================================================
    # GLOSSARY TAB
    # ==========================================================================
    with tab3:
        st.subheader("Domain Glossary")
        st.caption("Domain-specific terms to guide LLM annotation")
        
        # Load glossary
        glossary = run_query("""
            SELECT term_id, term, definition, is_active, created_at
            FROM DOC_INTELLIGENCE.SEMANTIC.GLOSSARY
            ORDER BY term
        """)
        
        if glossary is not None and len(glossary) > 0:
            st.dataframe(
                glossary,
                column_config={
                    "TERM_ID": st.column_config.NumberColumn("ID", width="small"),
                    "TERM": st.column_config.TextColumn("Term", width="medium"),
                    "DEFINITION": st.column_config.TextColumn("Definition", width="large"),
                    "IS_ACTIVE": st.column_config.CheckboxColumn("Active", width="small"),
                    "CREATED_AT": st.column_config.DatetimeColumn("Created", width="medium"),
                },
                hide_index=True,
                use_container_width=True
            )
        
        # Add new term
        st.markdown("### Add New Term")
        
        add_col1, add_col2 = st.columns([1, 2])
        
        with add_col1:
            new_term = st.text_input("Term", key="new_term")
        
        with add_col2:
            new_definition = st.text_area("Definition", key="new_definition", height=100)
        
        if st.button("➕ Add Term", use_container_width=False):
            if new_term:
                try:
                    safe_term = new_term.replace("'", "''")
                    safe_def = new_definition.replace("'", "''")
                    run_query(f"""
                        INSERT INTO DOC_INTELLIGENCE.SEMANTIC.GLOSSARY (term, definition)
                        VALUES ('{safe_term}', '{safe_def}')
                    """)
                    st.success(f"Added term: {new_term}")
                    st.rerun()
                except Exception as e:
                    st.error(f"Error: {e}")
            else:
                st.warning("Please enter a term")
    
    st.divider()
    
    # Taxonomy stats
    st.subheader("Taxonomy Statistics")
    
    stats_col1, stats_col2, stats_col3 = st.columns(3)
    
    with stats_col1:
        cat_count = run_query("SELECT COUNT(*) as cnt FROM DOC_INTELLIGENCE.SEMANTIC.CATEGORIES WHERE is_active = TRUE")
        st.metric("Active Categories", cat_count.iloc[0]['CNT'] if cat_count is not None else 0)
    
    with stats_col2:
        tag_count = run_query("SELECT COUNT(*) as cnt FROM DOC_INTELLIGENCE.SEMANTIC.TAGS WHERE is_active = TRUE")
        st.metric("Active Tags", tag_count.iloc[0]['CNT'] if tag_count is not None else 0)
    
    with stats_col3:
        term_count = run_query("SELECT COUNT(*) as cnt FROM DOC_INTELLIGENCE.SEMANTIC.GLOSSARY WHERE is_active = TRUE")
        st.metric("Glossary Terms", term_count.iloc[0]['CNT'] if term_count is not None else 0)

else:
    st.error("Could not connect to Snowflake")
