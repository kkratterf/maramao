// Maramao website: the few interactions of the page.

(function () {
  "use strict";

  // Clips play only while they are on screen. They are muted loops with
  // preload="none", so nothing is downloaded until a clip scrolls into view.
  // With reduced motion they stay on their poster and get controls instead.
  var clips = document.querySelectorAll("video[data-clip]");
  var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (still) {
    clips.forEach(function (v) { v.controls = true; });
  } else if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { var p = e.target.play(); if (p && p.catch) p.catch(function () {}); }
        else e.target.pause();
      });
    }, { rootMargin: "120px 0px" });
    clips.forEach(function (v) { io.observe(v); });
  } else {
    clips.forEach(function (v) { v.autoplay = true; v.preload = "auto"; });
  }

  // Break mode tabs: one clip on stage at a time. Hidden panels never load
  // their video; the observer above starts the new one once it is shown.
  document.querySelectorAll("[data-tabs]").forEach(function (box) {
    var tabs = Array.prototype.slice.call(box.querySelectorAll('[role="tab"]'));
    function select(tab, focus) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute("aria-selected", on ? "true" : "false");
        t.tabIndex = on ? 0 : -1;
        var panel = document.getElementById(t.getAttribute("aria-controls"));
        panel.hidden = !on;
        var v = panel.querySelector("video");
        if (v && !on) v.pause();
      });
      if (focus) tab.focus();
    }
    // Until the visitor picks a tab, the modes play through one after the
    // other: each clip runs once, its tab fills up, then the next one starts.
    // A click or an arrow key stops that and loops the chosen clip.
    var auto = !still && "IntersectionObserver" in window;
    var stopAuto = function () {
      if (!auto) return;
      auto = false;
      box.classList.remove("is-auto");
      tabs.forEach(function (t) {
        var v = document.getElementById(t.getAttribute("aria-controls")).querySelector("video");
        if (v) { v.loop = true; if (v.ended) { var p = v.play(); if (p && p.catch) p.catch(function () {}); } }
      });
    };
    tabs.forEach(function (tab, i) {
      var bar = document.createElement("i");
      bar.className = "mode-progress";
      bar.setAttribute("aria-hidden", "true");
      tab.appendChild(bar);
      var v = document.getElementById(tab.getAttribute("aria-controls")).querySelector("video");
      if (v && auto) {
        v.loop = false;
        v.addEventListener("timeupdate", function () {
          if (auto && v.duration) bar.style.setProperty("--p", String(v.currentTime / v.duration));
        });
        v.addEventListener("ended", function () {
          if (!auto) return;
          var nextTab = tabs[(i + 1) % tabs.length];
          var nv = document.getElementById(nextTab.getAttribute("aria-controls")).querySelector("video");
          if (nv) nv.currentTime = 0;
          bar.style.setProperty("--p", "0");
          select(nextTab);
        });
      }
      tab.addEventListener("click", function () { stopAuto(); select(tab); });
      tab.addEventListener("keydown", function (e) {
        var step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[e.key];
        if (!step) return;
        e.preventDefault();
        stopAuto();
        select(tabs[(i + step + tabs.length) % tabs.length], true);
      });
    });
    if (auto) box.classList.add("is-auto");
  });

  // FAQ accordion: every answer is open without JavaScript. With it they
  // start closed and slide open, like the coss/Base UI accordion.
  document.querySelectorAll("[data-accordion] .acc-trigger").forEach(function (btn) {
    var panel = document.getElementById(btn.getAttribute("aria-controls"));
    if (!panel) return;
    btn.setAttribute("aria-expanded", "false");
    panel.hidden = true;
    btn.addEventListener("click", function () {
      var open = btn.getAttribute("aria-expanded") === "true";
      btn.setAttribute("aria-expanded", open ? "false" : "true");
      if (still) { panel.hidden = open; return; }
      if (!open) {
        panel.hidden = false;
        var h = panel.scrollHeight;
        panel.style.height = "0px";
        requestAnimationFrame(function () { panel.style.height = h + "px"; });
      } else {
        panel.style.height = panel.scrollHeight + "px";
        requestAnimationFrame(function () { panel.style.height = "0px"; });
      }
      panel.addEventListener("transitionend", function done() {
        panel.removeEventListener("transitionend", done);
        if (btn.getAttribute("aria-expanded") === "false") panel.hidden = true;
        panel.style.height = "";
      });
    });
  });

  // Download buttons: point straight at the DMG of the latest release. The
  // file name carries the version, so ask the GitHub API for it; without
  // JavaScript or if the API fails, the link opens the release page.
  var api = "https://api.github.com/repos/kkratterf/maramao";
  var json = function (url) {
    return fetch(url, { headers: { Accept: "application/vnd.github+json" } }).then(function (r) { return r.ok ? r.json() : null; });
  };
  var downloads = document.querySelectorAll("[data-download]");
  if (downloads.length && window.fetch) {
    json(api + "/releases/latest")
      .then(function (release) {
        if (!release || !release.assets) return;
        var dmg = release.assets.filter(function (a) { return /\.dmg$/.test(a.name); })[0];
        if (!dmg) return;
        downloads.forEach(function (link) {
          link.href = dmg.browser_download_url;
          link.title = "Maramao " + release.tag_name + " · .dmg";
        });
        document.querySelectorAll("[data-version]").forEach(function (el) {
          el.textContent = release.tag_name.replace(/^v/, "");
        });
      })
      .catch(function () {});
  }

  // GitHub button: just the icon until the repository has 10 stars.
  var stars = document.querySelectorAll("[data-stars]");
  if (stars.length && window.fetch) {
    json(api)
      .then(function (repo) {
        var n = repo && repo.stargazers_count;
        if (!n || n < 10) return;
        var label = n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k" : String(n);
        stars.forEach(function (el) {
          var span = document.createElement("span");
          span.textContent = label;
          el.appendChild(span);
          el.setAttribute("aria-label", el.getAttribute("aria-label") + ", " + n + " ★");
        });
      })
      .catch(function () {});
  }

  // The logo meows when the pointer passes over it: a real recorded cat, a
  // different one each time (CC0, Joseph Sardin, BigSoundBank: the same voices
  // the app uses, trimmed and levelled). Browsers keep audio locked until the
  // visitor first clicks, taps or types, so the sounds are fetched only then and
  // a hover before that stays silent. On the home page a click on the logo
  // counts as that first gesture: it meows and scrolls to the top instead of
  // reloading the page.
  var logos = document.querySelectorAll(".brand");
  var AC = window.AudioContext || window.webkitAudioContext;
  if (logos.length && AC && window.fetch) {
    var base = (document.querySelector('script[src$="site.js"]') || {}).src || "";
    base = base.replace(/site\.js.*$/, "media/meows/");
    var names = ["meow-1", "meow-3", "meow-7", "meow-8", "meow-10", "meow-12",
      "little-meow-1", "little-meow-2", "little-meow-3", "little-meow-4",
      "little-meow-5", "little-meow-7", "little-meow-9", "little-meow-11"];
    var ctx = null, voices = [], bag = [], last = null, playing = null, pending = false;
    var load = function () {
      names.forEach(function (n) {
        fetch(base + n + ".mp3")
          .then(function (r) { return r.ok ? r.arrayBuffer() : null; })
          .then(function (data) {
            if (!data) return;
            // Safari only has the callback form of decodeAudioData.
            ctx.decodeAudioData(data, function (buf) {
              voices.push(buf);
              if (pending) { pending = false; meow(); }
            }, function () {});
          })
          .catch(function () {});
      });
    };
    var unlock = function () {
      if (!ctx) {
        try { ctx = new AC(); } catch (e) { return; }
        load();
      }
      if (ctx.state === "suspended") ctx.resume();
    };
    ["pointerdown", "pointerup", "keydown", "touchend"].forEach(function (t) {
      window.addEventListener(t, unlock, { passive: true, capture: true });
    });
    // A shuffled bag: every voice plays once before any repeats, and never
    // the same one twice in a row.
    var next = function () {
      if (!bag.length) {
        bag = voices.slice();
        for (var i = bag.length - 1; i > 0; i--) {
          var j = Math.floor(Math.random() * (i + 1)), t = bag[i]; bag[i] = bag[j]; bag[j] = t;
        }
        if (bag.length > 1 && bag[bag.length - 1] === last) bag.unshift(bag.pop());
      }
      return (last = bag.pop());
    };
    var meow = function () {
      if (!ctx || ctx.state !== "running" || !voices.length) return;
      var t = ctx.currentTime;
      // A new hover cuts the meow that is still going, so every hover answers.
      if (playing) {
        playing.gain.gain.setTargetAtTime(0, t, 0.02);
        playing.src.stop(t + 0.1);
      }
      var src = ctx.createBufferSource(), gain = ctx.createGain();
      src.buffer = next();
      src.playbackRate.value = 0.94 + Math.random() * 0.12;
      gain.gain.value = 0.55;
      src.connect(gain); gain.connect(ctx.destination);
      src.start(t);
      var me = playing = { src: src, gain: gain };
      src.onended = function () { if (playing === me) playing = null; };
    };
    logos.forEach(function (el) {
      el.addEventListener("pointerenter", function (e) { if (e.pointerType !== "touch") meow(); });
      el.addEventListener("click", function (e) {
        var here = el.href && el.href.split("#")[0] === location.href.split("#")[0];
        if (!here) return;
        e.preventDefault();
        unlock();
        // On the first click the context may still be resuming and the
        // voices still loading: meow as soon as both are ready.
        if (!voices.length) pending = true;
        else if (ctx && ctx.state !== "running" && ctx.resume) ctx.resume().then(meow, function () {});
        else meow();
        window.scrollTo({ top: 0, behavior: still ? "auto" : "smooth" });
      });
    });
  }

  var year = document.querySelector("[data-year]");
  if (year) year.textContent = String(new Date().getFullYear());
})();
