#!/usr/bin/env bash
# Print the top N open, unblocked leaf issues, highest priority first.
# Priority: tier-1 > tier-2 > tier-3 > no tier; then lowest issue number.
set -euo pipefail
limit="${1:-10}"
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# ponytail: first 100 open issues, 4 ancestor levels; paginate or deepen when the repo outgrows that.
gh api graphql -F owner="${repo%/*}" -F name="${repo#*/}" -f query='
fragment B on Issue { number blockedBy(first: 50) { nodes { state } } }
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, first: 100) { nodes {
      ...B title url
      labels(first: 20) { nodes { name } }
      assignees(first: 5) { nodes { login } }
      subIssues(first: 50) { nodes { state } }
      parent { ...B parent { ...B parent { ...B parent { ...B } } } }
    } }
  }
}' | jq -r --argjson limit "$limit" '
  def blocked: any(.blockedBy.nodes[]; .state == "OPEN");
  def chain: ., (.parent // empty | chain);
  def tier: ([.labels.nodes[].name | capture("^tier-(?<n>[0-9]+)$").n | tonumber] | min) // 99;
  [.data.repository.issues.nodes[]
    | select(all(.subIssues.nodes[]; .state != "OPEN"))
    | select(any(chain; blocked) | not)]
  | sort_by(tier, .number) | .[:$limit][]
  | "#\(.number)\t\(if tier == 99 then "-" else "tier-\(tier)" end)\t\([.assignees.nodes[].login] | join(",") | if . == "" then "-" else . end)\t\(.title)\t\(.url)"'
