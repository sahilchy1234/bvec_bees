import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _HomeContent(),
    const _ClubsContent(),
    const _DatingContent(),
    const _ChatContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.black,
              floating: true,
              snap: true,
              elevation: 0,
              title: Row(
                children: [
                  const Icon(Icons.hexagon_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'BVEC Bees',
                    style: GoogleFonts.dancingScript(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  color: Colors.white,
                  onPressed: () {
                    // Handle notification tap
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ];
        },
        body: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 0, left: 0, right: 0), // Padding outside nav bar
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03), // Transparent glass effect
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: const Border(
                  top: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white54,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                items: [
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                      child: FaIcon(
                        _selectedIndex == 0 ? FontAwesomeIcons.houseChimney : FontAwesomeIcons.house,
                        color: _selectedIndex == 0 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                    label: 'Feed',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FaIcon(
                        _selectedIndex == 1 ? FontAwesomeIcons.users : FontAwesomeIcons.user,
                        color: _selectedIndex == 1 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                    label: 'Clubs',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _selectedIndex == 2 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                        color: _selectedIndex == 2 ? Colors.white : Colors.white54,
                        size: 24,
                      ),
                    ),
                    label: 'Hot & Not',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FaIcon(
                        _selectedIndex == 3 ? FontAwesomeIcons.solidComment : FontAwesomeIcons.comment,
                        color: _selectedIndex == 3 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                    label: 'Chat',
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100), // Add padding for nav bar
      itemCount: 20, // Demo items to show scrolling
      itemBuilder: (context, index) {
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Text(
            index == 0 ? 'Home' : 'Scroll Item $index',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        );
      },
    );
  }
}

class _ClubsContent extends StatelessWidget {
  const _ClubsContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: 20,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Text(
            index == 0 ? 'Clubs' : 'Club $index',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        );
      },
    );
  }
}

class _DatingContent extends StatelessWidget {
  const _DatingContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: 20,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Text(
            index == 0 ? 'Dating' : 'Profile $index',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        );
      },
    );
  }
}

class _ChatContent extends StatelessWidget {
  const _ChatContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: 20,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Text(
            index == 0 ? 'Chat' : 'Message $index',
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        );
      },
    );
  }
}
