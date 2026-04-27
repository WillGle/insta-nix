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
          browser_dominates: "Spent most of the time in the browser.",
          unknown_high: "A lot of time wasnt tracked; info might be missing.",
          work_study_dominates: "You spent most of your time being productive.",
          communication_heavy: "Lots of time spent on chats and messages.",
          leisure_noticeable: "A good chunk of your time was for fun/media today."
        },
        quality: {
          legacy: "Not enough data for a full focus score yet.",
          high_fragmentation: "Youve been switching between apps a lot today.",
          strong_focus: "You had some great focus sessions today.",
          conflicted_focus: "Good focus, but with a lot of app switching in between.",
          switch_above_baseline: "Youre switching apps much more than you usually do.",
          short_sessions: "You are spending very little time in each app."
        },
        temporal: {
          peak_window: "Peak window: ",
          broad_spread: "Usage is spread across many time windows.",
          concentrated: "Activity is concentrated in a narrow window."
        },
        recommendation: {
          legacy: "Keep tracking to see more detailed trends later.",
          browser_ambiguity: "Try tracking browser tabs to see exactly what you’re doing.",
          unknown_high: "Help the tracker by mapping your untracked apps.",
          communication_switch_pressure: "Try batching your messages so you can focus longer.",
          study_ratio_low: "Turn on study mode during work to track better."
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
            kind: "Overview",
            priority: 90,
            text: $msg.composition.browser_dominates,
            metric: "browser_ambiguity_ratio"
          })
          + maybe(($today.categories.unknown_share > $t.composition.unknown_high); {
            kind: "Overview",
            priority: 85,
            text: $msg.composition.unknown_high,
            metric: "unknown_share"
          })
          + maybe(($today.metrics.productive_ratio_v1 > $t.composition.work_study_dominates); {
            kind: "Overview",
            priority: 70,
            text: $msg.composition.work_study_dominates,
            metric: "productive_ratio_v1"
          })
          + maybe(($today.metrics.communication_load > $t.composition.communication_heavy); {
            kind: "Overview",
            priority: 65,
            text: $msg.composition.communication_heavy,
            metric: "communication_load"
          })
          + maybe(($today.metrics.leisure_load > $t.composition.leisure_noticeable); {
            kind: "Overview",
            priority: 55,
            text: $msg.composition.leisure_noticeable,
            metric: "leisure_load"
          })
        ) as $composition_candidates
      | (
          maybe(($today.schema_ready | not); {
            kind: "Focus",
            priority: 95,
            text: $msg.quality.legacy,
            metric: "schema_ready"
          })
          + maybe((($today.scores.focus_score.value // 0) >= $t.quality.strong_focus) and (($today.scores.fragmentation_score.value // 0) >= $t.quality.high_fragmentation); {
            kind: "Focus",
            priority: 89,
            text: $msg.quality.conflicted_focus,
            metric: "focus_fragmentation_conflict"
          })
          + maybe((($today.scores.fragmentation_score.value // 0) >= $t.quality.high_fragmentation) and ((($today.scores.focus_score.value // 0) < $t.quality.strong_focus)); {
            kind: "Focus",
            priority: 88,
            text: $msg.quality.high_fragmentation,
            metric: "fragmentation_score"
          })
          + maybe((($today.scores.focus_score.value // 0) >= $t.quality.strong_focus) and ((($today.scores.fragmentation_score.value // 0) < $t.quality.high_fragmentation)); {
            kind: "Focus",
            priority: 80,
            text: $msg.quality.strong_focus,
            metric: "focus_score"
          })
          + maybe(($baseline.available and ($today.metrics.switch_rate != null) and ($baseline.averages.switch_rate != null) and ($baseline.averages.switch_rate > 0) and ($today.metrics.switch_rate > ($t.quality.switch_above_baseline_mult * $baseline.averages.switch_rate))); {
            kind: "Focus",
            priority: 76,
            text: $msg.quality.switch_above_baseline,
            metric: "switch_rate"
          })
          + maybe(($today.metrics.avg_session_length_proxy_seconds != null) and ($today.metrics.avg_session_length_proxy_seconds < $t.quality.short_session_proxy_seconds); {
            kind: "Focus",
            priority: 60,
            text: $msg.quality.short_sessions,
            metric: "avg_session_length_proxy_seconds"
          })
        ) as $quality_candidates
      | (
          maybe(($today.metrics.peak_slot_index >= 0); {
            kind: "Timing",
            priority: 72,
            text: ($msg.temporal.peak_window + $today.metrics.peak_slot_label + "."),
            metric: "peak_slot_label"
          })
          + maybe(($today.metrics.active_slot_count >= $t.temporal.broad_spread_slots); {
            kind: "Timing",
            priority: 68,
            text: $msg.temporal.broad_spread,
            metric: "active_slot_count"
          })
          + maybe(($today.metrics.active_slot_count > 0 and $today.metrics.active_slot_count <= $t.temporal.concentrated_slots); {
            kind: "Timing",
            priority: 52,
            text: $msg.temporal.concentrated,
            metric: "active_slot_count"
          })
        ) as $temporal_candidates
      | (
          maybe(($today.schema_ready | not); {
            kind: "Tip",
            priority: 97,
            text: $msg.recommendation.legacy,
            metric: "schema_ready"
          })
          + maybe(($today.categories.browser_ambiguity_ratio > $t.recommendation.browser_ambiguity_high); {
            kind: "Tip",
            priority: 90,
            text: $msg.recommendation.browser_ambiguity,
            metric: "browser_ambiguity_ratio"
          })
          + maybe(($today.categories.unknown_share > $t.recommendation.unknown_high); {
            kind: "Tip",
            priority: 88,
            text: $msg.recommendation.unknown_high,
            metric: "unknown_share"
          })
          + maybe((($today.metrics.communication_load > $t.recommendation.communication_heavy) and (($today.metrics.switch_rate // 0) > $t.recommendation.switch_rate_high)); {
            kind: "Tip",
            priority: 80,
            text: $msg.recommendation.communication_switch_pressure,
            metric: "communication_switch_pressure"
          })
          + maybe((($today.metrics.study_ratio < $t.recommendation.study_ratio_low) and ($today.metrics.work_study_share > $t.recommendation.work_study_share_present)); {
            kind: "Tip",
            priority: 74,
            text: $msg.recommendation.study_ratio_low,
            metric: "study_ratio"
          })
        ) as $recommendation_candidates
      | (
          maybe(($today.metrics.eye_strain_risk == "High"); {
            kind: "Health",
            priority: 92,
            text: "Take a 20-min screen break — eye strain risk is elevated (20-20-20 rule).",
            metric: "eye_strain_risk"
          })
          + maybe(($today.metrics.circadian_phase == "Night" or $today.metrics.circadian_phase == "Evening"); {
            kind: "Health",
            priority: 75,
            text: "Late-night screen use suppresses melatonin. Consider winding down soon.",
            metric: "circadian_phase"
          })
          + maybe((($today.metrics.cognitive_load_score // 0) > 70); {
            kind: "Health",
            priority: 85,
            text: "Cognitive load is high — batch your messages and reduce tab switching.",
            metric: "cognitive_load_score"
          })
          + maybe(($today.metrics.ultradian_score == 0 and ($today.metrics.active_hours // 0) > 2); {
            kind: "Health",
            priority: 68,
            text: "No 90-min deep work cycles detected. Block time for uninterrupted focus.",
            metric: "ultradian_score"
          })
          + maybe((($today.scores.digital_wellbeing_score.value // 100) < 40 and $today.schema_ready); {
            kind: "Health",
            priority: 82,
            text: "Digital wellbeing needs attention — try a focus sprint or take a proper break.",
            metric: "digital_wellbeing_score"
          })
        ) as $health_candidates
      | .insights = {
          by_class: {
            composition: first_ranked($composition_candidates),
            quality: first_ranked($quality_candidates),
            temporal: first_ranked($temporal_candidates),
            recommendation: first_ranked($recommendation_candidates),
            health: first_ranked($health_candidates)
          },
          recommendation_candidates: ranked($recommendation_candidates),
          health_candidates: ranked($health_candidates),
          all: ranked([
            first_ranked($composition_candidates),
            first_ranked($quality_candidates),
            first_ranked($temporal_candidates),
            first_ranked($recommendation_candidates),
            first_ranked($health_candidates)
          ] | map(select(. != null))),
          main: first_ranked([
            first_ranked($composition_candidates),
            first_ranked($quality_candidates),
            first_ranked($temporal_candidates),
            first_ranked($recommendation_candidates),
            first_ranked($health_candidates)
          ] | map(select(. != null)))
        }
    '
}
