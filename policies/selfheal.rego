package selfheal

default allow = false

# Ownership fixes — auto-approve for high confidence on non-critical services
allow if {
    input.action == "fix_ownership"
    input.ownership_confidence == "high"
    input.service_tier != "critical"
}

# Golden path upgrades — auto-approve for non-critical services
allow if {
    input.action == "golden_path_upgrade"
    input.service_tier != "critical"
    input.versions_behind > 1
}

# Secret rotation — auto-approve for non-critical services with expiry < 14 days
allow if {
    input.action == "fix_secret_expiry"
    input.service_tier != "critical"
    input.days_to_expiry < 14
}

# Critical services: always require human approval — no exceptions
deny if {
    input.service_tier == "critical"
    not input.human_approved
}

# Low confidence ownership: always propose, never auto-fix
deny if {
    input.action == "fix_ownership"
    input.ownership_confidence != "high"
}
