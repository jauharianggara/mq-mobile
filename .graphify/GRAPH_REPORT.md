# Graph Report - .  (2026-09-16)

## Corpus Check
- Corpus is ~37,600 words - fits in a single context window. You may not need a graph.

## Summary
- 358 nodes · 316 edges · 39 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output
- Edge kinds: contains: 316


## Input Scope
- Requested: auto
- Resolved: committed (source: default-auto)
- Included files: 77 · Candidates: 180
- Excluded: 35 untracked · 16811 ignored · 0 sensitive · 0 missing committed
- Recommendation: Use --scope all or graphify.yaml inputs.corpus for a knowledge-base folder.

## Graph Freshness
- Built from Git commit: `7ed9140`
- Compare this hash to `git rev-parse HEAD` before trusting freshness-sensitive graph output.
## God Nodes (most connected - your core abstractions)
1. `MqSantriApp` - 1 edges
2. `SplashScreen` - 1 edges
3. `_SplashScreenState` - 1 edges
4. `ForceUpdateScreen` - 1 edges
5. `HafalanDetailScreen` - 1 edges
6. `_HafalanDetailScreenState` - 1 edges
7. `HafalanScreen` - 1 edges
8. `_HafalanScreenState` - 1 edges
9. `HafalanSubmitScreen` - 1 edges
10. `_HafalanSubmitScreenState` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

### Community 9 - "Community 9"
Cohesion: 0.18
Nodes (5): MqSantriApp, SplashScreen, _SplashScreenState, ForceUpdateScreen, MqUstadzApp

### Community 14 - "Community 14"
Cohesion: 0.22
Nodes (2): HafalanDetailScreen, _HafalanDetailScreenState

### Community 23 - "Community 23"
Cohesion: 0.29
Nodes (2): HafalanScreen, _HafalanScreenState

### Community 10 - "Community 10"
Cohesion: 0.18
Nodes (2): HafalanSubmitScreen, _HafalanSubmitScreenState

### Community 30 - "Community 30"
Cohesion: 0.40
Nodes (2): HomeScreen, _HomeScreenState

### Community 8 - "Community 8"
Cohesion: 0.17
Nodes (2): KhatmilDetailScreen, _KhatmilDetailScreenState

### Community 24 - "Community 24"
Cohesion: 0.29
Nodes (2): KhatmilLeaderboardScreen, _KhatmilLeaderboardScreenState

### Community 28 - "Community 28"
Cohesion: 0.33
Nodes (2): KhatmilManualProgressScreen, _KhatmilManualProgressScreenState

### Community 1 - "Community 1"
Cohesion: 0.10
Nodes (2): KhatmilReaderScreen, _KhatmilReaderScreenState

### Community 31 - "Community 31"
Cohesion: 0.40
Nodes (2): KhatmilScreen, _KhatmilScreenState

### Community 33 - "Community 33"
Cohesion: 0.50
Nodes (2): LoginScreen, _LoginScreenState

### Community 20 - "Community 20"
Cohesion: 0.25
Nodes (2): NotificationScreen, _NotificationScreenState

### Community 16 - "Community 16"
Cohesion: 0.22
Nodes (2): ProfileScreen, _ProfileScreenState

### Community 5 - "Community 5"
Cohesion: 0.15
Nodes (2): QuranReaderScreen, _QuranReaderScreenState

### Community 29 - "Community 29"
Cohesion: 0.33
Nodes (2): QuranScreen, _QuranScreenState

### Community 34 - "Community 34"
Cohesion: 0.50
Nodes (2): RegisterScreen, _RegisterScreenState

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (2): ShellScreen, _ShellScreenState

### Community 26 - "Community 26"
Cohesion: 0.29
Nodes (2): TanyaScreen, _TanyaScreenState

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (2): TanyaThreadScreen, _TanyaThreadScreenState

### Community 12 - "Community 12"
Cohesion: 0.18
Nodes (2): VisitChatScreen, _VisitChatScreenState

### Community 18 - "Community 18"
Cohesion: 0.22
Nodes (4): VisitPickUstadzScreen, _VisitPickUstadzScreenState, UstadzProfilePage, _UstadzProfilePageState

### Community 7 - "Community 7"
Cohesion: 0.15
Nodes (2): VisitScheduleScreen, _VisitScheduleScreenState

### Community 22 - "Community 22"
Cohesion: 0.25
Nodes (2): VisitScreen, _VisitScreenState

### Community 4 - "Community 4"
Cohesion: 0.14
Nodes (2): VisitStatusScreen, _VisitStatusScreenState

### Community 13 - "Community 13"
Cohesion: 0.18
Nodes (2): WalletScreen, _WalletScreenState

### Community 19 - "Community 19"
Cohesion: 0.25
Nodes (2): KhatmilUstadzScreen, _KhatmilUstadzScreenState

### Community 15 - "Community 15"
Cohesion: 0.22
Nodes (2): PayoutScreen, _PayoutScreenState

### Community 11 - "Community 11"
Cohesion: 0.18
Nodes (2): SetoranReviewScreen, _SetoranReviewScreenState

### Community 25 - "Community 25"
Cohesion: 0.29
Nodes (2): SetoranScreen, _SetoranScreenState

### Community 21 - "Community 21"
Cohesion: 0.25
Nodes (2): UstadzWalletScreen, _UstadzWalletScreenState

### Community 17 - "Community 17"
Cohesion: 0.22
Nodes (2): VisitIncomingScreen, _VisitIncomingScreenState

### Community 6 - "Community 6"
Cohesion: 0.15
Nodes (2): VisitRequestScreen, _VisitRequestScreenState

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (2): VisitSettingsScreen, _VisitSettingsScreenState

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (1): MqApi

### Community 32 - "Community 32"
Cohesion: 0.40
Nodes (1): MqSessionStore

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (2): AppColors, AppTheme

### Community 35 - "Community 35"
Cohesion: 0.50
Nodes (3): StatusBadge, KpiCard, EmptyState

### Community 36 - "Community 36"
Cohesion: 0.50
Nodes (2): ConnectionErrorScreen, _ConnectionErrorScreenState

### Community 27 - "Community 27"
Cohesion: 0.29
Nodes (3): ConnectivityBanner, _ConnectivityBannerState, ForceUpdateScreen

## Knowledge Gaps
- **83 isolated node(s):** `MqSantriApp`, `SplashScreen`, `_SplashScreenState`, `ForceUpdateScreen`, `HafalanDetailScreen` (+78 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 14`** (2 nodes): `HafalanDetailScreen`, `_HafalanDetailScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 23`** (2 nodes): `HafalanScreen`, `_HafalanScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 10`** (2 nodes): `HafalanSubmitScreen`, `_HafalanSubmitScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (2 nodes): `HomeScreen`, `_HomeScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 8`** (2 nodes): `KhatmilDetailScreen`, `_KhatmilDetailScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (2 nodes): `KhatmilLeaderboardScreen`, `_KhatmilLeaderboardScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (2 nodes): `KhatmilManualProgressScreen`, `_KhatmilManualProgressScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 1`** (2 nodes): `KhatmilReaderScreen`, `_KhatmilReaderScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (2 nodes): `KhatmilScreen`, `_KhatmilScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (2 nodes): `LoginScreen`, `_LoginScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 20`** (2 nodes): `NotificationScreen`, `_NotificationScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 16`** (2 nodes): `ProfileScreen`, `_ProfileScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 5`** (2 nodes): `QuranReaderScreen`, `_QuranReaderScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (2 nodes): `QuranScreen`, `_QuranScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (2 nodes): `RegisterScreen`, `_RegisterScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (2 nodes): `ShellScreen`, `_ShellScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 26`** (2 nodes): `TanyaScreen`, `_TanyaScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 2`** (2 nodes): `TanyaThreadScreen`, `_TanyaThreadScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 12`** (2 nodes): `VisitChatScreen`, `_VisitChatScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 7`** (2 nodes): `VisitScheduleScreen`, `_VisitScheduleScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 22`** (2 nodes): `VisitScreen`, `_VisitScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 4`** (2 nodes): `VisitStatusScreen`, `_VisitStatusScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 13`** (2 nodes): `WalletScreen`, `_WalletScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 19`** (2 nodes): `KhatmilUstadzScreen`, `_KhatmilUstadzScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 15`** (2 nodes): `PayoutScreen`, `_PayoutScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 11`** (2 nodes): `SetoranReviewScreen`, `_SetoranReviewScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (2 nodes): `SetoranScreen`, `_SetoranScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 21`** (2 nodes): `UstadzWalletScreen`, `_UstadzWalletScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 17`** (2 nodes): `VisitIncomingScreen`, `_VisitIncomingScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 6`** (2 nodes): `VisitRequestScreen`, `_VisitRequestScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 3`** (2 nodes): `VisitSettingsScreen`, `_VisitSettingsScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 0`** (1 nodes): `MqApi`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (1 nodes): `MqSessionStore`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `AppColors`, `AppTheme`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (2 nodes): `ConnectionErrorScreen`, `_ConnectionErrorScreenState`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `MqSantriApp`, `SplashScreen`, `_SplashScreenState` to the rest of the system?**
  _83 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._