const fs = require('node:fs');
const assert = require('node:assert/strict');
const project = 'demo-cots-follow-up';
const root = `http://127.0.0.1:8088/v1/projects/${project}/databases/(default)/documents`;
const run = Date.now().toString();
const a=`a-${run}`, b=`b-${run}`, c=`c-${run}`, e=`expert-${run}`, admin=`admin-${run}`, area=`reef-${run}`;
const ph = new Date(Date.now()+8*3600000), year=ph.getUTCFullYear(), month=ph.getUTCMonth()+1;
const id=`${area}_${year}_${month}`;
let checks=0;
const encode = v => v===null?{nullValue:null}:v instanceof Date?{timestampValue:v.toISOString()}:Array.isArray(v)?{arrayValue:{values:v.map(encode)}}:typeof v==='object'?{mapValue:{fields:fields(v)}}:typeof v==='boolean'?{booleanValue:v}:Number.isInteger(v)?{integerValue:String(v)}:typeof v==='number'?{doubleValue:v}:{stringValue:v};
const fields = d => Object.fromEntries(Object.entries(d).map(([k,v])=>[k,encode(v)]));
const decode = f => Object.fromEntries(Object.entries(f).map(([k,v])=>[k,'stringValue'in v?v.stringValue:'integerValue'in v?Number(v.integerValue):'booleanValue'in v?v.booleanValue:'timestampValue'in v?new Date(v.timestampValue):'arrayValue'in v?(v.arrayValue.values||[]).map(x=>x.stringValue):v.mapValue?decode(v.mapValue.fields):null]));
function token(uid){const now=Math.floor(Date.now()/1000);return `${Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:now,exp:now+3600,firebase:{sign_in_provider:'custom'}})).toString('base64url')}.`;}
async function req(path,uid='owner',method='GET',body){return fetch(`${root}${path}`,{method,headers:{Authorization:`Bearer ${uid==='owner'?uid:token(uid)}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});}
async function ok(label,response,status=200){const body=await response.text();assert.ok((Array.isArray(status)?status:[status]).includes(response.status),`${label}: expected ${status}, got ${response.status}: ${body}`);checks++;return body?JSON.parse(body):null;}
async function seed(path,d){await ok('seed',await req('/'+path,'owner','PATCH',{fields:fields(d)}));}
async function get(uid=a){const doc=await ok('read current request',await req('/follow_up_reassignments/'+id,uid));return {doc,data:decode(doc.fields)};}
function write(path,data,transforms=[],pre){return {update:{name:`projects/${project}/databases/(default)/documents/${path}`,fields:fields(data)},...(pre?{currentDocument:pre}:{}),...(transforms.length?{updateTransforms:transforms.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})};}
async function change(uid,old,patch,action,{status=200,pre,extra=[]}={}){
 const next={...old?.data,...patch};
 const rev=next.revision=(old?.data.revision||0)+1;
 const eventId=`${id}_${rev}`;
 const recipients=new Set(['experts',a,next.replacement_uid,old?.data.replacement_uid].filter(Boolean));
 const writes=[write(`follow_up_month_authorizations/${id}`,{area_id:area,year:next.year,month:next.month,primary_uid:a,responsible_uid:next.responsible_uid}),
 write(`follow_up_reassignments/${id}`,next,['updated_at',...(!old?['requested_at']:[])],pre|| (old?{updateTime:old.doc.updateTime}:{exists:false})),
 write(`follow_up_reassignment_events/${eventId}`,{request_id:id,revision:rev,actor_uid:uid,action,at:new Date(),state:next},['at','state.updated_at',...(!old?['state.requested_at']:[])],{exists:false}),
 ...[...recipients].map(recipient=>write(`notifications/${eventId}_${recipient}`,{recipient_uid:recipient,type:'follow_up_reassignment',title:action,body:'Assignment update',related_record_id:id,zone:'Reef A',is_read:false,event_revision:rev,created_at:new Date()},['created_at'],{exists:false})),...extra];
 return ok(action,await req(':commit',uid,'POST',{writes}),status);
}
async function main(){
 const rules=fs.readFileSync('firebase/firestore.rules','utf8');
 const loaded=await fetch(`http://127.0.0.1:8088/emulator/v1/projects/${project}:securityRules`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'firestore.rules',content:rules}]}})});
 await ok('load local rules',loaded);
 for(const [uid,role,verified] of [[a,'user',true],[b,'user',true],[c,'user',false],[e,'expert',false],[admin,'admin',false]])await seed(`users/${uid}`,{uid,accountRole:role,isActive:true,fieldPersonnelVerified:verified,fullName:uid,email:'private@example.test'});
 await seed(`follow_up_assignments/${area}`,{area_id:area,area_name:'Reef A',barangay:'Barangay A',municipality:'Town',primary_diver_uid:a,primary_diver_name:'Diver A',initial_capture_id:'initial',initial_date:new Date(Date.UTC(year,month-2,15)),initial_detected_count:40});
 await ok('Expert cannot read private profile',await req('/users/'+b,e),403);
 await ok('Expert cannot query private profiles',await req(':runQuery',e,'POST',{structuredQuery:{from:[{collectionId:'users'}]}}),403);
 await ok('admin publishes minimal directory',await req('/follow_up_personnel/'+b,admin,'PATCH',{fields:fields({name:b,eligible:true})}));
 await ok('expert reads minimal directory',await req('/follow_up_personnel/'+b,e));
 await ok('admin can store an ineligible directory marker',await req('/follow_up_personnel/'+c,admin,'PATCH',{fields:fields({name:c,eligible:false})}));
 await ok('expert cannot read names of ineligible accounts',await req('/follow_up_personnel/'+c,e),403);
 await ok('expert cannot query the directory without an eligibility filter',await req(':runQuery',e,'POST',{structuredQuery:{from:[{collectionId:'follow_up_personnel'}]}}),403);
 await ok('expert queries eligible directory entries',await req(':runQuery',e,'POST',{structuredQuery:{from:[{collectionId:'follow_up_personnel'}],where:{fieldFilter:{field:{fieldPath:'eligible'},op:'EQUAL',value:encode(true)}}}}));
 await ok('expert cannot publish directory',await req('/follow_up_personnel/'+c,e,'PATCH',{fields:fields({name:c,eligible:true})}),403);
 const initial={area_id:area,area_name:'Reef A',barangay:'Barangay A',municipality:'Town',primary_uid:a,primary_name:'Diver A',year,month,responsible_uid:a,requester_uid:a,reason:'Unavailable due to fieldwork',status:'requested',replacement_uid:'',replacement_name:'',expert_uid:'',participants:[a],requested_at:new Date(),updated_at:new Date()};
 await change(c,null,{...initial,requester_uid:c,responsible_uid:c},'requested',{status:403});
 await change(a,null,initial,'requested');
 await ok('expert receives request notification',await req(`/notifications/${id}_1_experts`,e));
 await ok('nonparticipant cannot read reason',await req('/follow_up_reassignments/'+id,c),403);
 await change(a,null,initial,'requested',{status:[403,409]});
 let current=await get();
 await change(a,current,{status:'awaiting_acceptance',expert_uid:a,replacement_uid:b,replacement_name:b,participants:[a,b]},'proposed',{status:403});
 await change(e,current,{status:'awaiting_acceptance',expert_uid:e,replacement_uid:c,replacement_name:c,participants:[a,c]},'proposed',{status:403});
 await change(e,current,{status:'awaiting_acceptance',expert_uid:e,replacement_uid:b,replacement_name:b,participants:[a,b]},'proposed');
 await ok('B receives proposal notification',await req(`/notifications/${id}_2_${b}`,b));
 const proposed=await get();
 await ok('proposal not active',await req('/follow_up_month_authorizations/'+id,b)).then(doc=>assert.equal(decode(doc.fields).responsible_uid,a));
 await change(c,proposed,{status:'accepted',responsible_uid:c},'accepted',{status:403});
 await change(b,proposed,{status:'replacement_needed'},'declined');
 current=await get();assert.equal(current.data.status,'replacement_needed');checks++;
 await change(e,current,{status:'awaiting_acceptance',expert_uid:e,replacement_uid:b,replacement_name:b,participants:[a,b]},'proposed');
 current=await get();
 await change(e,current,{status:'replacement_needed'},'proposal_cancelled');
 await change(b,current,{status:'accepted',responsible_uid:b},'accepted',{status:[400,403,409]});
 current=await get();
 await change(e,current,{status:'awaiting_acceptance',expert_uid:e,replacement_uid:b,replacement_name:b,participants:[a,b]},'proposed');
 current=await get();
 await seed('users/'+b,{uid:b,accountRole:'user',isActive:true,fieldPersonnelVerified:false,fullName:b});
 await change(b,current,{status:'accepted',responsible_uid:b},'accepted',{status:403});
 await seed('users/'+b,{uid:b,accountRole:'user',isActive:true,fieldPersonnelVerified:true,fullName:b});
 await change(b,current,{status:'accepted',responsible_uid:b},'accepted');
 const accepted=await get();
 assert.equal(accepted.data.primary_uid,a);checks++;
 await ok('B is the active monthly diver',await req('/follow_up_month_authorizations/'+id,b)).then(doc=>assert.equal(decode(doc.fields).responsible_uid,b));
 await ok('B sees accepted assignment query',await req(':runQuery',b,'POST',{structuredQuery:{from:[{collectionId:'follow_up_reassignments'}],where:{fieldFilter:{field:{fieldPath:'participants'},op:'ARRAY_CONTAINS',value:encode(b)}}}}));
 await ok('A sees B acceptance notification',await req(`/notifications/${id}_7_${a}`,a));
 await ok('Expert sees B acceptance notification',await req(`/notifications/${id}_7_experts`,e));
 const visit=`visit-${run}`, captureId=`capture-${run}`, date=new Date(Date.UTC(year,month-1,Math.max(1,ph.getUTCDate()-1),4));
 const capture={uid:b,submitted_by:b,capture_source:'GoPro Underwater Image',citizen_contribution:true,has_processed_image:true,ai_detected_count:0,confidence:0,processed_at:new Date(),submitted_at:new Date(),monitoring_area_id:area,follow_up_survey_id:visit,follow_up_year:year,follow_up_month:month,gps:{latitude:null,longitude:null}};
 await ok('A cannot upload October follow-up evidence after acceptance',await req('/captures?documentId=bad-'+run,a,'POST',{fields:fields({...capture,uid:a})}),403);
 await ok('B uploads assigned evidence',await req('/captures?documentId='+captureId,b,'POST',{fields:fields(capture)}));
 const survey={area_id:area,area_name:'Reef A',barangay:'Barangay A',municipality:'Town',uid:b,submitted_by:b,survey_date:date,survey_calendar_date:date.toISOString().slice(0,10),field_observed_count:0,field_eliminated_count:0,capture_ids:[captureId],gps:{latitude:null,longitude:null},elimination_method:'',notes:'No COTS observed',ai_detected_count:0,submitted_at:new Date()};
 await ok('missing evidence cannot complete a visit',await req('/follow_up_surveys?documentId=missing-'+run,b,'POST',{fields:fields({...survey,capture_ids:['missing']})}),403);
 await ok('accepted B submits own valid survey',await req('/follow_up_surveys?documentId='+visit,b,'POST',{fields:fields(survey)}));
 await ok('forged calendar month cannot mark a different month monitored',await req('/follow_up_surveys?documentId=forged-month-'+run,b,'POST',{fields:fields({...survey,survey_calendar_date:'2026-11-01'})}),403);
 await ok('diver cannot forge validated infestation metadata',await req(':commit',b,'POST',{writes:[write('follow_up_surveys/'+visit,{...survey,validated_infestation_level:'High',infestation_validated_by:b,infestation_validated_at:new Date()},['infestation_validated_at'])]}),403);
 const assessment={area_id:area,survey_id:visit,survey_date:date,validated_infestation_level:'High',infestation_validated_by:e,infestation_validated_at:new Date()};
 await ok('Expert creates a separate validated assessment',await req(':commit',e,'POST',{writes:[write('follow_up_assessments/'+visit,assessment,['infestation_validated_at'],{exists:false})]}));
 await ok('diver cannot create a validated assessment',await req(':commit',b,'POST',{writes:[write('follow_up_assessments/bad-'+visit,{...assessment,infestation_validated_by:b},['infestation_validated_at'],{exists:false})]}),403);
 await ok('validated assessment cannot be overwritten',await req(':commit',e,'POST',{writes:[write('follow_up_assessments/'+visit,{...assessment,validated_infestation_level:'Low'},['infestation_validated_at'])]}),403);
 await ok('survey observations remain unchanged',await req('/follow_up_surveys/'+visit,b)).then(doc=>assert.equal(decode(doc.fields).field_observed_count,0));
 const eightVisit=visit+'-eight',eight=Array.from({length:8},(_,i)=>captureId+'-eight-'+i);
 for(const image of eight) await seed('captures/'+image,{...capture,follow_up_survey_id:eightVisit});
 await ok('replacement eight-image survey stays within Firestore limits',await req('/follow_up_surveys?documentId='+eightVisit,b,'POST',{fields:fields({...survey,capture_ids:eight})}));
 await ok('A reads B monitoring history',await req(':runQuery',a,'POST',{structuredQuery:{from:[{collectionId:'follow_up_surveys'}],where:{fieldFilter:{field:{fieldPath:'area_id'},op:'EQUAL',value:encode(area)}}}}));
 await ok('B reads area monitoring history',await req(':runQuery',b,'POST',{structuredQuery:{from:[{collectionId:'follow_up_surveys'}],where:{fieldFilter:{field:{fieldPath:'area_id'},op:'EQUAL',value:encode(area)}}}}));
 await ok('B cannot change primary assignment',await req('/follow_up_assignments/'+area,b,'PATCH',{fields:fields({primary_diver_uid:b})}),403);
 await ok('B reads complete audit history including the original request',await req(':runQuery',b,'POST',{structuredQuery:{from:[{collectionId:'follow_up_reassignment_events'}],where:{fieldFilter:{field:{fieldPath:'request_id'},op:'EQUAL',value:encode(id)}}}}));
 await ok('unrelated diver cannot query audit history',await req(':runQuery',c,'POST',{structuredQuery:{from:[{collectionId:'follow_up_reassignment_events'}],where:{fieldFilter:{field:{fieldPath:'request_id'},op:'EQUAL',value:encode(id)}}}}),403);
 await ok('audit history immutable',await req(`/follow_up_reassignment_events/${id}_7`,b,'PATCH',{fields:fields({action:'forged'})}),403);
 await ok('survey immutable',await req('/follow_up_surveys/'+visit,b,'PATCH',{fields:fields({...survey,uid:a})}),403);
 await ok('actor cannot forge later notification',await req(`/notifications/${id}_7_forged`,b,'PATCH',{fields:fields({recipient_uid:c,type:'follow_up_reassignment',title:'forged',body:'forged',related_record_id:id,event_revision:7,is_read:false,created_at:new Date()})}),403);
 await change(a,accepted,{status:'requested',requester_uid:a,reason:'Forged request',replacement_uid:'',replacement_name:'',expert_uid:''},'requested',{status:403});
 await change(b,accepted,{status:'requested',requester_uid:b,reason:'Replacement is now unavailable',replacement_uid:'',replacement_name:'',expert_uid:''},'requested');
 const secondRequest=await get(b);
 assert.equal(secondRequest.data.responsible_uid,b); checks++;
 await seed('follow_up_personnel/'+a,{name:a,eligible:true});
 const proposalPatch={status:'awaiting_acceptance',expert_uid:e,replacement_uid:a,replacement_name:a,participants:[a,b]};
 const race=await Promise.allSettled([change(e,secondRequest,proposalPatch,'proposed'),change(e,secondRequest,proposalPatch,'proposed')]);
 assert.equal(race.filter(r=>r.status==='fulfilled').length,1,'only one concurrent proposal wins'); checks++;
 const nextMonth=month===12?1:month+1,nextYear=month===12?year+1:year,nextId=`${area}_${nextYear}_${nextMonth}`;
 await ok('A initializes next month as primary',await req(':commit',a,'POST',{writes:[write('follow_up_month_authorizations/'+nextId,{area_id:area,year:nextYear,month:nextMonth,primary_uid:a,responsible_uid:a},[],{exists:false})]}));
 await ok('B cannot upload follow-up evidence next month',await req('/captures?documentId=next-'+run,b,'POST',{fields:fields({...capture,follow_up_year:nextYear,follow_up_month:nextMonth})}),403);
 await ok('A uploads next month follow-up evidence',await req('/captures?documentId=next-a-'+run,a,'POST',{fields:fields({...capture,uid:a,follow_up_year:nextYear,follow_up_month:nextMonth})}));
 await ok('unrelated diver cannot read survey',await req('/follow_up_surveys/'+visit,c),403);
 await ok('expert cannot change eligibility',await req('/users/'+b,e,'PATCH',{fields:fields({fieldPersonnelVerified:false})}),403);
 console.log(`Passed ${checks} Step 2 emulator assertions (${year}-${month}).`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
