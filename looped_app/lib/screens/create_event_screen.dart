import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/event_service.dart';

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
              primary: Colors.purpleAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
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
                primary: Colors.purpleAccent,
                onPrimary: Colors.white,
                surface: Color(0xFF1E1E1E),
                onSurface: Colors.white, // Text color
              ),
              timePickerTheme: const TimePickerThemeData(
                backgroundColor: Color(0xFF1E1E1E),
              )),
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
          const SnackBar(content: Text("Start Date & Time is required")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final startDateTime = _combine(_startDate!, _startTime!);
      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = _combine(_endDate!, _endTime!);
      }

      final eventData = {
        'name': _nameController.text.trim(),
        'starts_at': startDateTime.toIso8601String(),
        'ends_at': endDateTime?.toIso8601String(),
        'genre': _selectedGenre,
        'venue_name': _venueController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'visibility': _isPrivate ? 'private' : 'public',
        'is_paid_public': false, // Default
      };

      await Provider.of<EventService>(context, listen: false)
          .createEvent(eventData, imagePath: _selectedImage?.path);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Event Created Successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Create Event"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("BASIC INFO"),
                _buildTextField("Event Name", _nameController, required: true),
                const SizedBox(height: 16),

                // Icon Picker
                // Image Picker
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purpleAccent),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(File(_selectedImage!.path)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    color: Colors.grey, size: 32),
                                SizedBox(height: 8),
                                Text("Add Image",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("GENRE"),
                _buildDropdown("Genre", _genres, _selectedGenre, (val) {
                  if (val != null) setState(() => _selectedGenre = val);
                }),
                const SizedBox(height: 24),
                _buildSectionHeader("TIME"),
                Row(
                  children: [
                    Expanded(
                        child: _buildDatePickerButton(
                            "Starts At", _startDate, _startTime, true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildDatePickerButton(
                            "Ends At (Opt)", _endDate, _endTime, false)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("LOCATION"),
                _buildTextField("Venue Name (Optional)", _venueController),
                const SizedBox(height: 10),
                _buildTextField("Address", _addressController, required: true),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField("City", _cityController,
                            required: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField("Country", _countryController,
                            required: true)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("VISIBILITY"),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8)),
                  child: SwitchListTile(
                    title: const Text("Private Event",
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Requires invite code to join",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    value: _isPrivate,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => setState(() => _isPrivate = val),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createEvent,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        disabledBackgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : const Text("CREATE EVENT",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              color: Colors.purpleAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool required = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (val) => val == null || val.isEmpty ? "Required" : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value,
      Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: items
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(
      String label, DateTime? date, TimeOfDay? time, bool isStart) {
    final text = date == null
        ? "Select Date"
        : "${date.day}/${date.month} ${time?.format(context) ?? ''}";

    return GestureDetector(
      onTap: () => _pickDateTime(isStart: isStart),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    date != null ? Colors.purpleAccent : Colors.transparent)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 2),
            Text(text,
                style: TextStyle(
                    color: date != null ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
