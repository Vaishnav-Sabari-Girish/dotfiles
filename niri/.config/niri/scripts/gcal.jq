#!/usr/bin/env jq -f

# ---------------------------------------------------------------------------
# Build day -> events index (TSV format: day, time, summary, id)
# ---------------------------------------------------------------------------
def build_day_index(ym):
  .items[]? |
  ( .start.dateTime // (.start.date + "T00:00:00") ) as $startraw |
  ( $startraw[0:7] ) as $eventym |
  select($eventym == ym) |
  ( $startraw[8:10] ) as $day |
  ( if .start.dateTime then $startraw[11:16] else "All day" end ) as $time |
  ( .summary // "(no title)" ) as $summary |
  ( .id ) as $id |
  [$day, $time, $summary, $id] | @tsv;

# ---------------------------------------------------------------------------
# Build the Markdown payload for Neovim
# ---------------------------------------------------------------------------
def build_day_markdown(ym; day):
  .items[]? |
  ( .start.dateTime // (.start.date + "T00:00:00") ) as $startraw |
  select($startraw[0:7] == ym and $startraw[8:10] == day) |
  "## " + (.summary // "(no title)") + "\n" +
  ( if .start.dateTime then
      "**Time:** " + .start.dateTime[11:16] + " - " + (.end.dateTime // .start.dateTime)[11:16] + "\n"
    else
      "**All day**\n"
    end ) +
  ( if .location then "**Location:** " + .location + "\n" else "" end ) +
  ( if .description then "\n" + .description + "\n" else "" end ) +
  ( if .attendees then
      "\n**Attendees:**\n" +
      ( [ .attendees[] | "- " + .email + (if .responseStatus then " (" + .responseStatus + ")" else "" end) ] | join("\n") ) +
      "\n"
    else "" end ) +
  ( if .htmlLink then "\n[Open in Google Calendar](" + .htmlLink + ")\n" else "" end ) +
  "\n---\n";

# ---------------------------------------------------------------------------
# Action Router (Reads the $action argument passed from Bash)
# ---------------------------------------------------------------------------
if $action == "index" then
  build_day_index($ym)
elif $action == "markdown" then
  build_day_markdown($ym; $day)
else
  empty
end
