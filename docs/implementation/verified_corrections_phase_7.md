# Verified corrections — Phase 7: intentional APIs and hook metadata

Status: SQL prepared in supabase/changes/phase_7_account_hook_metadata_hardening.sql; NOT deployed.
No Auth configuration, raw data grant, employee record, role setting or business row was changed.

## Verified production dependency

The authenticator role in database postgres configures pgrst.db_pre_request=public.trexven_guard_account_access.
That guard is SECURITY INVOKER and calls public.trexven_previous_api_hook() as the request role. The getter is SECURITY DEFINER, reads private.account_deletion_api_hook and currently has postgres/anon/authenticated/service_role EXECUTE. Its one stored row has previous_hook=null.

Simply revoking anonymous EXECUTE would break anonymous REST requests before their target query. Making the entire guard SECURITY DEFINER could run a chained legacy hook as postgres, changing its authority. Neither shortcut is prepared here.

The SQL-source scan found trexven_guard_account_access as the sole current stored-function caller of the metadata getter. The configured REST hook is authoritative across Owner, POS and Edge clients. No client API rename is required.

## Prepared correction and privilege boundary

- Add public.trexven_prepare_account_request(): no arguments, void return, empty search_path, SECURITY DEFINER. Move the exact existing account admission logic into it: auth.uid-based shared transaction advisory lock and the existing closed/deleting-account rejection.
- It obtains the previous hook through the existing getter as postgres and overwrites trexven.previous_api_hook using set_config(...,true). This is a transaction-local handoff, not a response payload, persistent role setting or session-wide configuration. Clients receive no hook name.
- Keep public.trexven_guard_account_access SECURITY INVOKER. It calls admission, reads the transaction-local handoff and dispatches any previous hook through the original regprocedure/regproc/format logic AFTER the definer helper has returned. The chained hook therefore keeps the request role's privileges, including anonymous requests. The null current setting and a future legitimately configured hook are both preserved.
- Revoke metadata getter EXECUTE from PUBLIC/anon/authenticated, keeping postgres/service_role administration. Do not drop or rewrite its definition.
- Do not revoke, rewrite or alter grants on trexven_account_access_allowed. Its boolean anonymous behavior is intentionally used by account admission and existing policy helpers. No identity, account-state row or hook name is returned.
- Keep the current guard's ACL and authenticator setting unchanged; grant no private schema usage or private-table access.
- Guard exact hashes and ACLs of all three existing functions and the live authenticator hook setting. Abort if the new helper already exists. No business or Auth row writes occur.

Source review verifies that dynamic legacy-hook execution is outside the definer helper. No execution test, fake JWT/role impersonation, test account, login, fabricated transaction or production request probe was performed. This is preparation, not runtime acceptance.

## Intentionally exposed definer APIs

Supabase warns on definer functions that allow API-role execution; a warning alone does not establish an exploit or justify a blanket revocation.
Reviewed boundaries in the current correction phases:
- trexven_account_access_allowed: bounded boolean required by pre-request admission/policies; anonymous execution retained intentionally.
- New prepared trexven_prepare_account_request: bounded void admission + trusted transaction-local metadata handoff; intentionally executable by API roles. It grants no business capability. This will remain an intentional anonymous/authenticated-definer advisor finding; do not claim the total warning count will fall.
- user_owns_business: owner predicate includes account deletion and administrative business controls.
- Current checkout and operation-receipt recovery: preserve request identity, caller/business/branch authorization and existing grants; obsolete no-ID paths were separately restricted in Phase 4.
- Employee administration: owner-only backend predicates and restrictive RLS deployed in Phase 1.
- Country billing catalog/session: explicit owner gate plus immutable request/session snapshot. Snapshot reads, provider recording and subscription activation remain service-only.

Below is an access inventory, not a claim that all routines received a new full security audit in Phase 7. Existing financial/inventory/offline/notification APIs need their intended permission checks and must not be blanket-revoked. Private schema grants are unchanged. Further findings require individual evidence and a separate reviewed change.

| Routine | Anonymous | Authenticated |
|---|---|---|
| private.admin_business_access_allowed(p_business uuid) | no | yes |
| private.admin_record_business(p_table text, p_row jsonb) | no | yes |
| private.branch_record_access(business uuid, branch uuid) | no | yes |
| private.can_read_cash_register(reg uuid) | no | yes |
| private.can_read_membership(business uuid, member_user uuid) | no | yes |
| private.can_read_staff(business uuid, employee uuid) | no | yes |
| private.has_branch_access(business uuid, branch uuid) | no | yes |
| private.has_business_permission(business uuid, permission text) | no | yes |
| private.sales_history_access(business uuid, sold_at timestamp with time zone) | no | yes |
| private.submit_trexven_sale(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) | no | yes |
| private.subscription_read_feature(business uuid, feature text) | no | yes |
| public.acknowledge_trexven_supplier_return(p_return_id uuid, p_request_id uuid, p_accepted numeric, p_returned numeric, p_reason text) | no | yes |
| public.adjust_trexven_catalog_stock(p_business_id uuid, p_product_id uuid, p_delta numeric, p_reason text, p_request_id uuid) | no | yes |
| public.approve_pos_return(p_return_id uuid, p_request_id uuid, p_method text, p_confirmed boolean, p_evidence text, p_shift_id uuid, p_restock boolean, p_restock_reason text) | no | yes |
| public.approve_trexven_return(p_return_id uuid, p_request_id uuid, p_method text, p_confirmed boolean, p_evidence text, p_shift_id uuid) | no | yes |
| public.approve_trexven_stocktake(p_session_id uuid, p_request_id uuid, p_reason text) | no | yes |
| public.assert_trexven_staff_access(p_business_id uuid, p_employee_id uuid) | no | yes |
| public.cancel_trexven_uncommitted_operation(p_business_id uuid, p_request_id uuid, p_no_money_moved boolean) | no | yes |
| public.classify_trexven_branch_stock(p_business_id uuid, p_branch_id uuid, p_product_id uuid, p_request_id uuid, p_quantity numeric, p_condition text, p_reason text) | no | yes |
| public.classify_trexven_stock(p_business_id uuid, p_product_id uuid, p_request_id uuid, p_quantity numeric, p_condition text, p_reason text) | no | yes |
| public.close_trexven_cash_shift(p_shift_id uuid, p_request_id uuid, p_counted numeric, p_reason text, p_no_pending_cash boolean) | no | yes |
| public.complete_trexven_onboarding(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text, p_phone text) | no | yes |
| public.complete_trexven_transaction(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_items jsonb, p_payments jsonb, p_credit jsonb, p_branch_id uuid, p_shift_id uuid) | no | yes |
| public.configure_trexven_register(p_business_id uuid, p_request_id uuid, p_name text, p_members uuid[]) | no | yes |
| public.confirm_trexven_cash_handover(p_handover_id uuid, p_request_id uuid, p_accept boolean, p_counted numeric) | no | yes |
| public.count_trexven_stock(p_session_id uuid, p_request_id uuid, p_counts jsonb) | no | yes |
| public.create_trexven_branch(p_business_id uuid, p_name text) | no | yes |
| public.decide_trexven_credit_approval(p_approval_id uuid, p_approve boolean, p_over_limit_reason text) | no | yes |
| public.dispatch_trexven_branch_supplier_return(p_business_id uuid, p_branch_id uuid, p_request_id uuid, p_product_id uuid, p_quantity numeric, p_condition text, p_supplier_name text, p_reason text) | no | yes |
| public.dispatch_trexven_stock_transfer(p_business_id uuid, p_request_id uuid, p_source uuid, p_destination uuid, p_product_id uuid, p_quantity numeric, p_reason text) | no | yes |
| public.dispatch_trexven_supplier_return(p_business_id uuid, p_request_id uuid, p_product_id uuid, p_quantity numeric, p_condition text, p_supplier_name text, p_reason text) | no | yes |
| public.finalize_trexven_employee(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text) | no | yes |
| public.force_close_trexven_cash_shift(p_shift_id uuid, p_request_id uuid, p_counted numeric, p_reason text, p_review_pending_cash boolean) | no | yes |
| public.get_pos_expenses(p_business_id uuid, p_branch_id uuid, p_limit integer, p_before_created_at timestamp with time zone, p_before_id uuid, p_branch_history boolean) | no | yes |
| public.get_pos_notifications(p_business_id uuid, p_branch_id uuid, p_offset integer) | no | yes |
| public.get_pos_operation_history(p_business_id uuid, p_branch_id uuid, p_offset integer) | no | yes |
| public.get_trexven_business_day(p_business_id uuid) | no | yes |
| public.get_trexven_cash_context(p_business_id uuid) | no | yes |
| public.get_trexven_country_billing_catalog(p_business_id uuid) | no | yes |
| public.get_trexven_entitlements(p_business_id uuid) | no | yes |
| public.get_trexven_financial_summary(p_business_id uuid, p_start timestamp with time zone, p_end timestamp with time zone) | no | yes |
| public.get_trexven_inventory_capabilities(p_business_id uuid) | no | yes |
| public.get_trexven_notifications(p_business_id uuid, p_application text, p_offset integer) | no | yes |
| public.get_trexven_operation_receipt(p_business_id uuid, p_request_id uuid) | no | yes |
| public.get_trexven_operational_health(p_business_id uuid) | no | yes |
| public.get_trexven_pos_context(p_business_id uuid) | no | yes |
| public.get_trexven_return_inspection_items(p_return_id uuid) | no | yes |
| public.import_trexven_catalog(p_business_id uuid, p_request_id uuid, p_rows jsonb) | no | yes |
| public.inspect_trexven_return(p_return_id uuid, p_request_id uuid, p_conditions jsonb) | no | yes |
| public.is_business_member(target_business_id uuid) | no | yes |
| public.issue_pos_branch_offline_scope(p_business_id uuid, p_device_id uuid, p_branch_id uuid, p_shift_id uuid) | no | yes |
| public.issue_trexven_offline_scope(p_business_id uuid, p_device_id uuid, p_shift_id uuid) | no | yes |
| public.join_trexven_cash_shift(p_shift_id uuid, p_request_id uuid) | no | yes |
| public.manage_trexven_stocktake(p_session_id uuid, p_request_id uuid, p_action text, p_product_id uuid, p_counter_id uuid, p_reason text) | no | yes |
| public.mark_pos_notification_read(p_business_id uuid, p_alert_key text, p_read boolean, p_branch_id uuid) | no | yes |
| public.mark_trexven_notification_read(p_business_id uuid, p_alert_key text, p_read boolean, p_application text) | no | yes |
| public.move_trexven_cash(p_shift_id uuid, p_request_id uuid, p_amount numeric, p_kind text, p_reason text) | no | yes |
| public.open_trexven_cash_shift(p_register_id uuid, p_request_id uuid, p_opening numeric) | no | yes |
| public.prepare_trexven_angel_catalog_action(p_business_id uuid, p_conversation_id uuid, p_product_query text, p_operation text, p_value numeric, p_reason text, p_source_message text) | no | yes |
| public.receive_trexven_stock_transfer(p_transfer_id uuid, p_request_id uuid, p_quantity numeric, p_close_discrepancy boolean, p_reason text) | no | yes |
| public.record_confirmed_trexven_owner_sale(p_business_id uuid, p_request_id uuid, p_product_id uuid, p_units numeric, p_unit_price numeric, p_payments jsonb, p_shift_id uuid) | no | yes |
| public.record_pos_expense(p_business_id uuid, p_request_id uuid, p_amount numeric, p_category text, p_description text, p_branch_id uuid, p_shift_id uuid) | no | yes |
| public.record_trexven_application_error(p_business_id uuid, p_application text, p_error_code text) | no | yes |
| public.recover_trexven_legacy_checkout(p_business_id uuid, p_request_id uuid, p_employee_id uuid, p_total numeric, p_items jsonb, p_payment_method text, p_branch_id uuid) | no | yes |
| public.register_pos_device(p_business_id uuid, p_device_id uuid, p_platform text, p_branch_id uuid) | no | yes |
| public.repay_trexven_credit(p_sale_id uuid, p_request_id uuid, p_amount numeric, p_method text, p_confirmed boolean, p_evidence text, p_shift_id uuid) | no | yes |
| public.request_trexven_account_lifecycle(p_business_id uuid, p_request_id uuid, p_kind text, p_reason text) | no | yes |
| public.request_trexven_billing_session(p_business_id uuid, p_request_id uuid, p_plan_id text) | no | yes |
| public.request_trexven_cash_handover(p_shift_id uuid, p_request_id uuid, p_incoming_member uuid, p_counted numeric, p_reason text) | no | yes |
| public.request_trexven_country_billing_session(p_business_id uuid, p_request_id uuid, p_plan_id text, p_country_code text, p_interval_months integer) | no | yes |
| public.request_trexven_credit_approval(p_business_id uuid, p_request_id uuid, p_payload jsonb, p_branch_id uuid) | no | yes |
| public.request_trexven_return(p_sale_id uuid, p_request_id uuid, p_items jsonb, p_reason text) | no | yes |
| public.request_trexven_subscription_change(p_business_id uuid, p_request_id uuid, p_action text, p_plan_id text) | no | yes |
| public.require_trexven_feature(p_business_id uuid, p_feature text) | no | yes |
| public.resolve_trexven_angel_catalog_action(p_business_id uuid, p_conversation_id uuid, p_action_id uuid, p_confirm boolean) | no | yes |
| public.resolve_trexven_branch_condition_stock(p_business_id uuid, p_branch_id uuid, p_product_id uuid, p_request_id uuid, p_quantity numeric, p_condition text, p_action text, p_reason text) | no | yes |
| public.resolve_trexven_condition_stock(p_business_id uuid, p_product_id uuid, p_request_id uuid, p_quantity numeric, p_condition text, p_action text, p_reason text) | no | yes |
| public.reverse_trexven_credit_repayment(p_entry_id uuid, p_request_id uuid, p_reason text, p_confirmed boolean, p_evidence text, p_shift_id uuid) | no | yes |
| public.review_trexven_cash_shift(p_shift_id uuid, p_request_id uuid, p_reason text) | no | yes |
| public.review_trexven_inventory_discrepancy(p_review_id uuid, p_request_id uuid, p_reason text) | no | yes |
| public.review_trexven_offline_reconciliation(p_reconciliation_id uuid, p_request_id uuid, p_reason text) | no | yes |
| public.save_trexven_catalog_product(p_business_id uuid, p_request_id uuid, p_product_id uuid, p_fields jsonb) | no | yes |
| public.save_trexven_product_group(p_business_id uuid, p_group_id uuid, p_name text) | no | yes |
| public.set_trexven_branch_assignment(p_employee_id uuid, p_branch_id uuid, p_active boolean) | no | yes |
| public.set_trexven_branch_status(p_branch_id uuid, p_active boolean) | no | yes |
| public.set_trexven_credit_limit(p_business_id uuid, p_amount numeric, p_branch_id uuid) | no | yes |
| public.set_trexven_employee_permission(p_employee_id uuid, p_permission text, p_granted boolean) | no | yes |
| public.set_trexven_employee_status(p_employee_id uuid, p_status text) | no | yes |
| public.start_trexven_branch_stocktake(p_business_id uuid, p_branch_id uuid, p_request_id uuid, p_name text) | no | yes |
| public.start_trexven_stocktake(p_business_id uuid, p_request_id uuid, p_name text) | no | yes |
| public.submit_trexven_branch_sale(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) | no | yes |
| public.submit_trexven_stocktake(p_session_id uuid, p_request_id uuid) | no | yes |
| public.sync_pos_branch_offline_cash(p_request_id uuid, p_ticket jsonb, p_items jsonb, p_total numeric, p_occurred_at timestamp with time zone) | no | yes |
| public.sync_trexven_offline_cash(p_request_id uuid, p_ticket jsonb, p_items jsonb, p_total numeric, p_occurred_at timestamp with time zone) | no | yes |
| public.trexven_account_access_allowed() | yes | yes |
| public.trexven_previous_api_hook() | yes | yes |
| public.update_trexven_employee(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text) | no | yes |
| public.user_owns_business(target_business_id uuid) | no | yes |

## Advisor snapshot — 2026-10-21 after Phase 5

- 87 authenticated public definer findings, 2 anonymous definer findings.
- Catalog additionally lists 11 authenticated private definer helpers (98 total inventory entries).
- 18 RLS-enabled/no-policy informational findings; one is the new intentionally server-managed, empty country-price table with no anonymous/authenticated table grants.
- Leaked-password protection warning remains enabled as an advisor finding: the Auth feature itself is not enabled. Recommend enabling it in Authentication password security after checking project availability, with separate configuration approval. No setting was changed or claimed fixed.

References:
- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://docs.postgrest.org/en/v14/references/auth.html
- https://docs.postgrest.org/en/stable/references/configuration.html

Official docs confirm that the pre-request hook runs after role impersonation. That is why the invoker dispatcher must be preserved.

## Proposed approval checkpoint

Approve ONLY phase_7_account_hook_metadata_hardening.sql. Re-read the current definitions/grants/settings before applying once; promote exact source to the actual generated migration version. Compare guard invoker mode and retained ACL, metadata getter denial to API roles, new helper's void return/search_path/grants, unchanged account-access predicate, unchanged hook configuration/private schema grants, and unchanged financial/account-deletion row counts.

Owner/POS runtime acceptance after deployment remains the user's responsibility: existing authenticated REST flows and session restoration; anonymous requests; closed/deleting-account rejection; account-deletion admission lock coordination; direct metadata RPC denial. Do not configure a fake legacy hook or delete an account to validate production. Future hook-chain runtime checks require a safe approved environment. No frontend merge/release, Paystack activation, or Auth setting change is included.
