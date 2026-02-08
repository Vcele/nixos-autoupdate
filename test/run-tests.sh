#!/usr/bin/env bash
# Test script for nixos-autoupdate module functionality

set -euo pipefail

echo "=== NixOS Auto-Update Module Test Suite ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_passed=0
test_failed=0

function test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $2"
        test_passed=$((test_passed + 1))
    else
        echo -e "${RED}✗ FAILED${NC}: $2"
        test_failed=$((test_failed + 1))
    fi
}

function test_section() {
    echo
    echo -e "${YELLOW}>>> $1${NC}"
}

# Test 1: Flake structure
test_section "Testing Flake Structure"

if [ -f "flake.nix" ]; then
    test_result 0 "flake.nix exists"
else
    test_result 1 "flake.nix exists"
fi

if [ -f "module.nix" ]; then
    test_result 0 "module.nix exists"
else
    test_result 1 "module.nix exists"
fi

# Test 2: Example configurations
test_section "Testing Example Configurations"

for example in examples/*.nix; do
    if [ -f "$example" ]; then
        test_result 0 "Example exists: $(basename $example)"
    else
        test_result 1 "Example exists: $(basename $example)"
    fi
done

# Test 3: Syntax validation (basic)
test_section "Testing Syntax Validation"

# Check for balanced braces in main files
for file in flake.nix module.nix; do
    if [ -f "$file" ]; then
        open_braces=$(grep -o '{' "$file" | wc -l)
        close_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -eq "$close_braces" ]; then
            test_result 0 "Balanced braces in $file"
        else
            test_result 1 "Balanced braces in $file (open: $open_braces, close: $close_braces)"
        fi
    fi
done

# Test 4: Module options structure
test_section "Testing Module Options"

required_options=(
    "enable"
    "flake"
    "localFlake"
    "onlyOnACPower"
    "wakeup"
    "notification"
)

for option in "${required_options[@]}"; do
    if grep -q "^[ 	]*$option[ 	]*=" module.nix; then
        test_result 0 "Option '$option' defined"
    else
        test_result 1 "Option '$option' defined"
    fi
done

# Test 5: Wake-up functionality components
test_section "Testing Wake-up Functionality"

if grep -q "rtcwake\|wakealarm" module.nix; then
    test_result 0 "RTC wake alarm support included"
else
    test_result 1 "RTC wake alarm support included"
fi

if grep -q "wakeup.enable" module.nix; then
    test_result 0 "Wakeup enable option defined"
else
    test_result 1 "Wakeup enable option defined"
fi

if grep -q "schedule.*mkOption" module.nix; then
    test_result 0 "Schedule option defined (used for wake-up time)"
else
    test_result 1 "Schedule option defined (used for wake-up time)"
fi

if grep -q "autoSuspendAfter" module.nix; then
    test_result 0 "Auto-suspend option defined"
else
    test_result 1 "Auto-suspend option defined"
fi

# Test 6: AC power detection
test_section "Testing AC Power Detection"

if grep -q "onlyOnACPower" module.nix; then
    test_result 0 "AC power option defined"
else
    test_result 1 "AC power option defined"
fi

if grep -q "power_supply\|upower" module.nix; then
    test_result 0 "Power detection logic included"
else
    test_result 1 "Power detection logic included"
fi

# Test 7: Notification functionality
test_section "Testing Notification Functionality"

if grep -q "notification.enable" module.nix; then
    test_result 0 "Notification enable option defined"
else
    test_result 1 "Notification enable option defined"
fi

if grep -q "notify-send\|libnotify" module.nix; then
    test_result 0 "Notification system included"
else
    test_result 1 "Notification system included"
fi

if grep -q "notification.urgency" module.nix; then
    test_result 0 "Notification urgency option defined"
else
    test_result 1 "Notification urgency option defined"
fi

if grep -q "notification.timeout" module.nix; then
    test_result 0 "Notification timeout option defined"
else
    test_result 1 "Notification timeout option defined"
fi

# Test 8: Local flake support
test_section "Testing Local Flake Support"

if grep -q "localFlake" module.nix; then
    test_result 0 "Local flake option defined"
else
    test_result 1 "Local flake option defined"
fi

# Test 9: Systemd service configuration
test_section "Testing Systemd Configuration"

if grep -q "systemd.services.nixos-upgrade" module.nix; then
    test_result 0 "Main service configuration included"
else
    test_result 1 "Main service configuration included"
fi

if grep -q "CPUSchedulingPolicy\|IOSchedulingClass" module.nix; then
    test_result 0 "Resource scheduling options included"
else
    test_result 1 "Resource scheduling options included"
fi

# Test 10: Documentation
test_section "Testing Documentation"

if [ -f "README.md" ]; then
    test_result 0 "README.md exists"
    
    readme_sections=(
        "Features"
        "Installation"
        "Configuration"
        "Wake-up"
        "AC power"
        "Notification"
        "Local flake"
    )
    
    for section in "${readme_sections[@]}"; do
        if grep -qi "$section" README.md; then
            test_result 0 "README contains '$section' section"
        else
            test_result 1 "README contains '$section' section"
        fi
    done
else
    test_result 1 "README.md exists"
fi

# Summary
echo
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: $test_passed${NC}"
echo -e "${RED}Failed: $test_failed${NC}"
echo "Total: $((test_passed + test_failed))"

if [ $test_failed -eq 0 ]; then
    echo
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
