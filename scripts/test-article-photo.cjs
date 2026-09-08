// Run the component's actual lifecycle methods under a deterministic host.
// ArkUI layout remains covered by assembleHap and device validation.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONY_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');

function host() {
  let now = 1000000;
  let nextTimer = 1;
  const timers = new Map();
  const starts = new Map();
  const displayed = new Set();
  const context = {
    exports: {}, console,
    Date: { now: () => now },
    setTimeout: (callback, delay) => { const id = nextTimer++; timers.set(id, { callback, at: now + delay }); return id; },
    clearTimeout: id => timers.delete(id),
    appPreferences: {
      photoWaitStart: key => starts.get(key) || 0,
      setPhotoWait: (key, value) => starts.set(key, value),
      setPhotoLoaded: key => { displayed.add(key); starts.delete(key); }
    }
  };
  vm.createContext(context);
  function compile(source) {
    vm.runInContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, context);
  }
  compile(fs.readFileSync(path.join(root, 'core/PhotoLoadPolicy.ets'), 'utf8'));
  context.PhotoLoadPolicy = context.exports.PhotoLoadPolicy;
  let source = fs.readFileSync(path.join(root, 'components/ArticlePhotoView.ets'), 'utf8');
  source = source.replace(/^import .*\n/gm, '').split('  @Builder')[0] + '\n}';
  source = source.replace('@Component', '').replace('export struct ArticlePhotoView', 'export class ArticlePhotoView')
    .replace(/@Prop(?: @Watch\('[^']+'\))? /g, '').replace(/@State /g, '');
  compile(source);
  return {
    timers, starts, displayed, policy: context.PhotoLoadPolicy,
    advance(ms) { now += ms; },
    view(key = 'users/a/photos/test.jpg') {
      const view = new context.exports.ArticlePhotoView();
      view.photoKey = key; view.intent = 'generated'; view.loadPhoto = async () => 'file://photo.jpg';
      return view;
    }
  };
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('download stays in decoding and does not reset the original timeout', async () => {
  const h = host(), view = h.view();
  view.beginLoad(false); const started = view.startedAt;
  await settle();
  assert.equal(view.state, 'decoding'); assert.equal(view.startedAt, started);
  assert.equal(h.displayed.size, 0); assert.ok(h.timers.size > 0);
  view.loaded(view.activeRequest.id);
  assert.equal(view.state, 'loaded'); assert.equal(h.timers.size, 0);
  assert.equal(h.displayed.has(view.photoKey), true); assert.equal(h.starts.has(view.photoKey), false);
});

test('decode errors preserve the five-minute budget and ignore a late completion', async () => {
  const h = host(), view = h.view(); view.beginLoad(false); await settle();
  const requestId = view.activeRequest.id, started = view.startedAt;
  h.advance(120000); view.failed(requestId); view.loaded(requestId);
  assert.notEqual(view.state, 'loaded'); assert.equal(view.startedAt, started);
  h.advance(180000); view.retryGenerated(); assert.equal(view.state, 'failed');
});

test('reopening keeps its stored start; an explicit reload alone resets the budget', async () => {
  const h = host(), first = h.view(); first.beginLoad(false); await settle();
  const started = first.startedAt; first.aboutToDisappear(); h.advance(60000);
  const second = h.view(); second.beginLoad(false); await settle();
  assert.equal(second.startedAt, started);
  second.retry(); await settle(); assert.equal(second.startedAt, started + 60000);
});

test('a stalled network request expires and its late response is ignored', async () => {
  const h = host(), view = h.view(); let resolve;
  view.loadPhoto = () => new Promise(done => { resolve = done; });
  view.beginLoad(false); const deadline = h.timers.get(view.deadlineTimer);
  h.advance(300000); deadline.callback(); assert.equal(view.state, 'failed');
  resolve('file://late.jpg'); await settle(); assert.equal(view.state, 'failed');
});

test('leaving a component rejects in-flight responses and clears timers', async () => {
  const h = host(), view = h.view(); let resolve;
  view.loadPhoto = () => new Promise(done => { resolve = done; });
  view.beginLoad(false); view.aboutToDisappear();
  resolve('file://late.jpg'); await settle();
  assert.equal(h.timers.size, 0); assert.equal(view.activeRequest.url, '');
});

test('unknown photos retry neutrally, ordinary photos get a short recovery window', async () => {
  const h = host();
  for (const intent of ['unknown', 'original']) {
    const view = h.view('users/a/photos/' + intent + '.jpg'); view.intent = intent;
    view.loadPhoto = async () => ''; view.beginLoad(false); await settle();
    assert.equal(view.state, intent === 'unknown' ? 'fetching' : 'loading');
    h.advance(h.policy.timeoutMs(intent)); view.retryGenerated(); assert.equal(view.state, 'failed');
  }
});

test('an expired reopened task can still display a late completed image', async () => {
  const h = host(), view = h.view(); h.starts.set(view.photoKey, 500000);
  view.beginLoad(false); await settle(); assert.equal(view.state, 'decoding');
  view.loaded(view.activeRequest.id); assert.equal(view.state, 'loaded');
});

test('different account scopes do not share pending starts', async () => {
  const h = host(), first = h.view(); first.beginLoad(false); await settle(); h.advance(60000);
  const other = h.view('users/b/photos/test.jpg'); other.beginLoad(false); await settle();
  assert.notEqual(first.startedAt, other.startedAt);
  first.loaded(first.activeRequest.id); assert.equal(other.state, 'decoding');
});
