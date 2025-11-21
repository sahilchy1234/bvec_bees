import 'package:flutter/material.dart';

import '../widgets/cached_network_image_widget.dart';

class FullscreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullscreenImagePage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(40),
              onInteractionEnd: (_) => Navigator.of(context).pop(),
              child: CachedNetworkImageWidget(
                imageUrl: imageUrl,
                width: size.width,
                height: size.height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
