# Global Productivity Baselines
export STUDY_GOAL_BASELINE_SECONDS=${STUDY_GOAL_BASELINE_SECONDS:-14400} # Default: 4 hours

# Implementation logic

build_metrics_context() {
  local bundle_json="$1"

  printf '%s' "$bundle_json" \
    | jq '
      def zero_slots: ([range(0; 48)] | map(0));
      def categories: [
        "Work",
        "Study",
        "Communication",
        "Browser",
        "Entertainment",
        "Media",
        "System",
        "Unknown"
      ];
      def pad2:
        tostring
        | if length < 2 then "0" + . else . end;
      def slot_time($minutes):
        (($minutes / 60) | floor | pad2) + ":" + (($minutes % 60) | pad2);
      def slot_label($index):
        if $index < 0 or $index > 47 then
          "No peak yet"
        else
          slot_time($index * 30) + "-" + slot_time((($index + 1) * 30) % 1440)
        end;
      def focus_window($slots):
        ([ $slots | to_entries[] | select(.value > 0) | .key ]) as $active
        | if ($active | length) == 0 then
            "No tracked focus"
          else
            slot_time(($active[0] * 30)) + "-" + slot_time(((($active[-1] + 1) * 30)) % 1440)
          end;
      def app_entries($apps; $map):
        (($apps // {}) | to_entries | map(
          .key as $key
          | .value as $value
          | {
              key: $key,
              class: ($value.class // $key),
              name: ($value.name // $key),
              icon: ($value.icon // ""),
              seconds: ($value.seconds // 0),
              sample_count: ($value.sample_count // 0),
              session_count: ($value.session_count // 0),
              slots_30m: (($value.slots_30m // zero_slots) | if length == 48 then . else zero_slots end),
              category: ($map[$key] // "Unknown")
            }
        ) | sort_by(-.seconds, .name));
      def category_seconds($apps):
        (reduce categories[] as $name ({}; .[$name] = 0)) as $base
        | reduce $apps[] as $app ($base; .[$app.category] += ($app.seconds // 0));
      def category_slots($apps):
        (reduce categories[] as $name ({}; .[$name] = zero_slots)) as $base
        | reduce $apps[] as $app ($base; 
            .[$app.category] = ([.[$app.category], $app.slots_30m] | transpose | map(add))
          );
      def top_slots($slots):
        ($slots
          | to_entries
          | map(select(.value > 0) | {index: .key, label: slot_label(.key), seconds: .value})
          | sort_by(-.seconds, .index)
          | .[:5]);
      def annotate_day($map):
        . as $day
        | ($day.total_seconds // 0) as $total
        | ($day.study.total_seconds // 0) as $study_seconds
        | (env.STUDY_GOAL_BASELINE_SECONDS // "14400" | tonumber) as $baseline_goal_seconds
        | ($day.study_active.planned_total_seconds // 0) as $planned_total
        | (if $planned_total > $baseline_goal_seconds then $planned_total else $baseline_goal_seconds end) as $study_goal_seconds
        | (($day.slots_30m // zero_slots) | if length == 48 then . else zero_slots end) as $slots
        | (app_entries($day.apps; $map)) as $apps
        | (category_seconds($apps)) as $category_seconds
        | (category_slots($apps)) as $category_slots
        | ([ $slots | map(select(. > 0)) | length ][0]) as $active_slot_count
        | ([ $slots | to_entries[] | select(.value > 0) ]) as $active_slots
        | (if ($active_slots | length) == 0 then {key: -1, value: 0} else ($active_slots | max_by(.value)) end) as $peak
        | ([categories[] as $name | {name: $name, seconds: ($category_seconds[$name] // 0)}] | sort_by(-.seconds, .name)) as $top_categories
        | {
            date: $day.date,
            version: $day.version,
            missing: ($day.missing // false),
            schema_ready: ($day.schema_ready // false),
            updated_at: $day.updated_at,
            sample_seconds: $day.sample_seconds,
            sample_count: $day.sample_count,
            total_seconds: $total,
            study_seconds: $study_seconds,
            raw: $day,
            app_entries: $apps,
            categories: {
              seconds: $category_seconds,
              shares: (
                reduce categories[] as $name
                  ({};
                    .[$name] = (
                      if $total > 0 then
                        (($category_seconds[$name] // 0) / $total)
                      else
                        0
                      end
                    )
                  )
              ),
              breakdown: [
                categories[] as $name
                | {
                    name: $name,
                    seconds: ($category_seconds[$name] // 0),
                    share: (if $total > 0 then (($category_seconds[$name] // 0) / $total) else 0 end),
                    apps: ($apps | map(select(.category == $name)) | sort_by(-.seconds, .name) | .[:5])
                  }
              ],
              top_category: (if $total > 0 then $top_categories[0].name else "Unknown" end),
              top_category_seconds: (if $total > 0 then $top_categories[0].seconds else 0 end),
              known_category_ratio: (if $total > 0 then 1 - (($category_seconds["Unknown"] // 0) / $total) else 0 end),
              browser_ambiguity_ratio: (if $total > 0 then (($category_seconds["Browser"] // 0) / $total) else 0 end),
              unknown_share: (if $total > 0 then (($category_seconds["Unknown"] // 0) / $total) else 0 end),
              slots: $category_slots
            },
            metrics: {
              active_hours: ($total / 3600),
              safe_active_hours: (if ($total / 3600) > 0 then ($total / 3600) else 0.000001 end),
              safe_total_seconds: (if $total > 0 then $total else 1 end),
              active_slot_count: $active_slot_count,
              active_spread: $active_slot_count,
              focus_window: focus_window($slots),
              peak_slot_index: $peak.key,
              peak_slot_label: (if $peak.key >= 0 then slot_label($peak.key) else "No peak yet" end),
              peak_slot_seconds: $peak.value,
              top_slots: top_slots($slots),
              study_ratio: (if $total > 0 then ($study_seconds / $total) else 0 end),
              productive_ratio_v1: (if $total > 0 then ((($category_seconds["Work"] // 0) + ($category_seconds["Study"] // 0)) / $total) else 0 end),
              work_study_share: (if $total > 0 then ((($category_seconds["Work"] // 0) + ($category_seconds["Study"] // 0)) / $total) else 0 end),
              communication_load: (if $total > 0 then (($category_seconds["Communication"] // 0) / $total) else 0 end),
              leisure_load: (if $total > 0 then ((($category_seconds["Entertainment"] // 0) + ($category_seconds["Media"] // 0)) / $total) else 0 end),
              browser_ambiguity_ratio: (if $total > 0 then (($category_seconds["Browser"] // 0) / $total) else 0 end),
              known_category_ratio: (if $total > 0 then 1 - (($category_seconds["Unknown"] // 0) / $total) else 0 end),
              study_goal_seconds: $study_goal_seconds,
              study_goal_progress: (if $study_goal_seconds > 0 then ($study_seconds / $study_goal_seconds) else 0 end),
              session_density: (
                if ($day.schema_ready // false) then
                  (($day.session_count // 0) / (if ($total / 3600) > 0 then ($total / 3600) else 0.000001 end))
                else
                  null
                end
              ),
              switch_rate: (
                if ($day.schema_ready // false) then
                  (($day.switch_count // 0) / (if ($total / 3600) > 0 then ($total / 3600) else 0.000001 end))
                else
                  null
                end
              ),
              avg_session_length_proxy_seconds: (
                if ($day.schema_ready // false) then
                  ($total / (if ($day.session_count // 0) > 0 then ($day.session_count // 0) else 1 end))
                else
                  null
                end
              )
            }
          };

      . as $bundle
      | {
          target_date: $bundle.target_date,
          yesterday_date: $bundle.yesterday_date,
          category_map_path: $bundle.category_map_path,
          category_map_size: ($bundle.category_map | length),
          study_active: $bundle.study_active,
          title_tracking: false,
          today: ($bundle.today | annotate_day($bundle.category_map)),
          yesterday: ($bundle.yesterday | annotate_day($bundle.category_map)),
          trailing: ($bundle.trailing | map(annotate_day($bundle.category_map)))
        }
    '
}
