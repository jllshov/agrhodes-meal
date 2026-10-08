/**
 * Halls and buildings for Zone Defense room lists (QR admin + Zone Rounds).
 * Halls come from each facility's own room codes — not a fixed Atlanta list —
 * and are grouped by building on multi-building campuses (Cobb: Memory Village /
 * Legacy Building). The building is written onto each code by Nursiao's
 * Census → Building Setup → Sync to Zone Defense (room_qr_codes.building).
 * Keep identical in NURSAIIO/public/meal and the agrhodes-meal repo.
 */
(function() {
  'use strict';

  // Atlanta's original halls: shown in this order, even before they have codes
  var ATLANTA_HALLS = ['Taylor Hall', 'ICF Hall', 'Garden Hall', 'Victoria Court'];
  var ATLANTA_PREFIX = 'agrhodes-atl';

  function isAtlanta(prefix) { return prefix === ATLANTA_PREFIX; }

  /** Hall names to list: Atlanta's fixed four first (Atlanta only), then the rest A–Z. */
  function halls(rooms, prefix) {
    var seen = {};
    (rooms || []).forEach(function(r) { if (r && r.unit) seen[r.unit] = true; });
    var fixed = isAtlanta(prefix) ? ATLANTA_HALLS.slice() : [];
    var rest = Object.keys(seen).filter(function(h) { return fixed.indexOf(h) < 0; }).sort();
    return fixed.concat(rest);
  }

  /** A hall's building: the most common building on its codes ('' when none). */
  function buildingOfHall(rooms, hall) {
    var count = {};
    (rooms || []).forEach(function(r) {
      if (r && r.unit === hall && r.building) count[r.building] = (count[r.building] || 0) + 1;
    });
    var best = '';
    Object.keys(count).forEach(function(b) { if (!best || count[b] > count[best]) best = b; });
    return best;
  }

  function buildings(rooms) {
    var out = [];
    (rooms || []).forEach(function(r) { if (r && r.building && out.indexOf(r.building) < 0) out.push(r.building); });
    return out.sort();
  }

  /**
   * [{ building, halls: [...] }] — one group per building (A–Z), halls without a
   * building last. A single group with building '' when the campus has none.
   */
  function groups(rooms, prefix) {
    var hallList = halls(rooms, prefix);
    var names = buildings(rooms);
    if (!names.length) return [{ building: '', halls: hallList }];
    var byB = {};
    hallList.forEach(function(h) {
      var b = buildingOfHall(rooms, h);
      (byB[b] = byB[b] || []).push(h);
    });
    return names.concat(byB[''] ? [''] : []).map(function(b) { return { building: b, halls: byB[b] || [] }; });
  }

  // Building filter, remembered per facility on this device (not clinical data)
  function filterKey(prefix) { return 'zone_building_filter_' + (prefix || ''); }
  function getFilter(prefix) {
    try { return localStorage.getItem(filterKey(prefix)) || ''; } catch (_) { return ''; }
  }
  function setFilter(prefix, value) {
    try { localStorage.setItem(filterKey(prefix), value || ''); } catch (_) {}
  }

  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /** "All buildings | Memory Village | Legacy Building" pills; '' when there are no buildings. */
  function filterBarHtml(rooms, current, onChangeFn) {
    var names = buildings(rooms);
    if (!names.length) return '';
    var opts = [''].concat(names);
    return '<div class="zb-filter no-print" role="group" aria-label="Building">' +
      opts.map(function(b) {
        return '<button type="button" class="zb-pill' + (current === b ? ' active' : '') + '" ' +
          'onclick="' + onChangeFn + '(' + esc(JSON.stringify(b)) + ')">' + esc(b || 'All buildings') + '</button>';
      }).join('') + '</div>';
  }

  /** <option>s for a hall picker. */
  function hallOptionsHtml(rooms, prefix) {
    return groups(rooms, prefix).map(function(g) {
      var opts = g.halls.map(function(h) { return '<option value="' + esc(h) + '">' + esc(h) + '</option>'; }).join('');
      return g.building ? '<optgroup label="' + esc(g.building) + '">' + opts + '</optgroup>' : opts;
    }).join('');
  }

  window.ZoneBuildings = {
    halls: halls,
    buildingOfHall: buildingOfHall,
    buildings: buildings,
    groups: groups,
    getFilter: getFilter,
    setFilter: setFilter,
    filterBarHtml: filterBarHtml,
    hallOptionsHtml: hallOptionsHtml,
    isAtlanta: isAtlanta
  };
})();
