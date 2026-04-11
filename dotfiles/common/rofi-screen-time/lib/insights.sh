#!/usr/bin/env bash

build_insighted_context() {
  local scored_json="$1"

  printf '%s' "$scored_json" \
    | jq '
      def ranked($items):
        ($items | sort_by(-.priority, .kind));
      def first_ranked($items):
        (ranked($items) | .[0] // null);
      def maybe($condition; $item):
        if $condition then [$item] else [] end;

      . as $root
      | .today as $today
      | .baseline as $baseline
      | (
          maybe(($today.categories.browser_ambiguity_ratio > 0.40); {
            kind: "composition",
            priority: 90,
            text: "Browser dominates today; semantic certainty is limited.",
            metric: "browser_ambiguity_ratio"
          })
          + maybe(($today.categories.unknown_share > 0.20); {
            kind: "composition",
            priority: 85,
            text: "A large share is unmapped; category confidence is low.",
            metric: "unknown_share"
          })
          + maybe(($today.metrics.productive_ratio_v1 > 0.60); {
            kind: "composition",
            priority: 70,
            text: "Most tracked time was work/study-oriented.",
            metric: "productive_ratio_v1"
          })
          + maybe(($today.metrics.communication_load > 0.25); {
            kind: "composition",
            priority: 65,
            text: "Communication consumed a large share of active time.",
            metric: "communication_load"
          })
          + maybe(($today.metrics.leisure_load > 0.30); {
            kind: "composition",
            priority: 55,
            text: "Leisure and media usage make up a noticeable share of today.",
            metric: "leisure_load"
          })
        ) as $composition_candidates
      | (
          maybe(($today.schema_ready | not); {
            kind: "quality",
            priority: 95,
            text: "Legacy tracking data limits advanced scoring today.",
            metric: "schema_ready"
          })
          + maybe(($today.scores.fragmentation_score.value // 0) >= 70; {
            kind: "quality",
            priority: 88,
            text: "Usage is highly fragmented today.",
            metric: "fragmentation_score"
          })
          + maybe(($today.scores.focus_score.value // 0) >= 70; {
            kind: "quality",
            priority: 80,
            text: "Today shows strong intentional focus structure.",
            metric: "focus_score"
          })
          + maybe(($baseline.available and ($today.metrics.switch_rate != null) and ($baseline.averages.switch_rate != null) and ($baseline.averages.switch_rate > 0) and ($today.metrics.switch_rate > (1.2 * $baseline.averages.switch_rate))); {
            kind: "quality",
            priority: 76,
            text: "Switching is significantly above your 7-day baseline.",
            metric: "switch_rate"
          })
          + maybe(($today.metrics.avg_session_length_proxy_seconds != null) and ($today.metrics.avg_session_length_proxy_seconds < 900); {
            kind: "quality",
            priority: 60,
            text: "Active time is split into short sessions.",
            metric: "avg_session_length_proxy_seconds"
          })
        ) as $quality_candidates
      | (
          maybe(($today.metrics.peak_slot_index >= 0); {
            kind: "temporal",
            priority: 72,
            text: ("Peak window: " + $today.metrics.peak_slot_label + "."),
            metric: "peak_slot_label"
          })
          + maybe(($today.metrics.active_slot_count >= 10); {
            kind: "temporal",
            priority: 68,
            text: "Usage is spread across many time windows.",
            metric: "active_slot_count"
          })
          + maybe(($today.metrics.active_slot_count > 0 and $today.metrics.active_slot_count <= 4); {
            kind: "temporal",
            priority: 52,
            text: "Activity is concentrated in a narrow window.",
            metric: "active_slot_count"
          })
        ) as $temporal_candidates
      | (
          maybe(($today.schema_ready | not); {
            kind: "recommendation",
            priority: 97,
            text: "Let the new tracker run long enough to create version 2 days before relying on advanced scores.",
            metric: "schema_ready"
          })
          + maybe(($today.categories.browser_ambiguity_ratio > 0.40); {
            kind: "recommendation",
            priority: 90,
            text: "Consider title tracking to reduce browser ambiguity.",
            metric: "browser_ambiguity_ratio"
          })
          + maybe(($today.categories.unknown_share > 0.20); {
            kind: "recommendation",
            priority: 88,
            text: "Update category-map.json to improve insight quality.",
            metric: "unknown_share"
          })
          + maybe((($today.metrics.communication_load > 0.25) and (($today.metrics.switch_rate // 0) > 8)); {
            kind: "recommendation",
            priority: 80,
            text: "Batch messaging into fewer windows to reduce switching.",
            metric: "communication_switch_pressure"
          })
          + maybe((($today.metrics.study_ratio < 0.15) and ($today.metrics.work_study_share > 0.30)); {
            kind: "recommendation",
            priority: 74,
            text: "Use study mode during focus blocks to improve intentional tracking.",
            metric: "study_ratio"
          })
        ) as $recommendation_candidates
      | .insights = {
          by_class: {
            composition: first_ranked($composition_candidates),
            quality: first_ranked($quality_candidates),
            temporal: first_ranked($temporal_candidates),
            recommendation: first_ranked($recommendation_candidates)
          },
          recommendation_candidates: ranked($recommendation_candidates),
          all: ranked([
            first_ranked($composition_candidates),
            first_ranked($quality_candidates),
            first_ranked($temporal_candidates),
            first_ranked($recommendation_candidates)
          ] | map(select(. != null))),
          main: first_ranked([
            first_ranked($composition_candidates),
            first_ranked($quality_candidates),
            first_ranked($temporal_candidates),
            first_ranked($recommendation_candidates)
          ] | map(select(. != null)))
        }
    '
}
