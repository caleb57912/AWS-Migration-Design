<div align="center">

# 👋 Start Here

**The fastest way to understand this project and the work behind it.**

</div>

---

## ⏱️ The project in 60 seconds

I designed a migration to AWS for **Bayou Clinic Partners**, a fictional network of 8 outpatient clinics, and then built it in code. Patient data is encrypted and locked down, every tier runs across two Availability Zones, imaging moves to AWS HealthImaging, and every architecture choice is written down with the alternative I rejected.

The design is written in Terraform. A slice of it is deployed live, tested by breaking it on purpose, and then torn down.

## 🧭 Read in this order

| # | What | Why read it |
|---|---|---|
| 1 | [Design Plan](../docs/design-plan.md) | Every foundation in the design and the reason behind it |
| 2 | [Architecture diagram](../diagrams) | The whole system on one page |
| 3 | [Decision records](../docs/adr) | The trade-offs, and the alternatives I compared |
| 4 | [Terraform](../iac/terraform) | The design as working code |
| 5 | [Deploy evidence](../deploy-evidence) | Proof the deployed slice survives failures |
| 6 | [Presentation](../presentation) | The stakeholder briefing |

## 📒 Build log

Each step I completed, in order. Each entry has a short summary; the [deep dives](deep-dives) hold the full commands, configs, and evidence.

| # | Step | Phase | Result |
|---|---|---|---|
| 01 | [Repository and design plan](01-repo-and-design-plan.md) | 1 · Design | ✅ Repo created, design plan written |
