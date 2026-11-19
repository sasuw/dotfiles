#!/usr/bin/env zsh

column_table(){
  local table_width="${COLUMNS:-}"

  if [[ "${table_width}" != <-> ]]; then
    table_width=""
  fi

  if [[ -z "${table_width}" || "${table_width}" -lt 1 ]] && [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    table_width="$(tput cols 2>/dev/null || print -r -- "${table_width:-80}")"
  fi

  [[ "${table_width}" == <-> ]] || table_width=80

  sort | awk -F '|' -v table_width="${table_width}" '
    function spaces(count) {
      return count > 0 ? sprintf("%" count "s", "") : ""
    }

    function fit_cell(value, width, length_value) {
      length_value = length(value)

      if (width <= 0) {
        return ""
      }

      if (length_value <= width) {
        return value spaces(width - length_value)
      }

      if (width == 1) {
        return substr(value, 1, 1)
      }

      return substr(value, 1, width - 1) "~"
    }

    {
      row_count++

      for (column = 1; column <= NF; column++) {
        cells[row_count, column] = $column

        if (length($column) > max_width[column]) {
          max_width[column] = length($column)
        }
      }

      if (NF > column_count) {
        column_count = NF
      }
    }

    END {
      if (row_count == 0) {
        exit
      }

      width = table_width + 0
      if (width < 1) {
        width = 80
      }

      separator_width = column_count > 1 ? 2 : 0
      max_total = separator_width * (column_count - 1)

      for (column = 1; column <= column_count; column++) {
        max_total += max_width[column]
      }

      if (max_total <= width) {
        extra_width = width - max_total

        for (column = 1; column <= column_count; column++) {
          output_width[column] = max_width[column] + int(extra_width / column_count)

          if (column <= extra_width % column_count) {
            output_width[column]++
          }
        }
      } else {
        if (width < column_count + (2 * (column_count - 1))) {
          separator_width = 1
        }

        if (width < column_count + (column_count - 1)) {
          separator_width = 0
        }

        field_budget = width - (separator_width * (column_count - 1))
        if (field_budget < 1) {
          field_budget = 1
        }

        minimum_width = field_budget >= column_count * 4 ? 4 : 1

        for (step = 1; step <= minimum_width; step++) {
          for (column = 1; column <= column_count; column++) {
            if (allocated >= field_budget) {
              break
            }

            if (output_width[column] < max_width[column]) {
              output_width[column]++
              allocated++
            }
          }
        }

        while (allocated < field_budget) {
          best_column = 0
          best_width = width + 1

          for (column = 1; column <= column_count; column++) {
            remaining = max_width[column] - output_width[column]

            if (remaining > 0 && output_width[column] < best_width) {
              best_column = column
              best_width = output_width[column]
            }
          }

          if (best_column == 0) {
            break
          }

          output_width[best_column]++
          allocated++
        }
      }

      separator = spaces(separator_width)

      for (row = 1; row <= row_count; row++) {
        line = ""

        for (column = 1; column <= column_count; column++) {
          if (column > 1) {
            line = line separator
          }

          line = line fit_cell(cells[row, column], output_width[column])
        }

        print substr(line, 1, width)
      }
    }
  '
}
alias ct='column_table'

'column_table_sorted'(){
  column_table
}
alias cts='column_table_sorted'
