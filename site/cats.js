// Maramao website: the procedural cat and the few interactions of the page.
//
// The cat is a port of Sources/Maramao/Shared/CatView.swift: same 200x160
// design space, same poses, same palettes, so the cats on the site look like
// the ones in the app. Every element with `data-cat` becomes a cat:
//   <span class="cat" data-cat="sitting orange" data-flags="closed flip"></span>

(function () {
  "use strict";

  var NOSE = "#F28C99";
  var PALETTES = {
    orange: { fur: "#F59940", stripes: "#D16B1F", belly: "#FFE0B8", eyes: "#59B34D" },
    black: { fur: "#222222", stripes: null, belly: "#333333", eyes: "#F2CC33" },
    gray: { fur: "#8C8C8C", stripes: "#666666", belly: "#D9D9D9", eyes: "#4D99D9" },
    cream: { fur: "#FAF0DB", stripes: "#D9B88C", belly: "#FFFFFF", eyes: "#66A6F2" }
  };

  function n(v) { return Math.round(v * 100) / 100; }

  function ellipse(cx, cy, rx, ry, fill, extra) {
    return '<ellipse cx="' + n(cx) + '" cy="' + n(cy) + '" rx="' + n(rx) + '" ry="' + n(ry) + '" fill="' + fill + '"' + (extra || "") + "/>";
  }

  // Ellipse from a CatView-style rect (x, y, width, height).
  function oval(x, y, w, h, fill, extra) { return ellipse(x + w / 2, y + h / 2, w / 2, h / 2, fill, extra); }

  function stroke(d, color, width, extra) {
    return '<path d="' + d + '" fill="none" stroke="' + color + '" stroke-width="' + width + '" stroke-linecap="round"' + (extra || "") + "/>";
  }

  function leg(p, x, top, cls, dark, length) {
    length = length || 45;
    return '<g transform="translate(' + x + " " + top + ')"><g class="' + cls + '">' +
      '<rect x="-6" y="0" width="13" height="' + length + '" rx="6" fill="' + p.fur + '"' + (dark ? ' fill-opacity=".75"' : "") + "/>" +
      ellipse(0.5, length - 1.5, 8.5, 4.5, p.belly, dark ? ' fill-opacity=".7"' : "") +
      "</g></g>";
  }

  // The tail is drawn relative to its base so it can wag around it.
  function tail(p, sx, sy, wave, up) {
    var d;
    if (up) d = "M0 0Q-40 -5 " + n(-30 + wave * 25) + " -55";
    else d = "M0 0Q-10 18 85 " + n(6 - wave * 20);
    var s = stroke(d, p.fur, 12);
    if (p.stripes) s += '<path d="' + d + '" fill="none" stroke="' + p.stripes + '" stroke-opacity=".6" stroke-width="12" stroke-dasharray="6 9"/>';
    return '<g transform="translate(' + sx + " " + sy + ')"><g class="tail">' + s + "</g></g>";
  }

  function stripes(p, x, y, w, h) {
    if (!p.stripes) return "";
    var d = "";
    for (var i = 0; i < 3; i++) {
      var sx = x + w * (0.2 + i * 0.3);
      d += "M" + n(sx - 4) + " " + n(y + 2) + "Q" + n(sx + 6) + " " + n(y + h / 2) + " " + n(sx + 2) + " " + n(y + h);
    }
    return stroke(d, p.stripes, 5);
  }

  function head(p, cx, cy, r, closed, tilt) {
    var s = '<g transform="translate(' + n(cx) + " " + n(cy) + ")" + (tilt ? " rotate(" + n(tilt * 180 / Math.PI) + ")" : "") + '"><g class="head">';
    [-1, 1].forEach(function (side) {
      s += '<path d="M' + n(side * r * 0.85) + " " + n(-r * 0.35) + "L" + n(side * r * 0.75) + " " + n(-r * 1.25) + "L" + n(side * r * 0.15) + " " + n(-r * 0.8) + 'Z" fill="' + p.fur + '"/>';
      s += '<path d="M' + n(side * r * 0.72) + " " + n(-r * 0.5) + "L" + n(side * r * 0.68) + " " + n(-r * 1.05) + "L" + n(side * r * 0.3) + " " + n(-r * 0.8) + 'Z" fill="' + NOSE + '" fill-opacity=".6"/>';
    });
    s += ellipse(0, -r * 0.025, r, r * 0.925, p.fur);
    s += ellipse(0, r * 0.45, r * 0.55, r * 0.35, p.belly);
    if (p.stripes) {
      var d = "";
      [-0.25, 0, 0.25].forEach(function (dx) { d += "M" + n(r * dx) + " " + n(-r * 0.9) + "L" + n(r * dx * 0.8) + " " + n(-r * 0.55); });
      s += stroke(d, p.stripes, 3.5);
    }
    var lids = "", open = "";
    [-1, 1].forEach(function (side) {
      var ex = side * r * 0.42, ey = -r * 0.12;
      lids += "M" + n(ex - r * 0.18) + " " + n(ey) + "Q" + n(ex) + " " + n(ey + r * 0.16) + " " + n(ex + r * 0.18) + " " + n(ey);
      open += ellipse(ex, ey, r * 0.17, r * 0.2, p.eyes) + ellipse(ex, ey, r * 0.06, r * 0.17, "#000") +
        ellipse(ex + r * 0.015, ey - r * 0.105, r * 0.035, r * 0.035, "#fff");
    });
    // Both eye states are drawn; CSS can blink by swapping them.
    s += '<g class="eyes-open"' + (closed ? ' style="display:none"' : "") + ">" + open + "</g>";
    s += '<g class="eyes-closed"' + (closed ? "" : ' style="display:none"') + ">" + stroke(lids, "#000", 2.5, ' stroke-opacity=".75"') + "</g>";
    s += '<path d="M' + n(-r * 0.1) + " " + n(r * 0.2) + "L" + n(r * 0.1) + " " + n(r * 0.2) + "L0 " + n(r * 0.32) + 'Z" fill="' + NOSE + '"/>';
    s += stroke("M" + n(-r * 0.16) + " " + n(r * 0.42) + "Q" + n(-r * 0.06) + " " + n(r * 0.48) + " 0 " + n(r * 0.34) +
      "Q" + n(r * 0.06) + " " + n(r * 0.48) + " " + n(r * 0.16) + " " + n(r * 0.42), "#000", 1.8, ' stroke-opacity=".6"');
    var w = "";
    [-1, 1].forEach(function (side) {
      [-0.06, 0.08].forEach(function (dy) {
        w += "M" + n(side * r * 0.35) + " " + n(r * (0.3 + dy)) + "L" + n(side * r * 1.15) + " " + n(r * (0.22 + dy * 2));
      });
    });
    s += stroke(w, "#000", 1.2, ' stroke-opacity=".35"');
    return s + "</g></g>";
  }

  var POSES = {
    walking: function (p, closed) {
      var swing = Math.sin(0.8) * 10;
      return leg(p, 72, 105, "leg leg-b", true) + leg(p, 132, 105, "leg leg-a", true) +
        tail(p, 52, 92, 0, true) +
        oval(45, 70, 115, 50, p.fur) + oval(70, 98, 70, 20, p.belly) + stripes(p, 70, 70, 70, 20) +
        leg(p, 62, 105, "leg leg-a", false) + leg(p, 142, 105, "leg leg-b", false) +
        '<g class="bob">' + head(p, 160, 68, 27, closed) + "</g>";
    },
    sitting: function (p, closed) {
      var s = tail(p, 70, 142, 0, false) +
        oval(58, 82, 84, 68, p.fur) + oval(95, 70, 50, 70, p.fur) + oval(108, 88, 30, 48, p.belly) +
        stripes(p, 64, 88, 40, 30);
      [112, 128].forEach(function (x) {
        s += '<rect x="' + x + '" y="112" width="13" height="38" rx="6" fill="' + p.fur + '"/>' + oval(x - 2, 144, 17, 9, p.belly);
      });
      return s + head(p, 124, 56, 28, closed);
    },
    sleeping: function (p) {
      var d = "M40 135Q70 165 140 148";
      var s = '<g class="breathe">' + oval(35, 95, 140, 58, p.fur) + stripes(p, 60, 98, 80, 22) + "</g>" +
        head(p, 150, 118, 24, true, 0.15) + stroke(d, p.fur, 13);
      if (p.stripes) s += '<path d="' + d + '" fill="none" stroke="' + p.stripes + '" stroke-opacity=".5" stroke-width="13" stroke-linecap="round" stroke-dasharray="6 10"/>';
      return s;
    },
    stretching: function (p) {
      return tail(p, 50, 78, 0.5, true) +
        leg(p, 58, 95, "leg", true, 55) + leg(p, 70, 95, "leg", false, 55) +
        oval(45, 72, 60, 44, p.fur) + oval(85, 92, 75, 40, p.fur) + stripes(p, 55, 76, 50, 20) +
        '<rect x="120" y="136" width="55" height="12" rx="6" fill="' + p.fur + '"/>' + oval(165, 136, 16, 12, p.belly) +
        head(p, 155, 112, 25, true);
    }
  };

  function catSVG(pose, paletteName, flags) {
    var p = PALETTES[paletteName] || PALETTES.orange;
    var draw = POSES[pose] || POSES.sitting;
    var inner = draw(p, flags.indexOf("closed") >= 0);
    if (flags.indexOf("flip") >= 0) inner = '<g transform="translate(200 0) scale(-1 1)">' + inner + "</g>";
    return '<svg viewBox="0 0 200 160" aria-hidden="true" focusable="false">' + inner + "</svg>";
  }

  document.querySelectorAll("[data-cat]").forEach(function (el) {
    var parts = el.getAttribute("data-cat").split(/\s+/);
    var flags = (el.getAttribute("data-flags") || "").split(/\s+/);
    el.innerHTML = catSVG(parts[0], parts[1], flags);
    el.classList.add("cat-" + parts[0]);
  });

  // Replay the hero animation.
  var stage = document.querySelector(".stage");
  var replay = document.querySelector("[data-replay]");
  if (stage && replay) {
    replay.addEventListener("click", function () {
      stage.classList.remove("play");
      void stage.offsetWidth; // restart CSS animations
      stage.classList.add("play");
    });
  }

  // Scenes that play once and restart (the meme wall and the cat pile).
  var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.querySelectorAll("[data-loop]").forEach(function (scene) {
    if (still) return;
    var every = parseInt(scene.getAttribute("data-loop"), 10) || 5000;
    var timer = null;
    function run() {
      scene.classList.remove("run");
      void scene.offsetWidth;
      scene.classList.add("run");
    }
    function start() { if (!timer) { run(); timer = setInterval(run, every); } }
    function stop() { clearInterval(timer); timer = null; }
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (entries) {
        entries.forEach(function (e) { if (e.isIntersecting) start(); else stop(); });
      }).observe(scene);
    } else {
      start();
    }
  });

  // Copy buttons.
  document.querySelectorAll("[data-copy]").forEach(function (btn) {
    var label = btn.querySelector("span");
    var original = label ? label.textContent : "";
    btn.addEventListener("click", function () {
      var target = document.getElementById(btn.getAttribute("data-copy"));
      if (!target) return;
      var text = target.textContent.trim();
      var done = function () {
        btn.classList.add("copied");
        if (label) label.textContent = "Copiato!";
        setTimeout(function () {
          btn.classList.remove("copied");
          if (label) label.textContent = original;
        }, 1800);
      };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(done, function () { selectText(target); });
      } else {
        selectText(target);
      }
    });
  });

  function selectText(node) {
    var range = document.createRange();
    range.selectNodeContents(node);
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
  }

  // Download buttons: point straight at the DMG of the latest release. The
  // file name carries the version, so ask the GitHub API for it; without
  // JavaScript or if the API fails, the link opens the release page.
  var downloads = document.querySelectorAll("[data-download]");
  if (downloads.length && window.fetch) {
    fetch("https://api.github.com/repos/kkratterf/maramao/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (release) {
        if (!release || !release.assets) return;
        var dmg = release.assets.filter(function (a) { return /\.dmg$/.test(a.name); })[0];
        if (!dmg) return;
        downloads.forEach(function (link) {
          link.href = dmg.browser_download_url;
          link.title = "Maramao " + release.tag_name + " · .dmg";
        });
      })
      .catch(function () {});
  }

  var year = document.querySelector("[data-year]");
  if (year) year.textContent = String(new Date().getFullYear());
})();
