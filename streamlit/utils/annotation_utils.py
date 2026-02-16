"""
Annotation Utilities
====================
Helper functions for annotation operations.
"""

def get_annotation_quality_badge(confidence: float) -> str:
    """Return an emoji badge based on confidence level."""
    if confidence >= 0.9:
        return "🟢 High"
    elif confidence >= 0.7:
        return "🟡 Medium"
    elif confidence >= 0.5:
        return "🟠 Low"
    else:
        return "🔴 Very Low"


def format_entities(entities: dict) -> str:
    """Format entities dict for display."""
    if not entities:
        return "No entities extracted"
    
    parts = []
    
    if entities.get("people"):
        parts.append(f"**People:** {', '.join(entities['people'])}")
    
    if entities.get("organizations"):
        parts.append(f"**Organizations:** {', '.join(entities['organizations'])}")
    
    if entities.get("locations"):
        parts.append(f"**Locations:** {', '.join(entities['locations'])}")
    
    if entities.get("dates"):
        parts.append(f"**Dates:** {', '.join(entities['dates'])}")
    
    return "\n".join(parts) if parts else "No entities extracted"


def format_tags_for_display(tags: list) -> str:
    """Format tags as markdown badges."""
    if not tags:
        return ""
    return " ".join([f"`{tag}`" for tag in tags])


def validate_annotation(annotation: dict) -> list:
    """Validate an annotation and return list of issues."""
    issues = []
    
    if not annotation.get("category"):
        issues.append("Missing category")
    
    if not annotation.get("summary"):
        issues.append("Missing summary")
    elif len(annotation["summary"]) < 20:
        issues.append("Summary too short")
    
    confidence = annotation.get("confidence", 0)
    if confidence < 0.5:
        issues.append(f"Low confidence: {confidence:.0%}")
    
    return issues


def compare_annotations(old: dict, new: dict) -> dict:
    """Compare two annotations and return differences."""
    changes = {}
    
    fields = ["category", "summary", "tags", "key_terms", "entities", "confidence"]
    
    for field in fields:
        old_val = old.get(field)
        new_val = new.get(field)
        
        if old_val != new_val:
            changes[field] = {
                "old": old_val,
                "new": new_val
            }
    
    return changes
