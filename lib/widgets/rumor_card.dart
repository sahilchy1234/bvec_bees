import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/rumor_model.dart';

class RumorCard extends StatefulWidget {
  final RumorModel rumor;
  final String currentUserId;
  final VoidCallback onVoteYes;
  final VoidCallback onVoteNo;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const RumorCard({
    super.key,
    required this.rumor,
    required this.currentUserId,
    required this.onVoteYes,
    required this.onVoteNo,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<RumorCard> createState() => _RumorCardState();
}

class _AnimatedProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration duration;

  const _AnimatedProgressBar({
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 6,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetWidth = constraints.maxWidth * safeValue;
          return Stack(
            children: [
              Container(
                width: constraints.maxWidth,
                height: height,
                color: backgroundColor,
              ),
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                width: targetWidth,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RumorCardState extends State<RumorCard> {
  late bool _userVotedYes;
  late bool _userVotedNo;
  late int _yesVotesLocal;
  late int _noVotesLocal;
  late double _credScoreLocal;

  @override
  void initState() {
    super.initState();
    _updateVoteStatus();
  }

  @override
  void didUpdateWidget(RumorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always refresh local vote status when widget updates
    _updateVoteStatus();
  }

  void _updateVoteStatus() {
    _userVotedYes = widget.rumor.votedYesByUsers.contains(widget.currentUserId);
    _userVotedNo = widget.rumor.votedNoByUsers.contains(widget.currentUserId);
    _yesVotesLocal = widget.rumor.yesVotes;
    _noVotesLocal = widget.rumor.noVotes;
    _credScoreLocal = _calculateCredibility(_yesVotesLocal, _noVotesLocal);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Color _getCredibilityColor() {
    if (_credScoreLocal >= 0.75) {
      return Colors.green;
    } else if (_credScoreLocal >= 0.65) {
      return Colors.lightGreen;
    } else if (_credScoreLocal >= 0.55) {
      return Colors.lime;
    } else if (_credScoreLocal >= 0.45) {
      return Colors.yellow;
    } else if (_credScoreLocal >= 0.35) {
      return Colors.orange;
    } else if (_credScoreLocal >= 0.25) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  double _calculateCredibility(int yes, int no) {
    final total = yes + no;
    if (total == 0) return 0.5;
    return yes / total;
  }

  String _credibilityLabel(double score) {
    if (score >= 0.75) return 'Likely True';
    if (score >= 0.65) return 'Probably True';
    if (score >= 0.55) return 'Slightly True';
    if (score >= 0.45) return 'Neutral';
    if (score >= 0.35) return 'Slightly False';
    if (score >= 0.25) return 'Probably False';
    return 'Likely False';
  }

  bool _isControversialLocal() {
    final total = _yesVotesLocal + _noVotesLocal;
    if (total < 2) return false;
    final ratio = (_yesVotesLocal / total - 0.5).abs();
    return ratio < 0.15;
  }

  @override
  Widget build(BuildContext context) {
    final totalVotes = _yesVotesLocal + _noVotesLocal;
    final yesPercentage = totalVotes > 0 ? (_yesVotesLocal / totalVotes * 100) : 0.0;
    final noPercentage = 100 - yesPercentage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141414),
            Color(0xFF0F0F0F),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isControversialLocal()
              ? Colors.amber.withOpacity(0.6)
              : Colors.amber.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isControversialLocal()
                ? Colors.amber.withOpacity(0.15)
                : Colors.transparent,
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3),
                            Colors.yellow.withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: FaIcon(
                          FontAwesomeIcons.userSecret,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anonymous',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatTime(widget.rumor.timestamp),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isControversialLocal())
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: const Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.fire,
                          color: Colors.amber,
                          size: 9,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'SPICY',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.rumor.content,
              style: GoogleFonts.caveat(
                color: Colors.white,
                fontSize: 25,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Credibility Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Credibility',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _credibilityLabel(_credScoreLocal),
                      style: TextStyle(
                        color: _getCredibilityColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _AnimatedProgressBar(
                  value: _credScoreLocal.clamp(0.0, 1.0),
                  color: _getCredibilityColor(),
                  backgroundColor: Colors.grey[800]!,
                  height: 8,
                  duration: const Duration(milliseconds: 350),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'True',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'False',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Vote Statistics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yes: ${_yesVotesLocal}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _AnimatedProgressBar(
                        value: (yesPercentage / 100).clamp(0.0, 1.0),
                        color: Colors.green,
                        backgroundColor: Colors.grey[800]!,
                        height: 6,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No: ${_noVotesLocal}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _AnimatedProgressBar(
                        value: (noPercentage / 100).clamp(0.0, 1.0),
                        color: Colors.red,
                        backgroundColor: Colors.grey[800]!,
                        height: 6,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Vote Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        setState(() {
                          if (_userVotedYes) {
                            // remove yes vote
                            if (_yesVotesLocal > 0) _yesVotesLocal -= 1;
                            _userVotedYes = false;
                          } else {
                            // add yes vote
                            _yesVotesLocal += 1;
                            // if previously voted no, remove it
                            if (_userVotedNo && _noVotesLocal > 0) {
                              _noVotesLocal -= 1;
                            }
                            _userVotedYes = true;
                            _userVotedNo = false;
                          }
                          _credScoreLocal = _calculateCredibility(_yesVotesLocal, _noVotesLocal);
                        });
                        widget.onVoteYes();
                      },
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 120),
                        scale: _userVotedYes ? 0.98 : 1.0,
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _userVotedYes
                                ? Colors.green
                                : Colors.grey[850],
                            borderRadius: BorderRadius.circular(999),
                            border: _userVotedYes
                                ? null
                                : Border.all(
                                    color: Colors.amber.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                            boxShadow: _userVotedYes
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.thumbsUp,
                                color: _userVotedYes ? Colors.white : Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'True',
                                style: TextStyle(
                                  color: _userVotedYes ? Colors.white : Colors.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        setState(() {
                          if (_userVotedNo) {
                            // remove no vote
                            if (_noVotesLocal > 0) _noVotesLocal -= 1;
                            _userVotedNo = false;
                          } else {
                            // add no vote
                            _noVotesLocal += 1;
                            // if previously voted yes, remove it
                            if (_userVotedYes && _yesVotesLocal > 0) {
                              _yesVotesLocal -= 1;
                            }
                            _userVotedNo = true;
                            _userVotedYes = false;
                          }
                          _credScoreLocal = _calculateCredibility(_yesVotesLocal, _noVotesLocal);
                        });
                        widget.onVoteNo();
                      },
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 120),
                        scale: _userVotedNo ? 0.98 : 1.0,
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _userVotedNo
                                ? Colors.red
                                : Colors.grey[850],
                            borderRadius: BorderRadius.circular(999),
                            border: _userVotedNo
                                ? null
                                : Border.all(
                                    color: Colors.amber.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                            boxShadow: _userVotedNo
                                ? [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.thumbsDown,
                                color: _userVotedNo ? Colors.white : Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'False',
                                style: TextStyle(
                                  color: _userVotedNo ? Colors.white : Colors.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: FontAwesomeIcons.comment,
                  label: '${widget.rumor.commentCount}',
                  onTap: widget.onComment,
                ),
                _ActionButton(
                  icon: FontAwesomeIcons.share,
                  label: 'Share',
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.amber.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                icon,
                color: Colors.amber,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
