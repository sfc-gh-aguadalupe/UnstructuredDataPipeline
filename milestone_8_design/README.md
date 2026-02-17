# Milestone 8: Advanced Semantic Model - Design Document

## Executive Summary

This document outlines three architectural options for integrating an **enterprise ontology** (managed in AnzoGraph) with the **Snowflake Cortex annotation pipeline**. The goal is to use the customer's existing ontology to constrain and guide LLM-based document classification.

**Key Requirement**: The enterprise ontology in AnzoGraph must remain the source of truth. We need a seamless integration that doesn't require rebuilding the ontology in relational tables.

---

## Current State

### Existing Pipeline (Milestones 1-7)

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Documents      │────▶│  Cortex COMPLETE │────▶│  Annotations    │
│  (Snowflake)    │     │  (claude-3-5)    │     │  (Snowflake)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Flat Taxonomy       │
                    │  (Snowflake Tables)  │
                    │  - CATEGORIES        │
                    │  - TAGS              │
                    │  - GLOSSARY          │
                    └──────────────────────┘
```

### Target State (Milestone 8)

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Documents      │────▶│  Cortex COMPLETE │────▶│  Annotations    │
│  (Snowflake)    │     │  (claude-3-5)    │     │  (Snowflake)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Enterprise Ontology │
                    │  (AnzoGraph)         │
                    │  - Hierarchical      │
                    │  - Relationships     │
                    │  - SKOS/OWL/RDF      │
                    └──────────────────────┘
```

---

## Technical Context

### AnzoGraph Capabilities

AnzoGraph is Cambridge Semantics' massively parallel graph database that:
- Stores RDF/OWL/SKOS ontologies natively
- Exposes standard **SPARQL 1.1 endpoints** (HTTP GET/POST)
- Supports **JSON-LD export** via CONSTRUCT queries
- Handles deep hierarchies and complex relationships efficiently

**Endpoint Example:**
```
https://anzograph.customer.com:7070/sparql
```

### Snowflake Cortex Requirements

The annotation pipeline needs ontology data to:
1. **Build prompts** - Inject available categories/tags into LLM prompts
2. **Validate outputs** - Ensure LLM responses match valid ontology classes
3. **Store traceability** - Link annotations back to ontology IRIs

---

## Integration Options

### Option 1: Real-Time External Function (Direct SPARQL Queries)

Query AnzoGraph's SPARQL endpoint directly from Snowflake during annotation.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        REAL-TIME INTEGRATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐     ┌───────────────────┐     ┌───────────────────────┐  │
│  │   AnzoGraph   │◄───▶│ Snowflake         │────▶│   Cortex COMPLETE     │  │
│  │   SPARQL      │     │ External Function │     │                       │  │
│  │   Endpoint    │     │ (Python UDF)      │     │   LLM Annotation      │  │
│  └───────────────┘     └───────────────────┘     └───────────────────────┘  │
│         ▲                      │                                            │
│         │                      │                                            │
│    Live Query              JSON Response                                    │
│    per annotation          transformed to                                   │
│                            prompt text                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Implementation Components

1. **Network Rule** - Allow Snowflake to reach AnzoGraph endpoint
2. **External Access Integration** - Configure egress permissions
3. **Secret** - Store AnzoGraph credentials securely
4. **Python UDF** - Execute SPARQL queries and return results

#### Sample SPARQL Query

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX ent: <https://customer.com/ontology#>

SELECT ?class ?label ?description ?parent ?parentLabel
WHERE {
    ?class a rdfs:Class ;
           rdfs:label ?label .
    OPTIONAL { ?class rdfs:comment ?description }
    OPTIONAL { 
        ?class rdfs:subClassOf ?parent .
        ?parent rdfs:label ?parentLabel 
    }
}
ORDER BY ?parent ?label
```

#### Pros

| Benefit | Description |
|---------|-------------|
| Always Current | Every annotation uses the latest ontology state |
| No Data Duplication | AnzoGraph is the single source of truth |
| Simple Architecture | No sync jobs or cache management |
| Immediate Updates | Ontology changes reflected instantly |

#### Cons

| Drawback | Description |
|----------|-------------|
| Latency | 100-500ms added per annotation for SPARQL query |
| Dependency | Annotation fails if AnzoGraph is unavailable |
| Network Costs | Egress charges for external calls |
| Rate Limits | May need throttling for batch annotation |

#### Best For

- Small to medium ontologies (< 1,000 classes)
- Frequently changing ontologies
- Low annotation volume (< 1,000 docs/day)
- Environments where ontology freshness is critical

---

### Option 2: Scheduled Cache with JSON-LD (Recommended)

Periodically export ontology from AnzoGraph and cache in Snowflake as JSON-LD.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CACHED INTEGRATION                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐                          ┌───────────────────────────┐   │
│  │   AnzoGraph   │    Scheduled Export      │   Cortex COMPLETE         │   │
│  │   (Master)    │ ─────────────────────┐   │                           │   │
│  │               │    (hourly/daily)    │   │   LLM Annotation          │   │
│  └───────────────┘                      │   └───────────────────────────┘   │
│                                         │              ▲                    │
│                                         ▼              │                    │
│                              ┌──────────────────────┐  │                    │
│                              │  Snowflake Cache     │──┘                    │
│                              │  (VARIANT column)    │                       │
│                              │                      │                       │
│                              │  - JSON-LD format    │                       │
│                              │  - Full hierarchy    │                       │
│                              │  - Versioned         │                       │
│                              └──────────────────────┘                       │
│                                         │                                   │
│                                         ▼                                   │
│                              ┌──────────────────────┐                       │
│                              │  Transform Function  │                       │
│                              │  JSON-LD → NL Prompt │                       │
│                              └──────────────────────┘                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Implementation Components

1. **Cache Table** - Store JSON-LD exports with versioning
2. **Refresh Procedure** - Python stored proc to query AnzoGraph
3. **Scheduled Task** - Automate periodic refresh
4. **Transform View/Function** - Convert JSON-LD to prompt text

#### Data Model

```sql
CREATE TABLE SEMANTIC.ONTOLOGY_CACHE (
    cache_id INT AUTOINCREMENT PRIMARY KEY,
    export_format VARCHAR(20),           -- 'JSON-LD', 'TURTLE', 'N-QUADS'
    ontology_data VARIANT,               -- Full JSON-LD document
    graph_uri VARCHAR(500),              -- Source graph in AnzoGraph
    sparql_query VARCHAR(4000),          -- Query used to generate export
    class_count INT,                     -- Number of classes exported
    relationship_count INT,              -- Number of relationships
    exported_at TIMESTAMP_NTZ,
    expires_at TIMESTAMP_NTZ,
    is_current BOOLEAN DEFAULT TRUE,
    checksum VARCHAR(64)                 -- Detect changes
);
```

#### Sample JSON-LD Cache Content

```json
{
  "@context": {
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "skos": "http://www.w3.org/2004/02/skos/core#",
    "ent": "https://customer.com/ontology#"
  },
  "@graph": [
    {
      "@id": "ent:LegalDocument",
      "@type": "rdfs:Class",
      "rdfs:label": "Legal Document",
      "rdfs:comment": "Documents with legal implications or requirements"
    },
    {
      "@id": "ent:Contract",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:LegalDocument"},
      "rdfs:label": "Contract",
      "rdfs:comment": "A legally binding agreement between parties",
      "ent:suggestedTags": ["Requires-Signature", "Legal-Review-Required"]
    },
    {
      "@id": "ent:NDA",
      "@type": "rdfs:Class",
      "rdfs:subClassOf": {"@id": "ent:Contract"},
      "rdfs:label": "Non-Disclosure Agreement",
      "rdfs:comment": "Agreement establishing confidentiality between parties",
      "skos:altLabel": ["Confidentiality Agreement", "Secrecy Agreement"],
      "ent:suggestedTags": ["Confidential", "Contains-PII"]
    }
  ]
}
```

#### Pros

| Benefit | Description |
|---------|-------------|
| Performance | No latency during annotation (cached locally) |
| Resilience | Annotation continues even if AnzoGraph is down |
| JSON-LD Preserved | Native format maintained for compliance |
| Versioning | Can compare ontology versions over time |
| Auditability | Full traceability to source |

#### Cons

| Drawback | Description |
|----------|-------------|
| Staleness | Cache may be behind AnzoGraph (configurable lag) |
| Storage | Duplicate data in Snowflake |
| Sync Complexity | Need to manage refresh jobs |
| Transform Logic | Need to convert JSON-LD to prompt text |

#### Best For

- Large ontologies (1,000+ classes)
- Stable ontologies (changes daily/weekly, not hourly)
- High annotation volume (batch processing)
- Production environments requiring resilience

---

### Option 3: Hybrid - Live Queries with Local Enrichment

Combine AnzoGraph queries with Snowflake-managed prompt enhancements.

#### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HYBRID INTEGRATION                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐                      ┌───────────────────────────────┐   │
│  │   AnzoGraph   │    Structure         │   Snowflake                   │   │
│  │   (Master)    │ ──────────────────▶  │   ONTOLOGY_ENHANCEMENTS       │   │
│  │               │    (classes,         │                               │   │
│  │  - Classes    │     hierarchy)       │   - Few-shot examples         │   │
│  │  - Hierarchy  │                      │   - Custom descriptions       │   │
│  │  - Relations  │                      │   - Prompt templates          │   │
│  └───────────────┘                      │   - Local refinements         │   │
│                                         └───────────────────────────────┘   │
│                                                    │                        │
│                                                    ▼                        │
│                                         ┌───────────────────────────────┐   │
│                                         │   Merged Prompt               │   │
│                                         │                               │   │
│                                         │   AnzoGraph structure         │   │
│                                         │   + Snowflake examples        │   │
│                                         │   + Custom descriptions       │   │
│                                         └───────────────────────────────┘   │
│                                                    │                        │
│                                                    ▼                        │
│                                         ┌───────────────────────────────┐   │
│                                         │   Cortex COMPLETE             │   │
│                                         └───────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Implementation Components

1. **Lightweight Sync** - Pull class IRIs and labels from AnzoGraph
2. **Enhancement Table** - Store local additions (examples, descriptions)
3. **Merge Function** - Combine AnzoGraph structure with local data

#### Data Model

```sql
-- Lightweight reference to AnzoGraph (not duplicating ontology)
CREATE TABLE SEMANTIC.ONTOLOGY_ENHANCEMENTS (
    class_iri VARCHAR(500) PRIMARY KEY,     -- Reference to AnzoGraph IRI
    custom_description VARCHAR(2000),       -- LLM-optimized description
    few_shot_examples VARIANT,              -- JSON array of examples
    prompt_template VARCHAR(4000),          -- Custom prompt snippet
    suggested_tags ARRAY,                   -- Override/enhance tags
    is_active BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP_NTZ,
    enhanced_by VARCHAR(100),
    enhanced_at TIMESTAMP_NTZ
);
```

#### Pros

| Benefit | Description |
|---------|-------------|
| Flexibility | Can customize prompts without changing ontology |
| Best of Both | AnzoGraph for structure, Snowflake for tuning |
| Few-Shot Learning | Add examples that improve LLM accuracy |
| Domain Adaptation | Refine descriptions for specific use cases |

#### Cons

| Drawback | Description |
|----------|-------------|
| Complexity | Two systems to manage |
| Sync Issues | Enhancements may reference deleted classes |
| Maintenance | Need to keep enhancements aligned with ontology |
| Governance | Unclear which system is authoritative for what |

#### Best For

- Organizations with ML/prompt engineering teams
- Need to tune LLM performance iteratively
- Ontology is stable but prompt quality needs improvement
- Want to A/B test different prompt strategies

---

## Comparison Matrix

| Criteria | Option 1: Real-Time | Option 2: Cached | Option 3: Hybrid |
|----------|---------------------|------------------|------------------|
| **AnzoGraph as Source of Truth** | Yes | Yes | Partial |
| **Annotation Latency** | +100-500ms | None | +50-100ms |
| **Resilience (AnzoGraph down)** | Fails | Works | Partial |
| **Data Freshness** | Real-time | Configurable lag | Mixed |
| **Implementation Complexity** | Medium | Medium | High |
| **Operational Complexity** | Low | Medium | High |
| **JSON-LD Preservation** | No (parsed) | Yes (cached) | No |
| **Prompt Customization** | Limited | Limited | Full |
| **Storage Overhead** | None | Medium | Low |
| **Best For** | Small/dynamic ontology | Large/stable ontology | ML tuning |

---

## Recommendation

For most enterprise deployments, **Option 2 (Scheduled Cache with JSON-LD)** provides the best balance:

1. **AnzoGraph remains the master** - No ontology duplication or management overhead
2. **JSON-LD format preserved** - Meets compliance and traceability requirements
3. **Production resilient** - Annotation continues even during AnzoGraph maintenance
4. **Performance optimized** - No external calls during annotation
5. **Auditable** - Full version history of ontology exports

### Suggested Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Refresh Frequency | Every 4 hours | Balance freshness vs. load |
| Cache Retention | 7 days | Allow rollback if needed |
| Export Format | JSON-LD | Native format, standard |
| Validation | On refresh | Ensure export completeness |

---

## Next Steps

1. **Customer Review** - Present options and gather feedback
2. **Select Option** - Confirm architectural direction
3. **AnzoGraph Access** - Obtain endpoint URL, credentials, sample SPARQL
4. **Prototype** - Build proof-of-concept for selected option
5. **Testing** - Validate with subset of ontology
6. **Production Deployment** - Full implementation

---

## Open Questions for Customer

1. What is the approximate size of the enterprise ontology? (classes, relationships)
2. How frequently does the ontology change? (hourly, daily, weekly)
3. Is there an existing SPARQL query that exports the relevant subset?
4. Are there specific ontology standards in use? (OWL, SKOS, custom)
5. What is the expected annotation volume? (documents per day)
6. Are there compliance requirements for ontology traceability?

---

## Appendix: Technical References

### AnzoGraph Documentation
- [AnzoGraph Architecture](https://docs.cambridgesemantics.com/anzo/v5.3/userdoc/anzograph-architecture.htm)
- [SPARQL Endpoints](https://docs.cambridgesemantics.com/anzograph/v2.2/userdoc/azg-endpoints.htm)
- [JSON-LD Loading](https://docs.cambridgesemantics.com/anzograph/v2.5/userdoc/faq.htm)

### Snowflake Documentation
- [External Network Access](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)
- [External Functions](https://docs.snowflake.com/en/sql-reference/external-functions)
- [VARIANT Data Type](https://docs.snowflake.com/en/sql-reference/data-types-semistructured)

### Standards
- [JSON-LD Specification](https://json-ld.org/)
- [SPARQL 1.1 Protocol](https://www.w3.org/TR/sparql11-protocol/)
- [RDF Graph Store Protocol](https://www.w3.org/TR/sparql11-http-rdf-update/)

---

*Document Version: 1.0*  
*Last Updated: February 2026*  
*Status: Draft - Pending Customer Review*
