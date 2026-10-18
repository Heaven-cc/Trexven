# Source screen inventory

Source files are screen candidates, not proof of reachable routes or deployed
behavior. Most navigation uses `MaterialPageRoute`, not named route strings.
Full runtime reachability and screenshot audit remains pending.

Owner paths below are relative to `lib/screens`:

- Entry: `splash_screen.dart`, `welcome_screen.dart`, `main_screen.dart`.
- Auth: `auth/{account_gate,login_screen,register_screen,forgot_password_screen,reset_password_screen}.dart`.
- Setup: `setup/{business_setup_screen,setup_complete_screen}.dart`.
- Home/Angel: `dashboard/{dashboard_screen,angel_screen}.dart`.
- Inventory: `inventory/{inventory_tab,add_product_screen}.dart`.
- Finance/sales: `finance/{finance_tab,record_sale_screen}.dart`.
- Intelligence: `intelligence/{intelligence_tab,vision_server_screen,camera_screen,add_camera_screen,camera_detail_screen,camera_intelligence_screen,camera_event_screen,camera_alert_screen,live_feed_screen,events_screen,event_detail_screen,alerts_screen,recordings_screen,recording_playback_screen}.dart`.
- Me: `me/{me_tab,profile_screen,business_profile_screen,employment_screen,add_employee_screen,edit_employee_screen,employee_details_screen,employee_confirmation_screen,permissions_screen,billing_screen,notifications_settings_screen,security_screen,appearance_screen,data_backup_screen,help_support_screen,about_screen,privacy_policy_screen,terms_of_service_screen}.dart`.

POS paths relative to `lib/src/features`:

- Auth: `auth/{login_screen,business_selection_screen}.dart`.
- Home/checkout/sales: `pos/{dashboard_screen,checkout_screen,recent_sales_screen}.dart`.
- Product selection: `inventory/{scanner_screen,product_search_screen,product_detail_screen,quick_add_screen}.dart`.
- Additional loading destination: `BusinessLoadingScreen` in POS `lib/main.dart`.

Missing companion screen groups in the source inventory: branch selector,
variant editor, split/verified payments, credit/repayment/refund workflows,
transfers, damaged lifecycle, stocktaking, shifts, sync center, POS More settings
and role reports. Do not create decorative routes with pretend completion before
their backend behavior exists. Preserve additional existing legal, setup and
Vision routes during navigation changes.
