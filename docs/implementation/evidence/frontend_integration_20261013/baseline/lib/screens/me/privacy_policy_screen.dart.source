import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
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
                'TREXVEN PRIVACY POLICY',
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
              _paragraph(
                theme,
                'TREXVEN respects the privacy of individuals and businesses using our Services.',
              ),
              _paragraph(
                theme,
                'This Privacy Policy explains how TREXVEN may collect, use, store, process, protect, share, and otherwise handle personal information and business-related data when you use the TREXVEN application and related Services.',
              ),
              _paragraph(
                theme,
                'This Privacy Policy applies to TREXVEN services including, where available:',
              ),
              _bulletPoint(theme, 'The TREXVEN application'),
              _bulletPoint(theme, 'TREXVEN business management features'),
              _bulletPoint(theme, 'TREXVEN POS'),
              _bulletPoint(theme, 'Inventory management'),
              _bulletPoint(theme, 'Employee management'),
              _bulletPoint(theme, 'Notifications'),
              _bulletPoint(theme, 'TREXVEN Angel'),
              _bulletPoint(theme, 'AI features'),
              _bulletPoint(theme, 'Vision Server features'),
              _bulletPoint(theme, 'Camera integrations'),
              _bulletPoint(theme, 'Support services'),
              _bulletPoint(theme, 'Other related TREXVEN services'),
              _divider(theme),
              _section(theme, '1. INFORMATION WE MAY COLLECT'),
              _paragraph(
                theme,
                'The information collected depends on how you use TREXVEN.',
              ),
              _subSection(theme, '1.1 Account Information'),
              _paragraph(
                theme,
                'When you create or use an account, we may collect information such as:',
              ),
              _bulletPoint(theme, 'Name'),
              _bulletPoint(theme, 'Email address'),
              _bulletPoint(theme, 'Phone number where provided'),
              _bulletPoint(theme, 'User identification information'),
              _bulletPoint(theme, 'Authentication information'),
              _bulletPoint(theme, 'Account preferences'),
              _bulletPoint(theme, 'Account metadata'),
              _bulletPoint(theme, 'Profile information'),
              _paragraph(
                theme,
                'Passwords are handled through the applicable authentication system and should not be stored or exposed to TREXVEN users in readable form.',
              ),
              _subSection(theme, '1.2 Business Information'),
              _paragraph(
                theme,
                'Business administrators may provide information including:',
              ),
              _bulletPoint(theme, 'Business name'),
              _bulletPoint(theme, 'Business category'),
              _bulletPoint(theme, 'Business address'),
              _bulletPoint(theme, 'Phone number'),
              _bulletPoint(theme, 'Business email'),
              _bulletPoint(theme, 'Website'),
              _bulletPoint(theme, 'Country'),
              _bulletPoint(theme, 'Currency'),
              _bulletPoint(theme, 'Business settings'),
              _bulletPoint(theme, 'Operational preferences'),
              _subSection(theme, '1.3 Employee Information'),
              _paragraph(
                theme,
                'Businesses may enter or manage employee information.',
              ),
              _paragraph(
                theme,
                'Depending on the configuration, this may include:',
              ),
              _bulletPoint(theme, 'Employee name'),
              _bulletPoint(theme, 'Contact information where entered'),
              _bulletPoint(theme, 'Role'),
              _bulletPoint(theme, 'Permission level'),
              _bulletPoint(theme, 'Employment-related access information'),
              _bulletPoint(
                theme,
                'Account relationship to a business workspace',
              ),
              _paragraph(
                theme,
                'Businesses are responsible for ensuring they have a lawful basis for providing employee information to TREXVEN.',
              ),
              _subSection(theme, '1.4 Inventory and Product Data'),
              _paragraph(
                theme,
                'We may process information entered into TREXVEN relating to:',
              ),
              _bulletPoint(theme, 'Product names'),
              _bulletPoint(theme, 'Product categories'),
              _bulletPoint(theme, 'Barcodes'),
              _bulletPoint(theme, 'SKUs'),
              _bulletPoint(theme, 'Quantities'),
              _bulletPoint(theme, 'Stock levels'),
              _bulletPoint(theme, 'Prices'),
              _bulletPoint(theme, 'Product descriptions'),
              _bulletPoint(theme, 'Product images'),
              _bulletPoint(theme, 'Other product-related information'),
              _subSection(theme, '1.5 Sales and Operational Data'),
              _paragraph(
                theme,
                'TREXVEN may process business activity information such as:',
              ),
              _bulletPoint(theme, 'Sales records'),
              _bulletPoint(theme, 'Transaction information'),
              _bulletPoint(theme, 'Product movements'),
              _bulletPoint(theme, 'Inventory changes'),
              _bulletPoint(theme, 'System actions'),
              _bulletPoint(theme, 'Reports'),
              _bulletPoint(theme, 'Operational events'),
              _bulletPoint(theme, 'Authorized user activity'),
              _paragraph(
                theme,
                'The exact information collected depends on the features your Business uses.',
              ),
              _subSection(theme, '1.6 Camera and Vision Information'),
              _paragraph(
                theme,
                'If your Business connects cameras or TREXVEN Vision functionality, information processed may include:',
              ),
              _bulletPoint(theme, 'Camera identifiers'),
              _bulletPoint(theme, 'Camera names'),
              _bulletPoint(theme, 'Camera configuration details'),
              _bulletPoint(theme, 'Network connection information'),
              _bulletPoint(
                theme,
                'RTSP or stream configuration where necessary',
              ),
              _bulletPoint(theme, 'Device status'),
              _bulletPoint(theme, 'Detection events'),
              _bulletPoint(theme, 'Event timestamps'),
              _bulletPoint(
                theme,
                'Images or video frames where supported and configured',
              ),
              _bulletPoint(theme, 'AI-generated event information'),
              _bulletPoint(
                theme,
                'System logs related to Vision functionality',
              ),
              _paragraph(
                theme,
                'TREXVEN\'s processing of camera-related information depends on the architecture and configuration of the specific feature.',
              ),
              _paragraph(
                theme,
                'Some processing may occur on a local Vision Server or business-controlled environment, while other information may be synchronized with cloud services depending on how the Service is configured.',
              ),
              _paragraph(
                theme,
                'TREXVEN does not intentionally require more camera information than reasonably necessary to provide the requested feature.',
              ),
              _subSection(theme, '1.7 AI Interaction Information'),
              _paragraph(
                theme,
                'When you use TREXVEN Angel or other AI features, we may process:',
              ),
              _bulletPoint(theme, 'Questions submitted to the AI.'),
              _bulletPoint(theme, 'Instructions you provide.'),
              _bulletPoint(
                theme,
                'Relevant business context needed to respond.',
              ),
              _bulletPoint(theme, 'AI responses.'),
              _bulletPoint(
                theme,
                'Technical information needed to operate the AI feature.',
              ),
              _paragraph(
                theme,
                'Please avoid submitting unnecessary sensitive personal information to AI features.',
              ),
              _paragraph(
                theme,
                'AI interactions may be processed using technologies or service providers necessary to provide the feature.',
              ),
              _subSection(theme, '1.8 Device and Technical Information'),
              _paragraph(
                theme,
                'We may collect technical information including:',
              ),
              _bulletPoint(theme, 'Device type'),
              _bulletPoint(theme, 'Operating system'),
              _bulletPoint(theme, 'Application version'),
              _bulletPoint(theme, 'Build number'),
              _bulletPoint(theme, 'Language or locale settings'),
              _bulletPoint(theme, 'Crash information'),
              _bulletPoint(theme, 'Diagnostic information'),
              _bulletPoint(theme, 'Error logs'),
              _bulletPoint(theme, 'Connection information'),
              _bulletPoint(
                theme,
                'Device identifiers where necessary and permitted',
              ),
              _bulletPoint(theme, 'Security-related information'),
              _paragraph(
                theme,
                'This information helps us maintain, troubleshoot, secure, and improve TREXVEN.',
              ),
              _subSection(theme, '1.9 Usage Information'),
              _paragraph(
                theme,
                'We may collect information about how the Services are used, such as:',
              ),
              _bulletPoint(theme, 'Screens or features accessed'),
              _bulletPoint(theme, 'Feature interactions'),
              _bulletPoint(theme, 'Navigation activity'),
              _bulletPoint(theme, 'Settings changes'),
              _bulletPoint(theme, 'Login activity'),
              _bulletPoint(theme, 'Error events'),
              _bulletPoint(theme, 'Performance information'),
              _paragraph(
                theme,
                'We use this information to improve reliability, usability, security, and functionality.',
              ),
              _divider(theme),
              _section(theme, '2. HOW WE USE INFORMATION'),
              _paragraph(theme, 'TREXVEN may use information to:'),
              _bulletPoint(theme, 'Create and manage accounts.'),
              _bulletPoint(theme, 'Authenticate users.'),
              _bulletPoint(theme, 'Provide requested Services.'),
              _bulletPoint(theme, 'Maintain business workspaces.'),
              _bulletPoint(theme, 'Store and synchronize Business Data.'),
              _bulletPoint(theme, 'Process inventory and sales information.'),
              _bulletPoint(theme, 'Provide POS functionality.'),
              _bulletPoint(theme, 'Manage employees and permissions.'),
              _bulletPoint(theme, 'Deliver notifications.'),
              _bulletPoint(theme, 'Operate AI features.'),
              _bulletPoint(theme, 'Operate Vision and camera features.'),
              _bulletPoint(theme, 'Generate reports and insights.'),
              _bulletPoint(theme, 'Detect technical problems.'),
              _bulletPoint(theme, 'Protect against unauthorized access.'),
              _bulletPoint(theme, 'Improve performance.'),
              _bulletPoint(theme, 'Respond to support requests.'),
              _bulletPoint(theme, 'Develop and improve TREXVEN features.'),
              _bulletPoint(theme, 'Comply with legal obligations.'),
              _bulletPoint(theme, 'Enforce our Terms.'),
              _bulletPoint(
                theme,
                'Protect the security and integrity of the Services.',
              ),
              _paragraph(
                theme,
                'We process information only for purposes supported by an applicable legal basis where required by law.',
              ),
              _divider(theme),
              _section(theme, '3. HOW AI DATA MAY BE USED'),
              _paragraph(
                theme,
                'TREXVEN AI features may process relevant information to generate requested outputs.',
              ),
              _paragraph(
                theme,
                'For example, if you ask TREXVEN Angel about inventory trends, the system may use relevant inventory information available to your authorized account to answer the question.',
              ),
              _paragraph(
                theme,
                'AI features are designed to operate within the permissions and data access made available to the feature.',
              ),
              _paragraph(
                theme,
                'However, no automated system should be assumed to be perfectly accurate.',
              ),
              _paragraph(
                theme,
                'We may use technical and operational information to monitor and improve AI system performance, subject to applicable law and applicable agreements.',
              ),
              _paragraph(
                theme,
                'Where appropriate, we may use aggregated or de-identified information that does not reasonably identify you to analyze and improve our Services.',
              ),
              _divider(theme),
              _section(theme, '4. CAMERA AND VIDEO PRIVACY'),
              _paragraph(
                theme,
                'Camera and video data can contain personal information.',
              ),
              _paragraph(
                theme,
                'The Business operating a camera is generally responsible for determining:',
              ),
              _bulletPoint(theme, 'Whether monitoring is lawful.'),
              _bulletPoint(theme, 'What notices are required.'),
              _bulletPoint(theme, 'Whether consent is required.'),
              _bulletPoint(
                theme,
                'How long recordings or related data should be retained.',
              ),
              _bulletPoint(theme, 'Who should have access.'),
              _bulletPoint(theme, 'How surveillance information may be used.'),
              _paragraph(
                theme,
                'TREXVEN provides technology to support configured camera and Vision functionality.',
              ),
              _paragraph(
                theme,
                'The Business remains responsible for the legality of its camera deployment.',
              ),
              _paragraph(
                theme,
                'TREXVEN does not encourage the use of its Services for unlawful surveillance.',
              ),
              _paragraph(
                theme,
                'Users must not use the Services to secretly or unlawfully monitor individuals.',
              ),
              _divider(theme),
              _section(theme, '5. HOW WE SHARE INFORMATION'),
              _paragraph(
                theme,
                'We do not sell personal information to advertisers.',
              ),
              _paragraph(
                theme,
                'We may share information where necessary with:',
              ),
              _subSection(theme, 'Service Providers'),
              _paragraph(
                theme,
                'We may use service providers to help operate TREXVEN. These may include providers of:',
              ),
              _bulletPoint(theme, 'Cloud infrastructure'),
              _bulletPoint(theme, 'Database services'),
              _bulletPoint(theme, 'Authentication'),
              _bulletPoint(theme, 'Data storage'),
              _bulletPoint(theme, 'Error monitoring'),
              _bulletPoint(theme, 'AI processing'),
              _bulletPoint(theme, 'Email or notification delivery'),
              _bulletPoint(theme, 'SMS delivery where available'),
              _bulletPoint(theme, 'Customer support'),
              _bulletPoint(theme, 'Other necessary technical services'),
              _paragraph(
                theme,
                'Service providers may process information on our behalf subject to applicable contractual, technical, and legal safeguards.',
              ),
              _subSection(theme, 'Your Authorized Business Users'),
              _paragraph(
                theme,
                'Information may be visible to other authorized users within your Business according to the permissions and access levels configured by the Business.',
              ),
              _paragraph(
                theme,
                'For example, a Business Owner may have access to information that a Sales Employee does not.',
              ),
              _subSection(theme, 'Legal Requirements'),
              _paragraph(
                theme,
                'We may disclose information when we reasonably believe disclosure is necessary to:',
              ),
              _bulletPoint(theme, 'Comply with applicable law.'),
              _bulletPoint(theme, 'Respond to valid legal requests.'),
              _bulletPoint(theme, 'Protect the rights or safety of TREXVEN.'),
              _bulletPoint(theme, 'Protect users.'),
              _bulletPoint(theme, 'Investigate security incidents or fraud.'),
              _subSection(theme, 'Business Transactions'),
              _paragraph(
                theme,
                'If TREXVEN is involved in a merger, acquisition, financing, reorganization, or sale of assets, information may be transferred as part of that transaction, subject to applicable law.',
              ),
              _divider(theme),
              _section(theme, '6. DATA STORAGE AND SECURITY'),
              _paragraph(
                theme,
                'TREXVEN uses reasonable technical and organizational measures designed to protect information.',
              ),
              _paragraph(
                theme,
                'Depending on the architecture, security measures may include:',
              ),
              _bulletPoint(theme, 'Authentication controls'),
              _bulletPoint(theme, 'Role-based access controls'),
              _bulletPoint(theme, 'Secure connections'),
              _bulletPoint(theme, 'Access restrictions'),
              _bulletPoint(theme, 'Logging and monitoring'),
              _bulletPoint(theme, 'Database security features'),
              _bulletPoint(theme, 'Security updates'),
              _bulletPoint(theme, 'Controlled access to infrastructure'),
              _paragraph(
                theme,
                'No method of electronic transmission or storage is completely secure.',
              ),
              _paragraph(
                theme,
                'Therefore, we cannot guarantee absolute security.',
              ),
              _paragraph(
                theme,
                'You also play an important role in security. You should:',
              ),
              _bulletPoint(theme, 'Use a strong password.'),
              _bulletPoint(theme, 'Keep credentials private.'),
              _bulletPoint(theme, 'Avoid sharing accounts unnecessarily.'),
              _bulletPoint(theme, 'Remove access for former employees.'),
              _bulletPoint(theme, 'Review permissions.'),
              _bulletPoint(theme, 'Secure devices.'),
              _bulletPoint(theme, 'Secure connected cameras and networks.'),
              _bulletPoint(
                theme,
                'Protect RTSP credentials and other camera credentials.',
              ),
              _bulletPoint(
                theme,
                'Promptly report suspected unauthorized access.',
              ),
              _divider(theme),
              _section(theme, '7. DATA RETENTION'),
              _paragraph(
                theme,
                'We retain information for as long as reasonably necessary to:',
              ),
              _bulletPoint(theme, 'Provide the Services.'),
              _bulletPoint(theme, 'Maintain your account.'),
              _bulletPoint(theme, 'Support your Business workspace.'),
              _bulletPoint(theme, 'Comply with legal obligations.'),
              _bulletPoint(theme, 'Resolve disputes.'),
              _bulletPoint(theme, 'Enforce agreements.'),
              _bulletPoint(theme, 'Maintain security.'),
              _bulletPoint(theme, 'Maintain legitimate business records.'),
              _paragraph(
                theme,
                'Retention periods may differ depending on the type of information.',
              ),
              _paragraph(
                theme,
                'For example, some data may remain available while an account or Business workspace remains active, while backup copies or legally required records may remain for longer periods.',
              ),
              _paragraph(
                theme,
                'When information is no longer required, we may delete, anonymize, aggregate, or otherwise securely dispose of it in accordance with applicable law and technical limitations.',
              ),
              _divider(theme),
              _section(theme, '8. BACKUPS'),
              _paragraph(
                theme,
                'TREXVEN may create backups or redundancy copies to support reliability and disaster recovery.',
              ),
              _paragraph(
                theme,
                'Deleted information may not be immediately removed from all backup systems.',
              ),
              _paragraph(
                theme,
                'Backup copies may be retained for a limited period before being overwritten or deleted according to operational and security procedures.',
              ),
              _paragraph(
                theme,
                'Businesses should not rely exclusively on TREXVEN as their only backup system unless a specific service agreement expressly provides otherwise.',
              ),
              _paragraph(
                theme,
                'Businesses should maintain additional records or backups where appropriate for their operational or legal requirements.',
              ),
              _divider(theme),
              _section(theme, '9. YOUR RIGHTS AND CHOICES'),
              _paragraph(
                theme,
                'Depending on where you live and applicable law, you may have rights regarding your personal information.',
              ),
              _paragraph(theme, 'These rights may include the ability to:'),
              _bulletPoint(theme, 'Access personal information.'),
              _bulletPoint(theme, 'Correct inaccurate information.'),
              _bulletPoint(theme, 'Request deletion.'),
              _bulletPoint(theme, 'Restrict certain processing.'),
              _bulletPoint(theme, 'Object to certain processing.'),
              _bulletPoint(theme, 'Request portability where applicable.'),
              _bulletPoint(
                theme,
                'Withdraw consent where processing depends on consent.',
              ),
              _paragraph(
                theme,
                'Some requests may be subject to legal limitations.',
              ),
              _paragraph(
                theme,
                'For Business Data controlled by an organization, individual employees may need to submit certain requests through the Business that controls the information.',
              ),
              _paragraph(
                theme,
                'TREXVEN may need to verify identity and authority before processing certain requests.',
              ),
              _divider(theme),
              _section(theme, '10. ACCOUNT AND DATA DELETION'),
              _paragraph(
                theme,
                'You may be able to update certain information through the TREXVEN application.',
              ),
              _paragraph(
                theme,
                'Requests concerning account or personal data deletion may be submitted through applicable account settings or TREXVEN support.',
              ),
              _paragraph(theme, 'Deleting an account may affect access to:'),
              _bulletPoint(theme, 'Business information'),
              _bulletPoint(theme, 'Inventory'),
              _bulletPoint(theme, 'Sales history'),
              _bulletPoint(theme, 'Employee information'),
              _bulletPoint(theme, 'Reports'),
              _bulletPoint(theme, 'Settings'),
              _bulletPoint(theme, 'Other connected data'),
              _paragraph(
                theme,
                'If you are not the owner or authorized administrator of a Business workspace, deleting your individual account may not automatically delete Business Data controlled by the Business.',
              ),
              _paragraph(
                theme,
                'Some information may be retained where legally required or reasonably necessary for security, fraud prevention, dispute resolution, or other legitimate purposes.',
              ),
              _divider(theme),
              _section(theme, '11. INTERNATIONAL DATA TRANSFERS'),
              _paragraph(
                theme,
                'TREXVEN and its service providers may process information in countries other than the country where you live or operate.',
              ),
              _paragraph(
                theme,
                'Data protection laws may differ between countries.',
              ),
              _paragraph(
                theme,
                'Where required, TREXVEN will use appropriate safeguards for international data transfers.',
              ),
              _divider(theme),
              _section(theme, '12. CHILDREN\'S PRIVACY'),
              _paragraph(theme, 'TREXVEN is designed for business use.'),
              _paragraph(
                theme,
                'TREXVEN is not intended for children where use would require parental consent under applicable law.',
              ),
              _paragraph(
                theme,
                'We do not knowingly collect personal information from children in violation of applicable law.',
              ),
              _paragraph(
                theme,
                'If you believe information relating to a child has been improperly provided to TREXVEN, contact us so we can review the situation.',
              ),
              _divider(theme),
              _section(theme, '13. THIRD-PARTY LINKS AND SERVICES'),
              _paragraph(
                theme,
                'TREXVEN may contain links to third-party websites or services.',
              ),
              _paragraph(
                theme,
                'Those services operate independently and have their own privacy practices.',
              ),
              _paragraph(
                theme,
                'We encourage you to review the privacy policies of third-party services before providing information to them.',
              ),
              _paragraph(
                theme,
                'TREXVEN is not responsible for third-party privacy practices except as required by applicable law.',
              ),
              _divider(theme),
              _section(theme, '14. COOKIES AND SIMILAR TECHNOLOGIES'),
              _paragraph(
                theme,
                'Where TREXVEN provides web-based services, we or authorized service providers may use cookies, local storage, or similar technologies for purposes such as:',
              ),
              _bulletPoint(theme, 'Authentication'),
              _bulletPoint(theme, 'Session management'),
              _bulletPoint(theme, 'Security'),
              _bulletPoint(theme, 'Preferences'),
              _bulletPoint(theme, 'Performance'),
              _bulletPoint(theme, 'Analytics'),
              _paragraph(
                theme,
                'The exact technologies used may depend on the TREXVEN platform and version.',
              ),
              _paragraph(
                theme,
                'Where required by law, we will obtain consent before using non-essential cookies or similar technologies.',
              ),
              _divider(theme),
              _section(theme, '15. DO NOT SELL PERSONAL INFORMATION'),
              _paragraph(
                theme,
                'TREXVEN does not sell personal information to advertisers in exchange for money.',
              ),
              _paragraph(
                theme,
                'We do not allow advertisers to purchase access to your private TREXVEN business data.',
              ),
              _paragraph(
                theme,
                'If applicable law gives you specific rights concerning the sale or sharing of personal information, you may contact us regarding those rights.',
              ),
              _divider(theme),
              _section(theme, '16. BUSINESS DATA CONTROLLERS AND PROCESSORS'),
              _paragraph(
                theme,
                'When TREXVEN processes information on behalf of a Business, the Business may be responsible for determining the purposes and methods of processing certain information.',
              ),
              _paragraph(theme, 'For example, a Business may determine:'),
              _bulletPoint(theme, 'Which employee information to enter.'),
              _bulletPoint(theme, 'Which cameras to connect.'),
              _bulletPoint(theme, 'Which individuals receive access.'),
              _bulletPoint(theme, 'How camera monitoring is deployed.'),
              _bulletPoint(theme, 'What business information is stored.'),
              _paragraph(
                theme,
                'In such situations, the Business may have its own legal obligations to affected individuals.',
              ),
              _paragraph(
                theme,
                'TREXVEN may act as a technology provider processing information as necessary to provide the Services, depending on the applicable relationship and law.',
              ),
              _divider(theme),
              _section(theme, '17. SECURITY INCIDENTS'),
              _paragraph(
                theme,
                'If TREXVEN becomes aware of a security incident involving personal information, we will investigate and respond in accordance with applicable law.',
              ),
              _paragraph(
                theme,
                'Where legally required, affected users, Businesses, or regulators may be notified.',
              ),
              _paragraph(
                theme,
                'The timing and nature of notifications may depend on the circumstances of the incident and applicable legal requirements.',
              ),
              _divider(theme),
              _section(theme, '18. CHANGES TO THIS PRIVACY POLICY'),
              _paragraph(
                theme,
                'We may update this Privacy Policy from time to time.',
              ),
              _paragraph(theme, 'Changes may occur because of:'),
              _bulletPoint(theme, 'New TREXVEN features.'),
              _bulletPoint(theme, 'AI functionality changes.'),
              _bulletPoint(theme, 'Camera or Vision functionality changes.'),
              _bulletPoint(theme, 'Legal developments.'),
              _bulletPoint(theme, 'Security developments.'),
              _bulletPoint(theme, 'Changes to data processing practices.'),
              _paragraph(
                theme,
                'The "Last Updated" date will be revised when this Policy changes.',
              ),
              _paragraph(
                theme,
                'For significant changes, we may provide additional notice where required by applicable law.',
              ),
              _divider(theme),
              _section(theme, '19. CONTACT US'),
              _paragraph(
                theme,
                'For questions about privacy, data, or this Privacy Policy, contact:',
              ),
              _paragraph(
                theme,
                'TREXVEN Privacy Team\nEmail: support@trexven.com',
              ),
              _divider(theme),
              _section(theme, '20. FINAL IMPORTANT NOTICE'),
              _paragraph(
                theme,
                'TREXVEN is intended to give businesses powerful tools to manage operations, inventory, sales, employees, and, where enabled, AI and Vision intelligence.',
              ),
              _paragraph(theme, 'However:'),
              _bulletPoint(theme, 'AI is not perfect.'),
              _bulletPoint(theme, 'Camera detection is not perfect.'),
              _bulletPoint(theme, 'Barcode detection is not perfect.'),
              _bulletPoint(theme, 'Network connections can fail.'),
              _bulletPoint(theme, 'Devices can fail.'),
              _bulletPoint(theme, 'Human review remains important.'),
              _bulletPoint(
                theme,
                'Businesses remain responsible for how they use information and make decisions.',
              ),
              _paragraph(
                theme,
                'TREXVEN should be used as a business technology platform and decision-support system, not as a replacement for appropriate human judgment, independent verification, professional advice, legally required security measures, or compliance procedures.',
              ),
              _paragraph(
                theme,
                'Businesses using TREXVEN Vision, cameras, employee monitoring, or AI features should pay particular attention to applicable privacy, workplace, surveillance, employment, and data protection laws before deploying those features.',
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

  Widget _subSection(ThemeData theme, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: TrexvenFontSize.input,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
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

  Widget _divider(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(color: theme.trexvenColors.border!),
    );
  }
}
