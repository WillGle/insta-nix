#!/usr/bin/env bash

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
      def peak_activity_window($slots):
        (reduce range(0; 46) as $i ({best: -1, best_i: -1};
          (($slots[$i] // 0) + ($slots[$i+1] // 0) + ($slots[$i+2] // 0)) as $w
          | if $w > .best then {best: $w, best_i: $i} else . end
        )) as $r
        | if $r.best <= 0 then "No peak yet"
          else slot_time($r.best_i * 30) + "\u2013" + slot_time(($r.best_i + 3) * 30)
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
              first_seen: ($value.first_seen // ""),
              last_seen: ($value.last_seen // ""),
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

      . as $bundle
      | $bundle.today as $day
      | ($day.total_seconds // 0) as $total
      | (($day.slots_30m // zero_slots) | if length == 48 then . else zero_slots end) as $slots
      | (app_entries($day.apps; $bundle.category_map)) as $apps
      | (category_seconds($apps)) as $category_seconds
      | (category_slots($apps)) as $category_slots
      | ([ $slots | to_entries[] | select(.value > 0) ]) as $active_slots
      | (if ($active_slots | length) == 0 then {key: -1, value: 0} else ($active_slots | max_by(.value)) end) as $peak
      | ([categories[] as $name | {name: $name, seconds: ($category_seconds[$name] // 0)}] | sort_by(-.seconds, .name)) as $top_categories
      | {
          target_date: $bundle.target_date,
          category_map_path: $bundle.category_map_path,
          category_map: $bundle.category_map,
          today: {
            date: $day.date,
            updated_at: $day.updated_at,
            sample_seconds: $day.sample_seconds,
            sample_count: ($day.sample_count // 0),
            total_seconds: $total,
            slots_30m: $slots,
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
                    share: (if $total > 0 then (($category_seconds[$name] // 0) / $total) else 0 end)
                  }
              ],
              top_category: (if $total > 0 then $top_categories[0].name else "Unknown" end),
              top_category_seconds: (if $total > 0 then $top_categories[0].seconds else 0 end),
              slots: $category_slots
            },
            metrics: {
              active_slot_count: ([ $slots[] | select(. > 0) ] | length),
              peak_slot_index: $peak.key,
              peak_slot_label: (if $peak.key >= 0 then slot_label($peak.key) else "No peak yet" end),
              peak_slot_seconds: $peak.value,
              focus_window: peak_activity_window($slots),
              unknown_seconds: ($category_seconds["Unknown"] // 0),
              unknown_share: (
                if $total > 0 then (($category_seconds["Unknown"] // 0) / $total) else 0 end
              ),
              known_category_ratio: (
                if $total > 0 then 1 - (($category_seconds["Unknown"] // 0) / $total) else 0 end
              )
            }
          }
        }
    '
}
