class Song {
  final String title;
  final String artist;
  final String duration;
  final String albumArt; // asset path or color hex
  final Color artColor;
  final bool isPlaying;

  const Song({
    required this.title,
    required this.artist,
    required this.duration,
    required this.albumArt,
    required this.artColor,
    this.isPlaying = false,
  });
}

import 'package:flutter/material.dart';

class SongData {
  static const List<Map<String, dynamic>> queueSongs = [
    {
      'title': '4th Dimension',
      'artist': 'Kids See Ghosts',
      'duration': '2:46',
      'artColor': Color(0xFF7B9EA8),
      'isPlaying': true,
    },
    {
      'title': 'Blue Orangeade',
      'artist': 'TXT',
      'duration': '3:05',
      'artColor': Color(0xFF4DA6D9),
      'hasPlus': true,
    },
    {
      'title': 'Heavydirtysoul',
      'artist': 'Twenty One Pilots',
      'duration': '3:55',
      'artColor': Color(0xFF2C2C2C),
    },
    {
      'title': 'One Kiss',
      'artist': 'Calvin Harris & Dua Lipa',
      'duration': '3:34',
      'artColor': Color(0xFF3B5998),
    },
    {
      'title': 'I Love It',
      'artist': 'Lil pump',
      'duration': '2:08',
      'artColor': Color(0xFF7B68EE),
    },
  ];

  static const List<Map<String, dynamic>> albumTracks = [
    {
      'number': '01',
      'title': 'Feel the Love (feat. Pusha T)',
      'duration': '2:45',
      'artColor': Color(0xFF7B9EA8),
      'isPlaying': true,
    },
    {
      'number': '02',
      'title': 'Fire',
      'duration': '2:20',
      'artColor': Color(0xFF5B8A9E),
    },
    {
      'number': '03',
      'title': '4th Dimension (feat. Louis ...',
      'duration': '2:33',
      'artColor': Color(0xFF6B9AAE),
      'isPlaying': false,
      'hasBar': true,
    },
    {
      'number': '04',
      'title': 'Freeee (Ghost Town, Pt. 2) ...',
      'duration': '3:26',
      'artColor': Color(0xFF8BA8B5),
    },
    {
      'number': '05',
      'title': 'Reborn',
      'duration': '5:24',
      'artColor': Color(0xFF7090A0),
    },
    {
      'number': '06',
      'title': 'Kids See Ghosts (feat. Yas...',
      'duration': '4:05',
      'artColor': Color(0xFF6B9AAE),
    },
  ];
}
