## What changed

<!-- What this does, in a sentence or two. Written by a human. -->

## Why

<!-- The problem this solves. For a new alert: what symptom an on-call engineer
     would act on, and what the existing alerts miss. -->

## Testing

<!-- Steps a reviewer can paste, and the result.

     Query or alert changes also need evidence from a real cluster or the dev
     environment -- a screenshot of the query returning data, not just green CI.
     promtool proves the PromQL is right over series you wrote; it cannot prove
     the metric exists, carries the labels the join needs, or is in the unit you
     assumed. -->
