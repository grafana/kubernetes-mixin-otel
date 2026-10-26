local identifierChars = std.set(std.stringChars('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_:'));

local labelLists(expr, keyword) =
  [
    local rest = std.substr(expr, start + std.length(keyword), std.length(expr) - start - std.length(keyword));
    std.split(std.substr(rest, 0, std.findSubstr(')', rest)[0]), ', ')
    for start in std.findSubstr(keyword, expr)
  ];

local trailingIdentifier(expr, end) =
  local taken = std.foldl(
    function(acc, char)
      if acc.done || !std.member(identifierChars, char) then acc { done: true }
      else acc { chars: acc.chars + [char] },
    std.reverse(std.stringChars(std.substr(expr, 0, end))),
    { chars: [], done: false },
  ).chars;
  std.join('', std.reverse(taken));

// Walks expr tracking quote and brace depth so ${var:pipe} inside a matcher value
// is not mistaken for a selector.
local selectors(expr) =
  std.foldl(
    function(acc, index)
      local char = std.stringChars(expr)[index];
      if acc.quoted then acc { quoted: char != '"', current: acc.current + char }
      else if char == '"' then acc { quoted: true, current: acc.current + char }
      else if char == '{' then acc {
        depth: acc.depth + 1,
        current: if acc.depth == 0 then '' else acc.current + char,
        metric: if acc.depth == 0 then trailingIdentifier(expr, index) else acc.metric,
      }
      else if char == '}' && acc.depth == 1 then acc {
        depth: 0,
        current: '',
        found: acc.found + [{ metric: acc.metric, matchers: if acc.current == '' then [] else std.split(acc.current, ', ') }],
      }
      else if char == '}' then acc { depth: acc.depth - 1, current: acc.current + char }
      else if acc.depth > 0 then acc { current: acc.current + char }
      else acc,
    std.range(0, std.length(expr) - 1),
    { quoted: false, depth: 0, current: '', metric: '', found: [] },
  ).found;

{
  // Label lists of every aggregation, outermost first.
  aggregations(expr):: labelLists(expr, ' by ('),

  // Label lists of every vector-match on() clause.
  joinLabels(expr):: labelLists(expr, ' on ('),

  // {metric, matchers} per selector, in order of appearance.
  selectors(expr):: selectors(expr),

  metrics(expr):: std.set([selector.metric for selector in selectors(expr)]),

  matchersOn(expr, metric):: std.set(std.flattenArrays([
    selector.matchers
    for selector in selectors(expr)
    if selector.metric == metric
  ])),
}
