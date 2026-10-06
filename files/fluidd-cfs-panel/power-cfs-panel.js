/*
 * PowerUI CFS card for Fluidd.
 *
 * A card with the look of the Fluidd dashboard cards that shows the four slots of the CFS (a
 * spool in the real color, the material, the remaining filament and the loaded slot) and the
 * humidity and temperature of the box. Click a spool to edit its material and color.
 *
 * It starts docked in the dashboard, under the cards of its column. The button in its title bar
 * undocks it into a floating card that can be dragged anywhere; the same button docks it again.
 * The mode, the position and the collapsed state are kept in this browser.
 *
 * It talks to Moonraker only (the Klipper "box" object and the gcode script endpoint), so it does
 * not need the Creality web-server (port 9999). Colors and fonts come from the Fluidd theme.
 *
 * The slot data follows PowerScreen (src/cfs_model.cpp, src/cfs_panel.cpp):
 *   color_value    "0RRGGBB" (7 characters), "unknown" (spool without RFID) or "-1" (empty)
 *   material_type  id of Creality's material_database.json ("01001"), "unknown" or "-1"
 *   t_command      "T1A": the box and slot last selected by the printer
 * A slot is edited with the two commands the Creality interface sends:
 *   BOX_MODIFY_TN_DATA ADDR=<box> NUM=<A-D> PART=material_type DATA=<id>
 *   BOX_MODIFY_TN_DATA ADDR=<box> NUM=<A-D> PART=color_value DATA=0RRGGBB   (never with "#")
 */
(function () {
  "use strict";

  if (window.__power_cfs_panel_loaded) return;
  window.__power_cfs_panel_loaded = true;

  var CARD_ID = "power-cfs-card";
  var STYLE_ID = "power-cfs-style";
  var STORE_KEY = "power-cfs-panel";
  var POLL_MS = 3000;
  var POLL_ABSENT_MS = 30000;
  var MOUNT_MS = 1200;
  var AUTOFLOAT_MS = 15000;
  var VERIFY_MS = 2500;
  var VERIFY_TRIES = 3;
  var CUSTOM_FILE_URL = "/server/files/config/Helper-Script/cfs-custom-materials.json";
  var CUSTOM_REFRESH_MS = 30000;
  var MARGIN = 8;
  var SLOT_LETTERS = ["A", "B", "C", "D"];
  var PALETTE = ["#ffffff", "#2b2b2b", "#9ca3af", "#ef4444", "#f97316", "#eab308", "#22c55e", "#3b82f6", "#8b5cf6", "#ec4899"];

  // id: [brand, name, type, default color, min temp, max temp, nozzle temp].
  // Source: material_database.json of the K1C (V2.3.5.34).
  var MATERIALS = {
    "01001": ["Creality", "Hyper PLA", "PLA", "#ffffff", 190, 240, 220],
    "02001": ["Creality", "Hyper PLA-CF", "PLA-CF", "#ffffff", 190, 240, 220],
    "06002": ["Creality", "Hyper PETG", "PETG", "", 220, 270, 250],
    "03001": ["Creality", "Hyper ABS", "ABS", "", 240, 280, 260],
    "04001": ["Creality", "CR-PLA", "PLA", "#ffffff", 190, 240, 220],
    "05001": ["Creality", "CR-Silk", "PLA", "#ffffff", 190, 240, 220],
    "06001": ["Creality", "CR-PETG", "PETG", "", 220, 270, 250],
    "07001": ["Creality", "CR-ABS", "ABS", "", 240, 280, 260],
    "00001": ["Generic", "Generic PLA", "PLA", "", 190, 240, 220],
    "00002": ["Generic", "Generic PLA-Silk", "PLA", "", 190, 240, 220],
    "00003": ["Generic", "Generic PETG", "PETG", "", 220, 270, 250],
    "00004": ["Generic", "Generic ABS", "ABS", "", 240, 280, 260],
    "00005": ["Generic", "Generic TPU", "TPU", "", 210, 240, 230],
    "00006": ["Generic", "Generic PLA-CF", "PLA-CF", "", 190, 240, 220],
    "00007": ["Generic", "Generic ASA", "ASA", "", 240, 280, 270],
    "08001": ["Creality", "Ender-PLA", "PLA", "#ffffff", 190, 240, 220],
    "09001": ["Creality", "EN-PLA+", "PLA", "#ffffff", 190, 240, 220],
    "10001": ["Creality", "HP-TPU", "TPU", "#ffffff", 190, 240, 220],
    "11001": ["Creality", "CR-Nylon", "PA", "#ffffff", 250, 270, 260],
    "13001": ["Creality", "CR-PLA Carbon", "PLA-CF", "#ffffff", 190, 240, 220],
    "14001": ["Creality", "CR-PLA Matte", "PLA", "#ffffff", 190, 240, 220],
    "15001": ["Creality", "CR-PLA Fluo", "PLA", "#ffffff", 190, 240, 230],
    "16001": ["Creality", "CR-TPU", "TPU", "#ffffff", 210, 240, 220],
    "17001": ["Creality", "CR-Wood", "PLA", "#ffffff", 190, 240, 230],
    "18001": ["Creality", "HP Ultra PLA", "PLA", "#ffffff", 190, 240, 230],
    "19001": ["Creality", "HP-ASA", "ASA", "#ffffff", 240, 280, 270],
    "00008": ["Generic", "Generic PA", "PA", "", 240, 260, 260],
    "00009": ["Generic", "Generic PA-CF", "PA-CF", "", 260, 300, 280],
    "00010": ["Generic", "Generic BVOH", "BVOH", "", 200, 220, 210],
    "00011": ["Generic", "Generic PVA", "PVA", "#ffffff", 215, 225, 220],
    "00012": ["Generic", "Generic HIPS", "HIPS", "", 220, 250, 240],
    "00013": ["Generic", "Generic PET-CF", "PET-CF", "", 280, 320, 290],
    "00014": ["Generic", "Generic PETG-CF", "PETG-CF", "", 240, 260, 250],
    "00015": ["Generic", "Generic PA6-CF", "PA-CF", "", 280, 300, 290],
    "00016": ["Generic", "Generic PAHT-CF", "PA-CF", "", 300, 320, 300],
    "00017": ["Generic", "Generic PPS", "PPS", "", 320, 350, 320],
    "00018": ["Generic", "Generic PPS-CF", "PPS-CF", "", 300, 350, 305],
    "00019": ["Generic", "Generic PP", "PP", "", 220, 260, 240],
    "00020": ["Generic", "Generic PET", "PET", "", 250, 270, 220],
    "00021": ["Generic", "Generic PC", "PC", "", 250, 270, 260],
    "12003": ["Creality", "Hyper PAHT-CF", "PA-CF", "", 280, 320, 300],
    "01601": ["Creality", "Soleyin Ultra PLA", "PLA", "#ffffff", 190, 240, 220],
    "06003": ["Creality", "Hyper PETG-CF", "PETG-CF", "", 240, 260, 250],
    "01004": ["Creality", "Hyper Stardust", "PLA", "#ffffff", 190, 240, 220],
    "01002": ["Creality", "Hyper L-W PLA", "PLA", "#ffffff", 200, 270, 220],
    "06004": ["Creality", "Hyper PETG-GF", "PETG-GF", "", 240, 260, 250],
    "29001": ["Creality", "Hyper Marble", "PLA", "#ffffff", 190, 240, 220],
    "01003": ["Creality", "Hyper Luminous", "PLA", "#ffffff", 190, 230, 220],
    "06005": ["Creality", "Soleyin Basic PETG", "PETG", "", 230, 250, 250]
  };

  // Material Design Icons paths (the same icon set Fluidd uses).
  var ICONS = {
    drop: "M12 3C12 3 5.5 10.2 5.5 14.5a6.5 6.5 0 0 0 13 0C18.5 10.2 12 3 12 3z",
    thermo: "M10 4a2 2 0 0 1 4 0v9.3a4 4 0 1 1-4 0V4zm2 14.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z",
    chevronUp: "M7.41,15.41L12,10.83L16.59,15.41L18,14L12,8L6,14L7.41,15.41Z",
    undock: "M14,3V5H17.59L7.76,14.83L9.17,16.24L19,6.41V10H21V3M19,19H5V5H12V3H5C3.89,3 3,3.9 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V12H19V19Z",
    dock: "M4 4h16v10H4V4zm2 2v6h12V6H6zm5 12h2v2h-2v-2z",
    close: "M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"
  };

  var card, badgesEl, bodyEl, collapseBtn, modeBtn, headEl;
  var modal = null;
  var prefs = { mode: "docked", x: null, y: null, collapsed: false };
  var latest = null;
  var CUSTOM = {};          // ids of the custom filaments (from cfs-custom-materials.json)
  var macrosReady = false;  // the CFS_ADD_MATERIAL macro exists (module "CFS Custom Filaments" installed)
  var lastSignature = "";
  var pollTimer = null;
  var noDockSince = 0;
  var autoFloat = false;

  // ---------- Storage (per browser, never required) ----------

  function loadPrefs() {
    try {
      var saved = JSON.parse(window.localStorage.getItem(STORE_KEY) || "null");
      if (saved && typeof saved === "object") {
        if (saved.mode === "floating") prefs.mode = "floating";
        if (typeof saved.x === "number" && typeof saved.y === "number") {
          prefs.x = saved.x;
          prefs.y = saved.y;
        }
        prefs.collapsed = !!saved.collapsed;
      }
    } catch (e) {}
  }

  function savePrefs() {
    try {
      window.localStorage.setItem(STORE_KEY, JSON.stringify(prefs));
    } catch (e) {}
  }

  // ---------- Data ----------

  function isNone(s) {
    return s === "" || s === "-1" || s === "none" || s === "None" || s === undefined || s === null;
  }

  // Accepts "#RRGGBB", "RRGGBB" and "0RRGGBB". Returns "#rrggbb" or "".
  function parseColor(raw) {
    var s = String(raw === undefined || raw === null ? "" : raw).trim();
    if (s.charAt(0) === "#") s = s.slice(1);
    else if (s.length === 7 && s.charAt(0) === "0") s = s.slice(1);
    return /^[0-9a-fA-F]{6}$/.test(s) ? "#" + s.toLowerCase() : "";
  }

  function parseLength(raw) {
    var s = String(raw === undefined || raw === null ? "" : raw);
    return /^[0-9]+$/.test(s) ? parseInt(s, 10) : -1;
  }

  function parseNumber(raw) {
    var n = Number(raw);
    return raw !== "" && raw !== null && raw !== undefined && isFinite(n) && n >= 0 ? Math.round(n) : null;
  }

  function fieldAt(list, i) {
    return list && list[i] !== undefined && list[i] !== null ? String(list[i]) : "";
  }

  function parseSlot(unit, i) {
    var vender = fieldAt(unit.vender, i);
    var mat = fieldAt(unit.material_type, i);
    var col = fieldAt(unit.color_value, i);
    var slot = {
      kind: "empty", id: "", title: "Empty", detail: "", color: parseColor(col), remain: parseLength(fieldAt(unit.remain_len, i))
    };

    var hasMaterial = !isNone(mat) && mat !== "unknown";
    var hasVender = !isNone(vender) && vender !== "unknown";
    var anyUnknown = vender === "unknown" || mat === "unknown" || col === "unknown";

    if (hasMaterial) {
      slot.kind = "defined";
      slot.id = mat;
      var entry = MATERIALS[mat];
      if (entry) {
        slot.title = entry[2] || entry[1];
        // "Generic PLA" only repeats the type: show the name for the branded materials.
        slot.detail = entry[0] === "Generic" ? "" : entry[0] + " " + entry[1];
        if (!slot.color) slot.color = parseColor(entry[3]);
      } else {
        slot.title = "Material " + mat;
      }
      if (hasVender && !slot.detail) slot.detail = vender;
    } else if (slot.color || anyUnknown || hasVender) {
      slot.kind = "unset";
      slot.title = "Not set";
      if (hasVender) slot.detail = vender;
    }
    return slot;
  }

  // Returns null when the printer has no CFS object, otherwise { connected, printing, units: [...] }.
  function parseStatus(status) {
    var box = status && status.box;
    if (!box || typeof box !== "object") return null;
    var printState = status.print_stats && status.print_stats.state;
    var result = { connected: box.state === "connect", printing: printState === "printing" || printState === "paused", units: [] };
    if (!result.connected) return result;

    var active = null;
    var tCommand = String(box.t_command || "");
    if (/^T[1-4][A-Da-d]$/.test(tCommand)) {
      active = { box: parseInt(tCommand.charAt(1), 10), slot: tCommand.charAt(2).toUpperCase().charCodeAt(0) - 65 };
    }

    for (var n = 1; n <= 4; n++) {
      var unit = box["T" + n];
      if (!unit || typeof unit !== "object" || unit.state !== "connect") continue;
      var slots = [];
      for (var i = 0; i < 4; i++) slots.push(parseSlot(unit, i));
      var version = String(unit.version || "");
      result.units.push({
        id: n,
        version: version === "-1" ? "" : version,
        humidity: parseNumber(unit.dry_and_humidity),
        temperature: parseNumber(unit.temperature),
        active: active && active.box === n ? active.slot : -1,
        slots: slots
      });
    }
    return result;
  }

  function fetchStatus() {
    return fetch("/printer/objects/query?box&print_stats", { credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) throw new Error("HTTP " + response.status);
        return response.json();
      })
      .then(function (json) {
        return parseStatus(json && json.result && json.result.status);
      });
  }

  function runScript(script) {
    return fetch("/printer/gcode/script", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ script: script })
    }).then(function (response) {
      if (!response.ok) throw new Error("Moonraker answered HTTP " + response.status);
    });
  }

  // The custom filaments live in a file of the config folder (written by the CFS Custom Filaments
  // module): merge them into the table of materials.
  // Resolves true when the list was read. Only a missing file (404: nothing was ever added) empties the
  // list: when Moonraker is busy or restarting the filaments already known are kept and false is returned.
  function loadCustom() {
    return fetch(CUSTOM_FILE_URL + "?t=" + Date.now(), { credentials: "same-origin", cache: "no-store" })
      .then(function (response) {
        if (response.status === 404) return { materials: [] };
        if (!response.ok) throw new Error("HTTP " + response.status);
        return response.json();
      })
      .then(function (json) {
        Object.keys(CUSTOM).forEach(function (id) { delete MATERIALS[id]; });
        CUSTOM = {};
        var list = json && Array.isArray(json.materials) ? json.materials : [];
        list.forEach(function (m) {
          if (!m || !/^9[0-9]{4}$/.test(String(m.id))) return;
          MATERIALS[m.id] = [String(m.brand), String(m.name), String(m.type), parseColor(m.color), Number(m.min) || 0, Number(m.max) || 0, Number(m.nozzle) || 0];
          CUSTOM[m.id] = true;
        });
        return true;
      })
      .catch(function () { return false; });
  }

  function checkMacros() {
    return fetch("/printer/objects/list", { credentials: "same-origin" })
      .then(function (response) { return response.ok ? response.json() : null; })
      .then(function (json) {
        var objects = json && json.result && json.result.objects;
        macrosReady = Array.isArray(objects) && objects.indexOf("gcode_macro CFS_ADD_MATERIAL") >= 0;
      })
      .catch(function () {});
  }

  // Calls check() until it answers true: the helper of the printer works on its own, after the macro returned.
  function waitFor(check, tries, delay) {
    return check().then(function (done) {
      if (done || tries <= 1) return done;
      return new Promise(function (resolve) { window.setTimeout(resolve, delay); }).then(function () { return waitFor(check, tries - 1, delay); });
    });
  }

  // The helper writes its result (OK: or ERROR:) in the console of Klipper.
  function lastHelperMessage() {
    return fetch("/server/gcode_store?count=30", { credentials: "same-origin" })
      .then(function (response) { return response.ok ? response.json() : null; })
      .then(function (json) {
        var lines = (json && json.result && json.result.gcode_store) || [];
        for (var i = lines.length - 1; i >= 0; i--) {
          var text = String(lines[i].message || "");
          if (/^(\/\/ )?ERROR: /.test(text)) return text.replace(/^\/\/ /, "");
        }
        return "";
      })
      .catch(function () { return ""; });
  }

  // ---------- Interface helpers ----------

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function svg(path, className) {
    var s = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    s.setAttribute("viewBox", "0 0 24 24");
    if (className) s.setAttribute("class", className);
    var p = document.createElementNS("http://www.w3.org/2000/svg", "path");
    p.setAttribute("d", path);
    s.appendChild(p);
    return s;
  }

  // Round icon button built with the Vuetify classes Fluidd uses, so it looks like its own.
  function iconButton(path, title) {
    var btn = el("button", "v-btn v-btn--icon v-btn--round theme--dark v-size--default");
    btn.type = "button";
    btn.title = title;
    var content = el("span", "v-btn__content");
    var ic = el("span", "v-icon notranslate v-icon--dense theme--dark");
    ic.appendChild(svg(path, "v-icon__svg"));
    content.appendChild(ic);
    btn.appendChild(content);
    return btn;
  }

  function setButtonIcon(btn, path) {
    var holder = btn.querySelector(".v-icon");
    if (!holder) return;
    holder.textContent = "";
    holder.appendChild(svg(path, "v-icon__svg"));
  }

  function textButton(label, primary) {
    var btn = el("button", "v-btn theme--dark v-size--default " + (primary ? "v-btn--has-bg primary" : "v-btn--text"));
    btn.type = "button";
    btn.appendChild(el("span", "v-btn__content", label));
    return btn;
  }

  function addStyles() {
    if (document.getElementById(STYLE_ID)) return;
    var c = "#" + CARD_ID;
    var muted = "rgba(255,255,255,.6)";
    var line = "rgba(255,255,255,.1)";
    var css = [
      c + "{overflow:hidden}",
      c + " *{box-sizing:border-box}",
      c + ".pcfs-floating{position:fixed;z-index:1000;width:min(420px,calc(100vw - 16px));margin:0!important;box-shadow:none!important;font-family:Roboto,sans-serif;font-size:1rem;line-height:1.5}",
      c + ".pcfs-floating .card-heading{cursor:grab;touch-action:none;user-select:none}",
      c + ".pcfs-floating.pcfs-dragging .card-heading{cursor:grabbing}",
      c + " .pcfs-body{padding:16px}",
      c + ".pcfs-collapsed .pcfs-body{display:none}",
      c + " .pcfs-row{display:flex;align-items:center;gap:8px}",
      c + " .pcfs-badge{display:flex;align-items:center;gap:6px;background:rgba(255,255,255,.06);padding:6px 12px;border-radius:16px;font-size:.8125rem;font-weight:500;line-height:1}",
      c + " .pcfs-badge svg{width:16px;height:16px;fill:currentColor}",
      c + " .pcfs-badge.humidity{color:var(--v-info-base,#2196f3)}",
      c + " .pcfs-badge.temperature{color:var(--v-warning-base,#fb8c00)}",
      c + " .pcfs-chevron svg{transition:transform .2s ease}",
      c + ".pcfs-collapsed .pcfs-chevron svg{transform:rotate(180deg)}",
      c + " .pcfs-unit-title{display:flex;justify-content:space-between;color:" + muted + ";font-size:.75rem;font-weight:500;letter-spacing:.05em;text-transform:uppercase;margin:0 0 8px}",
      c + " .pcfs-unit-title:not(:first-child){margin-top:16px}",
      c + " .pcfs-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}",
      c + " .pcfs-tile{position:relative;background:rgba(255,255,255,.04);border:1px solid " + line + ";border-radius:8px;padding:12px;display:flex;align-items:center;gap:12px;min-width:0;cursor:pointer;transition:background .2s ease,border-color .2s ease}",
      c + " .pcfs-tile:hover{background:rgba(255,255,255,.08)}",
      c + " .pcfs-tile.active{border-color:var(--pcfs-spool,var(--v-success-base,#4caf50))}",
      c + " .pcfs-tile.empty{opacity:.5;cursor:default}",
      c + " .pcfs-tile.empty:hover{background:rgba(255,255,255,.04)}",
      c + " .pcfs-dot{position:absolute;top:6px;right:6px;width:7px;height:7px;border-radius:50%;background:var(--v-success-base,#4caf50);box-shadow:0 0 5px var(--v-success-base,#4caf50)}",
      c + " .pcfs-spool{width:44px;height:44px;border-radius:50%;background:var(--pcfs-spool,#4b5563);display:flex;align-items:center;justify-content:center;flex:none;box-shadow:inset 0 0 0 3px rgba(255,255,255,.15),inset 0 0 10px rgba(0,0,0,.6)}",
      c + " .pcfs-spool::after{content:'';width:12px;height:12px;border-radius:50%;background:#1c1c1c;box-shadow:inset 0 2px 4px rgba(0,0,0,.8)}",
      c + " .pcfs-info{display:flex;flex-direction:column;min-width:0}",
      c + " .pcfs-channel{font-size:.6875rem;color:" + muted + ";font-weight:500;letter-spacing:.05em;text-transform:uppercase}",
      c + " .pcfs-type{font-size:1.125rem;font-weight:500;line-height:1.2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      c + " .pcfs-detail{font-size:.75rem;color:" + muted + ";white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      c + " .pcfs-note{color:" + muted + ";padding:4px 2px}",
      "@media (max-width:480px){" + c + " .pcfs-grid{grid-template-columns:1fr}}",

      ".pcfs-overlay{position:fixed;inset:0;z-index:2000;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;padding:16px;font-family:Roboto,sans-serif;font-size:1rem;line-height:1.5}",
      ".pcfs-dialog{width:min(440px,100%);max-height:100%;overflow:auto;box-shadow:none!important}",
      ".pcfs-dialog *{box-sizing:border-box}",
      ".pcfs-dialog .pcfs-dialog-head{display:flex;align-items:center;justify-content:space-between;padding:8px 8px 8px 16px;border-bottom:thin solid " + line + ";font-size:1.125rem}",
      ".pcfs-dialog .pcfs-dialog-body{padding:16px;display:flex;flex-direction:column;gap:14px}",
      ".pcfs-dialog .pcfs-field{display:grid;grid-template-columns:96px 1fr;align-items:center;gap:12px}",
      ".pcfs-dialog label{color:" + muted + ";font-size:.875rem}",
      ".pcfs-dialog select{width:100%;appearance:none;background:rgba(255,255,255,.06);color:inherit;border:1px solid " + line + ";border-radius:4px;padding:8px 10px;font:inherit;font-size:.875rem;outline:none}",
      ".pcfs-dialog select:focus{border-color:var(--v-primary-base,#2196f3)}",
      ".pcfs-dialog select option{background:#262629;color:#fff}",
      ".pcfs-dialog .pcfs-temps{color:" + muted + ";font-size:.875rem}",
      ".pcfs-dialog .pcfs-colorrow{display:flex;align-items:center;gap:12px;margin-bottom:14px}",
      ".pcfs-dialog .pcfs-swatch{width:36px;height:36px;border-radius:50%;border:2px solid " + line + ";padding:0;overflow:hidden;cursor:pointer;background:none}",
      ".pcfs-dialog .pcfs-swatch input{width:200%;height:200%;margin:-25%;padding:0;border:0;cursor:pointer;background:none}",
      ".pcfs-dialog .pcfs-hex{font-size:.875rem;color:" + muted + ";font-variant-numeric:tabular-nums}",
      ".pcfs-dialog .pcfs-palette{display:flex;gap:8px;flex-wrap:wrap}",
      ".pcfs-dialog .pcfs-chip{width:22px;height:22px;border-radius:50%;border:2px solid " + line + ";padding:0;cursor:pointer}",
      ".pcfs-dialog .pcfs-status{min-height:1.5em;font-size:.875rem;color:" + muted + "}",
      ".pcfs-dialog .pcfs-status.error{color:var(--v-error-base,#ff5252)}",
      ".pcfs-dialog .pcfs-status.ok{color:var(--v-success-base,#4caf50)}",
      ".pcfs-dialog .pcfs-actions{display:flex;justify-content:flex-end;gap:8px;padding:8px 16px 16px}",
      ".pcfs-dialog input[type=text],.pcfs-dialog input[type=number]{width:100%;background:rgba(255,255,255,.06);color:inherit;border:1px solid " + line + ";border-radius:4px;padding:8px 10px;font:inherit;font-size:.875rem;outline:none}",
      ".pcfs-dialog input[type=text]:focus,.pcfs-dialog input[type=number]:focus{border-color:var(--v-primary-base,#2196f3)}",
      ".pcfs-dialog .pcfs-extra{display:flex;justify-content:flex-end;gap:8px;margin-top:-6px}",
      ".pcfs-dialog .pcfs-temprow{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}",
      ".pcfs-dialog .pcfs-tempcell label{display:block;font-size:.75rem;margin-bottom:2px}",
      ".pcfs-dialog .pcfs-hint{color:" + muted + ";font-size:.8125rem}",
      ".pcfs-dialog .v-btn[disabled]{opacity:.4;pointer-events:none}"
    ].join("");
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = css;
    document.head.appendChild(style);
  }

  // ---------- Card ----------

  function build() {
    card = el("div", "mb-2 mb-md-4 v-card v-sheet theme--dark rounded-md collapsable-card");
    card.id = CARD_ID;

    headEl = el("header", "v-card__title collapsable-card-title card-heading");
    var row = el("div", "row flex-nowrap no-gutters align-center");
    row.style.width = "100%";
    row.style.margin = "0";

    var title = el("div", "text-no-wrap col align-self-center");
    title.appendChild(el("span", "font-weight-light", "CFS"));
    row.appendChild(title);

    badgesEl = el("div", "col col-auto align-self-center pcfs-row");
    row.appendChild(badgesEl);

    var buttons = el("div", "col col-auto align-self-center pcfs-row");
    modeBtn = iconButton(ICONS.undock, "Undock");
    modeBtn.addEventListener("click", toggleMode);
    collapseBtn = iconButton(ICONS.chevronUp, "Collapse");
    collapseBtn.className += " pcfs-chevron";
    collapseBtn.addEventListener("click", toggleCollapsed);
    buttons.appendChild(modeBtn);
    buttons.appendChild(collapseBtn);
    row.appendChild(buttons);

    headEl.appendChild(row);
    bodyEl = el("div", "v-card__text pcfs-body");
    card.appendChild(headEl);
    card.appendChild(bodyEl);

    applyCollapsed();
    updateModeButton();
    enableDrag();
  }

  function isFloating() {
    return prefs.mode === "floating" || autoFloat;
  }

  function updateModeButton() {
    if (!modeBtn) return;
    var floating = isFloating();
    setButtonIcon(modeBtn, floating ? ICONS.dock : ICONS.undock);
    modeBtn.title = floating ? "Dock to the dashboard" : "Undock";
  }

  function toggleMode() {
    prefs.mode = isFloating() ? "docked" : "floating";
    autoFloat = false;
    noDockSince = 0;
    updateModeButton();
    ensureMounted();
    savePrefs();
  }

  function applyCollapsed() {
    // "collapsed" is the class Fluidd gives its own collapsed cards (it removes the title shadow).
    card.classList.toggle("collapsed", prefs.collapsed);
    card.classList.toggle("pcfs-collapsed", prefs.collapsed);
    collapseBtn.title = prefs.collapsed ? "Expand" : "Collapse";
  }

  function toggleCollapsed() {
    prefs.collapsed = !prefs.collapsed;
    applyCollapsed();
    if (isFloating()) clampPosition();
    savePrefs();
  }

  // ---------- Floating card ----------

  function clampPosition() {
    var maxX = Math.max(MARGIN, window.innerWidth - card.offsetWidth - MARGIN);
    var maxY = Math.max(MARGIN, window.innerHeight - card.offsetHeight - MARGIN);
    if (prefs.x === null || prefs.y === null) {
      // First time: bottom right corner.
      prefs.x = maxX - 10;
      prefs.y = maxY - 10;
    }
    prefs.x = Math.min(Math.max(MARGIN, prefs.x), maxX);
    prefs.y = Math.min(Math.max(MARGIN, prefs.y), maxY);
    card.style.left = prefs.x + "px";
    card.style.top = prefs.y + "px";
  }

  function enableDrag() {
    var startX = 0, startY = 0, originX = 0, originY = 0, dragging = false;

    headEl.addEventListener("pointerdown", function (event) {
      if (!isFloating()) return;
      if (event.button !== undefined && event.button !== 0) return;
      if (event.target && event.target.closest && event.target.closest("button")) return;
      dragging = true;
      startX = event.clientX;
      startY = event.clientY;
      originX = prefs.x;
      originY = prefs.y;
      card.classList.add("pcfs-dragging");
      try { headEl.setPointerCapture(event.pointerId); } catch (e) {}
      event.preventDefault();
    });

    headEl.addEventListener("pointermove", function (event) {
      if (!dragging) return;
      prefs.x = originX + event.clientX - startX;
      prefs.y = originY + event.clientY - startY;
      clampPosition();
    });

    function stop(event) {
      if (!dragging) return;
      dragging = false;
      card.classList.remove("pcfs-dragging");
      try { headEl.releasePointerCapture(event.pointerId); } catch (e) {}
      savePrefs();
    }
    headEl.addEventListener("pointerup", stop);
    headEl.addEventListener("pointercancel", stop);

    window.addEventListener("resize", function () {
      if (card && isFloating()) clampPosition();
    });
  }

  // ---------- Placement ----------

  function onDashboard() {
    var path = String(window.location.pathname || "").replace(/\/+$/, "");
    var hash = String(window.location.hash || "").replace(/\?.*$/, "").replace(/\/+$/, "");
    return (!path || path === "/") && (!hash || hash === "#" || hash === "#/");
  }

  // The card goes right after the draggable list of Fluidd, not inside it: Fluidd (vuedraggable)
  // counts the children of that list when the user reorders its cards.
  function findDock() {
    var lists = document.querySelectorAll("main .app-draggable.list-group");
    if (!lists.length) return null;
    var chosen = lists[0];
    for (var i = 0; i < lists.length; i++) {
      if (lists[i].querySelector("[role='tablist'], .v-tabs")) {
        chosen = lists[i];
        break;
      }
    }
    return chosen.parentNode ? { list: chosen, column: chosen.parentNode } : null;
  }

  function ensureMounted() {
    if (!card) return;

    if (autoFloat && prefs.mode === "docked" && findDock()) {
      autoFloat = false;
      updateModeButton();
    }

    if (isFloating()) {
      if (card.parentNode !== document.body) {
        document.body.appendChild(card);
        card.classList.add("pcfs-floating");
      }
      clampPosition();
      return;
    }

    card.classList.remove("pcfs-floating");
    card.style.left = "";
    card.style.top = "";

    if (!onDashboard()) {
      if (card.parentNode) card.parentNode.removeChild(card);
      noDockSince = 0;
      return;
    }

    var dock = findDock();
    if (!dock) {
      // The dashboard did not show up (other layout, slow page): show the card floating meanwhile.
      if (!noDockSince) noDockSince = Date.now();
      else if (Date.now() - noDockSince > AUTOFLOAT_MS) {
        autoFloat = true;
        updateModeButton();
        ensureMounted();
      }
      return;
    }
    noDockSince = 0;
    if (card.parentNode !== dock.column) {
      dock.column.insertBefore(card, dock.list.nextSibling);
    }
  }

  // ---------- Rendering ----------

  function renderUnit(unit, multiple) {
    var frag = document.createDocumentFragment();
    if (multiple) {
      var title = el("div", "pcfs-unit-title");
      title.appendChild(el("span", "", "Box " + unit.id));
      title.appendChild(el("span", "", unit.version ? "firmware " + unit.version : ""));
      frag.appendChild(title);
    }
    var grid = el("div", "pcfs-grid");
    unit.slots.forEach(function (slot, i) {
      var tile = el("div", "pcfs-tile" + (slot.kind === "empty" ? " empty" : "") + (unit.active === i ? " active" : ""));
      if (slot.color) tile.style.setProperty("--pcfs-spool", slot.color);
      tile.appendChild(el("div", "pcfs-spool"));
      var info = el("div", "pcfs-info");
      info.appendChild(el("span", "pcfs-channel", "Channel " + unit.id + SLOT_LETTERS[i]));
      info.appendChild(el("span", "pcfs-type", slot.title));
      var detail = [];
      if (slot.detail) detail.push(slot.detail);
      if (slot.remain >= 0) detail.push(slot.remain + " m");
      if (detail.length) info.appendChild(el("span", "pcfs-detail", detail.join(", ")));
      tile.appendChild(info);
      if (unit.active === i) tile.appendChild(el("div", "pcfs-dot"));
      if (slot.kind !== "empty") {
        tile.title = "Edit this spool";
        tile.addEventListener("click", function () { openEditor(unit, i); });
      }
      grid.appendChild(tile);
    });
    frag.appendChild(grid);
    return frag;
  }

  function badge(kind, path, text, title) {
    var b = el("div", "pcfs-badge " + kind);
    b.title = title;
    b.appendChild(svg(path));
    b.appendChild(el("span", "", text));
    return b;
  }

  function render(data) {
    var signature = JSON.stringify(data);
    if (signature === lastSignature) return;
    lastSignature = signature;

    bodyEl.textContent = "";
    badgesEl.textContent = "";

    if (!data.connected || !data.units.length) {
      bodyEl.appendChild(el("div", "pcfs-note", "CFS disconnected."));
    } else {
      var first = data.units[0];
      if (first.humidity !== null) badgesEl.appendChild(badge("humidity", ICONS.drop, first.humidity + "%", "Humidity " + first.humidity + "%"));
      if (first.temperature !== null) badgesEl.appendChild(badge("temperature", ICONS.thermo, first.temperature + "°C", "Temperature " + first.temperature + "°C"));
      data.units.forEach(function (unit) {
        bodyEl.appendChild(renderUnit(unit, data.units.length > 1));
      });
    }
    if (card && isFloating() && card.parentNode) clampPosition();
  }

  function removeCard() {
    closeEditor();
    if (card && card.parentNode) card.parentNode.removeChild(card);
    card = null;
    lastSignature = "";
    noDockSince = 0;
  }

  // ---------- Slot editor ----------

  function closeEditor() {
    if (modal && modal.parentNode) modal.parentNode.removeChild(modal);
    modal = null;
  }

  function uniq(list) {
    return list.filter(function (value, i) { return list.indexOf(value) === i; });
  }

  function materialIds() {
    return Object.keys(MATERIALS);
  }

  function brandsList() {
    return uniq(materialIds().map(function (id) { return MATERIALS[id][0]; }));
  }

  // The usual materials first, the rest in the order of the database.
  var TYPE_ORDER = ["PLA", "PETG", "ABS", "ASA", "TPU", "PA", "PC"];

  function sortTypes(types) {
    var rank = function (type) { var i = TYPE_ORDER.indexOf(type); return i < 0 ? TYPE_ORDER.length + types.indexOf(type) : i; };
    return types.slice().sort(function (a, b) { return rank(a) - rank(b); });
  }

  function typesList(brand) {
    return sortTypes(uniq(materialIds().filter(function (id) { return MATERIALS[id][0] === brand; }).map(function (id) { return MATERIALS[id][2]; })));
  }

  function allTypes() {
    return sortTypes(uniq(materialIds().map(function (id) { return MATERIALS[id][2]; })));
  }

  function namesList(brand, type) {
    return materialIds().filter(function (id) { return MATERIALS[id][0] === brand && MATERIALS[id][2] === type; });
  }

  function fillSelect(select, values, labels, selected) {
    select.textContent = "";
    values.forEach(function (value, i) {
      var option = el("option", "", labels ? labels[i] : value);
      option.value = value;
      if (value === selected) option.selected = true;
      select.appendChild(option);
    });
    if (selected !== undefined && values.indexOf(selected) >= 0) select.value = selected;
  }

  function field(label, control) {
    var row = el("div", "pcfs-field");
    row.appendChild(el("label", "", label));
    row.appendChild(control);
    return row;
  }

  // Color picker with a palette. onChange(value, byUser) is called on every change.
  function colorControl(initial, onChange) {
    var swatch = el("label", "pcfs-swatch");
    var picker = el("input");
    picker.type = "color";
    swatch.appendChild(picker);
    var hex = el("span", "pcfs-hex");
    var row = el("div", "pcfs-colorrow");
    row.appendChild(swatch);
    row.appendChild(hex);
    var palette = el("div", "pcfs-palette");
    var box = el("div");
    var api = {
      box: box,
      set: function (value, byUser) {
        picker.value = value;
        swatch.style.background = value;
        hex.textContent = value.toUpperCase();
        if (onChange) onChange(value, !!byUser);
      }
    };
    PALETTE.forEach(function (value) {
      var chip = el("button", "pcfs-chip");
      chip.type = "button";
      chip.title = value;
      chip.style.background = value;
      chip.addEventListener("click", function () { api.set(value, true); });
      palette.appendChild(chip);
    });
    picker.addEventListener("input", function () { api.set(picker.value, true); });
    box.appendChild(row);
    box.appendChild(palette);
    api.set(initial, false);
    return api;
  }

  function openEditor(unit, index, selectId) {
    closeEditor();
    var slot = unit.slots[index];
    var num = SLOT_LETTERS[index];

    var startId = MATERIALS[selectId] ? selectId : slot.id;
    var current = MATERIALS[startId];
    var brand = current ? current[0] : "Generic";
    var type = current ? current[2] : (typesList(brand)[0] || "");
    var materialId = current ? startId : (namesList(brand, type)[0] || "");
    // A filament just created comes with its own color; otherwise the spool keeps the one it has.
    var color = (selectId ? "" : slot.color) || parseColor(MATERIALS[materialId] && MATERIALS[materialId][3]) || "#ffffff";
    var colorTouched = !selectId && !!slot.color;
    var busy = false;

    modal = el("div", "pcfs-overlay");
    var dialog = el("div", "pcfs-dialog v-card v-sheet theme--dark rounded-md");
    modal.appendChild(dialog);

    var head = el("div", "pcfs-dialog-head");
    head.appendChild(el("span", "font-weight-light", "Channel " + unit.id + num));
    var closeBtn = iconButton(ICONS.close, "Close");
    head.appendChild(closeBtn);
    dialog.appendChild(head);

    var body = el("div", "pcfs-dialog-body");
    var brandSel = el("select");
    var typeSel = el("select");
    var nameSel = el("select");
    var temps = el("div", "pcfs-temps");
    body.appendChild(field("Brand", brandSel));
    body.appendChild(field("Material", typeSel));
    body.appendChild(field("Filament", nameSel));
    var extraRow = el("div", "pcfs-extra");
    var newBtn = textButton("New filament", false);
    var delBtn = textButton("Delete this filament", false);
    extraRow.appendChild(newBtn);
    extraRow.appendChild(delBtn);
    body.appendChild(extraRow);
    body.appendChild(field("Nozzle", temps));

    var cc = colorControl(color, function (value, byUser) {
      color = value;
      if (byUser) colorTouched = true;
    });
    body.appendChild(field("Color", cc.box));

    var status = el("div", "pcfs-status");
    if (latest && latest.printing) {
      status.textContent = "A print is in progress: the spools cannot be edited now.";
      status.className += " error";
    }
    body.appendChild(status);
    dialog.appendChild(body);

    var actions = el("div", "pcfs-actions");
    var cancelBtn = textButton("Cancel", false);
    var saveBtn = textButton("Save", true);
    actions.appendChild(cancelBtn);
    actions.appendChild(saveBtn);
    dialog.appendChild(actions);

    function setStatus(text, kind) {
      status.textContent = text;
      status.className = "pcfs-status" + (kind ? " " + kind : "");
    }

    function refreshInfo() {
      var entry = MATERIALS[materialId];
      temps.textContent = entry && entry[4] && entry[5] ? entry[4] + " - " + entry[5] + " °C" : "-";
      newBtn.style.display = macrosReady ? "" : "none";
      delBtn.style.display = macrosReady && CUSTOM[materialId] ? "" : "none";
      extraRow.style.display = macrosReady ? "" : "none";
    }

    function refreshNames() {
      var ids = namesList(brand, type);
      if (ids.indexOf(materialId) < 0) materialId = ids[0] || "";
      fillSelect(nameSel, ids, ids.map(function (id) { return MATERIALS[id][1]; }), materialId);
      refreshInfo();
    }

    function refreshTypes() {
      var types = typesList(brand);
      if (types.indexOf(type) < 0) type = types[0] || "";
      fillSelect(typeSel, types, null, type);
      refreshNames();
    }

    fillSelect(brandSel, brandsList(), null, brand);
    refreshTypes();

    brandSel.addEventListener("change", function () { brand = brandSel.value; refreshTypes(); });
    typeSel.addEventListener("change", function () { type = typeSel.value; refreshNames(); });
    nameSel.addEventListener("change", function () {
      materialId = nameSel.value;
      refreshInfo();
      // Until the user picks a color, follow the default color of the filament.
      var fallback = parseColor(MATERIALS[materialId] && MATERIALS[materialId][3]);
      if (!colorTouched && fallback) cc.set(fallback, false);
    });

    newBtn.addEventListener("click", function () { if (!busy) openCreator(unit, index, materialId); });
    delBtn.addEventListener("click", function () {
      if (busy || !CUSTOM[materialId]) return;
      var entry = MATERIALS[materialId];
      if (!window.confirm("Delete " + entry[0] + " " + entry[1] + " from the database?\nThe spools that use it will show as an unknown material.")) return;
      var id = materialId;
      setBusy(true);
      setStatus("Deleting...");
      runScript("CFS_REMOVE_MATERIAL ID=" + id).then(function () {
        return waitFor(function () { return loadCustom().then(function () { return !CUSTOM[id]; }); }, 8, 1000);
      }).then(function (gone) {
        if (!gone) {
          setBusy(false);
          return lastHelperMessage().then(function (message) { setStatus(message || "The printer did not confirm the removal.", "error"); });
        }
        lastSignature = "";
        openEditor(unit, index);
      }).catch(function (error) {
        setBusy(false);
        setStatus(error && error.message ? error.message : "The removal could not be sent.", "error");
      });
    });

    function finish() { closeEditor(); lastSignature = ""; poll(); }
    closeBtn.addEventListener("click", closeEditor);
    cancelBtn.addEventListener("click", closeEditor);
    modal.addEventListener("click", function (event) { if (event.target === modal && !busy) closeEditor(); });

    function setBusy(value) {
      busy = value;
      saveBtn.disabled = value;
      cancelBtn.disabled = value;
      closeBtn.disabled = value;
    }

    // The CFS takes a moment to report the change: look at it a few times before giving up.
    function verify(tries) {
      window.setTimeout(function () {
        fetchStatus().then(function (data) {
          var u = data && data.units.filter(function (item) { return item.id === unit.id; })[0];
          var s = u && u.slots[index];
          if (s && s.id === materialId && s.color === color) {
            setStatus("Saved.", "ok");
            window.setTimeout(finish, 900);
          } else if (tries > 1) {
            verify(tries - 1);
          } else {
            setBusy(false);
            setStatus("The CFS has not reported the change yet. Check the card in a few seconds.", "error");
          }
        }).catch(function () {
          if (tries > 1) verify(tries - 1);
          else { setBusy(false); setStatus("Could not read the CFS.", "error"); }
        });
      }, VERIFY_MS);
    }

    saveBtn.addEventListener("click", function () {
      if (busy || !materialId) return;
      setBusy(true);
      setStatus("Saving...");
      var target = "BOX_MODIFY_TN_DATA ADDR=" + unit.id + " NUM=" + num;
      // Checked again here: a print may have started while the dialog was open.
      fetchStatus().then(function (data) {
        if (data && data.printing) throw new Error("A print is in progress: the spools cannot be edited now.");
        return runScript(target + " PART=material_type DATA=" + materialId);
      }).then(function () {
        // Klipper treats "#" as a comment: the color goes as 0RRGGBB.
        return runScript(target + " PART=color_value DATA=0" + color.slice(1).toUpperCase());
      }).then(function () {
        verify(VERIFY_TRIES);
      }).catch(function (error) {
        setBusy(false);
        setStatus(error && error.message ? error.message : "The change could not be sent.", "error");
      });
    });

    if (latest && latest.printing) saveBtn.disabled = true;
    document.body.appendChild(modal);
  }

  // ---------- New filament ----------

  var NAME_PATTERN = /^[A-Za-z0-9._+-]+( [A-Za-z0-9._+-]+)*$/;

  function openCreator(unit, index, baseId) {
    closeEditor();
    var base = MATERIALS[baseId] ? baseId : materialIds()[0];
    var baseEntry = MATERIALS[base];
    var busy = false;

    modal = el("div", "pcfs-overlay");
    var dialog = el("div", "pcfs-dialog v-card v-sheet theme--dark rounded-md");
    modal.appendChild(dialog);

    var head = el("div", "pcfs-dialog-head");
    head.appendChild(el("span", "font-weight-light", "New filament"));
    var closeBtn = iconButton(ICONS.close, "Close");
    head.appendChild(closeBtn);
    dialog.appendChild(head);

    var body = el("div", "pcfs-dialog-body");
    var baseSel = el("select");
    fillSelect(baseSel, materialIds(), materialIds().map(function (id) { return MATERIALS[id][0] + " " + MATERIALS[id][1]; }), base);
    var brandIn = el("input");
    brandIn.type = "text";
    brandIn.maxLength = 24;
    brandIn.setAttribute("list", "pcfs-brands");
    var brandList = el("datalist");
    brandList.id = "pcfs-brands";
    brandsList().forEach(function (b) { var o = el("option"); o.value = b; brandList.appendChild(o); });
    var nameIn = el("input");
    nameIn.type = "text";
    nameIn.maxLength = 24;
    var typeSel = el("select");
    fillSelect(typeSel, allTypes(), null, baseEntry[2]);
    function numberInput(value) {
      var input = el("input");
      input.type = "number";
      input.min = "150";
      input.max = "350";
      input.step = "1";
      input.value = String(value);
      return input;
    }
    var nozzleIn = numberInput(baseEntry[6] || baseEntry[5]);
    var minIn = numberInput(baseEntry[4]);
    var maxIn = numberInput(baseEntry[5]);
    var temps = el("div", "pcfs-temprow");
    [["Nozzle", nozzleIn], ["Min", minIn], ["Max", maxIn]].forEach(function (pair) {
      var cell = el("div", "pcfs-tempcell");
      cell.appendChild(el("label", "", pair[0]));
      cell.appendChild(pair[1]);
      temps.appendChild(cell);
    });
    var color = parseColor(baseEntry[3]) || "#ffffff";
    var cc = colorControl(color, function (value) { color = value; });

    body.appendChild(el("div", "pcfs-hint", "Pick the filament it looks like: the new one starts as a copy of it."));
    body.appendChild(field("Based on", baseSel));
    body.appendChild(field("Brand", brandIn));
    body.appendChild(brandList);
    body.appendChild(field("Name", nameIn));
    body.appendChild(field("Material", typeSel));
    body.appendChild(field("Temp (\u00b0C)", temps));
    body.appendChild(field("Color", cc.box));
    var status = el("div", "pcfs-status");
    body.appendChild(status);
    dialog.appendChild(body);

    var actions = el("div", "pcfs-actions");
    var cancelBtn = textButton("Back", false);
    var createBtn = textButton("Add", true);
    actions.appendChild(cancelBtn);
    actions.appendChild(createBtn);
    dialog.appendChild(actions);

    function setStatus(text, kind) {
      status.textContent = text;
      status.className = "pcfs-status" + (kind ? " " + kind : "");
    }

    function setBusy(value) {
      busy = value;
      createBtn.disabled = value;
      cancelBtn.disabled = value;
      closeBtn.disabled = value;
    }

    // Choosing another base copies its material, temperatures and color.
    baseSel.addEventListener("change", function () {
      var entry = MATERIALS[baseSel.value];
      fillSelect(typeSel, allTypes(), null, entry[2]);
      nozzleIn.value = String(entry[6] || entry[5]);
      minIn.value = String(entry[4]);
      maxIn.value = String(entry[5]);
      cc.set(parseColor(entry[3]) || "#ffffff", false);
    });

    function back() { openEditor(unit, index, baseSel.value); }
    closeBtn.addEventListener("click", back);
    cancelBtn.addEventListener("click", back);

    function validate() {
      var brand = brandIn.value.trim();
      var name = nameIn.value.trim();
      if (!NAME_PATTERN.test(brand) || brand.length > 24) return "The brand needs letters, digits, spaces and . _ + - (24 characters at most).";
      if (!NAME_PATTERN.test(name) || name.length > 24) return "The name needs letters, digits, spaces and . _ + - (24 characters at most).";
      var nozzle = Number(nozzleIn.value), min = Number(minIn.value), max = Number(maxIn.value);
      var ok = function (n) { return isFinite(n) && n === Math.round(n) && n >= 150 && n <= 350; };
      if (!ok(nozzle) || !ok(min) || !ok(max)) return "The temperatures must be whole numbers between 150 and 350.";
      if (min > nozzle || nozzle > max) return "The temperatures must satisfy Min <= Nozzle <= Max.";
      var exists = materialIds().some(function (id) { return MATERIALS[id][0] === brand && MATERIALS[id][1] === name; });
      if (exists) return brand + " " + name + " already exists.";
      return "";
    }

    createBtn.addEventListener("click", function () {
      if (busy) return;
      var problem = validate();
      if (problem) { setStatus(problem, "error"); return; }
      var brand = brandIn.value.trim();
      var name = nameIn.value.trim();
      var space = function (text) { return text.replace(/ /g, "~"); };
      var command = "CFS_ADD_MATERIAL BASE=" + baseSel.value + " BRAND=" + space(brand) + " NAME=" + space(name) +
        " TYPE=" + space(typeSel.value) + " NOZZLE=" + nozzleIn.value + " MIN=" + minIn.value + " MAX=" + maxIn.value +
        " COLOR=" + color.slice(1).toUpperCase();
      setBusy(true);
      setStatus("Adding...");
      var created = "";
      fetchStatus().then(function (data) {
        if (data && data.printing) throw new Error("A print is in progress: the database cannot be changed now.");
        return runScript(command);
      }).then(function () {
        return waitFor(function () {
          return loadCustom().then(function () {
            created = materialIds().filter(function (id) { return CUSTOM[id] && MATERIALS[id][0] === brand && MATERIALS[id][1] === name; })[0] || "";
            return !!created;
          });
        }, 8, 1000);
      }).then(function (found) {
        if (!found) {
          setBusy(false);
          return lastHelperMessage().then(function (message) { setStatus(message || "The printer did not confirm the new filament.", "error"); });
        }
        lastSignature = "";
        openEditor(unit, index, created);
      }).catch(function (error) {
        setBusy(false);
        setStatus(error && error.message ? error.message : "The filament could not be added.", "error");
      });
    });

    document.body.appendChild(modal);
  }

  // ---------- Loop ----------

  function schedule(delay) {
    if (pollTimer) window.clearTimeout(pollTimer);
    pollTimer = window.setTimeout(poll, delay);
  }

  function poll() {
    if (document.hidden) {
      schedule(POLL_MS);
      return;
    }
    fetchStatus()
      .then(function (data) {
        latest = data;
        if (!data) {
          // The printer has no CFS object: nothing to show.
          removeCard();
          schedule(POLL_ABSENT_MS);
          return;
        }
        if (!card) {
          build();
          lastSignature = "";
        }
        render(data);
        ensureMounted();
        schedule(POLL_MS);
      })
      .catch(function () {
        // Moonraker unreachable (restarting, offline): keep what is shown and retry.
        schedule(POLL_MS);
      });
  }

  // The custom filaments and the macros are read again now and then; after a failed read, in a few seconds.
  function scheduleRefresh(lastOk) {
    window.setTimeout(function () {
      Promise.all([loadCustom(), checkMacros()]).then(function (results) { scheduleRefresh(results[0]); });
    }, lastOk ? CUSTOM_REFRESH_MS : POLL_MS);
  }

  function init() {
    loadPrefs();
    addStyles();
    // The custom filaments first, so their names are known when the first status arrives.
    Promise.all([loadCustom(), checkMacros()]).then(function (results) {
      poll();
      scheduleRefresh(results[0]);
    });
    // Fluidd rebuilds the dashboard when the user changes page or edits the layout.
    window.setInterval(ensureMounted, MOUNT_MS);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
