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

  // Copy buttons next to the install commands.
  document.querySelectorAll("[data-copy]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var code = document.getElementById(btn.getAttribute("data-copy"));
      if (!code || !navigator.clipboard) return;
      var label = btn.textContent;
      navigator.clipboard.writeText(code.textContent.trim()).then(function () {
        btn.textContent = btn.getAttribute("data-copied") || "Copied";
        setTimeout(function () { btn.textContent = label; }, 1600);
      });
    });
  });

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
        document.querySelectorAll("[data-version]").forEach(function (el) {
          el.textContent = release.tag_name.replace(/^v/, "");
        });
      })
      .catch(function () {});
  }

  var year = document.querySelector("[data-year]");
  if (year) year.textContent = String(new Date().getFullYear());
})();
