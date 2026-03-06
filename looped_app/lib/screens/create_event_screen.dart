import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/event_service.dart';
import '../ui/app_theme.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  // State
  String _selectedGenre = 'techno';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isPrivate = false;
  bool _isLoading = false;
  XFile? _selectedImage;

  final List<String> _genres = [
    'techno',
    'house',
    'reggaeton',
    'trance',
    'pop',
    'hiphop',
    'other'
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate =
        isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: AppTheme.background,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
            dialogTheme:
                const DialogThemeData(backgroundColor: AppTheme.surface),
          ),
          child: child!,
        );
      },
    );

    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: AppTheme.background,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
            dialogTheme:
                const DialogThemeData(backgroundColor: AppTheme.surface),
          ),
          child: child!,
        );
      },
    );

    if (time == null) return;

    setState(() {
      if (isStart) {
        _startDate = date;
        _startTime = time;
      } else {
        _endDate = date;
        _endTime = time;
      }
    });
  }

  DateTime _combine(DateTime d, TimeOfDay t) {
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventService = Provider.of<EventService>(context, listen: false);

      final startsAt = _combine(_startDate!, _startTime!);
      final endsAt = _endDate != null && _endTime != null
          ? _combine(_endDate!, _endTime!)
          : null;

      Uint8List? imageBytes;
      String? fileName;
      if (_selectedImage != null) {
        imageBytes = await _selectedImage!.readAsBytes();
        fileName = _selectedImage!.name;
      }

      await eventService.createEvent(
        {
          'name': _nameController.text,
          'genre': _selectedGenre,
          'starts_at': startsAt.toIso8601String(),
          if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
          'venue_name': _venueController.text,
          if (_addressController.text.isNotEmpty)
            'address': _addressController.text,
          if (_cityController.text.isNotEmpty) 'city': _cityController.text,
          if (_countryController.text.isNotEmpty)
            'country': _countryController.text,
          'is_private': _isPrivate,
        },
        imageBytes: imageBytes,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Create Event', style: AppTheme.titleMedium),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              _buildImagePicker(),
              const SizedBox(height: AppTheme.spacingLg),

              // Basic Info Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BASIC INFO', style: AppTheme.labelMedium),
                    const SizedBox(height: AppTheme.spacingMd),
                    _buildTextField('Event Name *', _nameController,
                        required: true),
                    const SizedBox(height: AppTheme.spacingMd),
                    _buildDropdown('Genre', _genres, _selectedGenre,
                        (v) => setState(() => _selectedGenre = v!)),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Date/Time Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DATE & TIME', style: AppTheme.labelMedium),
                    const SizedBox(height: AppTheme.spacingMd),
                    _buildDatePickerButton(
                        'Start *', _startDate, _startTime, true),
                    const SizedBox(height: AppTheme.spacingSm),
                    _buildDatePickerButton(
                        'End (Optional)', _endDate, _endTime, false),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Location Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LOCATION', style: AppTheme.labelMedium),
                    const SizedBox(height: AppTheme.spacingMd),
                    _buildTextField('Venue Name *', _venueController,
                        required: true),
                    const SizedBox(height: AppTheme.spacingMd),
                    _buildTextField('Address', _addressController),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField('City', _cityController)),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                            child:
                                _buildTextField('Country', _countryController)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Settings Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: AppTheme.spacingMd),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Private Event', style: AppTheme.bodyLarge),
                          Text('Only invited guests can join',
                              style: AppTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                      activeThumbColor: AppTheme.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.accent))
                    : ElevatedButton(
                        onPressed: _createEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXl),
                          ),
                        ),
                        child: Text(
                          'CREATE EVENT',
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.background,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: AppTheme.surfaceBorder, style: BorderStyle.solid),
          image: _selectedImage != null
              ? DecorationImage(
                  image: FileImage(File(_selectedImage!.path)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _selectedImage == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: AppTheme.textSecondary),
                    SizedBox(height: AppTheme.spacingSm),
                    Text('Add Event Image', style: AppTheme.bodyMedium),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool required = false}) {
    return TextFormField(
      controller: controller,
      style: AppTheme.bodyLarge,
      validator:
          required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.bodyMedium,
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppTheme.surface,
      style: AppTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.bodyMedium,
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
      items: items
          .map((g) => DropdownMenuItem(
                value: g,
                child: Text(g[0].toUpperCase() + g.substring(1)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePickerButton(
      String label, DateTime? date, TimeOfDay? time, bool isStart) {
    final hasValue = date != null && time != null;
    final displayText = hasValue
        ? '${date.day}/${date.month}/${date.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : 'Select $label';

    return GestureDetector(
      onTap: () => _pickDateTime(isStart: isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: hasValue
              ? Border.all(color: AppTheme.accent.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: hasValue ? AppTheme.accent : AppTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Text(
                displayText,
                style: AppTheme.bodyLarge.copyWith(
                  color:
                      hasValue ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
            if (hasValue)
              const Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
