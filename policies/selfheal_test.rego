package selfheal_test

import data.selfheal.allow

# --- Golden path upgrade ---

test_allow_golden_path_non_critical if {
    allow with input as {
        "action": "golden_path_upgrade",
        "service_tier": "standard",
        "versions_behind": 2
    }
}

test_deny_golden_path_critical if {
    not allow with input as {
        "action": "golden_path_upgrade",
        "service_tier": "critical",
        "versions_behind": 2
    }
}

test_deny_golden_path_zero_versions_behind if {
    not allow with input as {
        "action": "golden_path_upgrade",
        "service_tier": "standard",
        "versions_behind": 1
    }
}

# --- Ownership fix ---

test_allow_ownership_high_confidence_non_critical if {
    allow with input as {
        "action": "fix_ownership",
        "ownership_confidence": "high",
        "service_tier": "standard"
    }
}

test_deny_ownership_low_confidence if {
    not allow with input as {
        "action": "fix_ownership",
        "ownership_confidence": "low",
        "service_tier": "standard"
    }
}

test_deny_ownership_critical_service if {
    not allow with input as {
        "action": "fix_ownership",
        "ownership_confidence": "high",
        "service_tier": "critical"
    }
}

# --- Secret expiry ---

test_allow_secret_expiry_non_critical_urgent if {
    allow with input as {
        "action": "fix_secret_expiry",
        "service_tier": "standard",
        "days_to_expiry": 7
    }
}

test_deny_secret_expiry_critical_service if {
    not allow with input as {
        "action": "fix_secret_expiry",
        "service_tier": "critical",
        "days_to_expiry": 7
    }
}

test_deny_secret_expiry_not_urgent if {
    not allow with input as {
        "action": "fix_secret_expiry",
        "service_tier": "standard",
        "days_to_expiry": 30
    }
}
