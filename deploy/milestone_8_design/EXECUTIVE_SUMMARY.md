# Milestone 8: AnzoGraph Integration - Executive Summary

## The Challenge

Integrate the customer's **enterprise ontology** (managed in AnzoGraph) with the **Snowflake Cortex document annotation pipeline** without rebuilding the ontology in relational databases.

---

## Three Integration Options

### Option 1: Real-Time SPARQL Queries

```
AnzoGraph  ◄──────►  Snowflake External Function  ──────►  Cortex LLM
              Live SPARQL query per annotation
```

**Best for:** Small ontologies, frequent changes, low volume  
**Trade-off:** +100-500ms latency, fails if AnzoGraph is down

---

### Option 2: Scheduled JSON-LD Cache (Recommended)

```
AnzoGraph  ────────►  Snowflake VARIANT Cache  ──────►  Cortex LLM
           Periodic export (e.g., every 4 hours)
```

**Best for:** Large ontologies, stable structure, high volume  
**Trade-off:** Slight staleness (configurable), storage overhead

---

### Option 3: Hybrid with Local Enhancements

```
AnzoGraph (structure)  ─────┐
                            ├────►  Merged Prompt  ──────►  Cortex LLM
Snowflake (examples)   ─────┘
```

**Best for:** ML tuning, prompt optimization, A/B testing  
**Trade-off:** Higher complexity, governance challenges

---

## Quick Comparison

| Factor | Real-Time | Cached (Rec.) | Hybrid |
|--------|-----------|---------------|--------|
| AnzoGraph = Source of Truth | Yes | Yes | Partial |
| Added Latency | High | None | Low |
| Works if AnzoGraph Down | No | Yes | Partial |
| Implementation Effort | Medium | Medium | High |

---

## Recommendation

**Option 2 (Scheduled Cache)** for most enterprise deployments:

- AnzoGraph remains the master
- JSON-LD format preserved for compliance
- No latency impact during annotation
- Resilient to AnzoGraph downtime

---

## Questions for Customer

1. Ontology size? (number of classes/relationships)
2. Change frequency? (hourly, daily, weekly)
3. Expected annotation volume? (docs/day)
4. Compliance requirements for traceability?

---

*See [README.md](./README.md) for full technical details.*
