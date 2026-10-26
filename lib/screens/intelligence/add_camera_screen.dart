import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import '../../services/vision_service.dart';

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _rtspCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _aiEnabled = true;
  bool _testingConnection = false;
  bool _saving = false;
  String? _testResult;
  bool? _testSuccess;

  final _visionService = VisionService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _rtspCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _buildRtspUrl() => VisionService.cameraSource(
    _rtspCtrl.text,
    username: _usernameCtrl.text.trim(),
    password: _passwordCtrl.text,
  );
  Future<void> _testConnection() async {
    String url;
    try {
      url = _buildRtspUrl();
    } on FormatException catch (error) {
      setState(() {
        _testResult = CustomerPresentation.error(
          error,
          fallback:
              'We could not connect to this camera. Check its address and try again.',
        );
        _testSuccess = false;
      });
      return;
    }
    if (url.isEmpty) {
      setState(() {
        _testResult = 'Please enter an RTSP URL first.';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _testResult = null;
      _testSuccess = null;
    });

    final result = await _visionService.testConnection(url);
    if (!mounted) return;

    setState(() {
      _testingConnection = false;
      _testSuccess = result['success'] == true;
      _testResult = result['message']?.toString() ?? 'Unknown result';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await _visionService.addCamera(
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        source: _buildRtspUrl(),
        enabled: _aiEnabled,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CustomerPresentation.error(error))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera could not be registered. Check Vision Server pairing, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Add Camera',
          style: TextStyle(
            fontSize: TrexvenFontSize.section,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _section(theme, 'Camera Info'),
            _field(
              theme,
              controller: _nameCtrl,
              label: 'Camera Name',
              hint: 'Front Store Camera',
              icon: Icons.videocam_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            _field(
              theme,
              controller: _locationCtrl,
              label: 'Location',
              hint: 'Main entrance, stockroom…',
              icon: Icons.location_on_outlined,
            ),
            SizedBox(height: TrexvenSpacing.sectionGap),
            _section(theme, 'Stream Configuration'),
            _field(
              theme,
              controller: _rtspCtrl,
              label: 'Camera stream URL or webcam index',
              hint: 'rtsp://192.168.1.100:554/stream1',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Camera source required'
                  : null,
            ),
            _field(
              theme,
              controller: _usernameCtrl,
              label: 'Camera Username (optional)',
              hint: 'admin',
              icon: Icons.person_outline_rounded,
            ),
            _field(
              theme,
              controller: _passwordCtrl,
              label: 'Camera Password (optional)',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            // Test Connection button
            OutlinedButton.icon(
              onPressed: _testingConnection || _saving ? null : _testConnection,
              icon: _testingConnection
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: Icon(Icons.more_horiz_rounded, size: 16),
                    )
                  : Icon(Icons.wifi_tethering_rounded),
              label: Text(_testingConnection ? 'Testing…' : 'Test Connection'),
              style: OutlinedButton.styleFrom(foregroundColor: brandBlue),
            ),
            if (_testResult != null) ...[
              SizedBox(height: 10),
              _testBanner(theme),
            ],
            SizedBox(height: TrexvenSpacing.sectionGap),
            _section(theme, 'AI Settings'),
            Container(
              decoration: BoxDecoration(
                color: theme.trexvenColors.cardBackground,
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  title: Text(
                    'Enable AI Detection',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Register on your paired Vision Server and start local processing. Use 0 for the server webcam.',
                    style: TextStyle(
                      fontSize: TrexvenFontSize.caption,
                      color: theme.trexvenColors.muted,
                    ),
                  ),
                  value: _aiEnabled,
                  activeThumbColor: brandBlue,
                  onChanged: (v) => setState(() => _aiEnabled = v),
                ),
              ),
            ),
            SizedBox(height: TrexvenSpacing.sectionGap),
            ElevatedButton(
              onPressed: _saving || _testingConnection ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandBlue,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: Icon(Icons.more_horiz_rounded, size: 16),
                    )
                  : Text(
                      'Save Camera',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: TrexvenFontSize.input,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: TrexvenFontSize.body,
          fontWeight: FontWeight.w700,
          color: theme.trexvenColors.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _field(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final muted = theme.trexvenColors.muted!;

    return TrexvenTextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: TrexvenInputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: muted, size: 20),
      ),
    );
  }

  Widget _testBanner(ThemeData theme) {
    final success = _testSuccess ?? false;
    final successColor = theme.trexvenColors.success!;
    final errorColor = theme.trexvenColors.error!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: success
            ? successColor.withValues(alpha: 0.1)
            : errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: success ? successColor : errorColor,
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _testResult!,
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: success ? successColor : errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
