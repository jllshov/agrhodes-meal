/**
 * Brother QL label printing for room / area QR codes (QL-700 and QL-800 take the
 * same DK rolls). Browsers can't drive the printer directly; the print job's
 * @page is sized to the label so choosing the Brother printer lines it up.
 *
 * - Codes are drawn fresh, black on white: thermal printers turn the on-screen
 *   gray background into dots, which hurts scanning.
 * - Several labels print as ONE job, one label per page, so a whole hall or
 *   building prints and cuts in a row.
 * - Each label shows the room, its hall and (on a multi-building campus) building.
 * Needs qrcode.min.js (qrcodejs). Keep identical in NURSAIIO/public/meal and agrhodes-meal.
 */
(function() {
  'use strict';

  var PRESETS = {
    dk2205: { name: 'DK-2205 Continuous 62mm (62×62mm)', w: 62, h: 62 },
    dk1202: { name: 'DK-1202 Shipping (62×100mm)', w: 62, h: 100 },
    dk1201: { name: 'DK-1201 Address (29×90mm)', w: 90, h: 29 },
    dk1241: { name: 'DK-1241 Large Shipping (102×51mm)', w: 102, h: 51 },
    dk2210: { name: 'DK-2210 Continuous 29mm (29×60mm)', w: 60, h: 29 }
  };
  var STORE_KEY = 'agrhodes_label_preset';
  var DEFAULT_PRESET = 'dk2205';

  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function getPreset() {
    var k = '';
    try { k = localStorage.getItem(STORE_KEY) || ''; } catch (_) {}
    return PRESETS[k] ? k : DEFAULT_PRESET;
  }
  function setPreset(k) {
    if (!PRESETS[k]) return;
    try { localStorage.setItem(STORE_KEY, k); } catch (_) {}
  }

  function presetOptionsHtml(selected) {
    var sel = selected || getPreset();
    return Object.keys(PRESETS).map(function(k) {
      return '<option value="' + k + '"' + (k === sel ? ' selected' : '') + '>' + esc(PRESETS[k].name) + '</option>';
    }).join('');
  }

  /** Black-on-white PNG of the code (high error correction survives scuffs). */
  function qrDataUrl(text) {
    var holder = document.createElement('div');
    holder.style.cssText = 'position:absolute;left:-9999px;top:0;';
    document.body.appendChild(holder);
    try {
      new QRCode(holder, {
        text: text, width: 360, height: 360,
        colorDark: '#000000', colorLight: '#ffffff',
        correctLevel: QRCode.CorrectLevel.H
      });
      var canvas = holder.querySelector('canvas');
      return canvas ? canvas.toDataURL('image/png') : '';
    } finally {
      holder.parentNode.removeChild(holder);
    }
  }

  function subLine(loc) {
    var area = loc.unit || loc.eoc_department || '';
    return loc.building ? (area ? area + ' · ' + loc.building : loc.building) : area;
  }

  function labelHtml(loc, img, p) {
    // Tall labels (62mm rolls): code on top, text under it. Wide labels: side by side.
    var tall = p.h >= 55 && p.w <= 70;
    var name = esc(loc.display_name || ('Room ' + (loc.room_number || '')));
    var sub = esc(subLine(loc));
    return '<div class="label ' + (tall ? 'tall' : 'wide') + '">' +
      '<img src="' + img + '" alt="">' +
      '<div class="txt"><div class="name">' + name + '</div>' + (sub ? '<div class="sub">' + sub + '</div>' : '') + '</div>' +
    '</div>';
  }

  /**
   * Print one or many labels in a single job.
   * locs: room_qr_codes rows · baseUrl: the page's BASE_URL ('…/round.html#round=')
   */
  function print(locs, baseUrl, presetKey) {
    locs = (locs || []).filter(function(l) { return l && l.qr_identifier; });
    if (!locs.length) { alert('No QR codes to print.'); return; }
    if (typeof QRCode === 'undefined') { alert('The QR code library hasn\'t loaded yet — try again in a moment.'); return; }
    var key = PRESETS[presetKey] ? presetKey : getPreset();
    var p = PRESETS[key];
    var win = window.open('', '_blank', 'width=520,height=600');
    if (!win) { alert('Please allow pop-ups for this site to print labels.'); return; }

    var pages = locs.map(function(loc) { return labelHtml(loc, qrDataUrl(baseUrl + loc.qr_identifier), p); }).join('');
    var tallQr = Math.min(p.w, p.h) - 18;   // leave room for two text lines
    win.document.write(
      '<!DOCTYPE html><html><head><meta charset="utf-8"><title>' + locs.length + ' label' + (locs.length === 1 ? '' : 's') +
        ' — ' + esc(p.name) + '</title><style>' +
      '@page { size: ' + p.w + 'mm ' + p.h + 'mm; margin: 0; }' +
      '*{box-sizing:border-box;} html,body{margin:0;padding:0;background:#fff;color:#000;}' +
      '.label{width:' + p.w + 'mm;height:' + p.h + 'mm;overflow:hidden;font-family:Arial,Helvetica,sans-serif;' +
        'display:flex;align-items:center;justify-content:center;page-break-after:always;break-after:page;}' +
      '.label:last-child{page-break-after:auto;break-after:auto;}' +
      '.wide{gap:2.5mm;padding:1.5mm;}' +
      '.wide img{height:' + (p.h - 3) + 'mm;width:auto;flex-shrink:0;image-rendering:pixelated;}' +
      '.wide .txt{min-width:0;}' +
      '.tall{flex-direction:column;gap:1.5mm;padding:2mm;}' +
      '.tall img{width:' + tallQr + 'mm;height:' + tallQr + 'mm;image-rendering:pixelated;}' +
      '.tall .txt{text-align:center;}' +
      '.name{font-size:' + (p.h > 40 ? '13pt' : '9pt') + ';font-weight:700;line-height:1.1;word-break:break-word;}' +
      '.sub{font-size:' + (p.h > 40 ? '8.5pt' : '6.5pt') + ';margin-top:0.6mm;line-height:1.15;}' +
      '</style></head><body>' + pages +
      '<script>window.onload=function(){setTimeout(function(){window.print();},250);};<\/script>' +
      '</body></html>'
    );
    win.document.close();
  }

  /** Labels for every room code currently listed (building filter respected), hall by hall. */
  function printListed(rooms, prefix, baseUrl, presetKey) {
    var B = window.ZoneBuildings;
    var f = B ? B.getFilter(prefix) : '';
    var list = [];
    (B ? B.groups(rooms, prefix) : [{ building: '', halls: [] }]).forEach(function(g) {
      if (f && g.building !== f) return;
      g.halls.forEach(function(h) {
        (rooms || []).filter(function(r) { return r.unit === h; })
          .sort(function(a, b) { return String(a.room_number).localeCompare(String(b.room_number), undefined, { numeric: true }); })
          .forEach(function(r) { list.push(r); });
      });
    });
    if (!list.length) { alert('No room codes are listed to print.'); return; }
    var key = PRESETS[presetKey] ? presetKey : getPreset();
    setPreset(key);
    if (!confirm('Print ' + list.length + ' label' + (list.length === 1 ? '' : 's') + (f ? ' for ' + f : '') +
        ' on ' + PRESETS[key].name + '?\n\nIn the print dialog choose your Brother QL printer and the matching label size.')) return;
    print(list, baseUrl, key);
  }

  window.ZoneLabels = {
    printListed: printListed,
    PRESETS: PRESETS,
    getPreset: getPreset,
    setPreset: setPreset,
    presetOptionsHtml: presetOptionsHtml,
    qrDataUrl: qrDataUrl,
    print: print
  };
})();
