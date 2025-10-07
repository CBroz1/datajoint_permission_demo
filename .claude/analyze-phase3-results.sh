#!/bin/bash
# Analyze Phase 3 test results and generate comparison matrix

set -e

LOG_DIR=".claude/logs"
OUTPUT=".claude/PHASE3_RESULTS.md"

echo "Analyzing Phase 3 test results..."

# Start markdown file
cat > "$OUTPUT" <<'EOF'
# Phase 3: Parallel Test Results

**Date:** $(date)
**Tests Run:** Role vs Direct Grant, FK Configuration

---

## Test Configurations

| Test ID | Port | Description | Setup | Schema |
|---------|------|-------------|-------|--------|
EOF

# Add test configurations
for summary in ${LOG_DIR}/phase3-*-summary.txt; do
    if [ -f "$summary" ]; then
        port=$(basename "$summary" | cut -d'-' -f2)
        desc=$(basename "$summary" | cut -d'-' -f3 | sed 's/-summary.txt//')
        setup=$(grep "Setup:" "$summary" | cut -d' ' -f2)
        schema=$(grep "Schema:" "$summary" | cut -d' ' -f2)
        echo "| ${port}-${desc} | ${port} | ${desc} | ${setup} | ${schema} |" >> "$OUTPUT"
    fi
done

cat >> "$OUTPUT" <<'EOF'

---

## Error Comparison Matrix

| Test ID | User1 Parent2 | User2 Parent2 | User1 Parent3 | User2 Parent3 | Notes |
|---------|---------------|---------------|---------------|---------------|-------|
EOF

# Add error comparison
for summary in ${LOG_DIR}/phase3-*-summary.txt; do
    if [ -f "$summary" ]; then
        port=$(basename "$summary" | cut -d'-' -f2)
        desc=$(basename "$summary" | cut -d'-' -f3 | sed 's/-summary.txt//')

        u1p2=$(grep "User1 Parent2:" "$summary" | cut -d':' -f2- | xargs)
        u2p2=$(grep "User2 Parent2:" "$summary" | cut -d':' -f2- | xargs)
        u1p3=$(grep "User1 Parent3:" "$summary" | cut -d':' -f2- | xargs 2>/dev/null || echo "N/A")
        u2p3=$(grep "User2 Parent3:" "$summary" | cut -d':' -f2- | xargs 2>/dev/null || echo "N/A")

        # Determine if errors are verbose (1451) or non-verbose (1217)
        u1p2_code=$(echo "$u1p2" | grep -oP 'ERROR \K\d+' || echo "N/A")
        u2p2_code=$(echo "$u2p2" | grep -oP 'ERROR \K\d+' || echo "N/A")
        u1p3_code=$(echo "$u1p3" | grep -oP 'ERROR \K\d+' || echo "N/A")
        u2p3_code=$(echo "$u2p3" | grep -oP 'ERROR \K\d+' || echo "N/A")

        notes=""
        if [ "$u1p2_code" = "1217" ] || [ "$u2p2_code" = "1217" ]; then
            notes="Non-verbose error"
        elif [ "$u1p2_code" = "1451" ] || [ "$u2p2_code" = "1451" ]; then
            notes="Verbose error ✅"
        fi

        echo "| ${port}-${desc} | ERROR ${u1p2_code} | ERROR ${u2p2_code} | ERROR ${u1p3_code} | ERROR ${u2p3_code} | ${notes} |" >> "$OUTPUT"
    fi
done

cat >> "$OUTPUT" <<'EOF'

---

## Detailed Results

EOF

# Add detailed results for each test
for summary in ${LOG_DIR}/phase3-*-summary.txt; do
    if [ -f "$summary" ]; then
        port=$(basename "$summary" | cut -d'-' -f2)
        desc=$(basename "$summary" | cut -d'-' -f3 | sed 's/-summary.txt//')

        cat >> "$OUTPUT" <<EOF
### Test ${port}-${desc}

**Setup:** $(grep "Setup:" "$summary" | cut -d' ' -f2)
**Schema:** $(grep "Schema:" "$summary" | cut -d' ' -f2)

\`\`\`
$(cat "$summary")
\`\`\`

**Full Error Messages:**

User1 Parent2:
\`\`\`
$(cat "${LOG_DIR}/phase3-${port}-${desc}-user1-parent2.log" 2>/dev/null | grep -A 1 "ERROR" || echo "No error")
\`\`\`

User2 Parent2:
\`\`\`
$(cat "${LOG_DIR}/phase3-${port}-${desc}-user2-parent2.log" 2>/dev/null | grep -A 1 "ERROR" || echo "No error")
\`\`\`

EOF

        # Add parent3 results if they exist
        if [ -f "${LOG_DIR}/phase3-${port}-${desc}-user1-parent3.log" ]; then
            cat >> "$OUTPUT" <<EOF
User1 Parent3:
\`\`\`
$(cat "${LOG_DIR}/phase3-${port}-${desc}-user1-parent3.log" 2>/dev/null | grep -A 1 "ERROR" || echo "No error")
\`\`\`

User2 Parent3:
\`\`\`
$(cat "${LOG_DIR}/phase3-${port}-${desc}-user2-parent3.log" 2>/dev/null | grep -A 1 "ERROR" || echo "No error")
\`\`\`

EOF
        fi

        echo "---" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    fi
done

cat >> "$OUTPUT" <<'EOF'

## Key Findings

EOF

# Analyze patterns
echo "### Error Code Distribution" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "- ERROR 1217 (non-verbose): Occurs when user lacks ALL privileges on FK-referencing tables" >> "$OUTPUT"
echo "- ERROR 1451 (verbose): Occurs when user has ALL privileges on all FK-referencing tables" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "### Role vs Direct Grant Analysis" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Tests 3301-01-baseline, 3302-02-no_roles, and 3303-03-both_roles compare:" >> "$OUTPUT"
echo "- Baseline: user1 direct grants, user2 role-based grants" >> "$OUTPUT"
echo "- No roles: Both users have direct grants" >> "$OUTPUT"
echo "- Both roles: Both users have role-based grants" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "### FK Configuration Analysis" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Test 3308-08-one_child tests if having only one FK-referencing table changes behavior:" >> "$OUTPUT"
echo "- With single child table: Does error verbosity differ?" >> "$OUTPUT"
echo "- Compare to baseline with two child tables" >> "$OUTPUT"
echo "" >> "$OUTPUT"

cat >> "$OUTPUT" <<'EOF'

---

**Generated:** $(date)
**Log files:** `.claude/logs/phase3-*`
EOF

echo "Analysis complete: $OUTPUT"
echo ""
echo "To view:"
echo "  cat $OUTPUT"
