import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
class ProfileCompletionPage extends StatefulWidget {
  final String uid;
  final String email;

  const ProfileCompletionPage({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _authService = AuthService();
  final _storageService = StorageService();
  
  DateTime? _selectedDate;
  File? _avatarFile;
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _rollNoController.dispose();
    super.dispose();
  }

  bool _isValidImageHeader(List<int> bytes, String extension) {
    if (bytes.length < 8) return false;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        // Check for JPEG header (FF D8)
        return bytes[0] == 0xFF && bytes[1] == 0xD8;
      
      case 'png':
        // Check for PNG header (89 50 4E 47 0D 0A 1A 0A)
        return bytes[0] == 0x89 &&
               bytes[1] == 0x50 &&
               bytes[2] == 0x4E &&
               bytes[3] == 0x47 &&
               bytes[4] == 0x0D &&
               bytes[5] == 0x0A &&
               bytes[6] == 0x1A &&
               bytes[7] == 0x0A;
      
      default:
        return false;
    }
  }

  Future<void> _pickImage() async {
    try {
      debugPrint('Opening image picker...');
      final ImagePicker picker = ImagePicker();
      
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null) {
        debugPrint('Image selected: ${image.path}');
        
        // Verify file exists and extension
        final file = File(image.path);
        final String extension = image.path.split('.').last.toLowerCase();
        
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          throw Exception('Please select a JPG or PNG image');
        }
        
        if (!file.existsSync()) {
          throw Exception('Selected image file does not exist');
        }
        
        // Check file size (max 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('Image size must be less than 5MB');
        }
        
        // Validate image data
        final List<int> bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('Image file is empty');
        }
        
        // Check image headers
        if (!_isValidImageHeader(bytes, extension)) {
          throw Exception('Invalid image format. Please select a valid JPG or PNG image');
        }
        
        // Update the state with the new image
        setState(() {
          _avatarFile = file;
        });
        
        debugPrint('Image file validated and saved successfully');
      } else {
        debugPrint('No image selected');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      
      if (picked != null && picked != _selectedDate) {
        debugPrint('Date selected: ${picked.toString()}');
        setState(() {
          _selectedDate = picked;
        });
      }
    } catch (e) {
      debugPrint('Error selecting date: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('Form validation failed');
      return;
    }

    if (_selectedDate == null) {
      debugPrint('Date of birth not selected');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your date of birth'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      debugPrint('Starting profile completion process...');
      
      // Upload image if selected
      String? uploadedAvatarUrl;
      if (_avatarFile != null) {
        try {
          debugPrint('Starting profile image upload...');
          if (!_avatarFile!.existsSync()) {
            throw Exception('Selected image file no longer exists');
          }
          
          uploadedAvatarUrl = await _storageService.uploadProfileImage(
            widget.uid,
            _avatarFile!,
          );
          debugPrint('Profile image uploaded successfully: $uploadedAvatarUrl');
        } catch (e) {
          debugPrint('Error uploading profile image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading image: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Continue without the image if upload fails
        }
      }
      
      // Use the uploaded URL if successful, otherwise keep it null
      _avatarUrl = uploadedAvatarUrl;

      final user = UserModel(
        uid: widget.uid,
        email: widget.email,
        name: _nameController.text,
        avatarUrl: _avatarUrl,
        dateOfBirth: _selectedDate,
        mobileNumber: _mobileController.text,
        rollNo: _rollNoController.text,
        isProfileComplete: true,
      );
      
      debugPrint('Updating user profile...');
      await _authService.updateUserProfile(user);
      debugPrint('User profile updated successfully');
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to home page
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error during profile completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving your profile...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: _avatarFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.file(
                                      _avatarFile!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[200],
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          border: const OutlineInputBorder(),
                          errorText: _selectedDate == null ? 'Required' : null,
                        ),
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                              : 'Select Date',
                          style: TextStyle(
                            color: _selectedDate == null 
                                ? Theme.of(context).hintColor 
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(),
                        helperText: 'Enter 10-digit mobile number',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter your mobile number';
                        }
                        if (!RegExp(r'^\d{10}$').hasMatch(value!)) {
                          return 'Please enter a valid 10-digit mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rollNoController,
                      decoration: const InputDecoration(
                        labelText: 'Roll Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter your roll number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Complete Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}