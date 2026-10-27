const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/flutter_bootstrap.js', 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '')
  .replaceAll('__APP_VERSION__', '1.0.1.27');
async function start(release = '27', fail = false) {
  const nodes = [], removed = [], handlers = {};
  let redirect;
  const node = () => ({children: [], style: {}, append(x) {this.children.push(x)}, setAttribute() {}});
  const context = {
    URL, Date, location: {href: 'https://example.com/dev/#/ticket', replace(x) {redirect = x}},
    document: {baseURI: 'https://example.com/dev/', hidden: false,
      getElementById: id => nodes.find(n => n.id === id),
      createElement: node, createTextNode: text => text,
      body: {append(n) {nodes.push(n)}}, addEventListener: (name, cb) => handlers[name] = cb},
    navigator: {serviceWorker: {getRegistrations: async () => ['dev', 'prod'].map(env => ({
      scope: `https://example.com/${env}/`, unregister: async () => removed.push(env)
    }))}},
    fetch: async (url, options) => {
      assert.equal(options.cache, 'no-store');
      assert.equal(url.pathname, '/dev/version.json');
      if (fail) throw Error('Offline');
      return {ok: true, json: async () => ({version: '1.0.1', build_number: release})};
    },
    _flutter: {buildConfig: {builds: [{mainJsPath: 'main.dart.js'}]}, loader: {load: async () => {}}},
    window: {addEventListener: (name, cb) => handlers[name] = cb},
    setInterval: cb => handlers.interval = cb
  };
  await vm.runInNewContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  return {nodes, removed, handlers, context, redirect: () => redirect};
}
test('Versioned code loads, only DEV worker removed, no notice for matching release', async () => {
  const app = await start();
  assert.deepEqual(app.removed, ['dev']);
  assert.equal(app.context._flutter.buildConfig.builds[0].mainJsPath, 'main.1.0.1.27.dart.js');
  assert.equal(app.nodes.length, 0);
});
test('New release prompts once and reload preserves ticket route with fresh URL', async () => {
  const app = await start('28');
  assert.equal(app.nodes.length, 1);
  assert.equal(app.redirect(), undefined);
  await app.handlers.focus();
  assert.equal(app.nodes.length, 1);
  app.nodes[0].children[1].onclick();
  const target = new URL(app.redirect());
  assert.equal(target.searchParams.get('release'), '1.0.1.28');
  assert.equal(target.hash, '#/ticket');
});
test('Offline check does not interrupt app or display a false update', async () => {
  const app = await start('28', true);
  assert.equal(app.nodes.length, 0);
});
