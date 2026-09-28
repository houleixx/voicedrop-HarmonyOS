const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const test = require('node:test'), assert = require('node:assert/strict');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
const source = fs.readFileSync(path.resolve(process.env.HARMONY_REPO || path.join(__dirname, '..'), 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const names = ['cancelRecordFabPress', 'launchHomeRecorder', 'handleRecordFabTouch', 'toggleRecording', 'selectHomeTab', 'selectHomeTag'];
const methods = names.map(name => {
    const start = source.search(new RegExp('  private (?:async )?' + name + '\\('));
    assert.ok(start >= 0);
    return source.slice(start, source.indexOf('\n  private ', start + 4));
}).join('\n');
const settle = async () => {
    for (let i = 0; i < 12; i++)
        await Promise.resolve();
};
function deferred() {
    let resolve;
    const promise = new Promise(r => resolve = r);
    return {
        promise, resolve
    };
}
function host(permission = async () => ({
    authResults: [0]
})) {
    const timers = new Map(), calls = {
        start: 0, stop: 0, haptic: 0, permission: 0
    };
    let now = 0, id = 0;
    const context = {
        exports: {}, HomeTabIndex: {
            Recordings: 0, Community: 1, Books: 2
        }, TouchType: {
            Down: 0, Move: 1, Up: 2, Cancel: 3
        }, setTimeout: (fn, ms) => {
            timers.set(++id, {
                fn, time: now + ms
            });
            return id;
        }, clearTimeout: id => timers.delete(id), setInterval: () => 1, RECORDING_METER_INTERVAL_MS: 100,
        vibrator: {
            startVibration: () => calls.haptic++
        }, abilityAccessCtrl: {
            createAtManager: () => ({
                requestPermissionsFromUser: () => {
                    calls.permission++;
                    return permission();
                }
            })
        }, voiceRecorder: {
            start: async () => calls.start++
        }, AppLocale: {
            text: s => s
        }, promptAction: {
            showToast: () => {
            }
        }
    };
    vm.createContext(context);
    vm.runInContext(ts.transpileModule('export class Harness {\n' + methods + '\n}', {
        compilerOptions: {
            target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
        }
    }).outputText, context);
    const page = new context.exports.Harness();
    Object.assign(page, {
        context: {}, tab: 0, centerSelectedHomeTab: () => {
        }, ensureCommunityLoaded: () => {
        }, recording: false, recordingTransitioning: false, recordFabPressed: false, recordFabTimer: -1, recordLaunchGeneration: 0, pathStack: {
            size: () => 0
        }, defaultRecordTag: '', selectedTag: '', navigateHome: () => {
        }, updateRecordingMeter: () => {
        }, beginRecordingStop: () => calls.stop++
    });
    const touch = (type, x = 100, y = 100) => page.handleRecordFabTouch({
        type, touches: [{
                screenX: x, screenY: y
            }], stopPropagation: () => {
        }
    });
    const advance = ms => {
        now += ms;
        for (const [id, timer] of [...timers])
            if (timer.time <= now) {
                timers.delete(id);
                timer.fn();
            }
    };
    return {
        page, calls, touch, advance
    };
}
test('tap starts normal recording on release without ASR or haptic', async () => {
    const h = host();
    h.touch(0);
    h.advance(399);
    assert.equal(h.calls.permission, 0);
    h.touch(2);
    await settle();
    assert.equal(h.calls.start, 1);
    assert.equal(h.calls.haptic, 0);
    h.advance(1000);
    assert.equal(h.calls.start, 1);
});
test('400ms starts while finger remains down; release cannot stop or reopen recording', async () => {
    const h = host();
    h.touch(0);
    h.advance(399);
    assert.equal(h.calls.start, 0);
    h.advance(1);
    await settle();
    assert.equal(h.calls.start, 1);
    assert.equal(h.calls.haptic, 1);
    h.touch(2);
    h.touch(2);
    await settle();
    assert.equal(h.calls.start, 1);
    assert.equal(h.calls.stop, 0);
});
test('cancel and movement beyond 24 cancel both hold and release', async () => {
    for (const mode of ['cancel', 'move']) {
        const h = host();
        h.touch(0);
        mode === 'cancel' ? h.touch(3) : h.touch(1, 125);
        h.advance(400);
        h.touch(2);
        await settle();
        assert.equal(h.calls.start, 0);
    }
});
test('small movement permits hold', async () => {
    const h = host();
    h.touch(0);
    h.touch(1, 124);
    h.advance(400);
    await settle();
    assert.equal(h.calls.start, 1);
});
test('pending permission plus release and further presses never starts twice', async () => {
    const gate = deferred(), h = host(() => gate.promise);
    h.touch(0);
    h.advance(400);
    h.touch(2);
    h.touch(0);
    h.touch(2);
    gate.resolve({
        authResults: [0]
    });
    await settle();
    assert.equal(h.calls.permission, 1);
    assert.equal(h.calls.start, 1);
});
test('leaving while awaiting permission invalidates launch', async () => {
    const gate = deferred(), h = host(() => gate.promise);
    h.touch(0);
    h.touch(2);
    h.page.cancelRecordFabPress();
    h.page.recordLaunchGeneration++;
    gate.resolve({
        authResults: [0]
    });
    await settle();
    assert.equal(h.calls.start, 0);
});
test('cancel pending hold on page exit', async () => {
    const h = host();
    h.touch(0);
    h.page.cancelRecordFabPress();
    h.advance(400);
    h.touch(2);
    await settle();
    assert.equal(h.calls.start, 0);
});
test('denied permission does not start; next press can retry', async () => {
    let allowed = false;
    const h = host(async () => ({
        authResults: [allowed ? 0 : -1]
    }));
    h.touch(0);
    h.touch(2);
    await settle();
    assert.equal(h.calls.start, 0);
    allowed = true;
    h.touch(0);
    h.touch(2);
    await settle();
    assert.equal(h.calls.start, 1);
});
test('switching cached home tab cancels pending hold and permission launch', async () => {
    for (const pendingPermission of [false, true]) {
        const gate = deferred(), h = host(() => gate.promise);
        h.touch(0);
        if (pendingPermission)
            h.advance(400);
        h.page.selectHomeTab(1);
        h.advance(400);
        h.touch(2);
        gate.resolve({
            authResults: [0]
        });
        await settle();
        assert.equal(h.calls.start, 0);
    }
});
test('changing tag cancels pending hold', async () => {
    const h = host();
    h.touch(0);
    h.page.selectHomeTag('work');
    h.advance(400);
    h.touch(2);
    await settle();
    assert.equal(h.calls.start, 0);
});
