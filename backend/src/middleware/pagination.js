// Shared ?limit= / ?offset= parsing for list endpoints (Phase 5).
//
// Convention (see docs/API.md):
//   - `limit` is clamped to 1..500. When the client passes no limit at all
//     the default is 500 — large enough that family-scale lists are
//     returned in full, so existing clients that display everything keep
//     working unchanged. Clients that page pass explicit limit/offset.
//   - `offset` is clamped to >= 0.
//   - Paginated list responses add `total` (full filtered count), `limit`
//     and `offset` next to the existing list key. No success shape is
//     otherwise changed.
export const MAX_PAGE_LIMIT = 500;
export const DEFAULT_PAGE_LIMIT = 500;

export function parseLimitOffset(req, defaultLimit = DEFAULT_PAGE_LIMIT) {
  const rawLimit = req.query?.limit;
  const limit =
    rawLimit === undefined
      ? defaultLimit
      : Math.min(Math.max(parseInt(rawLimit, 10) || defaultLimit, 1), MAX_PAGE_LIMIT);
  const rawOffset = req.query?.offset;
  const offset = Math.max(parseInt(rawOffset, 10) || 0, 0);
  return { limit, offset };
}

/** Slice `list` to the requested page and return the page + its metadata. */
export function pageOf(list, { limit, offset }) {
  return {
    items: list.slice(offset, offset + limit),
    total: list.length,
    limit,
    offset,
  };
}
