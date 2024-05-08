import 'dart:async';                                     // new

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'guest_book_message.dart';                        // new

enum Attending { yes, no, unknown }

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  int _attendees = 0;
  int get attendees => _attendees;
  bool _emailVerified = false;

  Attending _attending = Attending.unknown;
  StreamSubscription<DocumentSnapshot>? _attendingSubscription;
  Attending get attending => _attending;

  StreamSubscription<QuerySnapshot>? _guestBookSubscription;
  List<GuestBookMessage> _guestBookMessages = [];
  List<GuestBookMessage> get guestBookMessages => _guestBookMessages;

  Future<void> init() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);
    
    _addAttendingListener();
    _addUserListeners();
  }

  set attending(Attending attending) {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final userDoc = FirebaseFirestore.instance
      .collection('attendees')
      .doc(user.uid);
      if (attending == Attending.yes) {
        userDoc.set(<String, dynamic> { 'attending': true } );
      } else {
        userDoc.set(<String, dynamic> { 'attending': false } );
      }
  }

  Future<DocumentReference> addMessageToGuestBook(String message) {
    var user = FirebaseAuth.instance.currentUser;
    if (!_loggedIn || user == null) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance
        .collection('guestbook')
        .add(<String, dynamic>{
      'text': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'name': user.displayName,
      'userId': user.uid,
    });
  }

  void _addAttendingListener() {
    FirebaseFirestore.instance
      .collection('attendees')
      .where('attending', isEqualTo: true)
      .snapshots()
      .listen((snapshot) { 
        _attendees = snapshot.docs.length;
      });
  }

  void _addUserListeners(){
    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _emailVerified = user.emailVerified;
        _loggedIn = true;

        _addGuestBookListener(user);
        _addUserAttendee(user);
      } else {
        _loggedIn = false;
        _emailVerified = false;
        _guestBookMessages = [];
        _guestBookSubscription?.cancel();
        _attendingSubscription?.cancel(); // new
      }
      notifyListeners();
    });
  }

  void _addGuestBookListener(User user){
    _guestBookSubscription = FirebaseFirestore.instance
        .collection('guestbook')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _guestBookMessages = [];
      for (final document in snapshot.docs) {
        _guestBookMessages.add(
          GuestBookMessage(
            name: document.data()['name'] as String,
            message: document.data()['text'] as String,
          ),
        );
      }
      notifyListeners();
    });
  }

  void _addUserAttendee(User user) {
    _attendingSubscription = FirebaseFirestore.instance
    .collection('attendees')
    .doc(user.uid)
    .snapshots()
    .listen((snapshot) {
      if (snapshot.data() != null) {
        if (snapshot.data()!['attending'] as bool) {
          _attending = Attending.yes;
        } else {
          _attending = Attending.no;
        }
      } else {
        _attending = Attending.unknown;
      }
      notifyListeners();
    });
  }
}