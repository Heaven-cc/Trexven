// Pure final-QA mocks; no credentials/network/customer records.
import { processVerifiedWebhook, type BillingProvider, type VerifiedPayment } from '../functions/_shared/billing-provider.ts';

function assert(value: boolean, label: string) { if (!value) throw new Error(label); }
async function rejects(action: () => Promise<unknown>, code: string) {
  try { await action(); } catch (error) { assert((error as Error).message === code, 'wrong rejection'); return; }
  throw new Error('Expected rejection');
}
const payment: VerifiedPayment = { paymentRef:'payment',sessionId:'session',amount:'1.00',currency:'NGN',status:'verified' };
function adapter(lookup = payment): BillingProvider {
  return { name:'synthetic',createCheckout:async()=>({reference:'session',url:'https://example.invalid'}),
    verifyWebhook:async(raw,headers)=>{
      if(headers.get('x-test-signature') !== 'valid' || raw.length !== 1) throw new Error('SIGNATURE_INVALID');
      return {eventId:'event',sessionId:'session',paymentRef:'payment'};
    },lookupPayment:async()=>lookup,cancelRenewal:async()=>{} };
}
Deno.test('billing provider is disabled by default',async()=>{
  await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers(),{rpc:async()=>{throw new Error('must not call');}}),'BILLING_PROVIDER_DISABLED');
});
Deno.test('unsigned notification never records payment',async()=>{
  await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers(),{rpc:async()=>{throw new Error('must not call');}},new Map([['synthetic',adapter()]])),'SIGNATURE_INVALID');
});
Deno.test('independent lookup identity mismatch never records payment',async()=>{
  await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers({'x-test-signature':'valid'}),{rpc:async()=>{throw new Error('must not call');}},new Map([['synthetic',adapter({...payment,sessionId:'other'})]])),'BILLING_PAYMENT_MISMATCH');
});
Deno.test('signed event requires independent verification and trusted RPC acknowledgement',async()=>{
  let calls=0;
  const result=await processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers({'x-test-signature':'valid'}),{
    rpc:async(name,args)=>{calls++;assert(name==='record_verified_trexven_billing_event','trusted contract');assert(args.p_payment_ref==='payment' && args.p_amount==='1.00','verified values');return {data:{id:'stored'},error:null};}
  },new Map([['synthetic',adapter()]]));
  assert(calls===1 && (result as {id:string}).id==='stored','server acknowledgement');
});
Deno.test('registry identity mismatch never verifies or records an event',async()=>{
  await rejects(()=>processVerifiedWebhook('different',new Uint8Array([1]),new Headers(),{rpc:async()=>{throw new Error('must not call');}},new Map([['different',adapter()]])),'BILLING_PROVIDER_DISABLED');
});
Deno.test('malformed verified amount and currency fail before persistence',async()=>{
  for(const invalid of [{amount:'-1.00'},{amount:'1.001'},{amount:'NaN'},{currency:'ngn'},{currency:'NGNN'}]) {
    await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers({'x-test-signature':'valid'}),{rpc:async()=>{throw new Error('must not call');}},new Map([['synthetic',adapter({...payment,...invalid})]])),'BILLING_PAYMENT_MISMATCH');
  }
});
Deno.test('lookup payment reference mismatch fails before persistence',async()=>{
  await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers({'x-test-signature':'valid'}),{rpc:async()=>{throw new Error('must not call');}},new Map([['synthetic',adapter({...payment,paymentRef:'foreign'})]])),'BILLING_PAYMENT_MISMATCH');
});
Deno.test('independently failed payment remains failed',async()=>{
  await processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers({'x-test-signature':'valid'}),{rpc:async(_name,args)=>{assert(args.p_status==='failed','failed payment must not activate a subscription');return {data:{status:'failed'},error:null};}},new Map([['synthetic',adapter({...payment,status:'failed'})]]));
});
Deno.test('database failure never acknowledges billing confirmation',async()=>{
  await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers({'x-test-signature':'valid'}),{rpc:async()=>({data:null,error:{code:'network'}})},new Map([['synthetic',adapter()]])),'BILLING_RECORD_UNCONFIRMED');
});
Deno.test('empty signed event identifiers fail before independent lookup',async()=>{
  const invalid={...adapter(),verifyWebhook:async()=>({eventId:'',sessionId:'session',paymentRef:'payment'}),lookupPayment:async()=>{throw new Error('must not look up');}};
  await rejects(()=>processVerifiedWebhook('synthetic',new Uint8Array([1]),new Headers(),{rpc:async()=>{throw new Error('must not call');}},new Map([['synthetic',invalid]])),'BILLING_EVENT_INVALID');
});
