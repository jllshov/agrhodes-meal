/*
  Private Zone Defense photos.
  savePrivatePhoto() shrinks a photo in the browser (max 1600 px JPEG, which also drops
  GPS / camera data) and sends it to Nursiao, which keeps it in private storage.
  It answers { id, facilityId }, or null when private storage isn't set up yet — the
  page then keeps its old upload. Opening a photo needs a Nursiao login.
*/
(function() {
  'use strict';
  // Atlanta's pages are served by Nursiao itself (/...); DeKalb and Cobb post to nursiao.com.
  var ORIGIN = /^\/meal\//.test(window.location.pathname) ? '' : 'https://nursiao.com';
  var MAX_SIDE = 1600;

  function shrink(file) {
    return new Promise(function(resolve) {
      if (!file || !/^image\//.test(file.type || 'image/')) return resolve(file);
      var url = URL.createObjectURL(file);
      var img = new Image();
      img.onload = function() {
        var scale = Math.min(1, MAX_SIDE / Math.max(img.naturalWidth, img.naturalHeight));
        var canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(img.naturalWidth * scale));
        canvas.height = Math.max(1, Math.round(img.naturalHeight * scale));
        canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(url);
        canvas.toBlob(function(blob) { resolve(blob || file); }, 'image/jpeg', 0.85);
      };
      img.onerror = function() { URL.revokeObjectURL(url); resolve(file); };
      img.src = url;
    });
  }

  /** fields: zone_facility_id, kind, qr_identifier, employee_number | inventory_id. Throws Error(message) on failure. */
  window.savePrivatePhoto = async function(file, fields) {
    var blob = await shrink(file);
    var fd = new FormData();
    fd.append('photo', blob, blob === file ? (file.name || 'photo.jpg') : 'photo.jpg');
    Object.keys(fields || {}).forEach(function(k) {
      if (fields[k] != null && fields[k] !== '') fd.append(k, String(fields[k]));
    });
    var res;
    try {
      res = await fetch(ORIGIN + '/api/zone-photos', { method: 'POST', body: fd });
    } catch (e) {
      throw new Error('No connection to Nursiao');
    }
    var data = {};
    try { data = await res.json(); } catch (_) {}
    if (res.status === 409 && data.error === 'photos_not_configured') return null;
    if (!res.ok || !data.id) throw new Error(data.error || ('error ' + res.status));
    return { id: data.id, facilityId: data.facilityId };
  };

  /** Link that opens a private photo (asks for a Nursiao login). */
  window.privatePhotoUrl = function(facilityId, id) {
    var ok = /^[0-9a-f-]{36}$/i;
    if (!ok.test(String(facilityId || '')) || !ok.test(String(id || ''))) return '';
    return (ORIGIN || window.location.origin) + '/photos/' + facilityId + '/' + id;
  };

  /** Photo link for a cleaning round's scores: private photo first, else an old public link. */
  window.admissionPhotoHref = function(scores) {
    scores = scores || {};
    if (scores.admission_photo_id) return window.privatePhotoUrl(scores.admission_photo_facility, scores.admission_photo_id);
    return /^https:\/\//.test(String(scores.admission_photo_url || '')) ? String(scores.admission_photo_url) : '';
  };
})();
