import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
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
        _testResult = error.message;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
            fontSize: 20,
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
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
            const SizedBox(height: 14),
            _field(
              theme,
              controller: _locationCtrl,
              label: 'Location',
              hint: 'Main entrance, stockroom…',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 14),
            _field(
              theme,
              controller: _usernameCtrl,
              label: 'Camera Username (optional)',
              hint: 'admin',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            _field(
              theme,
              controller: _passwordCtrl,
              label: 'Camera Password (optional)',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            // Test Connection button
            OutlinedButton.icon(
              onPressed: _testingConnection || _saving ? null : _testConnection,
              icon: _testingConnection
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(_testingConnection ? 'Testing…' : 'Test Connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandBlue,
                side: BorderSide(color: brandBlue),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 10),
              _testBanner(theme),
            ],
            const SizedBox(height: 24),
            _section(theme, 'AI Settings'),
            Container(
              decoration: BoxDecoration(
                color: theme.trexvenColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
                ),
              ),
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
                    fontSize: 12,
                    color: theme.trexvenColors.muted,
                  ),
                ),
                value: _aiEnabled,
                activeThumbColor: brandBlue,
                onChanged: (v) => setState(() => _aiEnabled = v),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving || _testingConnection ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Camera',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
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
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: muted),
        hintText: hint,
        hintStyle: TextStyle(color: muted.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: muted, size: 20),
        filled: true,
        fillColor: theme.trexvenColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandBlue, width: 2),
        ),
      ),
    );
  }

  Widget _testBanner(ThemeData theme) {
    final success = _testSuccess ?? false;
    final successColor = theme.trexvenColors.success ?? Colors.green;
    final errorColor = theme.trexvenColors.error ?? Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: success
            ? successColor.withOpacity(0.1)
            : errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: success ? successColor : errorColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testResult!,
              style: TextStyle(
                fontSize: 13,
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
