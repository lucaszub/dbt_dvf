# DVF Analytics - Documentation

> **Plateforme d'analyse du marché immobilier français**
>
> Portfolio End-to-End Data Engineering démontrant expertise : Ingestion Python → Orchestration Airflow → Transformation dbt → Snowflake → Visualisation Streamlit

---

## Quick Reference

| Attribut | Valeur |
|----------|--------|
| **Type de projet** | Data Engineering / Analytics Platform |
| **Architecture** | Medallion (Bronze → Silver → Gold) + Star Schema |
| **Stack** | Python, Airflow, dbt, Snowflake, Streamlit |
| **Hébergement** | Azure Container Apps |
| **Repository** | Monorepo |

---

## Documentation

### Planification & Produit

| Document | Description |
|----------|-------------|
| [Product Brief](./product-brief.md) | Vision produit, fonctionnalités, roadmap |

### Architecture & Technique

| Document | Description |
|----------|-------------|
| [Architecture](./architecture.md) | Architecture technique complète, C4 diagrams, ADRs |
| [Modèle de Données](./data-model.md) | Star Schema, transformations dbt, requêtes exemples |

### Guides _(À générer)_

| Document | Description | Statut |
|----------|-------------|--------|
| [Guide de Développement](./development-guide.md) | Setup local, conventions, tests | _(À générer)_ |
| [Guide de Déploiement](./deployment-guide.md) | CI/CD, Azure, Terraform | _(À générer)_ |

---

## Structure du Projet (Cible)

```
dvf-analytics/                      # Monorepo principal
├── docs/                           # 📚 Documentation (VOUS ÊTES ICI)
│   ├── index.md
│   ├── product-brief.md
│   ├── architecture.md
│   └── data-model.md
│
├── ingestion/                      # 🐍 Pipeline Python
│   ├── src/
│   └── tests/
│
├── airflow/                        # �� Orchestration
│   └── dags/
│
├── dbt_dvf/                        # 🔧 Transformations (✅ Existant)
│   ├── models/silver/
│   └── models/gold/
│
├── streamlit/                      # 📊 Application Web
│   ├── app.py
│   └── pages/
│
└── .github/workflows/              # ⚙️ CI/CD

dvf-infrastructure/                 # Repo séparé IaC
└── terraform/
```

---

## Stack Technique

| Couche | Technologie | Statut |
|--------|-------------|--------|
| **Ingestion** | Python 3.11+ | 🔲 À implémenter |
| **Orchestration** | Apache Airflow 2.8+ | 🔲 À implémenter |
| **Transformation** | dbt-core 1.7+ | ✅ Implémenté |
| **Stockage** | Snowflake | ✅ Configuré |
| **Visualisation** | Streamlit 1.30+ | 🔲 À implémenter |
| **Hébergement** | Azure Container Apps | 🔲 À configurer |
| **CI/CD** | GitHub Actions | 🔲 À implémenter |
| **IaC** | Terraform | 🔲 À implémenter (repo séparé) |

---

## Modèle de Données

### Star Schema (Gold Layer)

```
     dim_commune ◄──┐                      ┌──► dim_parcelle
                    │                      │
     dim_address ◄──┼─── fact_mutation ───┼──► dim_type_local
       _enriched    │        (FACT)        │
                    │                      │
                    └──────────────────────┼──► dim_code_postal
```

### Tables

| Table | Type | Lignes (estimé) |
|-------|------|-----------------|
| fact_mutation | Fait | ~15M |
| dim_address_enriched | Dimension | ~5M |
| dim_commune | Dimension | ~35K |
| dim_parcelle | Dimension | ~10M |
| dim_type_local | Dimension | ~5 |
| dim_code_postal | Dimension | ~6K |

---

## Prochaines Étapes

### Phase 1 : Fondations

- [ ] Restructurer en monorepo
- [ ] Implémenter pipeline ingestion Python
- [ ] Créer DAGs Airflow
- [ ] Setup CI/CD GitHub Actions

### Phase 2 : Application

- [ ] Développer app Streamlit
- [ ] Page carte interactive
- [ ] Filtres et statistiques
- [ ] Dockerfile + tests

### Phase 3 : Déploiement

- [ ] Terraform Azure Container Apps
- [ ] CD vers Azure
- [ ] Documentation déploiement

---

## Liens Utiles

### Sources de Données

- [DVF - data.gouv.fr](https://www.data.gouv.fr/fr/datasets/demandes-de-valeurs-foncieres/)
- [BAN - adresse.data.gouv.fr](https://adresse.data.gouv.fr/)

### Documentation Outils

- [dbt Documentation](https://docs.getdbt.com/)
- [Snowflake Documentation](https://docs.snowflake.com/)
- [Apache Airflow](https://airflow.apache.org/docs/)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)

---

## Contact

**Lucas Zubiarrain**
- GitHub: [@lucaszub](https://github.com/lucaszub)
- LinkedIn: [Lucas Zubiarrain](https://www.linkedin.com/in/lucas-zubiarrain/)

---

*Documentation générée le 2026-01-20 | Workflow BMAD*
