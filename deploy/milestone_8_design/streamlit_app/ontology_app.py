"""
Milestone 8: Ontology-Based Document Annotation Demo
=====================================================
A Streamlit app demonstrating JSON-LD ontology-based document annotation.

This app showcases:
- Ontology hierarchy visualization (from JSON-LD)
- Tag groups with mutual exclusivity rules
- LLM-powered document annotation using ontology context
- Comparison between flat and hierarchical annotations
"""

import streamlit as st
import pandas as pd
import json
from snowflake.snowpark.context import get_active_session

# =============================================================================
# Configuration
# =============================================================================

st.set_page_config(
    page_title="Ontology Annotation Demo",
    page_icon="🏷️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better visualization
st.markdown("""
<style>
    .hierarchy-box {
        background-color: #f0f2f6;
        border-radius: 10px;
        padding: 15px;
        margin: 10px 0;
        font-family: monospace;
    }
    .tag-group {
        background-color: #e8f4ea;
        border-left: 4px solid #28a745;
        padding: 10px 15px;
        margin: 10px 0;
        border-radius: 0 5px 5px 0;
    }
    .mutual-exclusive {
        background-color: #fff3cd;
        border-left: 4px solid #ffc107;
    }
    .annotation-result {
        background-color: #e7f3ff;
        border: 1px solid #0066cc;
        border-radius: 8px;
        padding: 15px;
        margin: 10px 0;
    }
    .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 20px;
        border-radius: 10px;
        text-align: center;
    }
</style>
""", unsafe_allow_html=True)


# =============================================================================
# Database Connection
# =============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session (works in SiS environment)."""
    try:
        return get_active_session()
    except Exception as e:
        st.error(f"Failed to get Snowflake session: {e}")
        st.info("This app must be run in Snowflake Streamlit in Snowflake (SiS)")
        return None


def run_query(query: str):
    """Execute a query and return results as DataFrame."""
    session = get_session()
    if session:
        try:
            return session.sql(query).to_pandas()
        except Exception as e:
            st.error(f"Query failed: {e}")
            return pd.DataFrame()
    return pd.DataFrame()


def run_query_scalar(query: str):
    """Execute a query and return single value."""
    df = run_query(query)
    if not df.empty:
        return df.iloc[0, 0]
    return None


# =============================================================================
# Data Loading Functions
# =============================================================================

@st.cache_data(ttl=300)
def get_ontology_list():
    """Get list of available ontologies."""
    query = """
    SELECT 
        ONTOLOGY_NAME as name,
        JSON_LD:"@context"."ent"::STRING as namespace,
        VERSION as version,
        CLASS_COUNT as class_count,
        IMPORTED_AT
    FROM DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE
    WHERE IS_CURRENT = TRUE
    ORDER BY IMPORTED_AT DESC
    """
    return run_query(query)


@st.cache_data(ttl=300)
def get_ontology_hierarchy(ontology_name: str):
    """Get formatted ontology hierarchy using the stored function."""
    query = f"""
    SELECT DOC_INTELLIGENCE.EXPERIMENT.GET_ONTOLOGY_HIERARCHY('{ontology_name}') as hierarchy
    """
    return run_query_scalar(query)


@st.cache_data(ttl=300)
def get_tag_groups(ontology_name: str):
    """Get tag groups from ontology."""
    query = f"""
    SELECT DOC_INTELLIGENCE.EXPERIMENT.GET_TAG_GROUPS('{ontology_name}') as tag_groups
    """
    return run_query_scalar(query)


@st.cache_data(ttl=300)
def get_ontology_classes(ontology_name: str):
    """Get all classes from an ontology."""
    query = f"""
    SELECT 
        c.value:"@id"::STRING as class_id,
        c.value:"rdfs:label"::STRING as label,
        c.value:"rdfs:comment"::STRING as description,
        c.value:"rdfs:subClassOf":"@id"::STRING as parent_class,
        c.value:"skos:altLabel" as synonyms
    FROM DOC_INTELLIGENCE.EXPERIMENT.ONTOLOGY_CACHE,
         LATERAL FLATTEN(input => JSON_LD:classes) c
    WHERE ONTOLOGY_NAME = '{ontology_name}'
    ORDER BY class_id
    """
    return run_query(query)


@st.cache_data(ttl=300)
def get_sample_documents():
    """Get sample documents for annotation testing."""
    query = """
    SELECT 
        d.DOCUMENT_ID as DOC_ID,
        d.FILE_NAME,
        d.STATUS as PROCESSING_STATUS
    FROM DOC_INTELLIGENCE.RAW.DOCUMENTS d
    WHERE d.STATUS = 'ANNOTATED'
    ORDER BY d.ANNOTATED_AT DESC
    LIMIT 20
    """
    return run_query(query)


@st.cache_data(ttl=60)
def get_experiment_annotations():
    """Get annotations from the experiment."""
    query = """
    SELECT 
        ea.DOCUMENT_ID,
        d.FILE_NAME,
        ea.CATEGORY_LABEL,
        ea.CATEGORY_PATH,
        ea.CONFIDENCE,
        ea.SUMMARY,
        ea.CREATED_AT
    FROM DOC_INTELLIGENCE.EXPERIMENT.EXPERIMENT_ANNOTATIONS ea
    JOIN DOC_INTELLIGENCE.RAW.DOCUMENTS d ON ea.DOCUMENT_ID = d.DOCUMENT_ID
    ORDER BY ea.CREATED_AT DESC
    """
    return run_query(query)


# =============================================================================
# Sidebar
# =============================================================================

with st.sidebar:
    st.title("🏷️ Ontology Demo")
    st.markdown("---")
    
    # Ontology selection
    ontologies = get_ontology_list()
    if not ontologies.empty:
        selected_ontology = st.selectbox(
            "Select Ontology",
            options=ontologies['NAME'].tolist(),
            index=0
        )
        
        # Show ontology info
        ont_info = ontologies[ontologies['NAME'] == selected_ontology].iloc[0]
        st.markdown(f"""
        **Version:** {ont_info['VERSION']}  
        **Classes:** {ont_info['CLASS_COUNT']}  
        **Loaded:** {ont_info['IMPORTED_AT']}
        """)
    else:
        selected_ontology = None
        st.warning("No ontologies loaded")
    
    st.markdown("---")
    
    # Navigation
    page = st.radio(
        "Navigation",
        ["📊 Overview", "🌳 Hierarchy", "🏷️ Tag Groups", "✨ Annotate", "📋 Results"],
        index=0
    )


# =============================================================================
# Main Content
# =============================================================================

if page == "📊 Overview":
    st.title("Ontology-Based Document Annotation")
    st.markdown("""
    This demo showcases **Milestone 8**: Using JSON-LD ontologies to provide 
    hierarchical context to LLMs for more accurate document classification.
    """)
    
    # Metrics row
    col1, col2, col3, col4 = st.columns(4)
    
    if selected_ontology:
        classes = get_ontology_classes(selected_ontology)
        annotations = get_experiment_annotations()
        
        with col1:
            st.metric("Ontology Classes", len(classes))
        
        with col2:
            tag_groups_json = get_tag_groups(selected_ontology)
            if tag_groups_json:
                try:
                    tag_groups = json.loads(tag_groups_json)
                    st.metric("Tag Groups", len(tag_groups))
                except (json.JSONDecodeError, TypeError):
                    st.metric("Tag Groups", 0)
            else:
                st.metric("Tag Groups", 0)
        
        with col3:
            st.metric("Annotations", len(annotations))
        
        with col4:
            if not annotations.empty and 'CONFIDENCE' in annotations.columns:
                avg_conf = annotations['CONFIDENCE'].mean()
                st.metric("Avg Confidence", f"{avg_conf:.1%}")
            else:
                st.metric("Avg Confidence", "N/A")
    
    st.markdown("---")
    
    # Architecture diagram
    st.subheader("How It Works")
    st.markdown("""
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │                    ONTOLOGY-BASED ANNOTATION                    │
    ├─────────────────────────────────────────────────────────────────┤
    │                                                                 │
    │   ┌──────────────┐      ┌──────────────┐      ┌─────────────┐  │
    │   │   JSON-LD    │      │   Snowflake  │      │    LLM      │  │
    │   │   Ontology   │─────▶│   Functions  │─────▶│   Prompt    │  │
    │   │   (VARIANT)  │      │  (Hierarchy) │      │  (Context)  │  │
    │   └──────────────┘      └──────────────┘      └─────────────┘  │
    │          │                                           │         │
    │          │         ┌──────────────────┐              │         │
    │          └────────▶│   Tag Groups     │              │         │
    │                    │ (Mutual Exclus.) │──────────────┘         │
    │                    └──────────────────┘                        │
    │                                                                 │
    │   Document ──▶ GET_ONTOLOGY_HIERARCHY() ──▶ CORTEX.COMPLETE   │
    │                GET_TAG_GROUPS()              ──▶ Annotation   │
    │                                                                 │
    └─────────────────────────────────────────────────────────────────┘
    ```
    """)
    
    # Key concepts
    st.subheader("Key Concepts")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        **JSON-LD Ontology Storage**
        - Ontology stored as VARIANT (native JSON)
        - Uses standard vocabularies (RDFS, SKOS)
        - `rdfs:subClassOf` for hierarchy
        - `skos:altLabel` for synonyms
        """)
        
        st.markdown("""
        **Hierarchy Extraction**
        - Recursive CTE builds class hierarchy
        - `LATERAL FLATTEN` extracts JSON arrays
        - `LISTAGG` formats for LLM consumption
        """)
    
    with col2:
        st.markdown("""
        **Tag Groups**
        - Embedded in JSON-LD (not separate table)
        - `ent:isMutuallyExclusive` constraint
        - Ensures consistent classification
        - Example: Document can't be both NDA AND Invoice
        """)
        
        st.markdown("""
        **LLM Annotation**
        - Context = Hierarchy + Tag Groups + Document
        - CORTEX.COMPLETE with claude-3-5-sonnet
        - Returns: type, hierarchy, confidence, reasoning
        """)


elif page == "🌳 Hierarchy":
    st.title("Ontology Hierarchy")
    
    if selected_ontology:
        hierarchy = get_ontology_hierarchy(selected_ontology)
        
        if hierarchy:
            st.markdown("### Class Hierarchy Tree")
            st.markdown("""
            This hierarchy is extracted from JSON-LD using `rdfs:subClassOf` relationships
            and formatted using a recursive CTE.
            """)
            
            # Display hierarchy in a code block for tree visualization
            st.code(hierarchy, language=None)
        
        st.markdown("---")
        
        # Show raw classes
        st.markdown("### All Classes (Raw Data)")
        classes = get_ontology_classes(selected_ontology)
        
        if not classes.empty:
            # Format for display
            display_df = classes.copy()
            display_df['SYNONYMS'] = display_df['SYNONYMS'].apply(
                lambda x: ', '.join(x) if isinstance(x, list) else str(x) if x else ''
            )
            
            st.dataframe(
                display_df,
                use_container_width=True
            )
    else:
        st.warning("Please select an ontology from the sidebar")


elif page == "🏷️ Tag Groups":
    st.title("Tag Groups")
    
    if selected_ontology:
        tag_groups_json = get_tag_groups(selected_ontology)
        
        if tag_groups_json:
            try:
                tag_groups = json.loads(tag_groups_json)
            except (json.JSONDecodeError, TypeError):
                tag_groups = []
            
            st.markdown("""
            Tag groups define **mutually exclusive categories**. A document can only 
            be assigned ONE tag from each mutual exclusive group.
            """)
            
            for group in tag_groups:
                is_exclusive = group.get('isMutuallyExclusive', False)
                
                # Create styled box
                style_class = "tag-group mutual-exclusive" if is_exclusive else "tag-group"
                
                st.markdown(f"""
                <div class="{style_class}">
                    <h4>{group['name']}</h4>
                    <p><em>{group.get('description', 'No description')}</em></p>
                    <p><strong>Mutual Exclusivity:</strong> {'Yes' if is_exclusive else 'No'}</p>
                    <p><strong>Members:</strong> {', '.join(group.get('members', []))}</p>
                </div>
                """, unsafe_allow_html=True)
            
            st.markdown("---")
            
            # Show raw JSON
            with st.expander("View Raw JSON-LD Tag Groups"):
                st.json(tag_groups)
        else:
            st.info("No tag groups defined in this ontology")
    else:
        st.warning("Please select an ontology from the sidebar")


elif page == "✨ Annotate":
    st.title("Annotate Documents")
    
    if selected_ontology:
        st.markdown("""
        Select a document to annotate using the ontology-based approach.
        The LLM will receive the full hierarchy and tag group context.
        """)
        
        # Get documents
        documents = get_sample_documents()
        
        if not documents.empty:
            # Document selection
            doc_options = {
                f"{row['FILE_NAME']} (ID: {row['DOC_ID']})": row['DOC_ID'] 
                for _, row in documents.iterrows()
            }
            
            selected_doc_label = st.selectbox(
                "Select Document",
                options=list(doc_options.keys())
            )
            
            selected_doc_id = doc_options[selected_doc_label]
            
            # Show document preview
            doc_row = documents[documents['DOC_ID'] == selected_doc_id].iloc[0]
            
            with st.expander("Document Preview", expanded=True):
                st.markdown(f"**File:** {doc_row['FILE_NAME']}")
                st.markdown(f"**Status:** {doc_row['PROCESSING_STATUS']}")
            
            # Annotate button
            if st.button("🚀 Annotate with Ontology", type="primary", use_container_width=True):
                with st.spinner("Calling CORTEX.COMPLETE with ontology context..."):
                    # Call the annotation procedure
                    query = f"""
                    CALL DOC_INTELLIGENCE.EXPERIMENT.ANNOTATE_WITH_ONTOLOGY(
                        '{selected_doc_id}', 
                        '{selected_ontology}'
                    )
                    """
                    result = run_query_scalar(query)
                    
                    if result:
                        st.success("Annotation complete!")
                        
                        # Get the annotation result
                        annotation_query = f"""
                        SELECT * FROM DOC_INTELLIGENCE.EXPERIMENT.EXPERIMENT_ANNOTATIONS
                        WHERE DOCUMENT_ID = {selected_doc_id}
                        ORDER BY CREATED_AT DESC
                        LIMIT 1
                        """
                        annotation = run_query(annotation_query)
                        
                        if not annotation.empty:
                            ann = annotation.iloc[0]
                            conf_val = f"{ann['CONFIDENCE']:.1%}" if pd.notna(ann.get('CONFIDENCE')) else "N/A"
                            
                            st.markdown(f"""
                            <div class="annotation-result">
                                <h3>📄 Annotation Result</h3>
                                <p><strong>Category:</strong> {ann.get('CATEGORY_LABEL', 'N/A')}</p>
                                <p><strong>Full Hierarchy:</strong> {ann.get('CATEGORY_PATH', 'N/A')}</p>
                                <p><strong>Confidence:</strong> {conf_val}</p>
                                <p><strong>Summary:</strong> {ann.get('SUMMARY', 'N/A')}</p>
                            </div>
                            """, unsafe_allow_html=True)
                            
                            # Clear cache to refresh results
                            st.cache_data.clear()
                    else:
                        st.error("Annotation failed")
        else:
            st.warning("No documents available for annotation")
    else:
        st.warning("Please select an ontology from the sidebar")


elif page == "📋 Results":
    st.title("Annotation Results")
    
    # Get all annotations
    annotations = get_experiment_annotations()
    
    if not annotations.empty:
        # Summary metrics
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Total Annotations", len(annotations))
        
        with col2:
            if 'CONFIDENCE' in annotations.columns:
                avg_confidence = annotations['CONFIDENCE'].mean()
                st.metric("Average Confidence", f"{avg_confidence:.1%}")
            else:
                st.metric("Average Confidence", "N/A")
        
        with col3:
            if 'CATEGORY_LABEL' in annotations.columns:
                unique_types = annotations['CATEGORY_LABEL'].nunique()
                st.metric("Unique Types", unique_types)
            else:
                st.metric("Unique Types", 0)
        
        st.markdown("---")
        
        # Results table
        st.subheader("All Annotations")
        
        display_df = annotations[['FILE_NAME', 'CATEGORY_LABEL', 'CATEGORY_PATH', 
                                   'CONFIDENCE', 'CREATED_AT']].copy()
        display_df['CONFIDENCE'] = display_df['CONFIDENCE'].apply(lambda x: f"{x:.1%}" if pd.notna(x) else "N/A")
        display_df.columns = ['File', 'Type', 'Hierarchy', 'Confidence', 'Annotated']
        
        st.dataframe(display_df, use_container_width=True)
        
        st.markdown("---")
        
        # Distribution chart
        st.subheader("Type Distribution")
        type_counts = annotations['CATEGORY_LABEL'].value_counts()
        st.bar_chart(type_counts)
        
        # Detailed view
        st.markdown("---")
        st.subheader("Detailed Annotations")
        
        for _, ann in annotations.iterrows():
            with st.expander(f"📄 {ann['FILE_NAME']}"):
                col1, col2 = st.columns([1, 2])
                
                with col1:
                    st.markdown(f"**Type:** {ann['CATEGORY_LABEL']}")
                    conf_val = f"{ann['CONFIDENCE']:.1%}" if pd.notna(ann['CONFIDENCE']) else "N/A"
                    st.markdown(f"**Confidence:** {conf_val}")
                    st.markdown(f"**Annotated:** {ann['CREATED_AT']}")
                
                with col2:
                    st.markdown(f"**Hierarchy:**")
                    st.code(ann['CATEGORY_PATH'])
                    st.markdown(f"**Summary:** {ann['SUMMARY']}")
    else:
        st.info("No annotations yet. Go to the 'Annotate' page to create some!")
        
        # Show how to run annotation
        st.markdown("""
        ### Quick Start
        1. Go to **✨ Annotate** page
        2. Select a document
        3. Click **Annotate with Ontology**
        4. View results here!
        """)


# =============================================================================
# Footer
# =============================================================================

st.markdown("---")
st.markdown("""
<div style="text-align: center; color: #666; font-size: 0.8em;">
    Milestone 8: JSON-LD Ontology Experiment | DOC_INTELLIGENCE.EXPERIMENT Schema
</div>
""", unsafe_allow_html=True)
