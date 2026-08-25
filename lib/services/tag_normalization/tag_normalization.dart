// Tag Normalization and Entity Seeding Service - Phase 4
//
// This module provides comprehensive tag normalization, seeding, and alias management
// for the wallpaper app's v6 tag system. It integrates with content providers
// (OpenVerse, Unsplash, GIPHY, Pixabay) to automatically seed and normalize tags
// from API metadata.
//
// Key Features:
// - Text normalization (lowercase, accent removal, special char stripping)
// - Tag extraction from various API formats
// - Entity type detection (PERSON, TEAM, SPORT, LOCATION, etc.)
// - Fuzzy matching with Levenshtein distance
// - Confidence scoring based on source and detection method
// - Pre-populated alias mapping for common entities
// - Bulk operations for performance
// - Cache-based alias resolution for fast lookups

export 'tag_normalizer.dart';
export 'tag_seeder.dart';
export 'tag_alias_service.dart';
