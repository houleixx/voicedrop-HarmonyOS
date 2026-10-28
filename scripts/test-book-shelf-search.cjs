const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(file, imports = {}) {
  const context = { exports: {}, require: name => { if (!(name in imports)) throw Error(name); return imports[name]; } };
  vm.createContext(context);
  vm.runInContext(ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, context);
  return context.exports;
}
const core = load('core/BookShelfSearch.ets');
const { BookShelfSearch: search, BookSearchRequestState: State } = core;
let identity = 'account-a', bearer = 'test-bearer', response;
const calls = [];
const shelfCache = new Map();
const { ShelfBook, BooksService } = load('data/BooksService.ets', {
  '../net/HttpClient': { httpClient: {get: async (...args) => { calls.push(args); return typeof response === 'function' ? response() : response; }} },
  './AppPreferences': {appPreferences: {bookShelfCache: key => shelfCache.get(key) || '', saveBookShelfCache: async (key, raw) => shelfCache.set(key, raw)}}, '../core/Api': {Api: {PUBLIC_WEB_BASE: 'https://example.invalid'}},
  './AuthStore': {authStore: {bookShelfCacheIdentity: () => identity, bearer: () => bearer}},
  '../core/BookShelfSearch': core,
  '../core/BookShelfCachePolicy': load('core/BookShelfCachePolicy.ets')
});
const book = new ShelfBook({slug:'one', title:'完整书名', main:'主标题', sub:'副标题', author:'Alice', category:'AI', mine:true});
const entries = search.parse(JSON.stringify({books:[{slug:'one',sub:'索引副题',intro:'导读钩子',toc:[{t:'Chapter One',b:'如何搭建系统'}]}]}));
test('optional category and strict ownership survive shelf parsing', () => {
  const books = new BooksService().parse(JSON.stringify({books:[{slug:'a',mine:true,category:'商业'},{slug:'b',mine:'true',category:null},{slug:'c',category:'未来'}]}));
  assert.equal(books[0].mine,true); assert.equal(books[0].category,'商业');
  assert.equal(books[1].mine,false); assert.equal(books[1].category,'');
  assert.equal(search.matchesFilter(books[2],'全部'),true);
});
test('filters show only present canonical categories in canonical order', () => {
  const books=['故事','AI','商业','未来',''].map(category => new ShelfBook({slug:category,category}));
  assert.deepEqual(Array.from(search.filters(books)),['全部','我的','商业','AI','故事']);
});
test('mine, category and search combine without reordering or adding index-only books', () => {
  const books=[book,new ShelfBook({slug:'two',category:'AI',author:'Alice'}),new ShelfBook({slug:'three',mine:true,category:'故事'})];
  const visible=books.filter(b=>search.matchesFilter(b,'我的') && search.hit(b,'alice',entries.find(e=>e.slug===b.slug))!==undefined);
  assert.deepEqual(visible.map(b=>b.slug),['one']);
  assert.equal(search.matchesFilter(book,'故事'),false);
});
test('title, main, subtitle, author and category match trimmed case-insensitive queries', () => {
  for(const query of ['完整','主标题','副标题',' ALICE ','ai']) assert.equal(search.hit(book,query),'');
  assert.equal(search.hit(book,'missing'),undefined);
});
test('supplementary subtitle and introduction match without chapter hint', () => {
  for(const query of ['索引副题','钩子']) assert.equal(search.hit(book,query,entries[0]),'');
});
test('chapter title and brief show first matching chapter title', () => {
  assert.equal(search.hit(book,'chapter',entries[0]),'Chapter One');
  assert.equal(search.hit(book,'搭建',entries[0]),'Chapter One');
  assert.equal(search.hit(book,'Alice',entries[0]),'');
});
test('blank query keeps write tile; nonempty query hides it', () => {
  assert.equal(search.showWrite('  \n '),true); assert.equal(search.showWrite('AI'),false);
  assert.equal(search.hit(book,' '),'');
});
test('malformed, HTML and missing books indexes fail instead of caching empty success', () => {
  for(const raw of ['<html>old backend</html>','{}','null','{"books":{}}']) assert.throws(()=>search.parse(raw));
  assert.equal(search.parse('{"books":[]}').length,0);
});
test('search parser tolerates missing fields and malformed entries', () => {
  const parsed=search.parse('{"books":[null,{}, {"slug":"a","sub":null,"intro":7,"toc":[null,{"t":null,"b":4},{"t":"标题"}]}]}');
  assert.equal(parsed.length,1); assert.equal(parsed[0].sub,''); assert.equal(parsed[0].intro,'');
  assert.equal(parsed[0].toc[0].t,''); assert.equal(parsed[0].toc[1].t,'标题');
});
test('lazy request gate deduplicates typing and caches loaded response', () => {
  const state=new State(); state.invalidate('a'); assert.equal(state.begin(' '),-1);
  const generation=state.begin('a'); assert.equal(state.begin('ab'),-1);
  assert.equal(state.finish(generation,'a',true),true); assert.equal(state.begin('abc'),-1);
});
test('failed index remains local-only until explicit retry', () => {
  const state=new State(); state.invalidate('a'); const generation=state.begin('q');
  state.finish(generation,'a',false); assert.equal(state.begin('typing'),-1);
  const retry=state.begin('typing',true); assert.ok(retry>generation); assert.equal(state.begin('typing',true),-1);
});
test('refresh rejects old request completion and permits a new index load', () => {
  const state=new State(); state.invalidate('a'); const old=state.begin('q');
  state.invalidate('a'); const current=state.begin('q');
  assert.equal(state.finish(old,'a',true),false); assert.equal(state.loading,true);
  assert.equal(state.finish(current,'a',true),true);
});
test('account transitions and leaving the page reject old responses', () => {
  const state=new State(); state.invalidate('a'); const old=state.begin('q');
  assert.equal(state.finish(old,'b',true),false);
  state.invalidate('b'); assert.equal(state.finish(old,'a',true),false);
  const next=state.begin('q'); state.invalidate(''); assert.equal(state.finish(next,'b',true),false);
});
test('search service sends bearer to search endpoint and parses valid response', async () => {
  response={ok:()=>true,text:'{"books":[{"slug":"one"}]}'}; calls.length=0;
  const result=await new BooksService().searchIndex(); assert.equal(result[0].slug,'one');
  assert.deepEqual(calls[0],['https://example.invalid/books/?format=search','test-bearer']);
});
test('search service rejects HTTP failures and old-account responses', async () => {
  response={ok:()=>false,code:503,text:'{}'}; await assert.rejects(()=>new BooksService().searchIndex(),/503/);
  response=()=>{identity='account-b'; return {ok:()=>true,text:'{"books":[]}'};};
  await assert.rejects(()=>new BooksService().searchIndex(),/账号已切换/); identity='account-a';
});
test('old backend HTTP 200 HTML can be retried successfully', async () => {
  response={ok:()=>true,text:'<html>legacy shelf</html>'}; await assert.rejects(()=>new BooksService().searchIndex());
  response={ok:()=>true,text:'{"books":[]}'}; assert.equal((await new BooksService().searchIndex()).length,0);
});

test('row identity changes when filtering shifts book covers and when search hides the write tile', () => {
  const a=new ShelfBook({slug:'a'}), b=new ShelfBook({slug:'b'}), c=new ShelfBook({slug:'c'});
  assert.equal(search.rowKey([a,b,c],'',0),'0:write:a');
  assert.equal(search.rowKey([b,c],'',0),'0:write:b');
  assert.equal(search.rowKey([b,c],'query',0),'0:b:c');
  assert.equal(search.rowKey([a,b,c],'',2),'2:b:c');
  assert.equal(search.rowKey([a,b],'query',2),'2::');
});

const { AppLocale } = load('core/AppLocale.ets', {
  '@kit.LocalizationKit': {}, './AppLanguage': load('core/AppLanguage.ets')
});
test('shelf filter labels translate without changing canonical category keys', () => {
  const labels = {'全部':'All','我的':'Mine','商业':'Business','投资':'Investing','AI':'AI',
    '科学':'Science','人文':'Humanities','身心':'Wellness','生活':'Lifestyle','故事':'Stories'};
  for (const [category, english] of Object.entries(labels)) {
    assert.equal(AppLocale.resolve('en', category), english);
    assert.equal(AppLocale.resolve('zh-Hans', category), category);
  }
  const books = search.CATEGORIES.map(category => new ShelfBook({slug:category,category}));
  const keys = Array.from(search.filters(books));
  assert.deepEqual(keys.map(key => AppLocale.resolve('en',key)),Object.values(labels));
  assert.deepEqual(Array.from(search.filters(books)),keys);
  assert.equal(search.matchesFilter(books[0],'商业'),true);
  assert.equal(AppLocale.resolve('en','未知分类'),'未知分类');
});


test('video is strict optional boolean and survives account-scoped raw response cache', async () => {
  const service = new BooksService();
  const raw = JSON.stringify({books:[{slug:'video',video:true},{slug:'legacy'},{slug:'false',video:false},{slug:'string',video:'true'},{slug:'number',video:1}]});
  response={ok:()=>true,text:raw};
  const fresh=await service.load();
  assert.deepEqual(Array.from(fresh,b=>b.video),[true,false,false,false,false]);
  assert.deepEqual(Array.from(service.cached(),b=>b.video),[true,false,false,false,false]);
  shelfCache.set(identity,'{"books":[{"slug":"old-cache"}]}');
  assert.equal(service.cached()[0].video,false);
});
test('video tab follows mine only when a video book exists and stale selection falls back', () => {
  const video=new ShelfBook({slug:'video',video:true,category:'AI'});
  const plain=new ShelfBook({slug:'plain',category:'科学'});
  assert.deepEqual(Array.from(search.filters([plain,video])),['全部','我的','视频','AI','科学']);
  assert.equal(search.validFilter([video],'视频'),'视频');
  assert.equal(search.validFilter([plain],'视频'),'全部');
  assert.equal(search.filters([]).includes('视频'),false);
  assert.equal(search.filters([plain]).includes('视频'),false);
  assert.equal(AppLocale.resolve('en','视频'),'Video');
});
test('video filter combines metadata and chapter searches without reordering', () => {
  const books=[new ShelfBook({slug:'one',video:true,title:'Alice'}),new ShelfBook({slug:'plain',title:'Alice'}),new ShelfBook({slug:'two',video:true,title:'Other'})];
  const index=search.parse('{"books":[{"slug":"two","toc":[{"t":"Alice chapter","b":"text"}]}]}');
  const visible=books.filter(b=>search.matchesFilter(b,'视频') && search.hit(b,'alice',index.find(e=>e.slug===b.slug))!==undefined);
  assert.deepEqual(visible.map(b=>b.slug),['one','two']);
  assert.equal(search.matchesFilter(new ShelfBook({slug:'legacy'}),'视频'),false);
  assert.equal(search.matchesFilter(new ShelfBook({slug:'false',video:false}),'视频'),false);
  assert.equal(search.showWrite(''),true);
});
