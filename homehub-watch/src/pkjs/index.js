var B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

// Watch-side limits (keep in sync with homehub.c).
var MAX_WATCH_ITEMS = 32;
var MAX_NAME_CHARS = 31;
var MAX_ID_CHARS = 39;
var MAX_STATUS_CHARS = 39;

function b64encode(input) {
  var output = '';
  var i = 0;
  while (i < input.length) {
    var c1 = input.charCodeAt(i++);
    var c2 = i < input.length ? input.charCodeAt(i++) : NaN;
    var c3 = i < input.length ? input.charCodeAt(i++) : NaN;

    var e1 = c1 >> 2;
    var e2 = ((c1 & 3) << 4) | (isNaN(c2) ? 0 : (c2 >> 4));
    var e3 = isNaN(c2) ? 64 : (((c2 & 15) << 2) | (isNaN(c3) ? 0 : (c3 >> 6)));
    var e4 = isNaN(c3) ? 64 : (c3 & 63);

    output += B64_CHARS.charAt(e1) + B64_CHARS.charAt(e2) +
      (e3 === 64 ? '=' : B64_CHARS.charAt(e3)) +
      (e4 === 64 ? '=' : B64_CHARS.charAt(e4));
  }
  return output;
}

// Reduce a JS string to one char per UTF-8 byte so base64 sees real bytes;
// b64encode/btoa silently corrupt char codes above 255 otherwise.
function utf8Bytes(str) {
  return unescape(encodeURIComponent(str));
}

function base64(str) {
  var bytes = utf8Bytes(str);
  return typeof btoa === 'function' ? btoa(bytes) : b64encode(bytes);
}

function loadConfig() {
  return {
    host: localStorage.getItem('hh_host') || '',
    user: localStorage.getItem('hh_user') || '',
    pass: localStorage.getItem('hh_pass') || ''
  };
}

function saveConfig(cfg) {
  localStorage.setItem('hh_host', cfg.host || '');
  localStorage.setItem('hh_user', cfg.user || '');
  localStorage.setItem('hh_pass', cfg.pass || '');
}

function authHeader(cfg) {
  if (!cfg.user) {
    return null;
  }
  return 'Basic ' + base64(cfg.user + ':' + cfg.pass);
}

function apiRequest(cfg, method, path, callback) {
  var xhr = new XMLHttpRequest();
  var base = cfg.host.replace(/\/+$/, '');
  xhr.open(method, base + path, true);
  var auth = authHeader(cfg);
  if (auth) {
    xhr.setRequestHeader('Authorization', auth);
  }
  xhr.timeout = 8000;
  xhr.onload = function() {
    if (xhr.status >= 200 && xhr.status < 300) {
      try {
        callback(null, xhr.responseText ? JSON.parse(xhr.responseText) : null);
      } catch (parseErr) {
        callback(new Error('Bad response'));
      }
    } else {
      callback(new Error('HTTP ' + xhr.status));
    }
  };
  xhr.onerror = function() {
    callback(new Error('No connection'));
  };
  xhr.ontimeout = function() {
    callback(new Error('Timeout'));
  };
  xhr.send();
}

// Only one sendAppMessage may be in flight at a time, so EVERYTHING that
// goes to the watch — items, sync markers, statuses — must pass through
// this queue. Never call Pebble.sendAppMessage directly.
var s_queue = [];
var s_sending = false;

function pump() {
  if (s_sending || s_queue.length === 0) {
    return;
  }
  s_sending = true;
  var msg = s_queue.shift();
  Pebble.sendAppMessage(msg, function() {
    s_sending = false;
    pump();
  }, function() {
    s_sending = false;
    pump();
  });
}

function queueMessage(msg) {
  s_queue.push(msg);
  pump();
}

function sendStatus(text) {
  queueMessage({ 'STATUS': String(text).substring(0, MAX_STATUS_CHARS) });
}

function itemName(name) {
  return String(name).substring(0, MAX_NAME_CHARS);
}

function itemMessage(type, id, name, state) {
  return {
    'ITEM_TYPE': type,
    'ITEM_ID': String(id),
    'ITEM_NAME': itemName(name),
    'ITEM_STATE': state ? 1 : 0
  };
}

function sendItems(sockets, groups) {
  // Groups first so a large socket list can't crowd them out of the cap.
  var out = [];
  var truncated = false;
  var pushItem = function(msg) {
    if (msg['ITEM_ID'].length > MAX_ID_CHARS) {
      return; // id wouldn't round-trip through the watch's buffer intact
    }
    if (out.length >= MAX_WATCH_ITEMS) {
      truncated = true;
      return;
    }
    out.push(msg);
  };
  groups.forEach(function(group) {
    pushItem(itemMessage(1, group.id, group.name, false));
  });
  sockets.forEach(function(socket) {
    if (socket.readonly) {
      return; // sensors — no on/off commands
    }
    pushItem(itemMessage(0, socket.id, socket.name, socket.state));
  });

  queueMessage({ 'SYNC_START': 1, 'STATUS': 'Syncing...' });
  out.forEach(queueMessage);
  queueMessage({ 'SYNC_DONE': 1,
                 'STATUS': truncated ? 'List cut at 32' : 'Connected' });
}

var s_refreshing = false;

function refresh() {
  if (s_refreshing) {
    return; // watch REQUEST_SYNC + JS 'ready' both fire at launch; run once
  }
  var cfg = loadConfig();
  if (!cfg.host) {
    sendStatus('Config needed');
    return;
  }
  s_refreshing = true;
  apiRequest(cfg, 'GET', '/api/sockets', function(sockErr, sockets) {
    if (sockErr) {
      s_refreshing = false;
      sendStatus(sockErr.message);
      return;
    }
    apiRequest(cfg, 'GET', '/api/groups', function(groupErr, groups) {
      s_refreshing = false;
      if (groupErr) {
        sendStatus(groupErr.message);
        return;
      }
      sendItems(sockets || [], groups || []);
    });
  });
}

function toggle(type, id) {
  var cfg = loadConfig();
  if (!cfg.host) {
    sendStatus('Config needed');
    return;
  }
  var path = (type === 1 ? '/api/groups/' : '/api/sockets/') + encodeURIComponent(id) + '/toggle';
  apiRequest(cfg, 'POST', path, function(err, body) {
    if (err) {
      sendStatus(err.message);
      return;
    }
    if (type === 0 && body && body.id) {
      // Socket toggle returns the updated socket — patch just that row
      // instead of re-syncing everything.
      var msg = itemMessage(0, body.id, body.name, body.state);
      msg['STATUS'] = 'Connected';
      queueMessage(msg);
    } else {
      // A group toggle changes many sockets; a full re-sync is the only
      // way to learn their new states.
      refresh();
    }
  });
}

function configHtml(cfg) {
  return '<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<style>body{font-family:sans-serif;margin:16px;background:#1e1e1e;color:#eee}' +
    'label{display:block;margin-top:12px;font-size:14px}' +
    'input{width:100%;box-sizing:border-box;padding:8px;font-size:16px;margin-top:4px}' +
    'button{margin-top:20px;width:100%;padding:12px;font-size:16px;background:#33c;color:#fff;border:none;border-radius:4px}' +
    'h2{margin-bottom:0}p{color:#aaa;font-size:13px}</style></head><body>' +
    '<h2>HomeHub Settings</h2>' +
    '<p>Host reachable from your phone — e.g. your Tailscale address, ' +
    'like <code>http://100.x.x.x:8080</code>.</p>' +
    '<form id="f">' +
    '<label>Host URL<input id="host" value="' + escapeAttr(cfg.host) + '" placeholder="http://100.x.x.x:8080"></label>' +
    '<label>Username<input id="user" value="' + escapeAttr(cfg.user) + '"></label>' +
    '<label>Password<input id="pass" type="password" value="' + escapeAttr(cfg.pass) + '"></label>' +
    '<button type="submit">Save</button>' +
    '</form>' +
    '<script>' +
    'document.getElementById("f").addEventListener("submit", function(e) {' +
    'e.preventDefault();' +
    'var cfg = {host: document.getElementById("host").value, user: document.getElementById("user").value, pass: document.getElementById("pass").value};' +
    'document.location = "pebblejs://close#" + encodeURIComponent(JSON.stringify(cfg));' +
    '});' +
    '</script>' +
    '</body></html>';
}

function escapeAttr(value) {
  return String(value).replace(/&/g, '&amp;').replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;').replace(/</g, '&lt;');
}

Pebble.addEventListener('ready', function() {
  // The watch also sends REQUEST_SYNC on launch; s_refreshing dedups the
  // two triggers. Both stay because either side can come up first.
  refresh();
});

Pebble.addEventListener('appmessage', function(e) {
  if (e.payload['REQUEST_SYNC']) {
    refresh();
  }
  if (e.payload['TOGGLE_ID']) {
    toggle(e.payload['TOGGLE_TYPE'], e.payload['TOGGLE_ID']);
  }
});

Pebble.addEventListener('showConfiguration', function() {
  var cfg = loadConfig();
  Pebble.openURL('data:text/html;charset=utf-8,' + encodeURIComponent(configHtml(cfg)));
});

Pebble.addEventListener('webviewclosed', function(e) {
  if (!e.response) {
    return;
  }
  try {
    var cfg = JSON.parse(decodeURIComponent(e.response));
    saveConfig(cfg);
    refresh();
  } catch (err) {
    sendStatus('Save failed');
  }
});
