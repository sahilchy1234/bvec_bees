import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    // Only update vote status if the rumor data actually changed
    if (oldWidget.rumor.id != widget.rumor.id ||
        oldWidget.rumor.yesVotes != widget.rumor.yesVotes ||
        oldWidget.rumor.noVotes != widget.rumor.noVotes ||
        !listEquals(oldWidget.rumor.votedYesByUsers, widget.rumor.votedYesByUsers) ||
        !listEquals(oldWidget.rumor.votedNoByUsers, widget.rumor.votedNoByUsers)) {
      _updateVoteStatus();
    }
  }

  void _updateVoteStatus() {
    setState(() {
      _userVotedYes = widget.rumor.votedYesByUsers.contains(widget.currentUserId);
      _userVotedNo = widget.rumor.votedNoByUsers.contains(widget.currentUserId);
      _yesVotesLocal = widget.rumor.yesVotes;
      _noVotesLocal = widget.rumor.noVotes;
      _credScoreLocal = _calculateCredibility(_yesVotesLocal, _noVotesLocal);
    });
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
        // border: Border.all(
        //   color: _isControversialLocal()
        //       ? Colors.amber.withOpacity(0.6)
        //       : Colors.amber.withOpacity(0.2),
        //   width: 1.5,
        // ),
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
                Row(
                  children: [
                    if (_isControversialLocal())
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                        //  color: Colors.amber.withOpacity(0.2),
                      //    borderRadius: BorderRadius.circular(6),
                      //    border: Border.all(color: Colors.amber, width: 1),
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
                    IconButton(
                      icon: const FaIcon(
                        FontAwesomeIcons.share,
                        color: Colors.amber,
                        size: 16,
                      ),
                      onPressed: widget.onShare,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content Card
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 500,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
               
              ),
              child: Text(
                widget.rumor.content,
                textAlign: TextAlign.center,
                style: GoogleFonts.caveat(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
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
          // Vote Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        try {
                          HapticFeedback.heavyImpact();
                          print('Haptic feedback: heavyImpact triggered');
                        } catch (e) {
                          print('Haptic feedback: Error - $e');
                        }
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
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _userVotedYes
                                ? Colors.amber
                                : Colors.grey[850],
                            borderRadius: BorderRadius.circular(999),
                            border: _userVotedYes
                                ? null
                                : Border.all(
                                  //  color: Colors.amber.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                            boxShadow: _userVotedYes
                                ? [
                                    BoxShadow(
                                    //  color: Colors.green.withOpacity(0.25),
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
                                color: _userVotedYes ? Colors.black : Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'True ($_yesVotesLocal)',
                                style: TextStyle(
                                  color: _userVotedYes ? Colors.black : Colors.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        try {
                          HapticFeedback.heavyImpact();
                          print('Haptic feedback: heavyImpact triggered');
                        } catch (e) {
                          print('Haptic feedback: Error - $e');
                        }
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
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _userVotedNo
                                ? Colors.amber
                                : Colors.grey[850],
                            borderRadius: BorderRadius.circular(999),
                            border: _userVotedNo
                                ? null
                                : Border.all(
                                    //color: Colors.amber.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                            boxShadow: _userVotedNo
                                ? [
                                    BoxShadow(
                                      // color: const Color.fromARGB(255, 145, 145, 0).withOpacity(0.25),
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
                                color: _userVotedNo ? Colors.black : Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'False ($_noVotesLocal)',
                                style: TextStyle(
                                  color: _userVotedNo ? Colors.black : Colors.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.comment,
                      color: Colors.amber,
                      size: 20,
                    ),
                    onPressed: widget.onComment,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
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

