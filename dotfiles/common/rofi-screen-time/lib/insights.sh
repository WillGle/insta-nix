#!/usr/bin/env bash

build_insighted_context() {
  local scored_json="$1"

  printf '%s' "$scored_json" \
    | jq '
      def thresholds: {
        composition: {
          browser_dominates: 0.40,
          unknown_high: 0.20,
          work_study_dominates: 0.60,
          communication_heavy: 0.25,
          leisure_noticeable: 0.30
        },
        quality: {
          high_fragmentation: 70,
          strong_focus: 70,
          switch_above_baseline_mult: 1.2,
          short_session_proxy_seconds: 900
        },
        temporal: {
          broad_spread_slots: 10,
          concentrated_slots: 4
        },
        recommendation: {
          browser_ambiguity_high: 0.40,
          unknown_high: 0.20,
          communication_heavy: 0.25,
          switch_rate_high: 8,
          study_ratio_low: 0.15,
          work_study_share_present: 0.30
        }
      };
      def templates: {
        composition: {
          browser_dominates: "Browser dominates today; semantic certainty is limited.",
          unknown_high: "A large share is unmapped; category confidence is low.",
          work_study_dominates: "Most tracked time was work/study-oriented.",
          communication_heavy: "Communication consumed a large share of active time.",
          leisure_noticeable: "Leisure and media usage make up a noticeable share of today."
        },
        quality: {
          legacy: "Legacy tracking data limits advanced scoring today.",
          high_fragmentation: "Usage is highly fragmented today.",
          strong_focus: "Today shows strong intentional focus structure.",
          conflicted_focus: "Focus structure detected despite high switching activity.",
          switch_above_baseline: "Switching is significantly above your 7-day baseline.",
          short_sessions: "Active time is split into short sessions."
        },
        temporal: {
          peak_window: "Peak window: ",
          broad_spread: "Usage is spread across many time windows.",
          concentrated: "Activity is concentrated in a narrow window."
        },
        recommendation: {
          legacy: "Let the new tracker run long enough to create version 2 days before relying on advanced scores.",
          browser_ambiguity: "Consider adding title tracking to reduce browser ambiguity.",
          unknown_high: "Update category-map.json to improve insight quality.",
          communication_switch_pressure: "Batch messaging into fewer windows to reduce switching.",
          study_ratio_low: "Use study mode during focus blocks to improve intentional tracking."
        }
      };
      def ranked($items):
        ($items | sort_by(-.priority, .kind));
      def first_ranked($items):
        (ranked($items) | .[0] // null);
      def maybe($condition; $item):
        if $condition then [$item] else [] end;

      . as $root
      | .today as $today
      | .baseline as $baseline
      | thresholds as $t
      | templates as $msg
      | (
          maybe(($today.categories.browser_ambiguity_ratio > $t.composition.browser_dominates); {
            kind: "composition",
            priority: 90,
            text: $msg.composition.browser_dominates,
            metric: "browser_ambiguity_ratio"
          })
          + maybe(($today.categories.unknown_share > $t.composition.unknown_high); {
            kind: "composition",
            priority: 85,
            text: $msg.composition.unknown_high,
            metric: "unknown_share"
          })
          + maybe(($today.metrics.productive_ratio_v1 > $t.composition.work_study_dominates); {
            kind: "composition",
            priority: 70,
            text: $msg.composition.work_study_dominates,
            metric: "productive_ratio_v1"
          })
          + maybe(($today.metrics.communication_load > $t.composition.communication_heavy); {
            kind: "composition",
            priority: 65,
            text: $msg.composition.communication_heavy,
            metric: "communication_load"
          })
          + maybe(($today.metrics.leisure_load > $t.composition.leisure_noticeable); {
            kind: "composition",
            priority: 55,
            text: $msg.composition.leisure_noticeable,
            metric: "leisure_load"
          })
        ) as $composition_candidates
      | (
          maybe(($today.schema_ready | not); {
            kind: "quality",
            priority: 95,
            text: $msg.quality.legacy,
            metric: "schema_ready"
          })
          + maybe((($today.scores.focus_score.value // 0) >= $t.quality.strong_focus) and (($today.scores.fragmentation_score.value // 0) >= $t.quality.high_fragmentation); {
            kind: "quality",
            priority: 89,
            text: $msg.quality.conflicted_focus,
            metric: "focus_fragmentation_conflict"
          })
          + maybe((($today.scores.fragmentation_score.value // 0) >= $t.quality.high_fragmentation) and ((($today.scores.focus_score.value // 0) < $t.quality.strong_focus)); {
            kind: "quality",
            priority: 88,
            text: $msg.quality.high_fragmentation,
            metric: "fragmentation_score"
          })
          + maybe((($today.scores.focus_score.value // 0) >= $t.quality.strong_focus) and ((($today.scores.fragmentation_score.value // 0) < $t.quality.high_fragmentation)); {
            kind: "quality",
            priority: 80,
            text: $msg.quality.strong_focus,
            metric: "focus_score"
          })
          + maybe(($baseline.available and ($today.metrics.switch_rate != null) and ($baseline.averages.switch_rate != null) and ($baseline.averages.switch_rate > 0) and ($today.metrics.switch_rate > ($t.quality.switch_above_baseline_mult * $baseline.averages.switch_rate))); {
            kind: "quality",
            priority: 76,
            text: $msg.quality.switch_above_baseline,
            metric: "switch_rate"
          })
          + maybe(($today.metrics.avg_session_length_proxy_seconds != null) and ($today.metrics.avg_session_length_proxy_seconds < $t.quality.short_session_proxy_seconds); {
            kind: "quality",
            priority: 60,
            text: $msg.quality.short_sessions,
            metric: "avg_session_length_proxy_seconds"
          })
        ) as $quality_candidates
      | (
          maybe(($today.metrics.peak_slot_index >= 0); {
            kind: "temporal",
            priority: 72,
            text: ($msg.temporal.peak_window + $today.metrics.peak_slot_label + "."),
            metric: "peak_slot_label"
          })
          + maybe(($today.metrics.active_slot_count >= $t.temporal.broad_spread_slots); {
            kind: "temporal",
            priority: 68,
            text: $msg.temporal.broad_spread,
            metric: "active_slot_count"
          })
          + maybe(($today.metrics.active_slot_count > 0 and $today.metrics.active_slot_count <= $t.temporal.concentrated_slots); {
            kind: "temporal",
            priority: 52,
            text: $msg.temporal.concentrated,
            metric: "active_slot_count"
          })
        ) as $temporal_candidates
      | (
          maybe(($today.schema_ready | not); {
            kind: "recommendation",
            priority: 97,
            text: $msg.recommendation.legacy,
            metric: "schema_ready"
          })
          + maybe(($today.categories.browser_ambiguity_ratio > $t.recommendation.browser_ambiguity_high); {
            kind: "recommendation",
            priority: 90,
            text: $msg.recommendation.browser_ambiguity,
            metric: "browser_ambiguity_ratio"
          })
          + maybe(($today.categories.unknown_share > $t.recommendation.unknown_high); {
            kind: "recommendation",
            priority: 88,
            text: $msg.recommendation.unknown_high,
            metric: "unknown_share"
          })
          + maybe((($today.metrics.communication_load > $t.recommendation.communication_heavy) and (($today.metrics.switch_rate // 0) > $t.recommendation.switch_rate_high)); {
            kind: "recommendation",
            priority: 80,
            text: $msg.recommendation.communication_switch_pressure,
            metric: "communication_switch_pressure"
          })
          + maybe((($today.metrics.study_ratio < $t.recommendation.study_ratio_low) and ($today.metrics.work_study_share > $t.recommendation.work_study_share_present)); {
            kind: "recommendation",
            priority: 74,
            text: $msg.recommendation.study_ratio_low,
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
