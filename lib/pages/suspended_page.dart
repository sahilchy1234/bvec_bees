import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../utils/suspension_utils.dart';

class SuspendedPage extends StatefulWidget {
  final String? note;
  final DateTime? until;

  const SuspendedPage({super.key, this.note, this.until});

  @override
  State<SuspendedPage> createState() => _SuspendedPageState();
}

class _SuspendedPageState extends State<SuspendedPage> {
  Timer? _timer;
  Duration? _remaining;
  String? _note;
  DateTime? _until;
  bool _isChecking = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _until = widget.until;
    _hydrateFromPrefsIfNeeded();
    _startRemainingTimer();
  }

  void _startRemainingTimer() {
    _recomputeRemaining();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _recomputeRemaining();
    });
  }

  Future<void> _hydrateFromPrefsIfNeeded() async {
    if (_note != null && _until != null) {
      _recomputeRemaining();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _note ??= prefs.getString(SuspensionUtils.prefSuspensionNoteKey);
    final storedUntilRaw = prefs.getString(SuspensionUtils.prefSuspensionUntilKey);
    _until ??= SuspensionUtils.parseStoredUntil(storedUntilRaw);
    if (mounted) {
      setState(() {
        _statusMessage = null;
      });
      _recomputeRemaining();
    }
  }

  void _recomputeRemaining() {
    if (!mounted) return;
    setState(() {
      if (_until == null) {
        _remaining = null;
      } else {
        _remaining = _until!.difference(DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    final remaining = _remaining;
    if (remaining == null) {
      return 'Duration unavailable';
    }
    if (remaining.isNegative) {
      return 'Awaiting review';
    }
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days > 0) {
      return '$days day${days == 1 ? '' : 's'} ${hours}h';
    }
    if (hours > 0) {
      return '$hours h ${minutes}m';
    }
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_user_uid');
      if (uid == null || uid.isEmpty) {
        throw Exception('No cached user found. Please log in again.');
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) {
        throw Exception('User record missing.');
      }
      final data = doc.data()!..['uid'] = uid;
      final user = UserModel.fromMap(data);
      if (SuspensionUtils.isUserSuspended(user)) {
        await SuspensionUtils.saveSuspensionState(user);
        if (mounted) {
          setState(() {
            _note = user.suspensionNote;
            _until = user.suspendedUntil;
            _statusMessage = 'Still suspended. Please check back later.';
          });
          _recomputeRemaining();
        }
      } else {
        await SuspensionUtils.clearSuspensionState();
        await prefs.setBool('isSuspended', false);
        await prefs.setBool('pending_verification', !user.isVerified);
        await prefs.setBool('isLoggedIn', user.isVerified);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          user.isVerified ? '/home' : '/pending',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('pending_verification', false);
    await prefs.setBool('isSuspended', false);
    await SuspensionUtils.clearSuspensionState();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final untilText = _until == null
        ? 'Pending review'
        : DateFormat('EEE, MMM d · hh:mm a').format(_until!.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.lock_clock, color: Colors.orangeAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Account Suspended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _note ?? 'An administrator has temporarily disabled your access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Suspension ends', value: untilText),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Time remaining', value: _formatRemaining()),
                  ],
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _refreshStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isChecking ? 'Checking...' : 'Check Status'),
              ),
              TextButton(
                onPressed: _isChecking ? null : _logout,
                child: const Text(
                  'Log out',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
