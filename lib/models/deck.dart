import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

@immutable
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.cards,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<DeckCard> cards;
  final DateTime createdAt;
  final DateTime updatedAt;

  Deck copyWith({
    String? id,
    String? name,
    List<DeckCard>? cards,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'cards': cards.map((card) => card.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Deck fromJson(Map<String, Object?> json) {
    final cardsJson = json['cards'];
    final cards = <DeckCard>[];
    if (cardsJson is List) {
      for (final rawCard in cardsJson) {
        if (rawCard is Map) {
          cards.add(
            DeckCard.fromJson(
              rawCard.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return Deck(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      cards: cards,
      createdAt:
          _parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

@immutable
class DeckCard {
  const DeckCard({
    required this.id,
    required this.label,
    required this.ocrText,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.defaultBucketId,
    this.thumbnailBytes,
  });

  final String id;
  final String label;
  final String ocrText;
  final String? note;
  final String? defaultBucketId;
  final Uint8List? thumbnailBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeckCard copyWith({
    String? id,
    String? label,
    String? ocrText,
    Object? note = _unset,
    Object? defaultBucketId = _unset,
    Object? thumbnailBytes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeckCard(
      id: id ?? this.id,
      label: label ?? this.label,
      ocrText: ocrText ?? this.ocrText,
      note: identical(note, _unset) ? this.note : note as String?,
      defaultBucketId: identical(defaultBucketId, _unset)
          ? this.defaultBucketId
          : defaultBucketId as String?,
      thumbnailBytes: identical(thumbnailBytes, _unset)
          ? this.thumbnailBytes
          : thumbnailBytes as Uint8List?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'ocrText': ocrText,
      'note': note,
      'defaultBucketId': defaultBucketId,
      'thumbnailBase64':
          thumbnailBytes == null ? null : base64Encode(thumbnailBytes!),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DeckCard fromJson(Map<String, Object?> json) {
    final thumbnailValue = json['thumbnailBase64'];
    Uint8List? thumbnailBytes;
    if (thumbnailValue is String && thumbnailValue.isNotEmpty) {
      try {
        thumbnailBytes = base64Decode(thumbnailValue);
      } catch (_) {
        thumbnailBytes = null;
      }
    }

    return DeckCard(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      ocrText: (json['ocrText'] as String?) ?? '',
      note: json['note'] as String?,
      defaultBucketId: json['defaultBucketId'] as String?,
      thumbnailBytes: thumbnailBytes,
      createdAt:
          _parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static const Object _unset = Object();
}

DateTime? _parseDateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
