import 'package:flutter/material.dart';
import 'operations_client.dart';

class PaymentDraft {
  final List<Map<String, dynamic>> payments;
  final Map<String, dynamic>? credit;
  const PaymentDraft(this.payments, this.credit);
}

Future<PaymentDraft?> confirmPayment(
  BuildContext context,
  double total,
  String method, {
  bool offline = false,
  bool cashAllowed = true,
  bool recovery = false,
  bool allowCredit = true,
}) async {
  final canonical = switch (method.toLowerCase()) {
    'transfer' || 'bank_transfer' => 'bank_transfer',
    'pos terminal' || 'card' => 'card',
    _ => 'cash',
  };
  final amounts = {
    for (final m in ['cash', 'bank_transfer', 'card'])
      m: TextEditingController(
        text: m == canonical && (m != 'cash' || cashAllowed)
            ? total.toStringAsFixed(2)
            : '0',
      ),
  };
  final evidence = {
    for (final m in ['bank_transfer', 'card']) m: TextEditingController(),
  };
  final name = TextEditingController(),
      contact = TextEditingController(),
      due = TextEditingController();
  var credit = false, confirmed = false;
  String? error;
  final result = await showDialog<PaymentDraft>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        scrollable: true,
        title: Text(
          offline ? 'Cash received · Pending Sync' : 'Confirm payment outcome',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recovery
                    ? 'Verify the original payment of ${total.toStringAsFixed(2)}. Do not collect payment again. The original receipt and request key are retained.'
                    : 'Sale total ${total.toStringAsFixed(2)}. Record only money actually received.',
              ),
              for (final m in amounts.keys)
                if (!offline || m == 'cash') ...[
                  TextField(
                    controller: amounts[m],
                    enabled: m != 'cash' || cashAllowed,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: m == 'card'
                          ? 'Confirmed external POS terminal amount'
                          : '$m amount',
                    ),
                  ),
                  if (m != 'cash')
                    TextField(
                      controller: evidence[m],
                      decoration: const InputDecoration(
                        labelText: 'Verified bank/terminal reference',
                      ),
                    ),
                ],
              if (!offline && allowCredit)
                CheckboxListTile(
                  value: credit,
                  onChanged: (v) => update(() => credit = v ?? false),
                  title: const Text('Request approval for unpaid balance'),
                ),
              if (credit) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Debtor name'),
                ),
                TextField(
                  controller: contact,
                  decoration: const InputDecoration(
                    labelText: 'Contact reference',
                  ),
                ),
                TextField(
                  controller: due,
                  decoration: const InputDecoration(
                    labelText: 'Due date YYYY-MM-DD',
                  ),
                ),
                const Text(
                  'The original request is retained while the owner or an authorized manager approves this exact sale.',
                ),
              ],
              CheckboxListTile(
                value: confirmed,
                onChanged: (v) => update(() => confirmed = v ?? false),
                title: const Text(
                  'I verified cash received, the bank-account transfer or successful external-terminal confirmation. A screenshot alone is insufficient.',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: !confirmed
                ? null
                : () {
                    try {
                      final payments = <Map<String, dynamic>>[];
                      var paid = 0;
                      for (final m in amounts.keys) {
                        final cents = offline && m != 'cash'
                            ? 0
                            : OperationsClient.moneyCents(
                                amounts[m]!.text,
                                allowZero: true,
                              );
                        paid += cents;
                        if (m == 'cash' && cents > 0 && !cashAllowed)
                          throw const FormatException(
                            'Join an assigned drawer before receiving cash.',
                          );
                        if (cents > 0 || (total == 0 && m == 'cash')) {
                          if (m != 'cash' && evidence[m]!.text.trim().isEmpty)
                            throw const FormatException(
                              'External confirmation reference required.',
                            );
                          payments.add({
                            'method': m,
                            'amount': cents / 100,
                            'confirmed': true,
                            if (m != 'cash')
                              'evidence': evidence[m]!.text.trim(),
                          });
                        }
                      }
                      final full = (total * 100).round();
                      if (paid > full ||
                          (!credit && paid != full) ||
                          offline && paid != full)
                        throw const FormatException(
                          'Confirmed payments must match the total unless approved credit is requested.',
                        );
                      Map<String, dynamic>? debtor;
                      if (credit) {
                        if (paid >= full ||
                            name.text.trim().isEmpty ||
                            contact.text.trim().isEmpty ||
                            !RegExp(
                              r'^\d{4}-\d{2}-\d{2}$',
                            ).hasMatch(due.text) ||
                            DateTime.tryParse(
                                  due.text,
                                )?.toIso8601String().substring(0, 10) !=
                                due.text)
                          throw const FormatException(
                            'Unpaid balance, debtor, contact and valid due date required.',
                          );
                        debtor = {
                          'debtor_name': name.text.trim(),
                          'contact': contact.text.trim(),
                          'due_date': due.text,
                        };
                      }
                      Navigator.pop(context, PaymentDraft(payments, debtor));
                    } catch (e) {
                      update(() => error = e.toString());
                    }
                  },
            child: Text(
              credit
                  ? 'Keep request for approval'
                  : offline
                  ? 'Record cash · Pending Sync'
                  : 'Confirm',
            ),
          ),
        ],
      ),
    ),
  );
  for (final c in [...amounts.values, ...evidence.values, name, contact, due]) {
    c.dispose();
  }
  return result;
}
