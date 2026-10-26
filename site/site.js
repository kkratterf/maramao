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
    tabs.forEach(function (tab, i) {
      tab.addEventListener("click", function () { select(tab); });
      tab.addEventListener("keydown", function (e) {
        var step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[e.key];
        if (!step) return;
        e.preventDefault();
        select(tabs[(i + step + tabs.length) % tabs.length], true);
      });
    });
  });

  // The hero Mac: a few seconds of work, then the break takes over, and again.
  // With reduced motion it stays on the break, the part worth seeing.
  var demo = document.querySelector("[data-demo]");
  if (demo) {
    var clock = demo.querySelector("[data-demo-clock]");
    var brk = demo.querySelector("[data-demo-break]");
    var fmt = function (s) { return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2); };
    var setState = function (state) { demo.setAttribute("data-state", state); };
    if (still) {
      setState("break");
      if (clock) clock.textContent = "4:59";
    } else {
      var tick = 0;
      setState("work");
      setInterval(function () {
        tick = (tick + 1) % 14; // 5 s of work, 9 s of break
        if (tick < 5) {
          setState("work");
          if (clock) clock.textContent = fmt(5 - tick);
        } else {
          setState("break");
          var left = 299 - (tick - 5);
          if (clock) clock.textContent = fmt(left);
          if (brk) brk.textContent = fmt(left);
        }
      }, 1000);
    }
  }

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

  var year = document.querySelector("[data-year]");
  if (year) year.textContent = String(new Date().getFullYear());
})();
