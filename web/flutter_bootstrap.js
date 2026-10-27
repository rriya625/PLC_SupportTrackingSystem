{{flutter_js}}
{{flutter_build_config}}

(async () => {
  const runningVersion = '__APP_VERSION__';
  const base = new URL(document.baseURI);
  // Retire only this portal's legacy worker; leave other sites/environments alone.
  if ('serviceWorker' in navigator) {
    try {
      for (const registration of await navigator.serviceWorker.getRegistrations()) {
        if (registration.scope === base.href) await registration.unregister();
      }
    } catch (_) { /* The portal can still start if browser settings deny access. */ }
  }
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath === 'main.dart.js' && !runningVersion.startsWith('__')) {
      build.mainJsPath = `main.${runningVersion}.dart.js`;
    }
  }
  let checking = false;
  async function checkVersion() {
    if (checking || document.hidden || document.getElementById('portal-update')) return;
    checking = true;
    try {
      const url = new URL('version.json', base);
      url.searchParams.set('check', Date.now());
      const response = await fetch(url, {cache: 'no-store'});
      if (!response.ok) return;
      const release = await response.json();
      if (!release.version || !release.build_number) return;
      const latest = `${release.version}.${release.build_number}`;
      if (latest === runningVersion) return;
      const notice = document.createElement('div');
      notice.id = 'portal-update';
      notice.setAttribute('role', 'status');
      notice.style.cssText = 'position:fixed;top:8px;left:5%;right:5%;z-index:2147483647;background:#fff3cd;color:#202020;padding:16px;border:2px solid #856404;border-radius:8px;font:16px Arial;box-shadow:0 2px 8px #555';
      notice.append(document.createTextNode(`Version ${latest} is available. Save your work, then reload. `));
      const button = document.createElement('button');
      button.textContent = 'Reload';
      button.style.cssText = 'padding:10px 18px;cursor:pointer';
      button.onclick = () => {
        const destination = new URL(location.href);
        destination.searchParams.set('release', latest);
        destination.searchParams.set('reload', Date.now());
        location.replace(destination.href);
      };
      notice.append(button);
      document.body.append(notice);
    } catch (_) { /* Offline/failed checks must not interrupt work. */ }
    finally { checking = false; }
  }
  await _flutter.loader.load();
  checkVersion();
  setInterval(checkVersion, 60000);
  window.addEventListener('focus', checkVersion);
  document.addEventListener('visibilitychange', checkVersion);
})();
