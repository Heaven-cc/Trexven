import 'package:supabase_flutter/supabase_flutter.dart';

bool saleOutcomeIsUnconfirmed(Object error) =>
    error is! ArgumentError &&
    error is! StateError &&
    !(error is PostgrestException &&
        (error.code == 'P0001' ||
            error.code == '42501' ||
            error.code?.startsWith('22') == true ||
            error.code?.startsWith('23') == true ||
            error.code == 'PGRST202'));

String saleErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'You do not have permission to record sales. Contact your business owner.';
    }
    if (error.code == 'P0001') return error.message;
    if (error.code == 'PGRST202') {
      return 'The sale service needs updating. Contact support.';
    }
    return 'The sale could not be saved. Contact support if this continues.';
  }
  if (error is StateError) return error.message.toString();
  if (error is ArgumentError) return error.message.toString();
  return 'Could not confirm the sale. Check your connection and retry this sale; it will not be recorded twice.';
}
