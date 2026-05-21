import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/dance_session_manager.dart';
import '../ui/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Permission states
  PermissionStatus _activityStatus = PermissionStatus.denied;
  PermissionStatus _sensorsStatus = PermissionStatus.denied;
  bool _isUploadingAvatar = false;
  Map<String, dynamic>? _profileData;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadUserProfile();
  }

  Future<void> _checkPermissions() async {
    final activity = await Permission.activityRecognition.status;
    final sensors = await Permission.sensors.status;
    if (mounted) {
      setState(() {
        _activityStatus = activity;
        _sensorsStatus = sensors;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final profile = await auth.fetchProfile();
      if (mounted) {
        setState(() {
          _profileData = profile;
          _loadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    setState(() => _activityStatus = status);
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _requestSensorsPermission() async {
    final status = await Permission.sensors.request();
    setState(() => _sensorsStatus = status);
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _changeUsername() async {
    if (_profileData == null) return;
    final usernameController = TextEditingController(text: _profileData!['username']);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Editar Nombre de Usuario', style: AppTheme.titleMedium),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  hintText: 'Nuevo nombre...',
                  hintStyle: AppTheme.bodyMedium,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'El nombre no puede estar vacío';
                  if (val.trim().length < 3) return 'Debe tener al menos 3 caracteres';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newName = usernameController.text.trim();
              Navigator.pop(ctx);

              setState(() => _loadingProfile = true);
              try {
                final auth = Provider.of<AuthService>(context, listen: false);
                await auth.updateProfile(newName);
                await _loadUserProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Nombre de usuario actualizado con éxito!')),
                  );
                }
              } catch (e) {
                setState(() => _loadingProfile = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await image.readAsBytes();
      final newUrl = await auth.uploadAvatar(bytes, image.name);
      
      setState(() {
        if (_profileData != null) {
          _profileData!['avatar_url'] = newUrl;
        }
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto de perfil actualizada!')),
        );
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e')),
        );
      }
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('¿Eliminar tu Cuenta?', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acción es irreversible y permanente.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Se eliminarán de forma definitiva tu perfil, nivel, rango, puntos acumulados y todo tu historial de baile.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              Navigator.pop(ctx);
              setState(() => _loadingProfile = true);
              try {
                await auth.deleteAccount();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuenta eliminada permanentemente. ¡Esperamos verte pronto!')),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                setState(() => _loadingProfile = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar cuenta: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('ELIMINAR MI CUENTA'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionManager = Provider.of<DanceSessionManager>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // 1. DIANÓSTICO DE PERMISOS
              // -------------------------------------------------------------
              _buildSectionTitle('Estado de Permisos (Diagnóstico)'),
              const SizedBox(height: 12),
              _buildPermissionCard(
                title: 'Detección de Actividad Física',
                description: 'Requerido para contar tus pasos físicos con el podómetro integrado.',
                status: _activityStatus,
                onTap: _requestActivityPermission,
              ),
              const SizedBox(height: 12),
              _buildPermissionCard(
                title: 'Sensores del Dispositivo (Acelerómetro)',
                description: 'Requerido para detectar el ritmo e intensidad del baile en tiempo real.',
                status: _sensorsStatus,
                onTap: _requestSensorsPermission,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _checkPermissions,
                  icon: const Icon(Icons.refresh, color: AppTheme.accent, size: 18),
                  label: const Text('Re-verificar Estado', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),

              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 2. RECORDATORIOS DE BIENESTAR
              // -------------------------------------------------------------
              _buildSectionTitle('Wellness & Bienestar'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Recordatorios de Hidratación',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Recibe avisos para tomar agua cada 30 minutos mientras bailas en tus sesiones.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  activeColor: AppTheme.accent,
                  activeTrackColor: AppTheme.accent.withOpacity(0.3),
                  value: sessionManager.hydrationRemindersEnabled,
                  onChanged: (val) {
                    sessionManager.setHydrationRemindersEnabled(val);
                  },
                ),
              ),

              const SizedBox(height: 32),

              // -------------------------------------------------------------
              // 3. EDITAR PERFIL & ELIMINAR CUENTA
              // -------------------------------------------------------------
              _buildSectionTitle('Gestión de Perfil y Cuenta'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    // Edit Username
                    ListTile(
                      onTap: _changeUsername,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_note, color: AppTheme.accent),
                      ),
                      title: const Text('Editar Nombre de Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: _loadingProfile 
                          ? const Text('Cargando...', style: TextStyle(color: Colors.grey, fontSize: 11))
                          : Text(_profileData != null ? '@${_profileData!['username']}' : 'Configurar apodo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                    const Divider(color: Color(0xFF1E1E1E), height: 1, indent: 56),
                    
                    // Edit Profile Pic
                    ListTile(
                      onTap: _pickAndUploadAvatar,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingAvatar 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
                            : const Icon(Icons.photo_camera_outlined, color: AppTheme.accent),
                      ),
                      title: const Text('Cambiar Foto de Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Seleccionar una nueva imagen de tu galería.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                    const Divider(color: Color(0xFF1E1E1E), height: 1, indent: 56),

                    // Delete Account
                    ListTile(
                      onTap: _confirmDeleteAccount,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                      ),
                      title: const Text('Eliminar Cuenta', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Borrar permanentemente todos tus datos.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required PermissionStatus status,
    required VoidCallback onTap,
  }) {
    final isGranted = status.isGranted;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    IconData statusIcon;

    if (isGranted) {
      badgeBg = AppTheme.success.withOpacity(0.15);
      badgeText = AppTheme.success;
      badgeLabel = 'AUTORIZADO';
      statusIcon = Icons.check_circle_outline;
    } else {
      badgeBg = Colors.redAccent.withOpacity(0.15);
      badgeText = Colors.redAccent;
      badgeLabel = 'SIN ACCESO';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: badgeText, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(color: badgeText, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Conceder Permiso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
