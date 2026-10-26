const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(file, imports = {}) {
    const c = {
        exports: {}, require: n => {
            if (!(n in imports))
                throw Error(n);
            return imports[n];
        }
    };
    vm.createContext(c);
    vm.runInContext(ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
        compilerOptions: {
            target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
        }
    }).outputText, c);
    return c.exports;
}
const core = load('core/BookWritingOptions.ets'), { BookWritingOptions: options } = core;
function harness({ getCode = 200, getText = '{"name":"Old"}', putCode = 200, putThrows = false, postCode = 202, postText = '', changeAfterPut = false } = {}) {
    let identity = 'user-a';
    const calls = [];
    const response = (code, text = '') => ({
        code, text, ok: () => code >= 200 && code < 300
    });
    const http = {
        get: async (...a) => {
            calls.push(['get', ...a]);
            return response(getCode, getText);
        }, putJson: async (...a) => {
            calls.push(['put', ...a]);
            if (putThrows)
                throw Error('offline');
            if (changeAfterPut)
                identity = 'user-b';
            return response(putCode);
        }, postJson: async (...a) => {
            calls.push(['post', ...a]);
            return response(postCode, postText);
        }
    };
    const { BookWritingService, BookSeedBody } = load('data/BookWritingService.ets', {
        './AuthStore': {
            authStore: {
                storageScope: () => identity, bearer: () => 'bearer-a'
            }
        }, '../net/HttpClient': {
            httpClient: http
        }, '../core/AppLocale': {
            AppLocale: {
                bookWritingCreditsInsufficient: (n, h) => `need ${n}, have ${h}`
            }
        }, '../core/Api': {
            Api: {
                FILES: 'https://example.invalid/files/api'
            }
        }, '../core/BookWritingOptions': core
    });
    return {
        service: new BookWritingService(), BookSeedBody, calls
    };
}
test('unchanged author does not save, modified and cleared names do', () => {
    assert.equal(options.nameToSave(' Old ', 'Old'), undefined);
    assert.equal(options.nameToSave(' New ', 'Old'), 'New');
    assert.equal(options.nameToSave('  ', 'Old'), '');
    assert.equal(options.nameToSave('', undefined), undefined);
    assert.equal(options.nameToSave(' New ', undefined), 'New');
});
test('late profile never overwrites user edits or a deliberate clear', () => {
    assert.equal(options.loadedDraft('', true, 'Old'), '');
    assert.equal(options.loadedDraft('New', true, 'Old'), 'New');
    assert.equal(options.loadedDraft('', false, 'Old'), 'Old');
});
test('nonempty author and true hidden accompany existing seed', async () => {
    const h = harness();
    assert.equal((await h.service.start(' seed ', 'Old', 'Old', true)).accepted, true);
    assert.deepEqual(h.calls.map(c => c[0]), ['post']);
    assert.deepEqual(JSON.parse(JSON.stringify(h.calls[0][3])), {
        seed: 'seed', hidden: true, author: 'Old'
    });
});
test('changed author saves before charged creation using the same bearer', async () => {
    const h = harness();
    await h.service.start('seed', ' New ', 'Old');
    assert.deepEqual(h.calls.map(c => c[0]), ['put', 'post']);
    assert.equal(h.calls[0][2], 'bearer-a');
    assert.equal(h.calls[1][2], 'bearer-a');
    assert.deepEqual(JSON.parse(JSON.stringify(h.calls[0][3])), {
        name: 'New'
    });
    assert.equal(h.calls[1][3].author, 'New');
    assert.equal(h.calls[1][3].hidden, false);
});
test('clearing a loaded author saves empty before omitting author', async () => {
    const h = harness();
    await h.service.start('seed', '  ', 'Old', false, true);
    assert.deepEqual(h.calls.map(c => c[0]), ['put', 'post']);
    assert.equal(h.calls[0][3].name, '');
    assert.equal('author' in h.calls[1][3], false);
});
test('failed name HTTP save cannot place a charged order', async () => {
    const h = harness({
        putCode: 500
    });
    const r = await h.service.start('seed', 'New', 'Old');
    assert.equal(r.accepted, false);
    assert.deepEqual(h.calls.map(c => c[0]), ['put']);
});
test('network name save failure cannot place a charged order', async () => {
    const h = harness({
        putThrows: true
    });
    assert.equal((await h.service.start('seed', 'New', 'Old')).accepted, false);
    assert.deepEqual(h.calls.map(c => c[0]), ['put']);
});
test('unknown empty author retries profile and retains an unedited name', async () => {
    const h = harness();
    await h.service.start('seed');
    assert.deepEqual(h.calls.map(c => c[0]), ['get', 'post']);
    assert.equal(h.calls[1][3].author, 'Old');
});
test('unknown author explicitly cleared saves empty after successful reread', async () => {
    const h = harness();
    await h.service.start('seed', '', undefined, false, true);
    assert.deepEqual(h.calls.map(c => c[0]), ['get', 'put', 'post']);
    assert.equal(h.calls[1][3].name, '');
});
test('failed profile retry keeps input and never creates a book', async () => {
    const h = harness({
        getCode: 503
    });
    assert.equal((await h.service.start('seed')).accepted, false);
    assert.deepEqual(h.calls.map(c => c[0]), ['get']);
});
test('missing name on successful profile is known empty; malformed profile rejects', async () => {
    const h = harness({
        getText: '{}'
    });
    assert.equal(await h.service.loadAuthor(), '');
    for (const getText of ['<html>', 'null', '[]', '42', '{"name":7}']) {
        const bad = harness({ getText });
        await assert.rejects(() => bad.service.loadAuthor());
    }
});
test('account switch while saving cannot place an order in another account', async () => {
    const h = harness({
        changeAfterPut: true
    });
    assert.equal((await h.service.start('seed', 'New', 'Old')).accepted, false);
    assert.deepEqual(h.calls.map(c => c[0]), ['put']);
});
test('existing 402 contract still updates balance after name succeeds', async () => {
    const h = harness({
        postCode: 402, postText: '{"need_suanli":320,"suanli":7}'
    });
    const r = await h.service.start('seed', 'Old', 'Old');
    assert.equal(r.balance, 7);
    assert.equal(r.accepted, false);
    assert.equal(r.message, 'need 320, have 7');
});
test('invalid empty seed never saves or orders', async () => {
    const h = harness();
    await h.service.start(' ', 'New', 'Old');
    assert.equal(h.calls.length, 0);
});
