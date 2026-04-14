# Rofi Screen Time Redesign Spec
**Document type:** Implementation spec for coding sub-agent  
**Target platform:** `rofi` application  
**Primary goal:** enable a coding sub-agent to implement the redesign with minimal follow-up questions

---

## 1. Purpose

This spec defines the **Category Map**, **KPI formulas**, **insight logic**, and **backlog tasks** for the current rofi-based screen time tracker.

This is **not** a generic BI document. It is an implementation-oriented spec tied to the current system constraints:

- app runs inside **rofi**
- current tracker already records:
  - `total_seconds`
  - `session_count`
  - `switch_count`
  - `slots_30m[48]`
  - per-app stats by `WM_CLASS`
  - 7-day averages / streak / vs-yesterday deltas
  - manual `study` object / study mode
- current tracker does **not** yet record:
  - category classification
  - window title / browser domain context
  - persisted session objects with exact start/end lists
  - keyboard/mouse idle within a still-open active window

This spec is designed so the coding sub-agent can start implementation without re-asking the product goal.

---

## 2. Product framing

The product should be treated as:

> **A compact rofi-based personal behavior analytics tool for focused computer use**

This means the redesign should optimize for these user questions:

1. Where did my time go?
2. Was my usage focused or fragmented?
3. Did study mode create more intentional usage?
4. What time windows are strongest / weakest?
5. How does today compare to my personal baseline?
6. What simple action should I take next?

This is **not** trying to become a full exploratory BI dashboard.
It is an **executive summary + insight console** inside rofi.

---

## 3. Non-goals

Do **not** optimize this phase for:

- full chart-heavy analytics
- machine learning predictions
- multi-device sync
- browser tab/domain intelligence without title tracking
- perfect focus classification
- deep session-chain modeling
- exact recovery-latency metrics

These are out of scope for this phase.

---

## 4. Current data model assumptions

This implementation spec assumes the current tracker has access to or can already derive the following per day:

## 4.1 Core day-level fields
- `total_seconds`
- `session_count`
- `switch_count`
- `slots_30m` length = 48
- per-app usage keyed by `WM_CLASS`
- optional `study.seconds`
- historical 7-day stats / streak / vs-yesterday

## 4.2 Per-app stats
At minimum, each app record should already contain or be extended to contain:
- `seconds`
- `slots_30m[48]` or equivalent partial slot usage
- maybe sample counts if already available

## 4.3 Historical availability
At least last 7 days should be queryable to compute:
- 7-day average
- personal baseline
- trend deltas
- best day / streak if already implemented

## 4.4 Day boundary definition
- A "day" is bounded by `00:00–23:59` local time.
- Sessions that straddle midnight are split at `00:00`: seconds before midnight are attributed to the previous day, seconds after midnight to the new day.
- This rule must be applied consistently in both the tracker and the stats layer to prevent drift in daily totals.

---

## 5. Redesign architecture

Implementation should be split into four layers:

1. **Category layer**
2. **Metric layer**
3. **Score layer**
4. **Insight layer**

The order matters.

### Required implementation order
1. Category map
2. Raw KPI calculations
3. Score calculations
4. Insight generation
5. Rofi presentation wiring

Do not start from UI wording first.

---

## 6. Category Map Spec

## 6.1 Objective

Map `WM_CLASS` values into semantic categories so the app can move from raw app-time to behavior-oriented insights.

This is the highest-ROI feature for the redesign.

## 6.2 Category taxonomy v1

Use exactly these categories in v1:

- `Work`
- `Study`
- `Communication`
- `Browser`
- `Entertainment`
- `Media`
- `System`
- `Unknown`

### Rationale
- `Work`: coding, terminals, IDEs, admin/dev tools
- `Study`: notes, PDF readers, flashcards, knowledge tools
- `Communication`: chat/email/team communication
- `Browser`: browser is neutral until title/domain exists
- `Entertainment`: games or obviously leisure-first apps
- `Media`: music/video consumption apps
- `System`: file manager, launcher, settings, system utilities
- `Unknown`: unmapped or uncertain cases

## 6.3 Hard rule: Browser remains neutral
Until window title/domain tracking exists, browsers must default to:
- `Browser`

Do **not** auto-map `firefox` or `chromium` to `Work` or `Entertainment`.

This is a core trust rule.

## 6.4 Hard rule: Unknown is valid
Do not force a fallback category other than `Unknown`.

If an app is unmapped, keep it visible as unknown. This preserves data-quality transparency.

## 6.5 Configuration format

Create a user-editable JSON file, for example:

- `~/.config/rofi-screen-time/category-map.json`

### Example schema
```json
{
  "$schema_version": 1,
  "categories": {
    "nvim": "Work",
    "code": "Work",
    "zed": "Work",
    "kitty": "Work",
    "wezterm": "Work",
    "alacritty": "Work",
    "tmux": "Work",
    "obsidian": "Study",
    "anki": "Study",
    "zathura": "Study",
    "okular": "Study",
    "telegram-desktop": "Communication",
    "discord": "Communication",
    "slack": "Communication",
    "thunderbird": "Communication",
    "firefox": "Browser",
    "chromium": "Browser",
    "google-chrome": "Browser",
    "spotify": "Media",
    "mpv": "Media",
    "vlc": "Media",
    "steam": "Entertainment",
    "lutris": "Entertainment",
    "heroic": "Entertainment",
    "thunar": "System",
    "nautilus": "System",
    "rofi": "System",
    "pavucontrol": "System",
    "nm-connection-editor": "System"
  }
}
```

## 6.6 Resolution rules

The resolver must apply these rules in order:

1. Read the `WM_CLASS`
2. Normalize casing if needed
3. Try exact match in category map
4. If no match:
   - return `Unknown`

No fuzzy mapping is required in v1.

## 6.7 Optional normalization rules
If needed, add a small normalization table before lookup:
- trim whitespace
- lowercase
- convert repeated aliases if known

Example:
- `Google-chrome` -> `google-chrome`
- `Code` -> `code`

This should be simple and explicit.

## 6.8 Derived category aggregates
Once mapping exists, the system must compute day-level aggregate seconds for:
- `category_seconds.Work`
- `category_seconds.Study`
- `category_seconds.Communication`
- `category_seconds.Browser`
- `category_seconds.Entertainment`
- `category_seconds.Media`
- `category_seconds.System`
- `category_seconds.Unknown`

The sum of all category seconds should equal total tracked seconds, unless there are known excluded records.

## 6.9 Data quality metrics from category map
The system must also compute:
- `known_category_ratio = 1 - (Unknown / safe_total_seconds)`
- `browser_ambiguity_ratio = Browser / total_seconds`

These are required because they represent semantic confidence limits.

---

## 7. KPI Spec

This section defines the core metrics that must be implemented.

All formulas here are for **v1**, tied to current data constraints.

---

## 7.1 Supporting helper values

These helper values should be implemented first.

### 7.1.1 Active hours
```text
active_hours = total_seconds / 3600
```

If `total_seconds == 0`, active hours = 0.

### 7.1.2 Safe divisor helper
Any division by time should use a safe divisor:
```text
safe_active_hours = max(active_hours, 1e-6)
safe_total_seconds = max(total_seconds, 1)
```

### 7.1.3 Active slot count
Count how many 30-minute slots have usage > 0:
```text
active_slot_count = count(slot > 0 for slot in slots_30m)
```

### 7.1.4 Peak slot index
```text
peak_slot_index = argmax(slots_30m)
```

### 7.1.5 Peak slot label
Convert slot index to time range:
- slot 0 = `00:00–00:30`
- slot 1 = `00:30–01:00`
- ...
- slot 47 = `23:30–24:00`

### 7.1.6 Category share
For every category:
```text
category_share_X = category_seconds_X / safe_total_seconds
```

---

## 7.2 Raw KPIs available now

These can be computed with current system data.

### 7.2.1 Total Active Time
```text
total_active_time = total_seconds
```

Display as formatted duration.

### 7.2.2 Session Density
```text
session_density = session_count / safe_active_hours
```

Interpretation:
- higher means usage is chopped into more sessions per active hour

### 7.2.3 Switch Rate
```text
switch_rate = switch_count / safe_active_hours
```

Interpretation:
- higher means more context switching

### 7.2.4 Avg Session Length Proxy
```text
avg_session_length_proxy_seconds = total_seconds / max(session_count, 1)
```

Important:
- label must explicitly include `Proxy`
- this is **not** median session length

### 7.2.5 Active Spread
```text
active_spread = active_slot_count
```

Interpretation:
- number of 30-min windows with any usage

### 7.2.6 Study Ratio
If study object exists:
```text
study_ratio = study_seconds / safe_total_seconds
```

Else:
```text
study_ratio = 0
```

### 7.2.7 Peak Usage Window
Use `peak_slot_index`, `peak_slot_label`, and `slots_30m[peak_slot_index]`.

---

## 7.3 KPIs enabled after category map

### 7.3.1 Category Breakdown
Compute formatted durations and shares for all 8 categories.

### 7.3.2 Productive Ratio v1
Use only `Work` + `Study` as productive.

```text
productive_ratio_v1 = (Work + Study) / safe_total_seconds
```

Do **not** include Browser in productive ratio at v1.

### 7.3.3 Communication Load
```text
communication_load = Communication / safe_total_seconds
```

### 7.3.4 Leisure Load
```text
leisure_load = (Entertainment + Media) / safe_total_seconds
```

### 7.3.5 Browser Ambiguity Ratio
```text
browser_ambiguity_ratio = Browser / safe_total_seconds
```

### 7.3.6 Known Category Ratio
```text
known_category_ratio = 1 - (Unknown / safe_total_seconds)
```

### 7.3.7 Work-Study Share
```text
work_study_share = (Work + Study) / safe_total_seconds
```

Same number as productive ratio v1 in this phase.

---

## 8. Score Formulas Spec

All scores must be implemented with:
- explicit inputs
- deterministic formulas
- bounded 0–100 output
- debug visibility for components

Avoid opaque formulas.

---

## 8.1 Normalization strategy

Scores need normalization. Use **baseline-relative normalization** where possible.

### 8.1.1 Preferred method
When a 7-day personal baseline exists for a metric:
```text
normalized_delta = current / max(baseline, epsilon)
```

Then clamp into an expected range before converting to 0–1.

### 8.1.2 Simpler v1 fallback
If baseline normalization is not yet implemented cleanly for a metric, use threshold-based normalization with clamp.

Example helper:
```text
norm_range(value, low, high):
    if value <= low: return 0
    if value >= high: return 1
    return (value - low) / (high - low)
```

The sub-agent may implement threshold-based v1 first, then baseline-relative v1.1 later.

### 8.1.3 Required behavior
Every score function must:
- clamp final value to `[0, 100]`
- return component breakdown for debugging

---

## 8.2 Fragmentation Score v1

#### 8.2.1 Objective
Measure how fragmented the day’s usage is.

#### 8.2.2 Required inputs
- `session_density`
- `switch_rate`
- `active_spread`
- optional `active_hours`

#### 8.2.3 Threshold normalization proposal
Use these initial thresholds:

### Session Density normalization
```text
session_density_norm = norm_range(session_density, 2, 20)
```

### Switch Rate normalization
```text
switch_rate_norm = norm_range(switch_rate, 4, 30)
```

### Active Spread Excess normalization
The idea is not to punish broad days automatically, but to capture days that are very scattered relative to active time.

Define:
```text
spread_ratio = active_slot_count / max(active_hours * 2, 1)
```

Reason:
- each hour has 2 half-hour slots
- ratio > 1 means usage is distributed across many slots relative to active time

Normalize:
```text
spread_norm = norm_range(spread_ratio, 0.6, 1.4)
```

#### 8.2.4 Formula
```text
fragmentation_score_0_1 =
    0.45 * session_density_norm +
    0.45 * switch_rate_norm +
    0.10 * spread_norm
```

```text
fragmentation_score = round(100 * fragmentation_score_0_1)
```

#### 8.2.5 Interpretation
- `0–39` = low fragmentation
- `40–69` = moderate fragmentation
- `70–100` = high fragmentation

#### 8.2.6 Important note
This score measures fragmentation, not moral failure.
High fragmentation may be expected in support/chat-heavy work.

---

## 8.3 Focus Score v1

#### 8.3.1 Objective
Estimate structured, intentional, focused usage using current data only.

#### 8.3.2 Required inputs
- `study_ratio`
- `work_study_share`
- `switch_rate`
- `fragmentation_score`

#### 8.3.3 Normalization helpers
```text
study_ratio_norm = clamp01(study_ratio)
work_study_norm = clamp01(work_study_share)
switch_penalty_norm = norm_range(switch_rate, 4, 30)
fragmentation_penalty_norm = fragmentation_score / 100
```

#### 8.3.4 Formula
```text
focus_score_0_1 =
    0.35 * study_ratio_norm +
    0.30 * work_study_norm +
    0.20 * (1 - switch_penalty_norm) +
    0.15 * (1 - fragmentation_penalty_norm)
```

```text
focus_score = round(100 * focus_score_0_1)
```

#### 8.3.5 Interpretation
- `0–39` = weak focus structure
- `40–69` = mixed focus day
- `70–100` = strong intentional/focused day

#### 8.3.6 Naming rule
If category layer is missing, do not expose this score yet.
If category layer exists but browser title context is missing, call this:
- `Focus Score`
not
- `Deep Work Score`

---

## 8.4 Intentional Usage Ratio v1

#### 8.4.1 Objective
Measure how much screen time was likely deliberate.

#### 8.4.2 Formula v1
Use only the strongest reliable current signal:
```text
intentional_usage_ratio_v1 = study_seconds / safe_total_seconds
```

#### 8.4.3 Optional formula v1.1
After category map exists, allow weighted productive inclusion:
```text
intentional_usage_ratio_v1_1 =
    (1.0 * study_seconds +
     0.6 * Work +
     0.4 * Study) / safe_total_seconds
```

> **⚠️ Double-counting risk:** `study_seconds` (from the study mode timer object) and `category_seconds.Study` (from the category map) may overlap if study mode sessions are also classified under the `Study` category. Before implementing v1.1, confirm whether these are orthogonal signals or the same underlying seconds. If they overlap, either remove the `0.4 * Study` term or replace `study_seconds` with a non-overlapping signal (e.g. `work_seconds`) to prevent the ratio exceeding 1.0.

However, to keep the metric honest, v1 should prefer the pure study-mode signal.

#### 8.4.4 Recommendation
Implement both:
- `intentional_usage_ratio_strict`
- `intentional_usage_ratio_extended`

But expose only one in main rofi summary initially.

---

## 8.5 Distraction Load v1

#### 8.5.1 Objective
Measure how much the day is dominated by likely distractive or interruptive usage.

#### 8.5.2 Inputs
- `communication_load`
- `leisure_load`
- `browser_ambiguity_ratio`
- `switch_rate`
- `session_density`

#### 8.5.3 Normalization
```text
comm_norm = clamp01(communication_load)
leisure_norm = clamp01(leisure_load)
browser_norm = clamp01(browser_ambiguity_ratio)
switch_norm = norm_range(switch_rate, 4, 30)
session_density_norm = norm_range(session_density, 2, 20)
```

#### 8.5.4 Formula
```text
distraction_load_0_1 =
    0.30 * comm_norm +
    0.25 * leisure_norm +
    0.20 * browser_norm +
    0.15 * switch_norm +
    0.10 * session_density_norm
```

```text
distraction_load = round(100 * distraction_load_0_1)
```

#### 8.5.5 Interpretation
- `0–39` = low distractive load
- `40–69` = mixed
- `70–100` = high distraction pressure

#### 8.5.6 Important note
Browser is included as ambiguity pressure, not confirmed distraction.
This is intentional.

---

## 8.6 Daily Consistency Score v1

#### 8.6.1 Objective
Give a rough sense of whether today aligns with normal usage structure.

#### 8.6.2 Inputs
Prefer:
- deviation from 7-day avg total time
- deviation from 7-day avg active slot count
- deviation from 7-day avg study ratio or work-study share

#### 8.6.3 Formula proposal
If the system already has 7-day baselines:
```text
time_dev = abs(today_total_seconds - avg7_total_seconds) / max(avg7_total_seconds, 1)
spread_dev = abs(today_active_slot_count - avg7_active_slot_count) / max(avg7_active_slot_count, 1)
study_dev = abs(today_study_ratio - avg7_study_ratio)
```

Normalize deviations:
```text
time_dev_norm = norm_range(time_dev, 0.0, 1.0)
spread_dev_norm = norm_range(spread_dev, 0.0, 1.0)
study_dev_norm = norm_range(study_dev, 0.0, 1.0)
```

Consistency is inverse deviation:
```text
daily_consistency_score_0_1 =
    1 - (
        0.45 * time_dev_norm +
        0.30 * spread_dev_norm +
        0.25 * study_dev_norm
    )
```

```text
daily_consistency_score = round(100 * clamp01(daily_consistency_score_0_1))
```

#### 8.6.4 Interpretation
- higher means closer to normal pattern
- lower means more irregular day

This is secondary; do not prioritize above fragmentation or focus.

---

# 9. Trend and baseline metrics

The app already has some history. The redesign should standardize how deltas are reported.

## 9.1 Required trend values
For each of these, compute:
- today value
- yesterday value if available
- 7-day average if available
- delta vs yesterday
- delta vs 7-day average

### Required metrics
- total_seconds
- study_ratio
- session_density
- switch_rate
- fragmentation_score
- focus_score
- productive_ratio_v1
- browser_ambiguity_ratio

## 9.2 Delta formatting
Use:
- absolute change for durations
- percentage point or % change for ratios/scores
- point change (`pts`) for integer scores (0–100 range)

Example:
- `+42m vs yesterday`
- `-12% vs 7-day avg`
- `+5 pts vs yesterday` (for Focus Score, Fragmentation Score, etc.)

---

# 10. Insight generation spec

The app should generate short text insights, not only numbers.

Rofi is best used for:
- summary
- exception
- recommendation

Not long paragraphs.

## 10.1 Insight output classes
The engine must generate up to 4 types:

1. `composition`
2. `quality`
3. `temporal`
4. `recommendation`

At least one insight should be produced if enough data exists.

### 10.1.1 Insight priority and deduplication rules

When multiple insights are candidates, apply these rules:

**Class priority order (highest to lowest):**
```
quality > composition > temporal > recommendation
```

**Deduplication:**
- Return at most **1 insight per class**.
- If multiple rules within the same class fire, prefer the one with the strongest signal (highest ratio or score deviation).

**Contradiction handling:**
- If conflicting signals exist (e.g. Focus Score ≥ 70 AND Fragmentation Score ≥ 70 simultaneously), prefer lower-confidence wording, e.g.:
  - `"Focus structure detected despite high switching activity."`
  - Do not emit both "strong focus" and "high fragmentation" as separate insights uncritically.

**Maximum insights on main screen:** 1 (the top-priority fired insight).
**Maximum insights in Recommendations drill-down:** all recommendation-class insights that fired.

## 10.2 Composition insight rules
Examples:
- If Browser share > 0.40:
  - `"Browser dominates today; semantic certainty is limited."`
- If Unknown share > 0.20:
  - `"A large share is unmapped; category confidence is low."`
- If Work+Study > 0.60:
  - `"Most tracked time was work/study-oriented."`
- If Communication load > 0.25:
  - `"Communication consumed a large share of active time."`

## 10.3 Quality insight rules
Examples:
- If Fragmentation Score >= 70:
  - `"Usage is highly fragmented today."`
- If Focus Score >= 70:
  - `"Today shows strong intentional focus structure."`
- If switch_rate > 1.2 * avg7_switch_rate:
  - `"Switching is significantly above your 7-day baseline."`
- If avg session proxy is low:
  - `"Active time is split into short sessions."`

## 10.4 Temporal insight rules
Examples:
- `"Peak window: 09:00–09:30."`
- If active_spread very high:
  - `"Usage is spread across many time windows."`
- If study time concentrated in one block:
  - `"Study activity is concentrated in a narrow window."`

## 10.5 Recommendation insight rules
Examples:
- If browser ambiguity high:
  - `"Consider adding title tracking to reduce browser ambiguity."`
- If communication load + switch rate high:
  - `"Batch messaging into fewer windows to reduce switching."`
- If study ratio is low but work/study share exists:
  - `"Use study mode during focus blocks to improve intentional tracking."`
- If Unknown share is high:
  - `"Update category-map.json to improve insight quality."`

---

# 11. Rofi presentation constraints

This is a rofi app. Keep that constraint central.

## 11.1 Main UX principle
Rofi should act as:
- **compact executive summary**
- **light drill-down navigator**
- **insight console**

It should **not** try to emulate a dense BI dashboard.

## 11.2 Main summary screen should show
Recommended top-level fields:

- Today Active
- Focus Score
- Fragmentation Score
- Study Ratio
- Top Category
- Peak Window
- Main Insight

## 11.3 Secondary screens
The app may offer drill-down entries such as:
- Overview
- Categories
- Focus & Fragmentation
- Time Windows
- 7-Day Trend
- Recommendations
- Data Quality

## 11.4 Data-quality screen
This should display:
- Browser ambiguity ratio
- Unknown category ratio
- whether title tracking exists
- whether focus score is partial/proxy

This is important for user trust.

---

# 12. Required naming conventions

Naming must be honest.

## 12.1 Must include “Proxy”
Use `Avg Session Length Proxy` if using `total_seconds / session_count`.

## 12.2 Avoid these names in v1
Do not use:
- Deep Work Score
- Productivity Score
- Recovery Score
- Attention Recovery
- Intent Inference
unless the data model is later upgraded

## 12.3 Allowed names in v1
- Focus Score
- Fragmentation Score
- Intentional Usage Ratio
- Distraction Load
- Productive Ratio v1
- Browser Ambiguity Ratio

---

# 13. Backlog implementation tasks

This section is formatted so a coding sub-agent can pick up tasks directly.

---

## Epic A — Category Layer

### Task A1 — Add category map config file loading
**Goal:** load user-editable `category-map.json`

**Requirements:**
- default path in config dir
- graceful handling if file missing
- return empty map if absent
- validate allowed category values only

**Acceptance criteria:**
- app can start without file
- invalid categories are warned and ignored
- exact `WM_CLASS -> category` lookup works

---

### Task A2 — Add WM_CLASS normalization helper
**Goal:** normalize app identifiers before category lookup

**Requirements:**
- lowercase
- trim whitespace
- optional alias rewrite map

**Acceptance criteria:**
- common casing differences resolve consistently

---

### Task A3 — Compute per-category aggregates
**Goal:** build day-level category seconds

**Requirements:**
- aggregate all mapped per-app seconds into 8 categories
- default unmapped apps to `Unknown`

**Acceptance criteria:**
- sum(category_seconds) equals total tracked seconds within acceptable rounding tolerance

---

### Task A4 — Expose category breakdown in stats layer
**Goal:** make category totals available to rofi UI and insight engine

**Requirements:**
- durations per category
- shares per category
- top category
- browser ambiguity ratio
- known category ratio

**Acceptance criteria:**
- stats command/json output includes all category fields

---

## Epic B — Raw KPI Layer

### Task B1 — Implement helper metric functions
**Goal:** centralize derived values

**Metrics:**
- active_hours
- session_density
- switch_rate
- avg_session_length_proxy_seconds
- active_slot_count
- peak_slot_index
- peak_slot_label

**Acceptance criteria:**
- functions return sane defaults for zero-data days
- peak slot label formatting is correct

---

### Task B2 — Implement category-enabled KPI calculations
**Goal:** compute v1 category KPIs

**Metrics:**
- productive_ratio_v1
- communication_load
- leisure_load
- browser_ambiguity_ratio
- work_study_share
- known_category_ratio

**Acceptance criteria:**
- ratios are clamped to `[0,1]`
- all values derive from category aggregates

---

### Task B3 — Add baseline comparison helpers
**Goal:** standardize comparisons versus yesterday and 7-day average

**Metrics:**
- delta absolute
- delta percent
- delta ratio for scores and rates

**Acceptance criteria:**
- no divide-by-zero issues
- output format is consistent across metrics

---

## Epic C — Score Layer

### Task C1 — Implement normalization utilities
**Goal:** provide reusable score normalization helpers

**Functions:**
- `clamp01(x)`
- `norm_range(value, low, high)`
- optional `norm_vs_baseline(value, baseline, low_mult, high_mult)`

**Acceptance criteria:**
- unit-testable pure functions
- score functions use shared helpers

---

### Task C2 — Implement Fragmentation Score v1
**Goal:** compute `fragmentation_score`

**Inputs:**
- session_density
- switch_rate
- active_spread ratio

**Formula:**
```text
0.45 * session_density_norm +
0.45 * switch_rate_norm +
0.10 * spread_norm
```

**Acceptance criteria:**
- score in `[0,100]`
- component values available for debug output
- label and interpretation strings defined

---

### Task C3 — Implement Focus Score v1
**Goal:** compute `focus_score`

**Inputs:**
- study_ratio
- work_study_share
- switch_rate
- fragmentation_score

**Formula:**
```text
0.35 * study_ratio_norm +
0.30 * work_study_norm +
0.20 * (1 - switch_penalty_norm) +
0.15 * (1 - fragmentation_penalty_norm)
```

**Acceptance criteria:**
- score in `[0,100]`
- disabled or hidden if category layer unavailable
- component values available for debug output

---

### Task C4 — Implement Intentional Usage Ratio v1
**Goal:** compute strict study-based intentional usage

**Formula:**
```text
study_seconds / total_seconds
```

**Acceptance criteria:**
- fallback to 0 if study data missing
- output available as ratio and formatted percent

---

### Task C5 — Implement Distraction Load v1
**Goal:** compute distraction pressure score

**Inputs:**
- communication_load
- leisure_load
- browser_ambiguity_ratio
- switch_rate
- session_density

**Acceptance criteria:**
- score in `[0,100]`
- components exposed for debug

---

### Task C6 — Optional: Implement Daily Consistency Score v1
**Goal:** compare today against 7-day pattern

**Acceptance criteria:**
- only if 7-day data exists
- hidden if not enough history

---

## Epic D — Insight Layer

### Task D1 — Build rules-based insight engine
**Goal:** generate structured short insights

**Output classes:**
- composition
- quality
- temporal
- recommendation

**Acceptance criteria:**
- supports multiple candidate insights
- can rank and return top insights
- deterministic rules only

---

### Task D2 — Add composition insight rules
**Examples to support:**
- browser dominates
- work/study dominates
- communication heavy
- unknown high

**Acceptance criteria:**
- rule threshold table lives in one place
- text templates are easy to edit

---

### Task D3 — Add quality insight rules
**Examples to support:**
- high fragmentation
- strong focus
- switching above baseline
- short-session structure

**Acceptance criteria:**
- uses score outputs and baseline metrics

---

### Task D4 — Add temporal insight rules
**Examples to support:**
- peak window
- broad spread day
- concentrated study block

**Acceptance criteria:**
- can generate at least one time-based insight from slots_30m

---

### Task D5 — Add recommendation rules
**Examples to support:**
- update category map
- add title tracking
- batch messaging
- use study mode more often

**Acceptance criteria:**
- At least 3 discrete recommendation rules are implemented, each with a distinct triggering condition.
- Each rule has a minimum threshold defined in a shared constants or config block (not hardcoded inline).
- No recommendation fires unconditionally — each requires at least one measured metric to exceed its threshold.
- Text templates are easy to locate and edit without changing rule logic.

---

## Epic E — Rofi Integration

### Task E1 — Redesign summary payload for rofi
**Goal:** expose only compact high-value metrics

**Required summary fields:**
- active time
- focus score
- fragmentation score
- study ratio
- top category
- peak window
- main insight

**Acceptance criteria:**
- summary remains compact enough for rofi
- no dense metric overload on main screen

---

### Task E2 — Add drill-down views
**Suggested views:**
- Overview
- Categories
- Focus & Fragmentation
- Time Windows
- Trend
- Recommendations
- Data Quality

**Acceptance criteria:**
- each view has a clear purpose
- no view tries to show all metrics at once

---

### Task E3 — Add Data Quality view
**Goal:** explain semantic limitations

**Display at minimum:**
- Browser ambiguity ratio
- Unknown share
- whether title tracking exists
- whether Focus Score is partial/proxy

**Acceptance criteria:**
- users can see why insight confidence is limited

---

## Epic F — Testing and validation

### Task F1 — Unit test metric helpers
**Goal:** verify helper math

**Coverage:**
- division safety
- slot label conversion
- ratio clamping
- normalization utilities

---

### Task F2 — Unit test score formulas
**Goal:** validate score behavior

**Cases:**
- zero-data day
- high-switch fragmented day
- high-study stable day
- browser-heavy ambiguous day

---

### Task F3 — Unit test category mapping
**Goal:** ensure exact mappings and unknown fallback behave correctly

---

### Task F4 — Snapshot test summary outputs
**Goal:** verify rofi summary lines remain stable and compact

**Snapshot format:** plaintext — each line of the rofi summary output is captured as a string and compared against a stored fixture file. Diffs must be human-readable.

**Acceptance criteria:**
- A fixture file of expected summary lines exists under a `tests/` or `fixtures/` directory.
- Tests fail if any summary line changes length beyond the rofi display budget or changes wording without a deliberate fixture update.

---

# 14. Suggested implementation sequencing

This is the recommended build order for the coding agent.

## Phase 1
- Task A1
- Task A2
- Task A3
- Task A4
- Task B1
- Task B2
- Task B3

> **Note:** Task B3 (baseline delta helpers) is included in Phase 1 because it is a dependency for the Daily Consistency Score (C6) and several insight rules in §10.3 that compare against the 7-day baseline.

## Phase 2
- Task C1
- Task C2
- Task C3
- Task C4
- Task C5

## Phase 3
- Task D1
- Task D2
- Task D3
- Task D4
- Task D5

## Phase 4
- Task E1
- Task E2
- Task E3

## Phase 5
- Task F1
- Task F2
- Task F3
- Task F4

This order minimizes rework.

---

# 15. Explicit assumptions and future corrections

This section is intentionally explicit so the coding agent does not over-implement.

## 15.1 Assumptions in this spec
- `session_count` already exists and is usable
- `switch_count` already exists and is usable
- `study_seconds` exists or can be zero
- 7-day averages already exist or can be derived from daily files

## 15.2 Known limitations that must not be hidden
- browser is semantically unresolved
- avg session length is only a proxy
- focus score is an estimate, not a deep-work truth signal
- no exact recovery or interruption chains yet

## 15.3 Future upgrade path, not for current backlog
Later schema upgrades may add:
- active window title
- browser domain parsing
- persisted session objects
- keyboard/mouse idle tracking
- title-aware productive browser split

Once that exists, this spec can be revised to:
- reclassify browser usage
- compute median session length
- build interruption/recovery metrics
- strengthen focus scoring

---

# 16. Minimal success criteria for this redesign

This redesign is successful if, after implementation, the rofi app can do all of the following:

1. show category-aware time breakdown
2. show focus and fragmentation as explicit scores
3. explain major ambiguity using browser/unknown metrics
4. compare today to personal baseline
5. produce at least one useful recommendation
6. remain compact and readable inside rofi

If it becomes visually dense or semantically overconfident, the redesign failed.

---

# 17. Final implementation instruction for sub-agent

When unsure between:
- adding more metrics
- or improving semantic trust

choose **semantic trust**.

When unsure between:
- a richer UI
- or a smaller clearer summary

choose **smaller clearer summary**.

When unsure between:
- inferred meaning
- or honest ambiguity

choose **honest ambiguity**.

That is the correct product direction for this rofi app.
