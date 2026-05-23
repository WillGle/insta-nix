#!/usr/bin/env bash

build_scored_context() {
  local metrics_json="$1"

  printf '%s' "$metrics_json" \
    | jq '
      def clamp01($value):
        if $value < 0 then 0 elif $value > 1 then 1 else $value end;
      def norm_range($value; $low; $high):
        if $high <= $low then
          0
        elif $value <= $low then
          0
        elif $value >= $high then
          1
        else
          (($value - $low) / ($high - $low))
        end;
      def avg($values):
        if ($values | length) == 0 then null else (($values | add) / ($values | length)) end;
      def delta($current; $base):
        if $current == null or $base == null then null else ($current - $base) end;
      def score_label_fragmentation($value):
        if $value == null then "Unavailable"
        elif $value < 40 then "Low fragmentation"
        elif $value < 70 then "Moderate fragmentation"
        else "High fragmentation"
        end;
      def score_label_focus($value):
        if $value == null then "Unavailable"
        elif $value < 40 then "Weak focus structure"
        elif $value < 70 then "Mixed focus day"
        else "Strong intentional focus day"
        end;
      def score_label_distraction($value):
        if $value == null then "Unavailable"
        elif $value < 40 then "Low distraction load"
        elif $value < 70 then "Mixed distraction load"
        else "High distraction pressure"
        end;
      def score_label_consistency($value):
        if $value == null then "Unavailable"
        elif $value < 40 then "Irregular day"
        elif $value < 70 then "Moderately consistent"
        else "Highly consistent"
        end;
      def unavailable_score($reason; $partial):
        {
          available: false,
          value: null,
          partial: $partial,
          label: "Unavailable",
          reason: $reason,
          components: {}
        };
      def add_base_scores:
        . as $day
        | ($day.metrics.session_density) as $session_density
        | ($day.metrics.switch_rate) as $switch_rate
        | ($day.metrics.active_slot_count) as $active_slot_count
        | ($day.metrics.active_hours) as $active_hours
        | ($day.metrics.study_ratio) as $study_ratio
        | ($day.metrics.work_study_share) as $work_study_share
        | ($day.metrics.communication_load) as $communication_load
        | ($day.metrics.leisure_load) as $leisure_load
        | ($day.metrics.browser_ambiguity_ratio) as $browser_ratio
        | ($day.categories.seconds["Work"] // 0) as $work_seconds
        | ($day.categories.seconds["Study"] // 0) as $study_category_seconds
        | (clamp01((($day.study_seconds + (0.6 * $work_seconds)) / ($day.metrics.safe_total_seconds // 1)))) as $intentional_extended
        | if ($day.schema_ready | not) then
            . + {
              scores: {
                intentional_usage_ratio_strict: unavailable_score("Requires version 2 tracking data."; false),
                fragmentation_score: unavailable_score("Requires version 2 tracking data."; false),
                focus_score: unavailable_score("Requires version 2 tracking data."; true),
                intentional_usage_ratio: unavailable_score("Requires version 2 tracking data."; false),
                intentional_usage_ratio_extended: unavailable_score("Requires version 2 tracking data."; true),
                distraction_load: unavailable_score("Requires version 2 tracking data."; true),
                daily_consistency_score: unavailable_score("Requires at least 3 version 2 days."; false)
              }
            }
          else
            ($active_slot_count / (if ($active_hours * 2) > 1 then ($active_hours * 2) else 1 end)) as $spread_ratio
            | (norm_range($session_density; 2; 20)) as $session_density_norm
            | (norm_range($switch_rate; 4; 30)) as $switch_rate_norm
            | (norm_range($spread_ratio; 0.6; 1.4)) as $spread_norm
            | ((0.45 * $session_density_norm) + (0.45 * $switch_rate_norm) + (0.10 * $spread_norm)) as $fragmentation_norm
            | (($fragmentation_norm * 100) | round) as $fragmentation_score
            | (clamp01($study_ratio)) as $study_ratio_norm
            | (clamp01($work_study_share)) as $work_study_norm
            | (norm_range($switch_rate; 4; 30)) as $switch_penalty_norm
            | ($fragmentation_score / 100) as $fragmentation_penalty_norm
            | ((0.35 * $study_ratio_norm) + (0.30 * $work_study_norm) + (0.20 * (1 - $switch_penalty_norm)) + (0.15 * (1 - $fragmentation_penalty_norm))) as $focus_norm
            | (($focus_norm * 100) | round) as $focus_score
            | (clamp01($communication_load)) as $comm_norm
            | (clamp01($leisure_load)) as $leisure_norm
            | (clamp01($browser_ratio)) as $browser_norm
            | ((0.30 * $comm_norm) + (0.25 * $leisure_norm) + (0.20 * $browser_norm) + (0.15 * $switch_rate_norm) + (0.10 * $session_density_norm)) as $distraction_norm
            | (($distraction_norm * 100) | round) as $distraction_score
            | . + {
              scores: {
                intentional_usage_ratio_strict: {
                  available: true,
                  value: $study_ratio,
                  partial: false,
                  label: "Intentional Usage Ratio",
                  reason: "",
                  components: {
                    study_ratio: $study_ratio
                  }
                },
                fragmentation_score: {
                  available: true,
                  value: $fragmentation_score,
                  partial: false,
                  label: score_label_fragmentation($fragmentation_score),
                  reason: "",
                  components: {
                    session_density_norm: $session_density_norm,
                    switch_rate_norm: $switch_rate_norm,
                    spread_norm: $spread_norm,
                    spread_ratio: $spread_ratio
                  }
                },
                focus_score: {
                  available: true,
                  value: $focus_score,
                  partial: true,
                  label: score_label_focus($focus_score),
                  reason: "Browser activity stays semantically neutral without title tracking.",
                  components: {
                    study_ratio_norm: $study_ratio_norm,
                    work_study_norm: $work_study_norm,
                    switch_penalty_norm: $switch_penalty_norm,
                    fragmentation_penalty_norm: $fragmentation_penalty_norm
                  }
                },
                intentional_usage_ratio: {
                  available: true,
                  value: $study_ratio,
                  partial: false,
                  label: "Intentional Usage Ratio",
                  reason: "",
                  components: {
                    study_ratio: $study_ratio
                  }
                },
                intentional_usage_ratio_extended: {
                  available: true,
                  value: $intentional_extended,
                  partial: true,
                  label: "Intentional Usage Ratio Extended",
                  reason: "Uses study mode plus weighted Work time to avoid overlapping Study double-count.",
                  components: {
                    study_seconds: $day.study_seconds,
                    work_seconds: $work_seconds
                  }
                },
                distraction_load: {
                  available: true,
                  value: $distraction_score,
                  partial: true,
                  label: score_label_distraction($distraction_score),
                  reason: "Browser activity is treated as ambiguity pressure, not confirmed distraction.",
                  components: {
                    communication_norm: $comm_norm,
                    leisure_norm: $leisure_norm,
                    browser_norm: $browser_norm,
                    switch_norm: $switch_rate_norm,
                    session_density_norm: $session_density_norm
                  }
                },
                daily_consistency_score: unavailable_score("Requires at least 3 version 2 days."; false)
              }
            }
          end;

      .today |= add_base_scores
      | .yesterday |= add_base_scores
      | .trailing |= map(add_base_scores)
      | (.trailing | map(select(.schema_ready == true))) as $eligible
      | ($eligible | length) as $eligible_days
      | ($eligible_days >= 3) as $baseline_available
      | (
          if $baseline_available then
            {
              total_seconds: avg($eligible | map(.total_seconds)),
              study_ratio: avg($eligible | map(.metrics.study_ratio)),
              session_density: avg($eligible | map(.metrics.session_density)),
              switch_rate: avg($eligible | map(.metrics.switch_rate)),
              fragmentation_score: avg($eligible | map(.scores.fragmentation_score.value)),
              focus_score: avg($eligible | map(.scores.focus_score.value)),
              productive_ratio_v1: avg($eligible | map(.metrics.productive_ratio_v1)),
              browser_ambiguity_ratio: avg($eligible | map(.metrics.browser_ambiguity_ratio)),
              active_slot_count: avg($eligible | map(.metrics.active_slot_count))
            }
          else
            null
          end
        ) as $avg7
      | .baseline = {
          eligible_days: $eligible_days,
          available: $baseline_available,
          averages: $avg7,
          deltas: {
            total_seconds: {
              current: .today.total_seconds,
              yesterday: .yesterday.total_seconds,
              avg7: (if $baseline_available then $avg7.total_seconds else null end),
              vs_yesterday: delta(.today.total_seconds; .yesterday.total_seconds),
              vs_avg7: (if $baseline_available then delta(.today.total_seconds; $avg7.total_seconds) else null end)
            },
            study_ratio: {
              current: .today.metrics.study_ratio,
              yesterday: .yesterday.metrics.study_ratio,
              avg7: (if $baseline_available then $avg7.study_ratio else null end),
              vs_yesterday: delta(.today.metrics.study_ratio; .yesterday.metrics.study_ratio),
              vs_avg7: (if $baseline_available then delta(.today.metrics.study_ratio; $avg7.study_ratio) else null end)
            },
            session_density: {
              current: .today.metrics.session_density,
              yesterday: .yesterday.metrics.session_density,
              avg7: (if $baseline_available then $avg7.session_density else null end),
              vs_yesterday: delta(.today.metrics.session_density; .yesterday.metrics.session_density),
              vs_avg7: (if $baseline_available then delta(.today.metrics.session_density; $avg7.session_density) else null end)
            },
            switch_rate: {
              current: .today.metrics.switch_rate,
              yesterday: .yesterday.metrics.switch_rate,
              avg7: (if $baseline_available then $avg7.switch_rate else null end),
              vs_yesterday: delta(.today.metrics.switch_rate; .yesterday.metrics.switch_rate),
              vs_avg7: (if $baseline_available then delta(.today.metrics.switch_rate; $avg7.switch_rate) else null end)
            },
            fragmentation_score: {
              current: .today.scores.fragmentation_score.value,
              yesterday: .yesterday.scores.fragmentation_score.value,
              avg7: (if $baseline_available then $avg7.fragmentation_score else null end),
              vs_yesterday: delta(.today.scores.fragmentation_score.value; .yesterday.scores.fragmentation_score.value),
              vs_avg7: (if $baseline_available then delta(.today.scores.fragmentation_score.value; $avg7.fragmentation_score) else null end)
            },
            focus_score: {
              current: .today.scores.focus_score.value,
              yesterday: .yesterday.scores.focus_score.value,
              avg7: (if $baseline_available then $avg7.focus_score else null end),
              vs_yesterday: delta(.today.scores.focus_score.value; .yesterday.scores.focus_score.value),
              vs_avg7: (if $baseline_available then delta(.today.scores.focus_score.value; $avg7.focus_score) else null end)
            },
            productive_ratio_v1: {
              current: .today.metrics.productive_ratio_v1,
              yesterday: .yesterday.metrics.productive_ratio_v1,
              avg7: (if $baseline_available then $avg7.productive_ratio_v1 else null end),
              vs_yesterday: delta(.today.metrics.productive_ratio_v1; .yesterday.metrics.productive_ratio_v1),
              vs_avg7: (if $baseline_available then delta(.today.metrics.productive_ratio_v1; $avg7.productive_ratio_v1) else null end)
            },
            browser_ambiguity_ratio: {
              current: .today.metrics.browser_ambiguity_ratio,
              yesterday: .yesterday.metrics.browser_ambiguity_ratio,
              avg7: (if $baseline_available then $avg7.browser_ambiguity_ratio else null end),
              vs_yesterday: delta(.today.metrics.browser_ambiguity_ratio; .yesterday.metrics.browser_ambiguity_ratio),
              vs_avg7: (if $baseline_available then delta(.today.metrics.browser_ambiguity_ratio; $avg7.browser_ambiguity_ratio) else null end)
            }
          }
        }
      | if (.today.schema_ready and $baseline_available) then
          (($avg7.total_seconds | if . > 1 then . else 1 end)) as $time_base
          | (($avg7.active_slot_count | if . > 1 then . else 1 end)) as $spread_base
          | ((.today.total_seconds - $avg7.total_seconds) | if . < 0 then -. else . end) as $time_abs
          | ((.today.metrics.active_slot_count - $avg7.active_slot_count) | if . < 0 then -. else . end) as $spread_abs
          | ((.today.metrics.study_ratio - $avg7.study_ratio) | if . < 0 then -. else . end) as $study_abs
          | ($time_abs / $time_base) as $time_dev
          | ($spread_abs / $spread_base) as $spread_dev
          | $study_abs as $study_dev
          | (norm_range($time_dev; 0; 1)) as $time_dev_norm
          | (norm_range($spread_dev; 0; 1)) as $spread_dev_norm
          | (norm_range($study_dev; 0; 1)) as $study_dev_norm
          | (1 - ((0.45 * $time_dev_norm) + (0.30 * $spread_dev_norm) + (0.25 * $study_dev_norm))) as $consistency_norm
          | .today.scores.daily_consistency_score = {
              available: true,
              value: ((clamp01($consistency_norm) * 100) | round),
              partial: false,
              label: score_label_consistency(((clamp01($consistency_norm) * 100) | round)),
              reason: "",
              components: {
                time_dev_norm: $time_dev_norm,
                spread_dev_norm: $spread_dev_norm,
                study_dev_norm: $study_dev_norm
              }
            }
        else
          .
        end
      | .today.scores.digital_wellbeing_score = (
          if (.today.schema_ready) then
            (
              ((.today.scores.focus_score.value // 0) / 100) * 0.30
              + ((1 - ((.today.scores.fragmentation_score.value // 0) / 100)) * 0.25)
              + ([(.today.metrics.study_goal_progress // 0), 1] | min) * 0.20
              + ([(.today.metrics.recovery_gap_count // 0) / 2, 1] | min) * 0.15
              + ((1 - ((.today.scores.distraction_load.value // 0) / 100)) * 0.10)
            ) * 100 | round
            | {
                available: true,
                value: .,
                label: (
                  if . >= 70 then "Strong digital wellness"
                  elif . >= 40 then "Moderate digital wellness"
                  else "Needs attention"
                  end
                ),
                reason: ""
              }
          else
            {available: false, value: null, label: "Unavailable", reason: "Requires version 2 tracking data."}
          end
        )
      | .data_quality = {
          schema_version: .today.version,
          schema_ready: .today.schema_ready,
          title_tracking: false,
          focus_score_partial: (.today.scores.focus_score.partial // true),
          baseline_available: .baseline.available,
          baseline_eligible_days: .baseline.eligible_days,
          category_map_path: .category_map_path,
          category_map_size: .category_map_size,
          known_category_ratio: .today.categories.known_category_ratio,
          browser_ambiguity_ratio: .today.categories.browser_ambiguity_ratio,
          unknown_share: .today.categories.unknown_share,
          unavailable_metrics: [
            if (.today.schema_ready | not) then
              "Advanced focus and fragmentation metrics require version 2 day data."
            else
              empty
            end,
            if (.baseline.available | not) then
              "7-day baselines need at least 3 version 2 days in the trailing window."
            else
              empty
            end,
            if .today.categories.browser_ambiguity_ratio > 0 then
              "Browser activity remains semantically neutral without title tracking."
            else
              empty
            end
          ]
        }
    '
}
