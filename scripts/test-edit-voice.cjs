const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const test=require('node:test'),assert=require('node:assert/strict');
const ts=require(process.env.HARMONY_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js');
// Execute the production gesture, permission and callback methods with controlled async ASR.
// Audio capture, network recognition and ArkUI rendering still require device validation.
const source=fs.readFileSync(path.resolve(__dirname,'../entry/src/main/ets/pages/Index.ets'),'utf8');
const names=['toggleDictation','touchY','handleEditHold','startEditHold','finishEditHold','completeEditHold','resetEditHold'];
const methods=names.map(name=>{const re=new RegExp('  private (?:async )?'+name+'\\(');const start=source.search(re);assert.ok(start>=0);const end=source.indexOf('\n  private ',start+4);return source.slice(start,end);}).join('\n');
const settle=async()=>{for(let i=0;i<12;i++)await Promise.resolve();};
function deferred(){let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};}
function host(permission=async()=>({authResults:[0]})){
 const sessions=[],sent=[],toasts=[];
 class AsrDictation{
  constructor(text,state){this.text=text;this.state=state;this.running=false;sessions.push(this);}
  async start(){this.running=true;this.state('正在听写…');}
  async stop(){this.running=false;if(this.stopGate)await this.stopGate.promise;this.state('');}
  async finish(){this.state('正在识别最后一句…');}
  isRunning(){return this.running;}
 }
 const ctx={exports:{},AsrDictation,TouchType:{Down:0,Move:1,Up:2,Cancel:3},abilityAccessCtrl:{createAtManager:()=>({requestPermissionsFromUser:permission})},AppLocale:{text:s=>s},promptAction:{showToast:({message})=>toasts.push(message)}};
 vm.createContext(ctx);
 const compiled=ts.transpileModule('export class Harness {\n'+methods+'\n}',{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS}}).outputText;
 vm.runInContext(compiled,ctx);
 const page=new ctx.exports.Harness();Object.assign(page,{context:{},editText:'',dictating:false,dictationTarget:'',holdEditPressed:false,holdEditCanceled:false,holdEditFinishing:false,holdEditCompleted:false,holdEditShouldSend:false,holdEditTranscriptText:'',holdEditPromptText:'',editHoldGeneration:0,editHoldStop:Promise.resolve(),sendEdit:async()=>sent.push(page.editText)});
 const touch=(type)=>page.handleEditHold({type,touches:[{screenY:300}],changedTouches:[]});
 return {page,sessions,sent,toasts,touch};
}
test('late cancellation completion cannot reset a new press',async()=>{
 const h=host();h.touch(0);await settle();const old=h.sessions[0];old.stopGate=deferred();
 h.touch(3);h.touch(0);await settle();assert.equal(h.sessions.length,1);old.stopGate.resolve();await settle();
 assert.equal(h.page.holdEditPressed,true);assert.equal(h.page.dictating,true);assert.equal(h.sessions.length,2);
});
test('old recognition and error callbacks cannot replace a new transcript',async()=>{
 const h=host();h.touch(0);await settle();const old=h.sessions[0];h.touch(3);await settle();h.touch(0);await settle();
 h.sessions[1].text('新指令',false);old.text('旧指令',true);old.state('听写连接失败');
 assert.equal(h.page.holdEditTranscriptText,'新指令');assert.equal(h.page.holdEditPressed,true);assert.equal(h.sent.length,0);
});
test('cancel while microphone permission is pending cannot start recording later',async()=>{
 const gate=deferred(),h=host(()=>gate.promise);h.touch(0);await settle();h.touch(3);await settle();gate.resolve({authResults:[0]});await settle();
 assert.equal(h.sessions.length,0);assert.equal(h.page.dictating,false);assert.equal(h.sent.length,0);
});
test('release submits the final text once; duplicate completion is ignored',async()=>{
 const h=host();h.touch(0);await settle();const s=h.sessions[0];s.text('改标题',false);h.touch(2);await settle();s.text('把标题改短',true);s.state('');await settle();
 assert.deepEqual(h.sent,['把标题改短']);
});
test('empty recognition then another utterance keeps voice submission working',async()=>{
 const h=host();h.touch(0);await settle();h.touch(2);h.sessions[0].state('');await settle();h.touch(0);await settle();h.touch(2);h.sessions[1].text('修改第二段',true);await settle();assert.deepEqual(h.sent,['修改第二段']);
});
test('release before permission returns still finishes and submits a normal utterance',async()=>{
 const gate=deferred(),h=host(()=>gate.promise);h.touch(0);await settle();h.touch(2);gate.resolve({authResults:[0]});await settle();
 assert.equal(h.sessions.length,1);h.sessions[0].text('把图片改成水彩',true);h.sessions[0].state('');await settle();assert.deepEqual(h.sent,['把图片改成水彩']);
});
