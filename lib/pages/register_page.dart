import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import 'pending_verification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _semesterController = TextEditingController();
  final _branchController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _selectedBirthdate;
  String? _selectedGender;
  File? _avatarFile;
  File? _idCardFile;
  final _picker = ImagePicker();
  final _authService = AuthService();
  final _storageService = StorageService();
  bool _isLoading = false;

  Future<void> _pickImage(bool isAvatar) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        if (isAvatar) {
          _avatarFile = File(image.path);
        } else {
          _idCardFile = File(image.path);
        }
      });
    }
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_avatarFile == null || _idCardFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload avatar and ID card'),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a gender'),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedBirthdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a birthdate'),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final newDocId = FirebaseFirestore.instance.collection('users').doc().id;

      final avatarUrl =
          await _storageService.uploadProfileImage(newDocId, _avatarFile!);
      final idCardUrl =
          await _storageService.uploadIdCard(newDocId, _idCardFile!);

      final normalizedRoll = _rollNoController.text.trim().toLowerCase();
      final user = UserModel(
        uid: newDocId,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        avatarUrl: avatarUrl,
        idCardUrl: idCardUrl,
        rollNo: normalizedRoll,
        semester: _semesterController.text.trim(),
        branch: _branchController.text.trim(),
        birthdate: _selectedBirthdate,
        gender: _selectedGender,
        isVerified: false,
        password: _passwordController.text,
      );

      await _authService.registerUser(user);

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_roll', normalizedRoll);
      await prefs.setString('current_user_uid', user.uid);
      await prefs.setString('current_user_name', user.name ?? 'User');
      await prefs.setString('current_user_email', user.email);
      await prefs.setString('current_user_avatar', user.avatarUrl ?? '');
      await prefs.setBool('pending_verification', true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingVerificationPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthdate) {
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const yellowPrimary = Color(0xFFFFC107);
    const yellowAccent = Color(0xFFFFD54F);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF2D2D2D),
                  const Color(0xFF1A1A1A),
                ],
              ),
            ),
          ),
          // Glossy overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                    stops: const [0.1, 0.5, 0.9],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      ),
                      const Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                // Form Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: yellowPrimary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                // Avatar Section
                                Center(
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              yellowPrimary.withOpacity(0.3),
                                              yellowAccent.withOpacity(0.1),
                                            ],
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(3.0),
                                          child: CircleAvatar(
                                            radius: 48,
                                            backgroundColor: const Color(0xFF2D2D2D),
                                            backgroundImage: _avatarFile != null
                                                ? FileImage(_avatarFile!)
                                                : null,
                                            child: _avatarFile == null
                                                ? const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: yellowPrimary,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => _pickImage(true),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: yellowPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.black,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Full Name
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  icon: Icons.person_outline,
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),

                                // Row for Semester and Roll No
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        value: _semesterController.text.isNotEmpty
                                            ? _semesterController.text
                                            : null,
                                        label: 'Semester',
                                        icon: Icons.school_outlined,
                                        items: List.generate(8, (index) {
                                          final val = (index + 1).toString();
                                          return DropdownMenuItem(
                                            value: val,
                                            child: Text(val),
                                          );
                                        }),
                                        onChanged: (v) {
                                          setState(() {
                                            _semesterController.text = v ?? '';
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _rollNoController,
                                        label: 'Roll No',
                                        icon: Icons.badge_outlined,
                                        validator: (v) =>
                                            (v == null || v.isEmpty) ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Branch Dropdown
                                _buildDropdown(
                                  value: _branchController.text.isNotEmpty
                                      ? _branchController.text
                                      : null,
                                  label: 'Branch',
                                  icon: Icons.engineering_outlined,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Computer Science and Engineering',
                                      child: Text(
                                        'Computer Science and Engineering',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Mechanical Engineering',
                                      child: Text(
                                        'Mechanical Engineering',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Civil Engineering',
                                      child: Text(
                                        'Civil Engineering',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Electronics and Telecommunication Engineering',
                                      child: Text(
                                        'Electronics and Telecommunication Engineering',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      _branchController.text = v ?? '';
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Birthdate
                                _buildTextField(
                                  controller: TextEditingController(text: _selectedBirthdate != null ? '${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year}' : ''),
                                  label: 'Birthdate',
                                  icon: Icons.cake_outlined,
                                  readOnly: true,
                                  onTap: () => _selectBirthdate(context),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),

                                // Gender
                                _buildDropdown(
                                  value: _selectedGender,
                                  label: 'Gender',
                                  icon: Icons.wc_outlined,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Male',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Female',
                                      child: Text('Female'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Non-binary',
                                      child: Text('Non-binary'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Prefer not to say',
                                      child: Text('Prefer not to say'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Email
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: true,
                                  validator: (v) =>
                                      (v == null || v.length < 6) ? 'Min 6 chars' : null,
                                ),
                                const SizedBox(height: 20),

                                // ID Card Upload
                                GestureDetector(
                                  onTap: () => _pickImage(false),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D2D),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _idCardFile != null
                                            ? yellowPrimary
                                            : Colors.grey.shade700,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: yellowPrimary.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.upload_file,
                                            color: yellowPrimary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'ID Card Image',
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _idCardFile?.path.split('/').last ??
                                                    'No file selected',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          _idCardFile != null
                                              ? Icons.check_circle
                                              : Icons.arrow_forward_ios,
                                          color: _idCardFile != null
                                              ? yellowPrimary
                                              : Colors.grey.shade600,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Register Button
                                Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [yellowPrimary, yellowAccent],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: yellowPrimary.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Register',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Login Link
                                Center(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: RichText(
                                      text: const TextSpan(
                                        text: 'Already have an account? ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Login',
                                            style: TextStyle(
                                              color: yellowPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function()? onTap,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFFFFC107), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        readOnly: readOnly,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: const Color(0xFF2D2D2D),
        items: items,
        onChanged: onChanged,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        icon: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFFC107)),
        ),
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFFFFC107), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
