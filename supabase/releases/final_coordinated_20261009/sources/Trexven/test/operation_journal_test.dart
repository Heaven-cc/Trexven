import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:trexven_operations/src/encrypted_state_native.dart';

void main(){
  test('interrupted financial intent survives restart and reuses the exact original request',()async{
    final directory=await Directory.systemTemp.createTemp('trexven_operation_test_');
    try{
      final file=File('${directory.path}/intent.enc');final key=SecretKey(List<int>.filled(32,9));
      OperationJournal journal()=>OperationJournal(stateFactory:()async=>EncryptedStateFile(file,()async=>key,aad:'TEST_ONLY'));
      final first=journal();
      await first.reserve('user','business','repay_trexven_credit',{'p_request_id':'original','p_amount':10});
      expect(await file.readAsString(),isNot(contains('original')));
      final restarted=journal();
      final retry=await restarted.reserve('user','business','repay_trexven_credit',{'p_request_id':'newly-generated','p_amount':10});
      expect(retry['p_request_id'],'original');
      await expectLater(restarted.reserve('other','business','repay_trexven_credit',{'p_request_id':'x','p_amount':10}),throwsStateError);
      await expectLater(restarted.reserve('user','business','repay_trexven_credit',{'p_request_id':'x','p_amount':11}),throwsStateError);
      await expectLater(restarted.complete('user','business','wrong'),throwsStateError);
      expect(await restarted.pending(),isNotNull);
      await restarted.complete('user','business','original');expect(await restarted.pending(),isNull);
    }finally{await directory.delete(recursive:true);}
  });
}
