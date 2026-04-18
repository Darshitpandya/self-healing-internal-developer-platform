# The Self-Healing Platform: When Your IDP Fixes Itself

> **"Most developer portals display problems. The self-healing platform fixes them."**

Most developer portals are read-only dashboards — they show what's wrong and wait for someone to file a ticket. The **Self-Healing Platform** pattern turns the portal into an active control surface: scorecards that trigger automated remediation actions, orphan ownership that self-corrects, golden path version drift that raises its own upgrade PR, and secret expiry that fires platform-side responses before a developer notices.

This is not a dashboard. It's a **platform control plane** — powered by Port.io scorecards, GitHub Actions remediation workflows, and OPA policy gates.

**PlatformCon 2026** — Darshit Pandya | Senior Principal Engineer – Platform @ Serko

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              DEVELOPER PORTAL (Port.io)              │
│                                                      │
│   Scorecards continuously evaluate service entities  │
│                                                      │
│   Score drops below threshold                        │
│              │                                       │
│              ▼                                       │
│   Self-Service Action fires (webhook)                │
└──────────────┬───────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────┐
│           REMEDIATION ENGINE (GitHub Actions)         │
│                                                      │
│   ┌──────────┐   ┌──────────────┐   ┌────────────┐  │
│   │   OPA    │   │  Remediation │   │OpenTelemetry│  │
│   │  Policy  │──▶│   Execute    │──▶│  Audit Log  │  │
│   │  Check   │   │  (raise PR)  │   │  (trace)    │  │
│   └──────────┘   └──────────────┘   └────────────┘  │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼
              Update Portal Entity (close the loop)
              Score recalculates → green ✅
```

### Three Self-Healing Actions

| Action | Trigger | What It Does |
|---|---|---|
| **Orphan Ownership** | Service has no owner, dissolved team, or conflicting declarations | Cross-references CODEOWNERS, GitHub Teams, PagerDuty on-call, PR approvers → raises PR or escalates |
| **Golden Path Upgrade** | Service behind golden path template (includes security patches) | Raises PR with template diff and changelog |
| **Secret Expiry** | Secret expiring within 14 days, no auto-rotation configured | Raises PR to migrate to Secrets Manager with auto-rotation |

### The OPA Policy Gate

Every self-healing action passes through OPA before executing:

```rego
default allow = false

allow if {
    input.action == "golden_path_upgrade"
    input.service_tier != "critical"
    input.versions_behind > 1
}

deny if {
    input.service_tier == "critical"
    not input.human_approved
}
```

**Auto-fix:** Non-critical services with high confidence.
**Propose + notify:** Critical services or low confidence.
**Block:** Cross-service changes, production data.

---

## Quick Start

### Prerequisites

- [Port.io account](https://www.getport.io/) (free tier works)
- GitHub personal access token with `repo` scope
- [OPA binary](https://www.openpolicyagent.org/docs/latest/#running-opa) installed (for local testing)
- (Optional) PagerDuty API key for SLA breach response

### Setup

```bash
git clone https://github.com/Darshitpandya/self-healing-internal-developer-platform.git
cd self-healing-internal-developer-platform

cp .env.example .env
# Edit .env with your PORT_CLIENT_ID, PORT_CLIENT_SECRET, and GITHUB_TOKEN
```

### Step 1: Create Port.io Entities and Scorecards

```bash
./scripts/setup-port.sh
```

This creates:
- Service blueprint with all properties
- 8 sample service entities (3 with ownership issues, 2 with golden path drift, 2 with secret expiry)
- 3 scorecards (ownership health, golden path compliance, secret health)
- 3 self-service actions (webhooks to GitHub Actions)

### Step 2: Trigger a Self-Healing Action

**Option A — From Port.io UI:**
Open Port.io → find a service with a red scorecard → click the self-service action.

**Option B — From GitHub (manual trigger):**
```bash
# Fix orphan ownership
gh workflow run fix-ownership.yml -f service_identifier=notifications-svc

# Golden path upgrade
gh workflow run golden-path-upgrade.yml \
  -f service_identifier=payments-svc \
  -f current_version=v1.2 \
  -f target_version=v1.5

# Fix secret expiry
gh workflow run fix-secret-expiry.yml \
  -f service_identifier=orders-svc \
  -f secret_name=PAYMENT_GATEWAY_API_KEY
```

### Step 3: See the Results

- A PR or Issue appears in the repo
- Port.io scorecard updates after the entity is modified

---

## What This Is

A **blueprint** for the Self-Healing Platform pattern — Port.io scorecards wired to GitHub Actions remediation workflows with OPA policy gates.

- ✅ Port.io blueprint, 3 scorecards, 3 self-service actions
- ✅ 3 GitHub Actions workflows (ownership, golden path, secret expiry)
- ✅ OPA policy gate (auto-fix / propose / block)
- ✅ OpenTelemetry tracing for audit trail
- ✅ 8 sample service entities with realistic data
- ✅ Setup script that creates everything in Port.io via API

## What This Is NOT

This is **not a production deployment**. Follow the Production Adoption Guide below.

### About the Sample Data

All service entities (ownership status, template versions, secret expiry dates) are **realistic but fictional** sample data for the demo. The setup script creates these in Port.io so you can see scorecards in action immediately. In production, your entities would be populated from real sources (GitHub, AWS, PagerDuty).

---

## Project Structure

```
scripts/
└── setup-port.sh                  Creates everything in Port.io via API
port/
├── blueprints/service.json        Service entity schema
├── scorecards/
│   ├── ownership-health.json      Ownership scorecard rules
│   ├── golden-path-compliance.json Golden path scorecard rules
│   └── secret-health.json         Secret health scorecard rules
└── actions/
    ├── fix-ownership.json         Self-service action → GitHub webhook
    ├── golden-path-upgrade.json   Self-service action → GitHub webhook
    └── fix-secret-expiry.json     Self-service action → GitHub webhook
.github/workflows/
├── fix-ownership.yml              Resolves orphan ownership
├── golden-path-upgrade.yml        Raises template upgrade PR
└── fix-secret-expiry.yml          Raises secret rotation PR
policies/
└── selfheal.rego                  OPA policy gate
otel/
└── tracing.py                     OpenTelemetry audit trail
sample-data/
├── services.json                  8 sample service entities
├── teams.json                     Team registry (active/dissolved)
├── ownership-signals.json         CODEOWNERS, PagerDuty, PR approver signals
├── template-changelog.json        Golden path version history
└── secrets.json                   Secret expiry data
```

---

## Production Adoption Guide

### Step 1: Connect Port.io to Real Data Sources

The blueprint uses sample data. In production, Port.io entities should be populated from real sources:

| Property | Source |
|---|---|
| `team_owner` | GitHub CODEOWNERS file or GitHub Teams API |
| `ownership_source` | Cross-reference CODEOWNERS + PagerDuty + GitHub Teams |
| `template_version` | Read from service's `package.json`, `pyproject.toml`, or catalog-info |
| `secret_health_status` | AWS Secrets Manager API or Vault API |
| `service_tier` | Your service catalog / Port.io entity metadata |

Port.io supports [data sources and integrations](https://docs.getport.io/build-your-software-catalog/) to populate entities automatically.

### Step 2: Configure Self-Service Actions for Your Org

Update the action JSON files in `port/actions/` — replace `<YOUR_GITHUB_ORG>` with your GitHub organisation name.

### Step 3: Write Your Own OPA Policies

The included `selfheal.rego` is an example. Customise the rules for your trust boundaries:

- Which service tiers get auto-remediation?
- What confidence level is required for ownership auto-fix?
- Which actions require human approval?

### Step 4: Add Real Ownership Resolution

The `fix-ownership.yml` workflow reads from `sample-data/ownership-signals.json`. In production, replace with real API calls:

```bash
# Query GitHub CODEOWNERS
gh api repos/{owner}/{repo}/contents/CODEOWNERS

# Query PagerDuty on-call
curl -H "Authorization: Token token=$PAGERDUTY_API_KEY" \
  "https://api.pagerduty.com/oncalls?schedule_ids[]=$SCHEDULE_ID"

# Query GitHub PR approvers
gh api repos/{owner}/{repo}/pulls?state=closed --jq '.[].requested_reviewers[].login'
```

### Step 5: Add PagerDuty Integration (Optional)

For SLA breach response, add `PAGERDUTY_API_KEY` and `PAGERDUTY_SERVICE_ID` to your GitHub Actions secrets. The workflow can create PagerDuty incidents with runbooks attached.

### Step 6: Configure OpenTelemetry

Set `OTEL_EXPORTER_OTLP_ENDPOINT` in your environment to export traces to your observability backend (Jaeger, Grafana Tempo, AWS X-Ray).

### Production Checklist

- [ ] Port.io entities populated from real data sources
- [ ] Self-service actions configured with your GitHub org
- [ ] OPA policies customised for your trust boundaries
- [ ] Ownership resolution queries real APIs (CODEOWNERS, PagerDuty, GitHub Teams)
- [ ] Golden path upgrade workflow applies real template diffs
- [ ] Secret expiry workflow integrates with your secrets manager
- [ ] PagerDuty integration configured (if using SLA response)
- [ ] OpenTelemetry exporter configured
- [ ] Rate limiting added (max PRs per hour to avoid PR floods)
- [ ] Grace window implemented (skip if entity updated in last 60 seconds — prevents revert wars)

---

## The Human Gate

Every self-healing action creates a **PR or Issue** — never auto-merges. This is a platform contract encoded in OPA:

```rego
deny if {
    input.service_tier == "critical"
    not input.human_approved
}
```

**Why:** During stress testing, a tag remediation on a Terraform-managed resource triggered a plan that wanted to replace the resource. In staging, that's a lesson. In production, that's data loss. The human gate is non-negotiable.

---

## License

MIT
