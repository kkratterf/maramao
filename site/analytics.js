// Page analytics with PostHog, without cookies: `persistence: 'memory'` keeps
// the anonymous id in memory only (no cookies, no localStorage), so the site
// needs no consent banner. It runs only on the production host, so local
// previews and forks send nothing. The project key is public by design: it
// can only send events, not read them. Same PostHog project and settings as
// kkratter.com, f4, maramao, fratmscript and portfolio.kkratter.com.
(function () {
  var key = "phc_REPLACE_WITH_PROJECT_KEY";
  if (key.indexOf("REPLACE") !== -1) return;
  if (location.hostname !== "maramao.kkratter.com") return;
  !function(t,e){var o,n,p,r;e.__SV||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split(".");2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}(p=t.createElement("script")).type="text/javascript",p.crossOrigin="anonymous",p.async=!0,p.src=s.api_host.replace(".i.posthog.com","-assets.i.posthog.com")+"/static/array.js",(r=t.getElementsByTagName("script")[0]).parentNode.insertBefore(p,r);var u=e;for(void 0!==a?u=e[a]=[]:a="posthog",u.people=u.people||[],u.toString=function(t){var e="posthog";return"posthog"!==a&&(e+="."+a),t||(e+=" (stub)"),e},u.people.toString=function(){return u.toString(1)+".people (stub)"},o="init capture register register_once unregister identify reset get_distinct_id set_config opt_in_capturing opt_out_capturing has_opted_out_capturing".split(" "),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);
  posthog.init(key, {
    api_host: "https://eu.i.posthog.com",
    persistence: "memory",
    person_profiles: "identified_only",
    disable_session_recording: true,
  });
})();
