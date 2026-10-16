import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Widget buildNavigationBar(BuildContext context, int index) => NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(i == 1
          ? '/map'
          : i == 2
              ? '/profile'
              : '/home'),
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.assignment_outlined), label: 'Missions'),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Carte'),
        NavigationDestination(
            icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    );
