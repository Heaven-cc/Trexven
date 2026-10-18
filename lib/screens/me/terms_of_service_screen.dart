import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms of Service',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: TrexvenFontSize.section,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: TrexvenSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TREXVEN TERMS OF SERVICE',
                style: TextStyle(
                  fontSize: TrexvenFontSize.section,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Last Updated: August 26, 2026',
                style: TextStyle(
                  fontSize: TrexvenFontSize.body,
                  fontWeight: FontWeight.w700,
                  color: theme.trexvenColors.muted,
                ),
              ),
              SizedBox(height: TrexvenSpacing.sectionGap),
              _section(theme, 'Welcome to TREXVEN.'),
              _paragraph(
                theme,
                'These Terms of Service ("Terms") govern your access to and use of the TREXVEN application, software, websites, services, artificial intelligence features, business management tools, inventory tools, point-of-sale features, employee management tools, camera and Vision Server integrations, notifications, and related services (collectively, the "Services").',
              ),
              _paragraph(
                theme,
                'TREXVEN is operated under the TREXVEN/ODT platform. Throughout these Terms, "TREXVEN," "we," "us," and "our" refer to the operator of the TREXVEN Services. "You," "your," "Business," and "User" refer to the individual or organization accessing or using the Services.',
              ),
              _paragraph(
                theme,
                'By creating an account, accessing TREXVEN, connecting a device, registering a business, using the TREXVEN POS, connecting a camera or Vision Server, or otherwise using any part of the Services, you agree to be bound by these Terms.',
              ),
              _paragraph(
                theme,
                'If you do not agree with these Terms, you must not access or use TREXVEN.',
              ),
              _divider(theme),
              _section(theme, '1. ABOUT TREXVEN'),
              _paragraph(
                theme,
                'TREXVEN is a business management platform designed to help businesses organize, manage, and understand their operations.',
              ),
              _paragraph(
                theme,
                'Depending on the features made available to you, TREXVEN may provide tools for:',
              ),
              _bulletPoint(theme, 'Business and store management'),
              _bulletPoint(theme, 'Inventory and product management'),
              _bulletPoint(theme, 'Product barcode scanning'),
              _bulletPoint(theme, 'Product search and quick product entry'),
              _bulletPoint(theme, 'Stock monitoring'),
              _bulletPoint(theme, 'Low-stock notifications'),
              _bulletPoint(theme, 'Sales and transaction management'),
              _bulletPoint(theme, 'TREXVEN POS functionality'),
              _bulletPoint(theme, 'Employee and staff management'),
              _bulletPoint(theme, 'Role and permission management'),
              _bulletPoint(
                theme,
                'Business reporting and operational insights',
              ),
              _bulletPoint(theme, 'Notifications and alerts'),
              _bulletPoint(theme, 'Camera registration and management'),
              _bulletPoint(theme, 'IP camera integrations'),
              _bulletPoint(theme, 'RTSP and network camera connectivity'),
              _bulletPoint(theme, 'TREXVEN Vision Server functionality'),
              _bulletPoint(theme, 'AI-powered event detection and analysis'),
              _bulletPoint(theme, 'Security and operational monitoring'),
              _bulletPoint(
                theme,
                'TREXVEN Angel and other AI-assisted features',
              ),
              _bulletPoint(theme, 'Data synchronization'),
              _bulletPoint(
                theme,
                'Cloud-based account and business data storage',
              ),
              _bulletPoint(
                theme,
                'Other present or future features offered through the TREXVEN ecosystem',
              ),
              _paragraph(
                theme,
                'TREXVEN may update, improve, remove, replace, suspend, or introduce features at any time, subject to applicable law.',
              ),
              _paragraph(
                theme,
                'Not every feature will necessarily be available to every user, business, device, country, operating system, subscription plan, or version of the application.',
              ),
              _divider(theme),
              _section(theme, '2. ELIGIBILITY'),
              _paragraph(
                theme,
                'You may use TREXVEN only if you are legally permitted to enter into a binding agreement under applicable law.',
              ),
              _paragraph(
                theme,
                'If you use TREXVEN on behalf of a business, company, partnership, store, organization, employer, or other legal entity, you represent and warrant that:',
              ),
              _numberedPoint(
                theme,
                1,
                'You have authority to accept these Terms on behalf of that entity.',
              ),
              _numberedPoint(
                theme,
                2,
                'You have authority to create or manage the TREXVEN account for that entity.',
              ),
              _numberedPoint(
                theme,
                3,
                'The information you provide about the entity is accurate.',
              ),
              _numberedPoint(
                theme,
                4,
                'The entity agrees to be bound by these Terms.',
              ),
              _numberedPoint(
                theme,
                5,
                'You will ensure that employees and authorized users of your business use TREXVEN in accordance with these Terms and applicable law.',
              ),
              _paragraph(
                theme,
                'The business account owner or other authorized administrator may be responsible for activities performed through the business account and by users to whom access has been granted.',
              ),
              _divider(theme),
              _section(theme, '3. YOUR TREXVEN ACCOUNT'),
              _paragraph(theme, 'Certain TREXVEN features require an account.'),
              _paragraph(
                theme,
                'When creating or maintaining an account, you agree to provide accurate, current, and complete information.',
              ),
              _paragraph(theme, 'You are responsible for:'),
              _bulletPoint(
                theme,
                'Maintaining the confidentiality of your login credentials.',
              ),
              _bulletPoint(
                theme,
                'Protecting your password and authentication methods.',
              ),
              _bulletPoint(
                theme,
                'Restricting unauthorized access to your account.',
              ),
              _bulletPoint(
                theme,
                'Ensuring information associated with your account remains accurate.',
              ),
              _bulletPoint(
                theme,
                'Promptly updating information when it changes.',
              ),
              _bulletPoint(
                theme,
                'Promptly notifying us if you believe your account has been accessed without authorization.',
              ),
              _paragraph(theme, 'You must not:'),
              _bulletPoint(
                theme,
                'Share your password with unauthorized persons.',
              ),
              _bulletPoint(
                theme,
                'Sell or transfer your account without authorization.',
              ),
              _bulletPoint(
                theme,
                'Attempt to gain access to another user\'s account.',
              ),
              _bulletPoint(
                theme,
                'Use another person\'s account without permission.',
              ),
              _bulletPoint(
                theme,
                'Circumvent authentication or security systems.',
              ),
              _bulletPoint(
                theme,
                'Create accounts for fraudulent, unlawful, or abusive purposes.',
              ),
              _paragraph(
                theme,
                'You are responsible for activities performed through your account to the extent permitted by applicable law.',
              ),
              _paragraph(
                theme,
                'TREXVEN may suspend, restrict, or terminate an account where we reasonably believe that account security has been compromised or these Terms have been violated.',
              ),
              _divider(theme),
              _section(theme, '4. BUSINESS ACCOUNTS AND WORKSPACES'),
              _paragraph(
                theme,
                'TREXVEN may allow an account owner to create or manage one or more business workspaces.',
              ),
              _paragraph(
                theme,
                'A business workspace may contain information relating to:',
              ),
              _bulletPoint(theme, 'Business name'),
              _bulletPoint(theme, 'Business category'),
              _bulletPoint(theme, 'Address'),
              _bulletPoint(theme, 'Contact information'),
              _bulletPoint(theme, 'Products'),
              _bulletPoint(theme, 'Inventory'),
              _bulletPoint(theme, 'Prices'),
              _bulletPoint(theme, 'Sales'),
              _bulletPoint(theme, 'Employees'),
              _bulletPoint(theme, 'Employee roles'),
              _bulletPoint(theme, 'Permissions'),
              _bulletPoint(theme, 'Cameras'),
              _bulletPoint(theme, 'Vision systems'),
              _bulletPoint(theme, 'AI events'),
              _bulletPoint(theme, 'Business activity'),
              _bulletPoint(theme, 'Reports'),
              _bulletPoint(theme, 'Notifications'),
              _bulletPoint(theme, 'Other operational information'),
              _paragraph(
                theme,
                'The person or entity creating a business workspace is responsible for ensuring that it has the necessary rights and authority to enter the information and manage that workspace.',
              ),
              _paragraph(
                theme,
                'Business administrators may invite, create, authorize, remove, or manage employees and other users.',
              ),
              _paragraph(
                theme,
                'You are responsible for selecting appropriate access levels and permissions for your employees and authorized users.',
              ),
              _paragraph(
                theme,
                'TREXVEN provides tools to assist with access management, but the Business remains responsible for deciding who should have access to its information and systems.',
              ),
              _divider(theme),
              _section(theme, '5. EMPLOYEES, USERS, ROLES, AND PERMISSIONS'),
              _paragraph(
                theme,
                'TREXVEN may allow businesses to create employee records and assign users different roles and permissions.',
              ),
              _paragraph(
                theme,
                'Depending on the Services available, these roles may include categories such as:',
              ),
              _bulletPoint(theme, 'Owner'),
              _bulletPoint(theme, 'Manager'),
              _bulletPoint(theme, 'Sales Employee'),
              _bulletPoint(theme, 'Inventory Employee'),
              _bulletPoint(theme, 'Other custom or predefined access roles'),
              _paragraph(
                theme,
                'Permissions may control access to functions such as:',
              ),
              _bulletPoint(theme, 'Inventory'),
              _bulletPoint(theme, 'Products'),
              _bulletPoint(theme, 'Sales'),
              _bulletPoint(theme, 'POS'),
              _bulletPoint(theme, 'Reports'),
              _bulletPoint(theme, 'Employees'),
              _bulletPoint(theme, 'Cameras'),
              _bulletPoint(theme, 'Vision events'),
              _bulletPoint(theme, 'AI features'),
              _bulletPoint(theme, 'Settings'),
              _bulletPoint(theme, 'Business configuration'),
              _bulletPoint(theme, 'Other system functions'),
              _paragraph(
                theme,
                'The Business is responsible for configuring its access controls appropriately.',
              ),
              _paragraph(
                theme,
                'TREXVEN does not guarantee that a permission configuration selected by a Business will meet every legal, security, operational, or organizational requirement of that Business.',
              ),
              _paragraph(theme, 'Businesses should regularly review:'),
              _bulletPoint(theme, 'Employee access'),
              _bulletPoint(theme, 'User roles'),
              _bulletPoint(theme, 'Permissions'),
              _bulletPoint(theme, 'Active accounts'),
              _bulletPoint(theme, 'Connected devices'),
              _bulletPoint(theme, 'Former employee access'),
              _paragraph(
                theme,
                'When an employee or authorized user should no longer have access, the Business should promptly remove or restrict that access.',
              ),
              _divider(theme),
              _section(theme, '6. TREXVEN POS AND SALES FEATURES'),
              _paragraph(
                theme,
                'TREXVEN may provide point-of-sale and sales management functionality.',
              ),
              _paragraph(
                theme,
                'The availability of POS features may vary depending on the version of the Services, device capabilities, configuration, connected systems, or future service updates.',
              ),
              _paragraph(theme, 'Businesses are responsible for:'),
              _bulletPoint(theme, 'Entering accurate products and pricing.'),
              _bulletPoint(theme, 'Reviewing sales information.'),
              _bulletPoint(theme, 'Managing authorized users.'),
              _bulletPoint(
                theme,
                'Complying with tax laws and financial recordkeeping requirements.',
              ),
              _bulletPoint(
                theme,
                'Verifying transactions before relying on them.',
              ),
              _bulletPoint(
                theme,
                'Maintaining any legally required receipts or records.',
              ),
              _bulletPoint(
                theme,
                'Configuring business-specific prices and inventory correctly.',
              ),
              _paragraph(
                theme,
                'TREXVEN does not automatically guarantee that a product price, inventory quantity, sales record, tax calculation, financial total, or report is correct.',
              ),
              _paragraph(
                theme,
                'Users should review critical business and financial information.',
              ),
              _paragraph(
                theme,
                'TREXVEN is not a bank, payment processor, financial institution, accounting firm, tax adviser, or legal adviser unless explicitly stated otherwise for a particular service.',
              ),
              _paragraph(
                theme,
                'The Services should not be treated as professional accounting, tax, legal, financial, or regulatory advice.',
              ),
              _divider(theme),
              _section(theme, '7. INVENTORY AND PRODUCT INFORMATION'),
              _paragraph(
                theme,
                'TREXVEN may allow users to create, modify, import, scan, search, organize, and manage product information.',
              ),
              _paragraph(theme, 'Product information may include:'),
              _bulletPoint(theme, 'Product names'),
              _bulletPoint(theme, 'Categories'),
              _bulletPoint(theme, 'Barcodes'),
              _bulletPoint(theme, 'SKU information'),
              _bulletPoint(theme, 'Quantities'),
              _bulletPoint(theme, 'Stock levels'),
              _bulletPoint(theme, 'Cost information'),
              _bulletPoint(theme, 'Selling prices'),
              _bulletPoint(theme, 'Price ranges'),
              _bulletPoint(theme, 'Product images'),
              _bulletPoint(theme, 'Descriptions'),
              _bulletPoint(theme, 'Supplier-related information'),
              _bulletPoint(theme, 'Other inventory data'),
              _paragraph(
                theme,
                'The Business is responsible for the accuracy of information entered into the system.',
              ),
              _paragraph(
                theme,
                'Barcode scanning and automated product lookup may not always correctly identify a product.',
              ),
              _paragraph(
                theme,
                'Before relying on automatically identified product information, the Business should verify the result.',
              ),
              _paragraph(theme, 'TREXVEN does not guarantee that:'),
              _bulletPoint(theme, 'Every barcode will be recognized.'),
              _bulletPoint(theme, 'Every product lookup will return a result.'),
              _bulletPoint(
                theme,
                'Product information returned by a database or third-party source is accurate.',
              ),
              _bulletPoint(
                theme,
                'Inventory quantities will always reflect the physical stock in real time.',
              ),
              _bulletPoint(
                theme,
                'Automated deductions or updates will always match physical inventory.',
              ),
              _paragraph(
                theme,
                'Businesses should conduct appropriate physical inventory checks and audits.',
              ),
              _divider(theme),
              _section(theme, '8. ARTIFICIAL INTELLIGENCE FEATURES'),
              _paragraph(
                theme,
                'TREXVEN may offer AI-powered features, including TREXVEN Angel, computer vision, automated detection, business insights, suggestions, summaries, classifications, predictions, alerts, and related functionality.',
              ),
              _paragraph(theme, 'AI-generated output may be based on:'),
              _bulletPoint(theme, 'Information provided by users.'),
              _bulletPoint(theme, 'Business data.'),
              _bulletPoint(theme, 'Inventory information.'),
              _bulletPoint(theme, 'Sales information.'),
              _bulletPoint(theme, 'System events.'),
              _bulletPoint(theme, 'Camera or video data where applicable.'),
              _bulletPoint(theme, 'Third-party technologies.'),
              _bulletPoint(theme, 'Statistical and machine-learning models.'),
              _paragraph(
                theme,
                'AI output may be inaccurate, incomplete, outdated, misleading, unavailable, or inappropriate for a particular situation.',
              ),
              _paragraph(
                theme,
                'You understand and agree that AI-generated information should not be treated as guaranteed factual information.',
              ),
              _paragraph(
                theme,
                'You should independently review important AI-generated output before making significant decisions based on it.',
              ),
              _paragraph(
                theme,
                'This is particularly important for decisions involving:',
              ),
              _bulletPoint(theme, 'Employment'),
              _bulletPoint(theme, 'Discipline'),
              _bulletPoint(theme, 'Termination'),
              _bulletPoint(theme, 'Security'),
              _bulletPoint(theme, 'Financial decisions'),
              _bulletPoint(theme, 'Pricing'),
              _bulletPoint(theme, 'Inventory losses'),
              _bulletPoint(theme, 'Theft allegations'),
              _bulletPoint(theme, 'Legal matters'),
              _bulletPoint(theme, 'Regulatory matters'),
              _bulletPoint(theme, 'Safety matters'),
              _paragraph(
                theme,
                'TREXVEN\'s AI features are designed to assist users and businesses. They do not replace human judgment.',
              ),
              _paragraph(
                theme,
                'You remain responsible for decisions made using information or suggestions generated by the Services.',
              ),
              _divider(theme),
              _section(theme, '9. TREXVEN VISION, CAMERAS, AND VISION SERVER'),
              _paragraph(
                theme,
                'TREXVEN may allow businesses to connect cameras, IP cameras, network video streams, NVR systems, RTSP streams, Vision Servers, or related hardware and software.',
              ),
              _paragraph(
                theme,
                'When you connect a camera or video source, you represent and warrant that:',
              ),
              _numberedPoint(
                theme,
                1,
                'You own the device or have authorization to connect it.',
              ),
              _numberedPoint(
                theme,
                2,
                'You have the legal right to access and process the video stream.',
              ),
              _numberedPoint(
                theme,
                3,
                'You have provided any notices or obtained any consents required by applicable law.',
              ),
              _numberedPoint(
                theme,
                4,
                'Your use of video monitoring complies with applicable privacy, employment, workplace, surveillance, and data protection laws.',
              ),
              _numberedPoint(
                theme,
                5,
                'You will not use TREXVEN Vision for unlawful surveillance.',
              ),
              _paragraph(
                theme,
                'TREXVEN may process video or image data to provide requested functionality, including potentially:',
              ),
              _bulletPoint(theme, 'Object detection'),
              _bulletPoint(theme, 'Product-related detection'),
              _bulletPoint(theme, 'Movement detection'),
              _bulletPoint(theme, 'Event detection'),
              _bulletPoint(theme, 'Activity monitoring'),
              _bulletPoint(theme, 'Security-related alerts'),
              _bulletPoint(theme, 'Operational insights'),
              _bulletPoint(theme, 'Other computer vision functionality'),
              _paragraph(
                theme,
                'Detection results are not guaranteed to be accurate.',
              ),
              _paragraph(theme, 'The system may:'),
              _bulletPoint(theme, 'Miss events.'),
              _bulletPoint(theme, 'Incorrectly identify events.'),
              _bulletPoint(theme, 'Produce false positives.'),
              _bulletPoint(theme, 'Produce false negatives.'),
              _bulletPoint(theme, 'Experience delays.'),
              _bulletPoint(theme, 'Be affected by camera angle.'),
              _bulletPoint(theme, 'Be affected by lighting.'),
              _bulletPoint(theme, 'Be affected by network quality.'),
              _bulletPoint(theme, 'Be affected by obstructions.'),
              _bulletPoint(theme, 'Be affected by hardware performance.'),
              _bulletPoint(theme, 'Be affected by environmental conditions.'),
              _paragraph(
                theme,
                'TREXVEN Vision must not be relied upon as the sole security system protecting a business, person, property, inventory, or financial assets.',
              ),
              _paragraph(
                theme,
                'You should maintain appropriate independent security measures where necessary.',
              ),
              _divider(theme),
              _section(theme, '10. CAMERA MONITORING AND LEGAL RESPONSIBILITY'),
              _paragraph(
                theme,
                'You are solely responsible for ensuring that your use of cameras and monitoring technologies complies with applicable law.',
              ),
              _paragraph(
                theme,
                'Depending on your location, laws may regulate:',
              ),
              _bulletPoint(theme, 'Workplace surveillance'),
              _bulletPoint(theme, 'Employee monitoring'),
              _bulletPoint(theme, 'Notice requirements'),
              _bulletPoint(theme, 'Consent requirements'),
              _bulletPoint(theme, 'Audio recording'),
              _bulletPoint(theme, 'Video recording'),
              _bulletPoint(theme, 'Biometric information'),
              _bulletPoint(theme, 'Facial recognition'),
              _bulletPoint(theme, 'Data retention'),
              _bulletPoint(theme, 'Cross-border data transfers'),
              _bulletPoint(theme, 'Monitoring of customers or visitors'),
              _paragraph(
                theme,
                'TREXVEN does not provide legal advice regarding whether your proposed use of cameras is lawful.',
              ),
              _paragraph(
                theme,
                'You should consult a qualified legal professional where necessary.',
              ),
              _paragraph(
                theme,
                'You must not use TREXVEN to unlawfully monitor individuals in areas where they reasonably expect privacy, including locations such as:',
              ),
              _bulletPoint(theme, 'Bathrooms'),
              _bulletPoint(theme, 'Changing rooms'),
              _bulletPoint(theme, 'Other legally protected private spaces'),
              _paragraph(
                theme,
                'You must not connect cameras that you are not authorized to access.',
              ),
              _divider(theme),
              _section(
                theme,
                '11. NO GUARANTEE OF DETECTION OR LOSS PREVENTION',
              ),
              _paragraph(
                theme,
                'TREXVEN Vision and AI features may assist with identifying potentially relevant events.',
              ),
              _paragraph(theme, 'However, TREXVEN does not guarantee:'),
              _bulletPoint(theme, 'Theft prevention.'),
              _bulletPoint(theme, 'Theft detection.'),
              _bulletPoint(theme, 'Identification of every suspicious event.'),
              _bulletPoint(
                theme,
                'Accurate attribution of an event to a particular person.',
              ),
              _bulletPoint(theme, 'Prevention of employee misconduct.'),
              _bulletPoint(theme, 'Prevention of inventory loss.'),
              _bulletPoint(theme, 'Prevention of financial loss.'),
              _bulletPoint(theme, 'Continuous monitoring.'),
              _bulletPoint(theme, 'Uninterrupted camera connectivity.'),
              _paragraph(
                theme,
                'An alert, AI event, detection, or absence of an alert must not be treated as conclusive evidence that a person committed or did not commit an act.',
              ),
              _paragraph(
                theme,
                'Businesses should independently investigate relevant events before taking action.',
              ),
              _paragraph(
                theme,
                'You should not make serious decisions about an individual solely on the basis of automated output without appropriate human review.',
              ),
              _divider(theme),
              _section(theme, '12. THIRD-PARTY DEVICES AND SERVICES'),
              _paragraph(
                theme,
                'TREXVEN may work with third-party services, infrastructure, hardware, operating systems, devices, cameras, network equipment, APIs, cloud providers, authentication providers, databases, AI providers, and payment services.',
              ),
              _paragraph(
                theme,
                'Your use of third-party products may be governed by separate terms and privacy policies.',
              ),
              _paragraph(
                theme,
                'TREXVEN is not responsible for third-party services that:',
              ),
              _bulletPoint(theme, 'Become unavailable.'),
              _bulletPoint(theme, 'Change their APIs.'),
              _bulletPoint(theme, 'Change their pricing.'),
              _bulletPoint(theme, 'Change their terms.'),
              _bulletPoint(theme, 'Experience outages.'),
              _bulletPoint(theme, 'Lose connectivity.'),
              _bulletPoint(theme, 'Return inaccurate information.'),
              _bulletPoint(theme, 'Stop supporting a device.'),
              _bulletPoint(theme, 'Introduce compatibility changes.'),
              _paragraph(
                theme,
                'Compatibility with a device or service at one time does not guarantee permanent compatibility.',
              ),
              _divider(theme),
              _section(theme, '13. ACCEPTABLE USE'),
              _paragraph(theme, 'You agree not to use TREXVEN to:'),
              _bulletPoint(theme, 'Break the law.'),
              _bulletPoint(theme, 'Commit fraud.'),
              _bulletPoint(theme, 'Facilitate theft.'),
              _bulletPoint(theme, 'Impersonate another person.'),
              _bulletPoint(theme, 'Access systems without authorization.'),
              _bulletPoint(theme, 'Circumvent security controls.'),
              _bulletPoint(theme, 'Interfere with the Services.'),
              _bulletPoint(theme, 'Upload malicious software.'),
              _bulletPoint(
                theme,
                'Attempt to reverse engineer protected parts of the Services except where legally permitted.',
              ),
              _bulletPoint(
                theme,
                'Probe or test systems without authorization.',
              ),
              _bulletPoint(
                theme,
                'Attempt to overload or disrupt TREXVEN infrastructure.',
              ),
              _bulletPoint(
                theme,
                'Harvest information about other users without authorization.',
              ),
              _bulletPoint(
                theme,
                'Use the Services to unlawfully surveil individuals.',
              ),
              _bulletPoint(
                theme,
                'Use AI or Vision features to violate privacy rights.',
              ),
              _bulletPoint(
                theme,
                'Upload content that you do not have the right to use.',
              ),
              _bulletPoint(
                theme,
                'Attempt to gain access to another Business\'s data.',
              ),
              _bulletPoint(theme, 'Use another user\'s credentials.'),
              _bulletPoint(
                theme,
                'Resell access to TREXVEN without authorization.',
              ),
              _bulletPoint(
                theme,
                'Misrepresent AI output as independently verified fact.',
              ),
              _bulletPoint(
                theme,
                'Use automated systems to abuse or scrape the Services without authorization.',
              ),
              _paragraph(
                theme,
                'We may investigate suspected violations and take appropriate action, including restricting or terminating access.',
              ),
              _divider(theme),
              _section(theme, '14. DATA OWNERSHIP'),
              _paragraph(
                theme,
                'As between you and TREXVEN, you or your Business retain ownership of business information and other content that you lawfully submit to TREXVEN, subject to applicable agreements and law.',
              ),
              _paragraph(theme, 'This may include:'),
              _bulletPoint(theme, 'Product information'),
              _bulletPoint(theme, 'Inventory data'),
              _bulletPoint(theme, 'Business information'),
              _bulletPoint(theme, 'Sales information'),
              _bulletPoint(theme, 'Employee records'),
              _bulletPoint(theme, 'User-created content'),
              _bulletPoint(theme, 'Camera configuration information'),
              _bulletPoint(theme, 'Other Business Data'),
              _paragraph(
                theme,
                'You grant TREXVEN the limited rights necessary to host, store, process, transmit, analyze, secure, back up, and otherwise use your information solely as reasonably necessary to provide, maintain, improve, secure, and support the Services.',
              ),
              _paragraph(
                theme,
                'TREXVEN may also generate technical, operational, diagnostic, statistical, and aggregated information from use of the Services.',
              ),
              _paragraph(
                theme,
                'Where permitted by law, aggregated or de-identified information that does not reasonably identify you or your Business may be used to operate, analyze, improve, and develop the Services.',
              ),
              _divider(theme),
              _section(theme, '15. DATA ACCURACY AND YOUR RESPONSIBILITY'),
              _paragraph(
                theme,
                'You are responsible for the information entered into TREXVEN.',
              ),
              _paragraph(
                theme,
                'Before relying on important information, you should review and verify it.',
              ),
              _paragraph(theme, 'This includes:'),
              _bulletPoint(theme, 'Product quantities'),
              _bulletPoint(theme, 'Prices'),
              _bulletPoint(theme, 'Sales'),
              _bulletPoint(theme, 'Employee information'),
              _bulletPoint(theme, 'Business details'),
              _bulletPoint(theme, 'Camera settings'),
              _bulletPoint(theme, 'AI results'),
              _bulletPoint(theme, 'Reports'),
              _bulletPoint(theme, 'Notifications'),
              _bulletPoint(theme, 'System configurations'),
              _paragraph(
                theme,
                'TREXVEN is a technology platform and may depend on information supplied by users and connected systems.',
              ),
              _paragraph(
                theme,
                'Incorrect input may produce incorrect output.',
              ),
              _divider(theme),
              _section(theme, '16. AVAILABILITY OF THE SERVICES'),
              _paragraph(
                theme,
                'We aim to provide reliable Services but do not guarantee uninterrupted or error-free operation.',
              ),
              _paragraph(theme, 'The Services may be unavailable because of:'),
              _bulletPoint(theme, 'Maintenance'),
              _bulletPoint(theme, 'Updates'),
              _bulletPoint(theme, 'Server issues'),
              _bulletPoint(theme, 'Network failures'),
              _bulletPoint(theme, 'Internet outages'),
              _bulletPoint(theme, 'Third-party outages'),
              _bulletPoint(theme, 'Device failures'),
              _bulletPoint(theme, 'Camera failures'),
              _bulletPoint(theme, 'Power failures'),
              _bulletPoint(theme, 'Software defects'),
              _bulletPoint(theme, 'Security incidents'),
              _bulletPoint(theme, 'Events outside our reasonable control'),
              _paragraph(
                theme,
                'We may temporarily suspend part of the Services for maintenance, updates, security, or operational reasons.',
              ),
              _paragraph(
                theme,
                'Where practical, we may provide notice of planned significant maintenance.',
              ),
              _divider(theme),
              _section(theme, '17. SERVICE CHANGES'),
              _paragraph(theme, 'TREXVEN is continuously evolving.'),
              _paragraph(
                theme,
                'We may modify, improve, add, remove, or discontinue features.',
              ),
              _paragraph(theme, 'For example, we may:'),
              _bulletPoint(theme, 'Introduce new AI features.'),
              _bulletPoint(theme, 'Change camera integrations.'),
              _bulletPoint(theme, 'Update Vision Server requirements.'),
              _bulletPoint(theme, 'Improve POS functionality.'),
              _bulletPoint(theme, 'Modify available reports.'),
              _bulletPoint(theme, 'Change supported devices.'),
              _bulletPoint(theme, 'Update notification systems.'),
              _bulletPoint(
                theme,
                'Change the appearance or organization of the application.',
              ),
              _paragraph(
                theme,
                'Where legally required, we will provide applicable notice before material changes take effect.',
              ),
              _paragraph(
                theme,
                'Continued use of the Services after applicable changes become effective may constitute acceptance of those changes, where permitted by law.',
              ),
              _divider(theme),
              _section(theme, '18. FEES AND SUBSCRIPTIONS'),
              _paragraph(
                theme,
                'Some TREXVEN features may currently be free while other features may require payment now or in the future.',
              ),
              _paragraph(
                theme,
                'If paid plans are introduced or made available to you, applicable pricing, billing terms, renewal information, and payment conditions will be provided before you are required to purchase the applicable plan, except where otherwise permitted by law.',
              ),
              _paragraph(theme, 'Unless otherwise stated:'),
              _bulletPoint(theme, 'Fees may be non-refundable.'),
              _bulletPoint(theme, 'Taxes may apply.'),
              _bulletPoint(
                theme,
                'Subscription access may depend on successful payment.',
              ),
              _bulletPoint(
                theme,
                'Failure to pay may result in feature restrictions or suspension.',
              ),
              _paragraph(
                theme,
                'Any specific subscription terms presented at the time of purchase form part of your agreement with TREXVEN.',
              ),
              _divider(theme),
              _section(theme, '19. INTELLECTUAL PROPERTY'),
              _paragraph(
                theme,
                'TREXVEN and its software, branding, design, logos, interfaces, technology, documentation, and other proprietary materials are protected by applicable intellectual property laws.',
              ),
              _paragraph(
                theme,
                'Except for the limited right to use the Services under these Terms, no ownership rights are transferred to you.',
              ),
              _paragraph(theme, 'You may not:'),
              _bulletPoint(
                theme,
                'Copy TREXVEN\'s software except where legally permitted.',
              ),
              _bulletPoint(
                theme,
                'Reproduce proprietary designs without authorization.',
              ),
              _bulletPoint(theme, 'Use TREXVEN branding in a misleading way.'),
              _bulletPoint(theme, 'Claim ownership of TREXVEN technology.'),
              _bulletPoint(
                theme,
                'Sell or license access to the Services without authorization.',
              ),
              _paragraph(
                theme,
                'You may use the TREXVEN Services for legitimate internal business purposes in accordance with these Terms.',
              ),
              _divider(theme),
              _section(theme, '20. FEEDBACK'),
              _paragraph(
                theme,
                'If you provide suggestions, feedback, ideas, or recommendations regarding TREXVEN, you agree that we may use that feedback without restriction or compensation to the extent permitted by law.',
              ),
              _paragraph(theme, 'You are not required to provide feedback.'),
              _divider(theme),
              _section(theme, '21. SUSPENSION AND TERMINATION'),
              _paragraph(theme, 'You may stop using TREXVEN at any time.'),
              _paragraph(
                theme,
                'We may suspend or terminate access where reasonably necessary, including if:',
              ),
              _bulletPoint(theme, 'You violate these Terms.'),
              _bulletPoint(theme, 'We suspect unauthorized activity.'),
              _bulletPoint(theme, 'Your use creates a security risk.'),
              _bulletPoint(theme, 'You engage in fraud or unlawful activity.'),
              _bulletPoint(
                theme,
                'Continued access may harm TREXVEN or other users.',
              ),
              _bulletPoint(theme, 'Required by law.'),
              _paragraph(
                theme,
                'Where appropriate and legally required, we may provide notice or an opportunity to address the issue.',
              ),
              _paragraph(
                theme,
                'Termination may result in loss of access to some or all account information, subject to applicable data retention obligations and our Privacy Policy.',
              ),
              _divider(theme),
              _section(theme, '22. DISCLAIMERS'),
              _paragraph(
                theme,
                'THE SERVICES ARE PROVIDED ON AN "AS AVAILABLE" AND, TO THE EXTENT PERMITTED BY APPLICABLE LAW, "AS IS" BASIS.',
              ),
              _paragraph(
                theme,
                'TREXVEN DOES NOT GUARANTEE THAT THE SERVICES WILL ALWAYS:',
              ),
              _bulletPoint(theme, 'Be uninterrupted.'),
              _bulletPoint(theme, 'Be error-free.'),
              _bulletPoint(theme, 'Be completely secure.'),
              _bulletPoint(theme, 'Detect every event.'),
              _bulletPoint(theme, 'Produce accurate AI results.'),
              _bulletPoint(theme, 'Prevent theft or loss.'),
              _bulletPoint(theme, 'Correctly identify every product.'),
              _bulletPoint(
                theme,
                'Correctly calculate every business outcome.',
              ),
              _bulletPoint(theme, 'Meet every business requirement.'),
              _paragraph(
                theme,
                'Nothing in these Terms excludes warranties that cannot legally be excluded.',
              ),
              _divider(theme),
              _section(theme, '23. LIMITATION OF LIABILITY'),
              _paragraph(
                theme,
                'To the maximum extent permitted by applicable law, TREXVEN and its operators, affiliates, employees, and service providers will not be liable for indirect, incidental, consequential, special, exemplary, or punitive damages arising from your use of or inability to use the Services.',
              ),
              _paragraph(theme, 'This may include damages relating to:'),
              _bulletPoint(theme, 'Lost profits.'),
              _bulletPoint(theme, 'Lost business opportunities.'),
              _bulletPoint(theme, 'Data loss.'),
              _bulletPoint(theme, 'Inventory loss.'),
              _bulletPoint(theme, 'Theft.'),
              _bulletPoint(theme, 'Employee misconduct.'),
              _bulletPoint(theme, 'Camera failures.'),
              _bulletPoint(theme, 'Missed AI detections.'),
              _bulletPoint(theme, 'Incorrect AI output.'),
              _bulletPoint(theme, 'Business interruption.'),
              _bulletPoint(theme, 'Device or network failures.'),
              _paragraph(
                theme,
                'Nothing in these Terms limits liability where such limitation is prohibited by applicable law.',
              ),
              _divider(theme),
              _section(theme, '24. INDEMNIFICATION'),
              _paragraph(
                theme,
                'To the extent permitted by law, you agree to defend, indemnify, and hold harmless TREXVEN and its operators from claims arising from:',
              ),
              _bulletPoint(theme, 'Your unlawful use of the Services.'),
              _bulletPoint(theme, 'Your violation of these Terms.'),
              _bulletPoint(
                theme,
                'Your unauthorized use of camera or surveillance systems.',
              ),
              _bulletPoint(
                theme,
                'Your violation of another person\'s privacy rights.',
              ),
              _bulletPoint(
                theme,
                'Content or data you submit without appropriate rights.',
              ),
              _bulletPoint(theme, 'Your misuse of AI-generated output.'),
              _paragraph(
                theme,
                'This obligation applies only to the extent permitted by applicable law.',
              ),
              _divider(theme),
              _section(theme, '25. GOVERNING LAW AND DISPUTES'),
              _paragraph(
                theme,
                'These Terms will be governed by the laws applicable to the TREXVEN operating entity and the relevant contractual relationship, unless applicable consumer or other mandatory laws require otherwise.',
              ),
              _paragraph(
                theme,
                'Before starting formal legal proceedings, the parties should, where reasonable, attempt to resolve disputes through good-faith communication.',
              ),
              _paragraph(
                theme,
                'Nothing in this section prevents either party from seeking urgent legal remedies where appropriate.',
              ),
              _paragraph(
                theme,
                'Before publishing, this section should be completed with the specific legal jurisdiction, governing law, dispute resolution process, and company/legal entity information applicable to TREXVEN.',
              ),
              _divider(theme),
              _section(theme, '26. CHANGES TO THESE TERMS'),
              _paragraph(theme, 'We may update these Terms when necessary.'),
              _paragraph(theme, 'We may do so because of:'),
              _bulletPoint(theme, 'Changes to TREXVEN.'),
              _bulletPoint(theme, 'New features.'),
              _bulletPoint(theme, 'Legal requirements.'),
              _bulletPoint(theme, 'Security requirements.'),
              _bulletPoint(theme, 'Operational changes.'),
              _paragraph(
                theme,
                'The "Last Updated" date will indicate when the Terms were most recently revised.',
              ),
              _paragraph(
                theme,
                'For significant changes, we may provide additional notice where required.',
              ),
              _divider(theme),
              _section(theme, '27. CONTACT'),
              _paragraph(
                theme,
                'Questions about these Terms may be directed to:',
              ),
              _paragraph(theme, 'TREXVEN Support\nEmail: support@trexven.com'),
              _paragraph(
                theme,
                'If this email address changes, the updated contact information may be made available through the TREXVEN application or official support channels.',
              ),
              SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: TrexvenFontSize.input,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _paragraph(ThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: TrexvenFontSize.body,
          color: theme.trexvenColors.muted,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _bulletPoint(ThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: TrexvenFontSize.body,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: theme.trexvenColors.muted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberedPoint(ThemeData theme, int number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: TextStyle(
              fontSize: TrexvenFontSize.body,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: theme.trexvenColors.muted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(color: theme.trexvenColors.border!),
    );
  }
}
