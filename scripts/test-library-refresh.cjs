// Exercise the production ArkTS metadata loader with deterministic cache/network responses.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function host() {
  const calls = [], cached = new Map(), remote = new Map();
  const source = fs.readFileSync(path.join(root, 'data/LibraryStore.ets'), 'utf8');
  const method = source.slice(source.indexOf('  async enrichMissingMetadata('), source.indexOf('  async fetchArticle('));
  const context = { exports: {}, ArticleBody: {firstArticlePhotoKey: (articles, photos) => photos?.[0] || ''} };
  vm.createContext(context);
  vm.runInContext(ts.transpileModule(`export class Loader { ${method} }`, {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText, context);
  const loader = new context.exports.Loader();
  loader.cachedArticle = row => cached.get(row.stem());
  loader.fetchArticle = async row => {calls.push(row.stem()); const value=remote.get(row.stem()); if(value instanceof Error) throw value; return value;};
  return {loader,calls,cached,remote};
}
const row = (id, key='') => ({stem:()=>id, hasArticles:true, title:'old', tags:['old'], coverPhotoKey:key});
const doc = (title, key) => ({articles:[{title}],tags:[],photos:key?[key]:[]});
test('ordinary entry reuses article cache, explicit refresh replaces cached empty cover', async()=>{
 const h=host(), r=row('a');h.cached.set('a',doc('cached',''));h.remote.set('a',doc('new','photos/new.jpg'));
 await h.loader.enrichMissingMetadata([r]);assert.equal(r.title,'cached');assert.equal(h.calls.length,0);
 await h.loader.enrichMissingMetadata([r],undefined,true);assert.equal(r.title,'new');assert.equal(r.coverPhotoKey,'photos/new.jpg');assert.deepEqual(h.calls,['a']);
});
test('target notification bypasses only its cache and successful empty response clears old fields', async()=>{
 const h=host(), a=row('a','photos/old.jpg'), b=row('b','photos/b.jpg');h.cached.set('a',doc('cached','photos/old.jpg'));h.remote.set('a',doc('',''));
 await h.loader.enrichMissingMetadata([a,b],['a']);assert.deepEqual(h.calls,['a']);assert.equal(a.title,'');assert.equal(a.coverPhotoKey,'');assert.equal(a.tags.length,0);assert.equal(b.title,'old');assert.equal(b.coverPhotoKey,'photos/b.jpg');
});
test('failed refresh keeps the last visible metadata and can retry later', async()=>{
 const h=host(), r=row('a','photos/old.jpg');h.remote.set('a',new Error('offline'));
 assert.equal(await h.loader.enrichMissingMetadata([r],undefined,true),false);assert.equal(r.coverPhotoKey,'photos/old.jpg');
 h.remote.set('a',doc('recovered','photos/new.jpg'));await h.loader.enrichMissingMetadata([r],undefined,true);assert.equal(r.coverPhotoKey,'photos/new.jpg');
});
