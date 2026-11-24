#!/usr/bin/env bash
#
# Structural validation for the devloop ecosystem.
# Checks files, links, JSON, phases, agents, leaks, and cross-references.
#
# Usage: ./validate.sh
# Exit code: 0 = all checks pass, 1 = failures found

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
ERRORS=()

pass() {
    PASS=$((PASS + 1))
    printf "  \033[32mPASS\033[0m %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    ERRORS+=("$1")
    printf "  \033[31mFAIL\033[0m %s\n" "$1"
}

# has_text FILE PHRASE: PHRASE appears in FILE with line breaks folded to
# spaces, so prose can wrap freely without breaking a marker.
has_text() {
    [[ -f "$1" ]] && tr '\n' ' ' < "$1" | tr -s ' ' | grep -qF -- "$2"
}

# require_markers FILE MARKER...: one pass/fail line per marker, matched
# with has_text so a phrase that wraps across lines still matches.
require_markers() {
    local file="$1"; shift
    local marker
    for marker in "$@"; do
        if has_text "$file" "$marker"; then
            pass "$file has: $marker"
        else
            fail "$file is missing: $marker"
        fi
    done
}

section() {
    printf "\n\033[1m%s\033[0m\n" "$1"
}

# ─────────────────────────────────────────────
section "1. Required files exist"
# ─────────────────────────────────────────────

required_files=(
    ".claude-plugin/plugin.json"
    ".codex-plugin/plugin.json"
    "LICENSE"
    "README.md"
    # Implement skill
    "skills/implement/SKILL.md"
    "skills/implement/references/quality-checklist.md"
    "skills/implement/references/review-and-finish.md"
    # Plan skill (owns the plan artifacts: tracker schema + chunk template)
    "skills/plan/SKILL.md"
    "skills/plan/references/chunk-template.md"
    "skills/plan/references/tracker-schema.md"
    # Spec skill
    "skills/spec/SKILL.md"
    "skills/spec/references/spec-template.md"
    "skills/spec/references/clarification-taxonomy.md"
    "skills/spec/references/validation-checklist.md"
    # Agents
    "agents/review-plan.md"
    "agents/review-impl.md"
)

for f in "${required_files[@]}"; do
    if [[ -f "$f" ]]; then
        pass "$f exists"
    else
        fail "$f is missing"
    fi
done

# ─────────────────────────────────────────────
section "2. Internal markdown links resolve"
# ─────────────────────────────────────────────

check_links_in() {
    local file="$1"
    local dir
    dir="$(dirname "$file")"

    local targets
    targets="$(sed -n 's/.*\[.*\](\([^)]*\.md[^)]*\)).*/\1/p' "$file" 2>/dev/null || true)"

    if [[ -z "$targets" ]]; then
        return
    fi

    while IFS= read -r target; do
        # Skip external links
        [[ "$target" == http* ]] && continue
        # Strip any anchor (#section)
        target="${target%%#*}"
        local resolved="$dir/$target"
        if [[ -f "$resolved" ]]; then
            pass "$file -> $target"
        else
            fail "$file -> $target (not found: $resolved)"
        fi
    done <<< "$targets"
}

check_links_in "README.md"
check_links_in "skills/implement/SKILL.md"
check_links_in "skills/plan/SKILL.md"
check_links_in "skills/spec/SKILL.md"
check_links_in "skills/plan/references/chunk-template.md"
check_links_in "skills/plan/references/tracker-schema.md"
check_links_in "skills/implement/references/quality-checklist.md"
check_links_in "skills/implement/references/review-and-finish.md"
check_links_in "skills/spec/references/spec-template.md"
check_links_in "skills/spec/references/clarification-taxonomy.md"
check_links_in "skills/spec/references/validation-checklist.md"

# ─────────────────────────────────────────────
section "3. JSON validity"
# ─────────────────────────────────────────────

# plugin.json (Claude Code)
if python3 -m json.tool .claude-plugin/plugin.json > /dev/null 2>&1; then
    pass "plugin.json is valid JSON"
else
    fail "plugin.json is invalid JSON"
fi

# plugin.json (Codex)
if python3 -m json.tool .codex-plugin/plugin.json > /dev/null 2>&1; then
    pass "codex plugin.json is valid JSON"
else
    fail "codex plugin.json is invalid JSON"
fi

# Codex manifest required fields + skills-dir pointer (Codex uses a
# directory string for skills, not Claude's array of objects).
for field in name version description skills; do
    if python3 -c "import json; d=json.load(open('.codex-plugin/plugin.json')); assert '$field' in d" 2>/dev/null; then
        pass "codex plugin.json has '$field' field"
    else
        fail "codex plugin.json missing '$field' field"
    fi
done

codex_skills="$(python3 -c "import json; print(json.load(open('.codex-plugin/plugin.json')).get('skills',''))" 2>/dev/null || echo '')"
if [[ "$codex_skills" == "./skills/" ]]; then
    pass "codex plugin.json skills points to ./skills/"
else
    fail "codex plugin.json skills should be './skills/' (got '$codex_skills')"
fi

# JSON blocks in markdown files
validate_json_blocks() {
    local file="$1"
    local block_num=0
    local in_json=false
    local json_buf=""

    while IFS= read -r line; do
        if [[ "$line" == '```json' ]]; then
            in_json=true
            json_buf=""
            block_num=$((block_num + 1))
            continue
        fi
        if [[ "$line" == '```' ]] && $in_json; then
            in_json=false
            if echo "$json_buf" | python3 -m json.tool > /dev/null 2>&1; then
                pass "$file JSON block #$block_num is valid"
            else
                fail "$file JSON block #$block_num is invalid JSON"
            fi
            continue
        fi
        if $in_json; then
            json_buf+="$line"$'\n'
        fi
    done < "$file"
}

validate_json_blocks "skills/plan/references/tracker-schema.md"
validate_json_blocks "skills/plan/references/chunk-template.md"

# ─────────────────────────────────────────────
section "4. plugin.json has required fields"
# ─────────────────────────────────────────────

for field in name description author; do
    if python3 -c "import json; d=json.load(open('.claude-plugin/plugin.json')); assert '$field' in d" 2>/dev/null; then
        pass "plugin.json has '$field' field"
    else
        fail "plugin.json missing '$field' field"
    fi
done

# Skills and agents are auto-discovered from skills/ and agents/. The
# manifest must NOT enumerate them: the current Claude Code schema rejects
# skills/agents as arrays of objects (`claude plugin validate` reports
# "Invalid input"). Verify the directories instead, and guard against a
# regression that re-adds the keys.
for s in spec plan implement; do
    if [[ -f "skills/$s/SKILL.md" ]]; then
        pass "skills/$s/SKILL.md present (auto-discovered)"
    else
        fail "skills/$s/SKILL.md missing"
    fi
done
if python3 -c "import json,sys; d=json.load(open('.claude-plugin/plugin.json')); sys.exit(1 if ('skills' in d or 'agents' in d) else 0)" 2>/dev/null; then
    pass "plugin.json does not enumerate skills/agents (schema-valid auto-discovery)"
else
    fail "plugin.json must not enumerate skills/agents (current Claude Code schema rejects object arrays)"
fi

# Marketplace catalogs (both harnesses) exist, are valid JSON, and list devloop.
# `plugin install` pulls from a marketplace, so a bare plugin.json is not
# installable on its own.
for mpfile in ".claude-plugin/marketplace.json" ".agents/plugins/marketplace.json"; do
    if [[ ! -f "$mpfile" ]]; then
        fail "$mpfile missing (needed for plugin install)"
    elif python3 -c "import json,sys; d=json.load(open('$mpfile')); sys.exit(0 if any(p.get('name')=='devloop' for p in d.get('plugins',[])) else 1)" 2>/dev/null; then
        pass "$mpfile is valid JSON and lists the devloop plugin"
    else
        fail "$mpfile must be valid JSON and list a plugin named devloop"
    fi
done

# ─────────────────────────────────────────────
section "5. Skill phases are sequential (spec 1-5, plan 1-5, implement 1-3)"
# ─────────────────────────────────────────────

implement_skill="skills/implement/SKILL.md"
plan_skill="skills/plan/SKILL.md"
spec_skill="skills/spec/SKILL.md"

check_phase_sequence() {
    local file="$1"
    local label="$2"
    local want="$3"

    local phase_count
    phase_count="$(grep -cE '^## Phase [0-9]+:' "$file" || true)"
    if [[ "$phase_count" -eq "$want" ]]; then
        pass "$label has $phase_count phases"
    else
        fail "$label has $phase_count phases (expected $want)"
    fi

    local expected=1
    local phase_nums
    phase_nums="$(grep -E '^## Phase [0-9]+:' "$file" | sed 's/^## Phase //' | sed 's/:.*//' || true)"
    while IFS= read -r num; do
        [[ -z "$num" ]] && continue
        if [[ "$num" -eq "$expected" ]]; then
            pass "$label Phase $num is sequential"
        else
            fail "$label Phase $num out of order (expected $expected)"
        fi
        expected=$((expected + 1))
    done <<< "$phase_nums"
}

check_phase_sequence "$spec_skill" "Spec SKILL.md" 5
check_phase_sequence "$plan_skill" "Plan SKILL.md" 5
check_phase_sequence "$implement_skill" "Implement SKILL.md" 3

# ─────────────────────────────────────────────
section "6. Quality checklist has exactly 6 concerns"
# ─────────────────────────────────────────────

checklist="skills/implement/references/quality-checklist.md"
checklist_count="$(grep -cE '^## [0-9]+\.' "$checklist" || true)"
if [[ "$checklist_count" -eq 6 ]]; then
    pass "quality-checklist.md has $checklist_count points"
else
    fail "quality-checklist.md has $checklist_count points (expected 6)"
fi

expected=1
checklist_nums="$(grep -E '^## [0-9]+\.' "$checklist" | sed 's/^## //' | sed 's/\..*//' || true)"
while IFS= read -r num; do
    [[ -z "$num" ]] && continue
    if [[ "$num" -eq "$expected" ]]; then
        pass "Checklist point $num is sequential"
    else
        fail "Checklist point $num out of order (expected $expected)"
    fi
    expected=$((expected + 1))
done <<< "$checklist_nums"

# ─────────────────────────────────────────────
section "7. Gate structure and concern names"
# ─────────────────────────────────────────────

# Implement Phase 3 lists the 6 concern names in bold (the shared
# checklist). The plan-review gate lives in /plan Phase 4; its criteria
# (the 6 concerns plus TDD quality) live in the review-plan agent.
phase3_names=(
    "Completeness"
    "Correctness"
    "Regression"
    "Robustness"
    "Blindspots"
    "Maintainability"
)

for name in "${phase3_names[@]}"; do
    count="$(grep -c "\*\*$name\*\*" "$implement_skill" || true)"
    if [[ "$count" -ge 1 ]]; then
        pass "\"$name\" in Implement Phase 3 checklist"
    else
        fail "\"$name\" not found in Implement SKILL.md"
    fi
done

# The plan-review gate is artifact-triggered in /plan Phase 4.
if grep -q "Run this review on the Phase 3 tracker" "$plan_skill"; then
    pass "Plan SKILL.md has artifact-triggered plan-review gate"
else
    fail "Plan SKILL.md missing artifact-triggered gate pattern"
fi

# The /implement quality gate is triggered when all chunks complete.
if grep -q "When all chunks are complete, run the code review" "$implement_skill"; then
    pass "Implement SKILL.md has artifact-triggered quality gate"
else
    fail "Implement SKILL.md missing quality gate pattern"
fi

# /plan records the gate field; /implement verifies it before the TDD cycle.
if grep -q "plan_review" "$plan_skill" && grep -q "plan_review" "$implement_skill"; then
    pass "plan_review tracker field referenced in /plan and /implement"
else
    fail "plan_review tracker field not referenced in both skills"
fi

# ─────────────────────────────────────────────
section "8. Rule lists are sequentially numbered"
# ─────────────────────────────────────────────

check_lessons() {
    local file="$1"
    local label="$2"
    local lesson_nums=()
    local in_lessons=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^"## "(Implementation|Planning|Spec)" rules"$ ]]; then
            in_lessons=true
            continue
        fi
        if $in_lessons && [[ "$line" == "---" || "$line" == "## "* ]]; then
            break
        fi
        if $in_lessons; then
            num=""
            if echo "$line" | grep -qE '^[0-9]+\. \*\*'; then
                num="$(echo "$line" | sed 's/\..*//')"
            fi
            if [[ -n "$num" ]]; then
                lesson_nums+=("$num")
            fi
        fi
    done < "$file"

    local count=${#lesson_nums[@]}
    if [[ "$count" -gt 0 ]]; then
        pass "$label: found $count lessons"
    else
        fail "$label: no lessons found"
    fi

    local expected=1
    for num in "${lesson_nums[@]}"; do
        if [[ "$num" -eq "$expected" ]]; then
            pass "$label: lesson $num is sequential"
        else
            fail "$label: lesson $num out of order (expected $expected)"
        fi
        expected=$((expected + 1))
    done
}

check_lessons "$implement_skill" "Implement"
check_lessons "$plan_skill" "Plan"
check_lessons "$spec_skill" "Spec"

# ─────────────────────────────────────────────
section "9. Example configs have required sections"
# ─────────────────────────────────────────────

# The examples/<stack>/ directories are the canonical starting templates a
# user copies into .devloop/ (config.md + domain.md). Any one could be the
# copied file, so each must carry the full section set.
implement_sections=(
    "Build & Test Commands"
    "Architecture Patterns"
    "Standards to Verify"
    "Blindspots to Check"
    "Commit Conventions"
    "Documentation Location"
)

for cfg in examples/*/config.md; do
    stack="$(basename "$(dirname "$cfg")")"
    for section_name in "${implement_sections[@]}"; do
        if grep -q "$section_name" "$cfg"; then
            pass "examples/$stack/config.md has \"$section_name\""
        else
            fail "examples/$stack/config.md missing \"$section_name\""
        fi
    done
done

spec_sections=(
    "Domain Context"
    "Architecture Overview"
    "Domain-Specific Concerns"
    "Quality Standards"
)

for cfg in examples/*/domain.md; do
    stack="$(basename "$(dirname "$cfg")")"
    for section_name in "${spec_sections[@]}"; do
        if grep -q "$section_name" "$cfg"; then
            pass "examples/$stack/domain.md has \"$section_name\""
        else
            fail "examples/$stack/domain.md missing \"$section_name\""
        fi
    done
done

# ─────────────────────────────────────────────
section "10. No project-specific leaks in core files"
# ─────────────────────────────────────────────

core_files=(
    "skills/implement/SKILL.md"
    "skills/plan/SKILL.md"
    "skills/spec/SKILL.md"
    "skills/plan/references/chunk-template.md"
    "skills/plan/references/tracker-schema.md"
    "skills/implement/references/quality-checklist.md"
    "skills/implement/references/review-and-finish.md"
    "skills/spec/references/spec-template.md"
    "skills/spec/references/clarification-taxonomy.md"
    "skills/spec/references/validation-checklist.md"
    "agents/review-plan.md"
    "agents/review-impl.md"
)
leaked_terms=("SapClient" "fetchFn" "vitest" "npx tsc" "CSRF" "Zod" "gradlew" "Hilt" "Room" "Jetpack" "AndroidManifest")

leak_found=false
for file in "${core_files[@]}"; do
    for term in "${leaked_terms[@]}"; do
        if grep -qi "$term" "$file" 2>/dev/null; then
            fail "$file contains project-specific term \"$term\""
            leak_found=true
        fi
    done
done
if ! $leak_found; then
    pass "No project-specific terms in core files"
fi

# ─────────────────────────────────────────────
section "11. Agent frontmatter is valid"
# ─────────────────────────────────────────────

# Every agent declares its tools (the loop below fails a missing line, which
# would grant every tool). The review agents have no Edit or Write tool in
# their frontmatter, in either the inline or the list form; their Bash
# writes are barred only by the prompt.
for agent in agents/*.md; do
    if awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f && /^tools:/ {t=1; print; next} t && /^[[:space:]]+-/ {print; next} {t=0}' "$agent" | grep -qE '(Edit|Write)\b'; then
        fail "$(basename "$agent") frontmatter must not grant Edit or Write"
    else
        pass "$(basename "$agent") frontmatter grants no Edit or Write"
    fi
done

for agent in agents/*.md; do
    basename="$(basename "$agent")"
    for field in name description tools model; do
        if grep -q "^${field}:" "$agent"; then
            pass "$basename has '$field' field"
        else
            fail "$basename missing '$field' field"
        fi
    done
done

# ─────────────────────────────────────────────
section "12. Skills reference their review agents"
# ─────────────────────────────────────────────

# review-plan is /plan's gate; section 18 pins /implement's review-impl spawns.
if grep -q "review-plan" "$plan_skill"; then
    pass "Plan SKILL.md references review-plan agent"
else
    fail "Plan SKILL.md does not reference review-plan agent"
fi

# ─────────────────────────────────────────────
section "13. SKILL.md frontmatter follows spec"
# ─────────────────────────────────────────────

check_skill_frontmatter() {
    local file="$1"
    local label="$2"

    if grep -q '^name:' "$file"; then
        local skill_name
        skill_name="$(sed -n 's/^name:[[:space:]]*//p' "$file" | head -1 | tr -d ' ')"
        pass "$label has 'name' field: $skill_name"
        if echo "$skill_name" | grep -qE '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
            pass "$label name format is valid"
        else
            fail "$label name '$skill_name' should be lowercase letters, numbers, and hyphens"
        fi
    else
        fail "$label missing 'name' field"
    fi

    if grep -q '^description:' "$file"; then
        pass "$label has 'description' field"
    else
        fail "$label missing 'description' field"
    fi

    if grep -q '\$ARGUMENTS' "$file"; then
        pass "$label uses \$ARGUMENTS placeholder"
    else
        fail "$label missing \$ARGUMENTS (user input won't reach the process)"
    fi
}

check_skill_frontmatter "$implement_skill" "Implement SKILL.md"
check_skill_frontmatter "$plan_skill" "Plan SKILL.md"
check_skill_frontmatter "$spec_skill" "Spec SKILL.md"

# ─────────────────────────────────────────────
section "14. SKILL.md files are under 510 lines"
# ─────────────────────────────────────────────

for skill_file in "$implement_skill" "$plan_skill" "$spec_skill"; do
    label="$(basename "$(dirname "$skill_file")")"
    lines="$(wc -l < "$skill_file")"
    if [[ "$lines" -le 510 ]]; then
        pass "$label SKILL.md is $lines lines (limit: 510)"
    else
        fail "$label SKILL.md is $lines lines (recommended limit: 510)"
    fi
done

# ─────────────────────────────────────────────
section "15. No harness-specific mechanics in skill/agent prose"
# ─────────────────────────────────────────────

# devloop is harness-agnostic: skill and agent instructions describe
# behavior, not the keystrokes/slash-commands/brand of any one harness.
# Each pattern is anchored so it matches the mechanic, not an innocent
# word (e.g. "/rename" must not match "removed/renamed").
harness_patterns=(
    'Shift\+Tab'
    'Ctrl\+G'
    '/compact([^a-zA-Z]|$)'
    '/rename([^a-zA-Z]|$)'
    '[-]-resume'
    'Claude Code'
    'Plan Mode'
    'Normal Mode'
)

harness_leak=false
for file in "${core_files[@]}"; do
    for pat in "${harness_patterns[@]}"; do
        if grep -qE "$pat" "$file" 2>/dev/null; then
            fail "$file contains harness-specific mechanic matching /$pat/"
            harness_leak=true
        fi
    done
done
if ! $harness_leak; then
    pass "No harness-specific mechanics in skill/agent prose"
fi

# ─────────────────────────────────────────────
section "16. No em or en dashes in published files"
# ─────────────────────────────────────────────

# The repo uses standard punctuation, not em (U+2014) or en (U+2013) dashes.
# Scan every published markdown file (core skill/agent prose plus the
# top-level docs). docs/ is not part of the release, so it is out of scope.
# (Arrows U+2192 are used deliberately and are not flagged.)
em_dash_files=("${core_files[@]}" "README.md" "CHANGELOG.md" "PRIVACY.md" "AGENTS.md" ".devloop/config.md" ".devloop/domain.md" examples/*/config.md examples/*/domain.md)

em_dash_found=false
for file in "${em_dash_files[@]}"; do
    [[ -f "$file" ]] || continue
    if grep -qP "\x{2014}|\x{2013}" "$file" 2>/dev/null; then
        fail "$file contains an em or en dash (use standard punctuation)"
        em_dash_found=true
    fi
done
if ! $em_dash_found; then
    pass "No em or en dashes in published files"
fi

# ─────────────────────────────────────────────
section "17. Config discovery points at .devloop/"
# ─────────────────────────────────────────────

# The plugin-install-safe convention: skills and agents read project
# config from a .devloop/ directory in the project root, not from a
# copied-in template in the read-only plugin cache. Guard against
# reintroducing the cache pointer, and require each skill to name the
# .devloop/ home.
pointer_found=false
for file in "${core_files[@]}"; do
    if grep -q "plugin's skill directory" "$file" 2>/dev/null; then
        fail "$file points config discovery at the plugin's skill directory (use .devloop/)"
        pointer_found=true
    fi
done
if ! $pointer_found; then
    pass "No plugin-cache config pointer in core files"
fi

for skill_file in "$spec_skill" "$plan_skill" "$implement_skill"; do
    label="$(basename "$(dirname "$skill_file")")"
    if grep -q "\.devloop/" "$skill_file"; then
        pass "$label SKILL.md references .devloop/"
    else
        fail "$label SKILL.md does not reference the .devloop/ config home"
    fi
done

# The review agents discover project config too; each must name the
# .devloop/ home so a future edit can't silently revert one to the
# plugin-cache model.
for agent in agents/review-plan.md agents/review-impl.md; do
    basename="$(basename "$agent")"
    if grep -q "\.devloop/" "$agent"; then
        pass "$basename references .devloop/"
    else
        fail "$basename does not reference the .devloop/ config home"
    fi
done

# ─────────────────────────────────────────────
section "18. Phase 3 code review spawn is size-adaptive"
# ─────────────────────────────────────────────

# /implement Phase 3 runs one review-impl with lenses: all on a small diff
# and one review-impl per lens in parallel on a large diff. Guard both paths
# so an edit can't silently fall back to a single lens or a fixed spawn.
for token in "review-impl agent with lenses: all to review implementation" "review-impl agent with lenses: conformance to review implementation" "review-impl agent with lenses: correctness to review implementation" "review-impl agent with lenses: cleanup to review implementation"; do
    if grep -qF "$token" "$implement_skill"; then
        pass "implement SKILL.md Phase 3 names the spawn: \"$token\""
    else
        fail "implement SKILL.md Phase 3 is missing the spawn \"$token\" (small -> lenses: all; large -> one agent per lens)"
    fi
done

# ─────────────────────────────────────────────
section "19. devloop dogfoods its own config convention"
# ─────────────────────────────────────────────

# The README instructs users to commit .devloop/config.md and domain.md, and
# this repo runs its own loop on itself, so those files must exist here and
# carry the same schema the examples do. Without them review-impl's conventions
# angle has nothing to read when it reviews a devloop diff, which is how the
# gap was found in the first place.
for own_cfg in ".devloop/config.md" ".devloop/domain.md"; do
    if [[ -f "$own_cfg" ]]; then
        pass "$own_cfg exists (repo dogfoods the convention it ships)"
    else
        fail "$own_cfg is missing; the README tells users to commit it, so this repo must too"
    fi
done

# Reuse section 9's heading lists rather than restating them, the same
# single-canonical-source rule this repo asks of its own docs.
if [[ -f ".devloop/config.md" ]]; then
    for section_name in "${implement_sections[@]}"; do
        if grep -q "$section_name" ".devloop/config.md"; then
            pass ".devloop/config.md has \"$section_name\""
        else
            fail ".devloop/config.md missing \"$section_name\""
        fi
    done
fi

if [[ -f ".devloop/domain.md" ]]; then
    for section_name in "${spec_sections[@]}"; do
        if grep -q "$section_name" ".devloop/domain.md"; then
            pass ".devloop/domain.md has \"$section_name\""
        else
            fail ".devloop/domain.md missing \"$section_name\""
        fi
    done
fi

# The root project-rules file is what review-impl's conventions angle reads
# first, and it is the harness-native one (both Claude Code and Codex pick it
# up). It must point at config.md so the rules keep one canonical home.
if [[ -f "AGENTS.md" ]]; then
    pass "AGENTS.md exists (harness-native project rules)"
    if grep -q "\.devloop/config\.md" "AGENTS.md"; then
        pass "AGENTS.md points at .devloop/config.md (rules have one home)"
    else
        fail "AGENTS.md must point at .devloop/config.md so the rules are not duplicated"
    fi
else
    fail "AGENTS.md is missing; review-impl's conventions angle reads it first"
fi

# The committed config is only reachable if .gitignore un-ignores it.
if grep -q '^!\.devloop/config\.md' .gitignore && grep -q '^!\.devloop/domain\.md' .gitignore; then
    pass ".gitignore un-ignores .devloop/config.md and domain.md"
else
    fail ".gitignore must un-ignore .devloop/config.md and .devloop/domain.md (trackers stay ignored)"
fi

# ─────────────────────────────────────────────
section "20. review-impl angle counts stay in sync across docs"
# ─────────────────────────────────────────────

# agents/review-impl.md is the source of truth: correctness angles are
# lettered headers (Angle A..E), cleanup angles are five named headers. Every
# doc that states a count must match it, or an angle edit silently leaves the
# docs claiming the wrong number. The counts are derived from review-impl.md
# so the doc checks self-update; the 5+5 pin below is the tripwire a
# deliberate angle change trips.
ri="agents/review-impl.md"
c_angles=$(grep -cE '^\*\*Angle [A-Z]:' "$ri")
k_angles=$(grep -cE '^\*\*(Reuse|Simplification|Efficiency|Altitude|Maintainability)\.' "$ri")
words=("" "one" "two" "three" "four" "five" "six" "seven" "eight" "nine")
c_word="${words[$c_angles]:-$c_angles}"

if [[ "$c_angles" -eq 5 && "$k_angles" -eq 5 ]]; then
    pass "review-impl.md defines 5 correctness + 5 cleanup angles"
else
    fail "review-impl.md now has $c_angles correctness + $k_angles cleanup angles (was 5 + 5); if intended, update this pin AND every doc count (README, skills/implement/SKILL.md, and the website's llms.txt)"
fi

if grep -qE "\*\*Correctness\*\* \($c_angles angles\)" README.md; then
    pass "README states Correctness ($c_angles angles)"
else
    fail "README must say \"**Correctness** ($c_angles angles)\" to match review-impl.md"
fi

if grep -qE "\*\*Cleanup\*\* \($k_angles angles\)" README.md; then
    pass "README states Cleanup ($k_angles angles)"
else
    fail "README must say \"**Cleanup** ($k_angles angles)\" to match review-impl.md"
fi

if grep -qE "correctness \($c_angles angles\)" skills/implement/SKILL.md; then
    pass "implement SKILL.md states correctness ($c_angles angles)"
else
    fail "skills/implement/SKILL.md must say \"correctness ($c_angles angles)\" to match review-impl.md"
fi

# ─────────────────────────────────────────────
section "21. Agent Plugins root manifest conformance and cross-manifest consistency"
# ─────────────────────────────────────────────

# devloop ships three manifests: .claude-plugin/plugin.json (Claude Code),
# .codex-plugin/plugin.json (Codex), and a root plugin.json in the vendor-
# neutral Agent Plugins format (agent-plugins.org 1.0.0). Three manifests
# means three version + description surfaces,
# the exact drift .devloop/config.md warns about, so this section validates
# the root manifest against the spec's fatal rules AND pins version and
# description identical across all three.

if [[ -f plugin.json ]] && python3 -m json.tool plugin.json > /dev/null 2>&1; then
    pass "root plugin.json is valid JSON"
else
    fail "root plugin.json is missing or invalid JSON"
fi

# Agent Plugins 1.0.0 fatal rules: required [$schema, name], $schema is the
# canonical const, name matches the spec pattern, top level is a closed field
# set, and author (if present) carries only name/email/url.
if python3 - <<'PY' 2>/dev/null
import json, re, sys
d = json.load(open("plugin.json"))
allowed = {"$schema","name","version","description","author","homepage",
           "repository","license","keywords","extensions"}
const = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
name = d.get("name", "")
ok = (
    d.get("$schema") == const
    and "name" in d
    and not (set(d) - allowed)
    and 1 <= len(name) <= 64
    and re.match(r"^(?!.*(?:--|\.\.))[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$", name)
    and (not isinstance(d.get("author"), dict)
         or not (set(d["author"]) - {"name","email","url"}))
)
sys.exit(0 if ok else 1)
PY
then
    pass "root plugin.json conforms to Agent Plugins 1.0.0 (schema const, name pattern, closed fields)"
else
    fail "root plugin.json violates Agent Plugins 1.0.0 (check \$schema const, name pattern, no unknown top-level fields, author fields)"
fi

# Version identical across all three manifests.
if python3 -c "import json; v={json.load(open(p)).get('version') for p in ['plugin.json','.claude-plugin/plugin.json','.codex-plugin/plugin.json']}; import sys; sys.exit(0 if len(v)==1 and None not in v else 1)" 2>/dev/null; then
    pass "version matches across all three manifests"
else
    fail "version must be identical in plugin.json, .claude-plugin/plugin.json, and .codex-plugin/plugin.json"
fi

# Description identical across all three manifests (the canonical blurb).
if python3 -c "import json; s={json.load(open(p)).get('description') for p in ['plugin.json','.claude-plugin/plugin.json','.codex-plugin/plugin.json']}; import sys; sys.exit(0 if len(s)==1 and None not in s else 1)" 2>/dev/null; then
    pass "description matches across all three manifests"
else
    fail "description must be verbatim identical across all three manifests (single canonical blurb)"
fi

# ─────────────────────────────────────────────
section "22. /spec check mode is documented"
# ─────────────────────────────────────────────

# /spec has two modes: the interview (the default) and check mode, which
# validates an existing design doc instead of writing a new spec. Check mode
# hands the design doc itself to /plan as spec_doc, so both halves are pinned.
if grep -q "Check mode" "$spec_skill"; then
    pass "spec SKILL.md documents check mode"
else
    fail "spec SKILL.md must document check mode (validating an existing design doc)"
fi
if has_text "$spec_skill" "design doc's path as its \`spec_doc\`"; then
    pass "spec SKILL.md check mode hands the design doc to /plan as spec_doc"
else
    fail "spec SKILL.md check mode must name the design doc as the spec_doc /plan records"
fi

# ─────────────────────────────────────────────
section "23. /plan reviews before its checkpoint and carries the v4 rules"
# ─────────────────────────────────────────────

# The gate runs before the plan is shown, so the user approves a reviewed
# plan; an edit at the checkpoint re-runs the gate. Each marker below pins
# one rule of that flow so a rewrite can't drop it silently.
if grep -qE '^## Phase 4: Plan review' "$plan_skill" && grep -qE '^## Phase 5: Checkpoint' "$plan_skill"; then
    pass "plan SKILL.md runs the review gate (Phase 4) before the checkpoint (Phase 5)"
else
    fail "plan SKILL.md must have '## Phase 4: Plan review...' followed by '## Phase 5: Checkpoint...'"
fi
plan_markers=(
    "Any tracker edit at the checkpoint"
    "Self-check before the gate"
    "| Fast lane"
    "\`proof\`"
    "Autonomy"
    "design doc"
)
for marker in "${plan_markers[@]}"; do
    if has_text "$plan_skill" "$marker"; then
        pass "plan SKILL.md names: $marker"
    else
        fail "plan SKILL.md is missing: $marker"
    fi
done
if grep -qF "\`proof\`" skills/plan/references/tracker-schema.md; then
    pass "tracker-schema.md documents the proof field"
else
    fail "tracker-schema.md must document the \`proof\` field"
fi
if has_text agents/review-plan.md "previous report" && has_text agents/review-plan.md "design doc's recorded decisions"; then
    pass "review-plan.md takes the previous report and binds design-doc decisions"
else
    fail "review-plan.md must accept a previous report and bind a design doc's recorded decisions"
fi
if grep -q "## Autonomy" README.md && grep -q "review-and-finish.md" README.md; then
    pass "README documents the Autonomy section and links its rules"
else
    fail "README must describe the optional ## Autonomy section and link review-and-finish.md"
fi
raf="skills/implement/references/review-and-finish.md"
for marker in "Review rounds" "the first one included" "default 3" "default none" "a check or test that still fails after a fix attempt" "falls back to 3"; do
    if has_text "$raf" "$marker"; then
        pass "review-and-finish.md states: $marker"
    else
        fail "review-and-finish.md must state the Autonomy rule: $marker"
    fi
done

# ─────────────────────────────────────────────
section "24. /implement review, checkpoint 2, finish and close are documented"
# ─────────────────────────────────────────────

# review-and-finish.md is the one home for what happens around the code
# review; implement SKILL.md links it. Each marker pins one rule.
for marker in "lenses: all" "## Review protocol" "At a convergence checkpoint, write" "with no rounds left, don't revise for a warning" "or whose reported lines a fix touched" "<feature>-code-review.md" "no plan or spec change is waiting" "no_change_needed" "The count lives in the session" "## Edits at a checkpoint" "doesn't use up Review rounds" "before editing the tracker" "goes through Converge" "ran after the last code change" "Starting a named command" "stops the run: report it as" "is skipped with a note" "## Fast lane" "## Pre-review checks" "## Finding policy" "## Diff size" "## Checkpoint 2" "## Finish steps and close" "again with the previous report" "any FAIL gives FAIL" "No edits while reviewers run" "quality_verification.final" "done-trackers" "state the request and the proof test"; do
    if has_text "$raf" "$marker"; then
        pass "review-and-finish.md has: $marker"
    else
        fail "review-and-finish.md is missing: $marker"
    fi
done
require_markers "$raf" "A spec change always goes to the user" "falls back to" "without \`auto\` or \`ask\` falls back" "is a spec change and goes to the user" "a passing re-gate under" "its open warnings and set-aside findings"
require_markers "$implement_skill" "automatic convergences per session" "A verdict from a self-check" "Checkpoint 2 lists every convergence that ran" "doesn't count toward the limit" "while any spec change waits"
if has_text "$implement_skill" "With \`Convergence: auto\` (the" && has_text "$raf" "**Convergence**: \`auto\` (default)"; then
    pass "convergence is set by the Convergence setting (auto by default)"
else
    fail "implement SKILL.md and review-and-finish.md must describe the Convergence setting (auto by default, ask)"
fi
if has_text "$raf" "At checkpoint 1 or a convergence checkpoint"; then
    fail "review-and-finish.md must not give checkpoint 1 and a convergence checkpoint one rule: a convergence edit keeps plan_review at FAIL until the user approves"
else
    pass "review-and-finish.md keeps the convergence-checkpoint edit rule apart from checkpoint 1"
fi
if grep -q "review-and-finish.md" "$implement_skill"; then
    pass "implement SKILL.md links review-and-finish.md"
else
    fail "implement SKILL.md must link references/review-and-finish.md"
fi
if has_text "$implement_skill" "diff-size rule"; then
    pass "implement SKILL.md sizes the code review by review-and-finish.md's diff-size rule"
else
    fail "implement SKILL.md must size the code review by review-and-finish.md's diff-size rule"
fi
if has_text agents/review-impl.md "review is expected and is not a finding"; then
    pass "review-impl.md says an empty quality_verification during the gate is not a finding"
else
    fail "review-impl.md must say an empty quality_verification during the gate is not a finding (it is written after the gate)"
fi
for ex in README.md .devloop/config.md examples/*/config.md; do
    if grep -q "Pre-review checks" "$ex" && grep -q "done-trackers" "$ex"; then
        pass "$ex shows the pre-review checks and done-trackers forms"
    else
        fail "$ex must show the 'Pre-review checks' list and the 'done-trackers' setting"
    fi
done

# ─────────────────────────────────────────────
section "25. Runtime verification is optional, recorded and shown at checkpoint 2"
# ─────────────────────────────────────────────

require_markers "$raf" "## Runtime verification" "Verify recipe" "Test-only and docs-only diffs" \
    "the runtime verification verdict" "not an approval" "including a fix for a FAIL" \
    "latest verification run came after the last code change" "Save the record with the code report"
if grep -q "Verify recipe" README.md; then
    pass "README.md names the Verify recipe setting"
else
    fail "README.md must name the 'Verify recipe' setting"
fi
# The recipe is read from Build & Test Commands, so a config that puts it
# elsewhere teaches a placement the rule doesn't look at.
for ex in .devloop/config.md examples/*/config.md; do
    if awk '/^## /{inb=($0 ~ /^## Build & Test Commands/)} inb && /\*\*Verify recipe\*\*/{f=1} END{exit !f}' "$ex"; then
        pass "$ex puts the Verify recipe under Build & Test Commands"
    else
        fail "$ex must put the 'Verify recipe' list under Build & Test Commands"
    fi
done

# ─────────────────────────────────────────────
section "26. review-impl reports findings as a flat JSON list"
# ─────────────────────────────────────────────

# The findings list is a per-run contract the skills join and attach
# outcomes to: the keys are pinned here and the example must parse.
if [[ $(grep -c '^```json$' agents/review-impl.md) -ge 1 ]]; then
    pass "review-impl.md has a JSON findings example"
    validate_json_blocks "agents/review-impl.md"
else
    fail "review-impl.md must show its findings as a fenced JSON block"
fi
for key in file line lens category confidence introduced prior summary failure_scenario fix also_at verdict scope_notes findings; do
    if grep -q "\"$key\"" agents/review-impl.md; then
        pass "review-impl.md JSON has key: $key"
    else
        fail "review-impl.md JSON is missing key: $key"
    fi
done
require_markers "$raf" '`outcome`' "A lens not re-run counts with its last verdict" "overlap through" \
    "**Conventions**" "stays in the session and is shown at checkpoint 2"
require_markers agents/review-impl.md "Different mistakes stay separate" "of the lenses you ran"
require_markers "$plan_skill" "**Fast-lane check.**" "no tracker exists for this feature" "write no tracker" "did not come back from the fast lane"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
printf "\n\033[1m━━━ Results ━━━\033[0m\n"
printf "  \033[32m%d passed\033[0m\n" "$PASS"

if [[ "$FAIL" -gt 0 ]]; then
    printf "  \033[31m%d failed\033[0m\n" "$FAIL"
    printf "\n\033[31mFailures:\033[0m\n"
    for err in "${ERRORS[@]}"; do
        printf "  - %s\n" "$err"
    done
    exit 1
else
    printf "  \033[32m0 failed\033[0m\n"
    printf "\n\033[32mAll checks passed.\033[0m\n"
    exit 0
fi
