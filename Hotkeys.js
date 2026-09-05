var GROUPS = [
  { id: "custom", title: "Custom" },
  { id: "start", title: "Getting started" },
  { id: "windows", title: "Windows" },
  { id: "workspaces", title: "Workspaces" },
  { id: "move", title: "Move & resize" },
  { id: "apps", title: "Applications" },
  { id: "capture", title: "Capture" },
  { id: "clipboard", title: "Clipboard" },
  { id: "notify", title: "Notifications" },
  { id: "panels", title: "Panels" },
  { id: "system", title: "System" },
  { id: "hardware", title: "Hardware" },
  { id: "other", title: "Other" }
]

var KEY_LABELS = {
  SUPER: "Super",
  SHIFT: "Shift",
  CTRL: "Ctrl",
  CONTROL: "Ctrl",
  ALT: "Alt",
  RETURN: "Enter",
  ESCAPE: "Esc",
  PRINT: "Print",
  COMMA: ",",
  PERIOD: ".",
  MINUS: "-",
  EQUAL: "=",
  SLASH: "/",
  TAB: "Tab",
  SPACE: "Space",
  BACKSPACE: "Backspace",
  DELETE: "Delete",
  LEFT: "Left",
  RIGHT: "Right",
  UP: "Up",
  DOWN: "Down",
  HOME: "Home",
  INSERT: "Insert",
  PAGEUP: "Page Up",
  PAGEDOWN: "Page Down",
  "LEFT MOUSE BUTTON": "Left Click",
  "RIGHT MOUSE BUTTON": "Right Click",
  "MIDDLE MOUSE BUTTON": "Middle Click",
  MOUSE_DOWN: "Scroll Down",
  MOUSE_UP: "Scroll Up",
  XF86AUDIORAISEVOLUME: "Vol +",
  XF86AUDIOLOWERVOLUME: "Vol −",
  XF86AUDIOMUTE: "Mute",
  XF86AUDIOMICMUTE: "Mic Mute",
  XF86AUDIOPLAY: "Play",
  XF86AUDIOPAUSE: "Pause",
  XF86AUDIONEXT: "Next Track",
  XF86AUDIOPREV: "Prev Track",
  XF86AUDIOSTOP: "Stop",
  XF86MONBRIGHTNESSUP: "Brightness +",
  XF86MONBRIGHTNESSDOWN: "Brightness −",
  XF86KBDBRIGHTNESSUP: "Keyboard Light +",
  XF86KBDBRIGHTNESSDOWN: "Keyboard Light −",
  XF86KBDLIGHTONOFF: "Keyboard Light",
  XF86TOUCHPADTOGGLE: "Touchpad",
  XF86TOUCHPADON: "Touchpad On",
  XF86TOUCHPADOFF: "Touchpad Off",
  XF86POWEROFF: "Power",
  XF86CALCULATOR: "Calculator",
  XF86EJECT: "Eject"
}

function trim(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "")
}

function prettyPart(part) {
  var raw = trim(part)
  if (!raw) return ""
  var key = raw.toUpperCase()
  if (KEY_LABELS[key]) return KEY_LABELS[key]
  if (key.indexOf("XF86") === 0) raw = raw.substring(4)
  return raw.replace(/[A-Za-z0-9]+/g, function(word) {
    return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
  })
}

function prettyCombo(raw) {
  var parts = String(raw || "").split(/\s*\+\s*/)
  var labels = []
  for (var i = 0; i < parts.length; i++) {
    var label = prettyPart(parts[i])
    if (label) labels.push(label)
  }
  return labels.join(" + ")
}

function parseLine(line) {
  var text = String(line || "").replace(/\s+$/, "")
  if (!text) return null

  var idx = text.indexOf("→")
  if (idx === -1) idx = text.indexOf("->")
  if (idx === -1) return null

  var keys = trim(text.substring(0, idx)).replace(/\s+/g, " ")
  var action = trim(text.substring(idx + (text.charAt(idx) === "→" ? 1 : 2)))
  if (!keys || !action) return null

  return {
    rawCombo: keys,
    action: action,
    prettyKeys: prettyCombo(keys)
  }
}

function isBareXf86(combo) {
  var raw = trim(combo)
  return raw.indexOf("+") === -1 && raw.toUpperCase().indexOf("XF86") === 0
}

function containsXf86(combo) {
  return String(combo || "").toUpperCase().indexOf("XF86") !== -1
}

function rowCombo(row) {
  return row && (row.rawCombo || row.keys) || ""
}

function dropRedundantXf86(rows) {
  var hasTypedChord = {}
  for (var i = 0; i < rows.length; i++) {
    if (!containsXf86(rowCombo(rows[i]))) hasTypedChord[rows[i].action] = true
  }

  var out = []
  for (var j = 0; j < rows.length; j++) {
    if (isBareXf86(rowCombo(rows[j])) && hasTypedChord[rows[j].action]) continue
    out.push(rows[j])
  }
  return out
}

function parseDump(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var out = []
  var seen = {}
  for (var i = 0; i < lines.length; i++) {
    var row = parseLine(lines[i])
    if (!row) continue
    var dedupe = row.prettyKeys + "\t" + row.action
    if (seen[dedupe]) continue
    seen[dedupe] = true
    out.push(row)
  }
  return dropRedundantXf86(out)
}

function matchesAny(text, patterns) {
  for (var i = 0; i < patterns.length; i++) {
    if (text.indexOf(patterns[i]) !== -1) return true
  }
  return false
}

function parseDefaultActions(luaText) {
  var actions = {
    "copy url from web app": true,
    "download video from web app": true
  }
  var re = /o\.bind(?:_toggle)?\s*\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"/g
  var match
  var text = String(luaText || "")
  while ((match = re.exec(text)) !== null) {
    if (match[2]) actions[match[2].toLowerCase()] = true
  }
  return actions
}

function isGeneratedStockAction(action) {
  var text = String(action || "").toLowerCase()
  if (/^switch to workspace \d+$/.test(text)) return true
  if (/^move window to workspace \d+$/.test(text)) return true
  if (/^move window silently to workspace \d+$/.test(text)) return true
  if (/^bar panel \d+$/.test(text)) return true
  if (/^switch to group window \d+$/.test(text)) return true
  if (text.indexOf("capture highlighted") === 0) return true
  if (text.indexOf("capture entire screen") === 0) return true
  if (text.indexOf("select next window to capture") === 0) return true
  if (text.indexOf("select previous window to capture") === 0) return true
  if (text.indexOf("select window to capture") === 0) return true
  return false
}

function isStockAction(action, defaultActions) {
  var text = String(action || "").toLowerCase()
  if (!text) return true
  if (defaultActions && defaultActions[text]) return true
  return isGeneratedStockAction(action)
}
function classify(action, defaultActions) {
  var text = String(action || "").toLowerCase()

  if (defaultActions && !isStockAction(action, defaultActions)) return "custom"

  if (matchesAny(text, [
    "keybindings", "omarchy menu", "apps menu", "system menu", "theme menu",
    "hardware menu", "capture menu", "toggle menu", "launch apps",
    "background switcher", "emoji", "dictation"
  ])) return "start"
  if (text === "terminal" || text === "browser" || text === "file manager"
      || text === "editor" || text === "calculator") return "start"

  if (matchesAny(text, [
    "clipboard", "universal copy", "universal paste", "universal cut",
    "copy url", "download video"
  ])) return "clipboard"

  if (matchesAny(text, [
    "screenshot", "screenrecording", "screenrecord", "color picker",
    "extract text", "ocr", "webcam", "capture "
  ])) return "capture"

  if (matchesAny(text, [
    "notification", "silencing", "reminder", "show time",
    "show battery", "toggle weather"
  ])) return "notify"

  if (text === "play" || text === "pause"
      || matchesAny(text, [
        "volume", "mute", "brightness", "keyboard light", "keyboard backlight",
        "keyboard brightness", "touchpad", "next track", "previous track",
        "eject media", "audio output", "audio source", "media source"
      ]) || text.indexOf("xf86") !== -1) return "hardware"

  if (matchesAny(text, [
    "lock system", "locking on idle", "nightlight", "laptop display",
    "monitor scaling", "toggle top bar", "power menu", "zoom"
  ])) return "system"

  if (matchesAny(text, [
    "audio", "bluetooth", "display", "calendar", "network", "power",
    "activity", "bar panel"
  ])) return "panels"

  if (matchesAny(text, [
    "workspace", "scratchpad", "next monitor", "previous monitor"
  ])) return "workspaces"

  if (matchesAny(text, [
    "close window", "close all windows", "full screen", "full width",
    "window split", "window floating", "pseudo window", "pop window",
    "window transparency", "window gaps", "square aspect", "window grouping",
    "window group", "out of group", "into group", "in group", "group window",
    "grouped window", "window width", "workspace layout", "reveal active"
  ])) return "windows"

  if (matchesAny(text, [
    "focus on", "swap window", "expand window", "shrink window",
    "move window", "resize window", "next window", "previous window",
    "cycle to"
  ])) return "move"

  if (matchesAny(text, [
    "tmux", "herdr", "music", "docker", "signal", "obsidian", "omawrite",
    "passwords", "chatgpt", "grok", "email", "youtube", "whatsapp",
    "google", "browser (", "file manager (", "share", "transcode",
    "agent", "x post"
  ]) || text === "x") return "apps"

  return "other"
}

function normalizeNeedle(text) {
  var s = String(text || "").toLowerCase()
  s = s.replace(/[|+,\-_]+/g, " ")
  s = s.replace(/\b(meta|win|mod4|super_l|super_r)\b/g, "super")
  s = s.replace(/\b(control|ctl)\b/g, "ctrl")
  s = s.replace(/\breturn\b/g, "enter")
  s = s.replace(/\bescape\b/g, "esc")
  s = s.replace(/\bpage\s*up\b/g, "pageup")
  s = s.replace(/\bpage\s*down\b/g, "pagedown")
  s = s.replace(/\s+/g, " ")
  return trim(s)
}

function rowHaystack(row) {
  if (!row) return ""
  if (row._haystack) return row._haystack
  var bits = [row.action, row.prettyKeys, row.rawCombo]
  row._haystack = normalizeNeedle(bits.join(" "))
  return row._haystack
}

function rowMatches(row, query) {
  var q = normalizeNeedle(query)
  if (!q) return true
  var hay = rowHaystack(row)
  if (hay.indexOf(q) !== -1) return true

  var tokens = q.split(" ")
  for (var i = 0; i < tokens.length; i++) {
    var tok = tokens[i]
    if (hay.indexOf(tok) !== -1) continue
    if (tok === "?" && hay.indexOf("/") !== -1) continue
    if (tok === "/" && hay.indexOf("?") !== -1) continue
    return false
  }
  return tokens.length > 0
}

function filterBindings(rows, query) {
  var list = rows || []
  if (!normalizeNeedle(query)) return list
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (rowMatches(list[i], query)) out.push(list[i])
  }
  return out
}

function groupBindings(rows, defaultActions) {
  var buckets = {}
  for (var i = 0; i < GROUPS.length; i++) buckets[GROUPS[i].id] = []

  for (var r = 0; r < rows.length; r++) {
    var row = rows[r]
    var id = classify(row.action, defaultActions)
    if (!buckets[id]) id = "other"
    buckets[id].push(row)
  }

  var groups = []
  for (var g = 0; g < GROUPS.length; g++) {
    var spec = GROUPS[g]
    var items = buckets[spec.id] || []
    if (items.length === 0) continue
    groups.push({ id: spec.id, title: spec.title, items: items })
  }
  return groups
}

function columnCount(width) {
  var minWidth = 240
  var count = Math.floor(Number(width || 0) / minWidth)
  if (count < 2) return 2
  if (count > 5) return 5
  return count
}

function flattenUnits(groups) {
  var units = []
  for (var g = 0; g < (groups || []).length; g++) {
    var group = groups[g]
    if (!group || !group.items || group.items.length === 0) continue
    units.push({ kind: "header", id: group.id, title: group.title })
    for (var i = 0; i < group.items.length; i++) {
      units.push({ kind: "item", id: group.id, title: group.title, item: group.items[i] })
    }
  }
  return units
}

function pushChunk(chunks, current) {
  if (current && current.items.length > 0) chunks.push(current)
}

function packColumns(groups, count) {
  var units = flattenUnits(groups)
  var n = Math.max(1, Number(count) || 1)
  var columns = []
  var idx = 0

  for (var c = 0; c < n; c++) {
    var leftCols = n - c
    var leftUnits = units.length - idx
    var budget = leftCols > 0 ? Math.ceil(leftUnits / leftCols) : leftUnits
    var chunks = []
    var current = null
    var used = 0

    while (idx < units.length && used < budget) {
      var u = units[idx]
      if (u.kind === "header") {
        if (used > 0 && used + 2 > budget && c < n - 1) break
        pushChunk(chunks, current)
        current = { id: u.id, title: u.title, items: [] }
        used += 1
        idx++
        continue
      }
      if (!current || current.id !== u.id) {
        pushChunk(chunks, current)
        current = { id: u.id, title: u.title, items: [] }
        used += 1
      }
      current.items.push(u.item)
      used += 1
      idx++
    }
    pushChunk(chunks, current)
    columns.push({ height: used, groups: chunks })
  }

  while (idx < units.length) {
    var last = columns[columns.length - 1]
    var extra = units[idx]
    var tail = last.groups.length ? last.groups[last.groups.length - 1] : null
    if (extra.kind === "header") {
      last.groups.push({ id: extra.id, title: extra.title, items: [] })
    } else {
      if (!tail || tail.id !== extra.id) {
        tail = { id: extra.id, title: extra.title, items: [] }
        last.groups.push(tail)
      }
      tail.items.push(extra.item)
    }
    last.height += 1
    idx++
  }

  for (var d = 0; d < columns.length; d++) {
    var kept = []
    for (var g = 0; g < columns[d].groups.length; g++) {
      if (columns[d].groups[g].items.length > 0) kept.push(columns[d].groups[g])
    }
    columns[d].groups = kept
  }

  return columns
}
