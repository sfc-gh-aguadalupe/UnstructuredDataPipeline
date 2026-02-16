"""
Search Utilities
================
Helper functions for Cortex Search operations.
"""

def build_filter_object(category=None, file_extension=None, source_type=None, review_status=None):
    """Build a filter object for Cortex Search."""
    filters = []
    
    if category:
        filters.append({"@eq": {"category": category}})
    
    if file_extension:
        filters.append({"@eq": {"file_extension": file_extension}})
    
    if source_type:
        filters.append({"@eq": {"source_type": source_type}})
    
    if review_status:
        filters.append({"@eq": {"review_status": review_status}})
    
    if len(filters) == 0:
        return None
    elif len(filters) == 1:
        return filters[0]
    else:
        return {"@and": filters}


def highlight_matches(text: str, query: str, max_length: int = 300) -> str:
    """Highlight query terms in text and truncate."""
    import re
    
    if not text:
        return ""
    
    # Find query terms
    terms = query.lower().split()
    
    # Truncate if needed
    if len(text) > max_length:
        # Try to center on first match
        lower_text = text.lower()
        first_match = -1
        for term in terms:
            pos = lower_text.find(term)
            if pos != -1:
                first_match = pos
                break
        
        if first_match > max_length // 2:
            start = first_match - max_length // 2
            text = "..." + text[start:start + max_length] + "..."
        else:
            text = text[:max_length] + "..."
    
    # Highlight matches (simple version)
    for term in terms:
        pattern = re.compile(f"({re.escape(term)})", re.IGNORECASE)
        text = pattern.sub(r"**\1**", text)
    
    return text


def format_search_result(result: dict) -> dict:
    """Format a search result for display."""
    return {
        "document_id": result.get("document_id"),
        "chunk_id": result.get("chunk_id"),
        "file_name": result.get("file_name", "Unknown"),
        "category": result.get("category", "Uncategorized"),
        "preview": result.get("chunk_text", "")[:300] + "...",
        "summary": result.get("summary", ""),
        "tags": result.get("tags", "").split(", ") if result.get("tags") else [],
        "score": result.get("_relevance_score", 0)
    }
