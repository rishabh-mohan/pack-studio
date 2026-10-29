import 'package:flutter/material.dart';

import 'theme.dart';

class RecentPack {
  const RecentPack({
    required this.name,
    required this.path,
    required this.lastOpened,
  });

  final String name;
  final String path;
  final DateTime lastOpened;
}

/// Home, laid out like d30mode's main menu: the wallpaper on top, a ruled
/// notebook panel below, and menu pills hanging off the right edge.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNewPack,
    required this.onOpenPack,
    required this.onSettings,
    required this.onOpenRecent,
    required this.onDeleteRecent,
    this.recent = const [],
    this.notice,
  });

  final VoidCallback onNewPack;
  final VoidCallback onOpenPack;
  final VoidCallback onSettings;
  final void Function(RecentPack) onOpenRecent;
  final void Function(RecentPack) onDeleteRecent;
  final List<RecentPack> recent;
  /// A problem to show instead of the packs (e.g. root denied).
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // The game is a phone layout; on a wide window keep that shape.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(
            builder: (context, box) {
              final wallpaperHeight = box.maxHeight * 0.52;
              return Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: StudioColors.paper,
                      child: CustomPaint(painter: _RulePainter()),
                    ),
                  ),
                  SizedBox(
                    height: wallpaperHeight,
                    width: double.infinity,
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: StudioColors.outline,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Image.asset(
                        'assets/placeholder/desk.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        cacheWidth: 900,
                        filterQuality: FilterQuality.medium,
                        // The art is a local, git-ignored placeholder: without it
                        // (a fresh clone) the screen is just plain paper.
                        errorBuilder: (context, error, stack) => const ColoredBox(color: StudioColors.rule),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _SquareButton(
                          icon: Icons.settings,
                          tooltip: 'Settings',
                          label: 'Settings',
                          onTap: onSettings,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: wallpaperHeight * 0.30,
                    right: 0,
                    child: _Pill(
                      icon: Icons.folder_open,
                      label: 'Open pack',
                      onTap: onOpenPack,
                    ),
                  ),
                  Positioned(
                    top: wallpaperHeight - 112, // fully on the wallpaper, clear of the title below
                    right: 0,
                    child: _StartPill(label: 'New pack', onTap: onNewPack),
                  ),
                  Positioned(
                    top: wallpaperHeight + 16,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: _Panel(recent: recent, notice: notice, onOpenRecent: onOpenRecent, onDeleteRecent: onDeleteRecent),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The lower half: pack title like the game's account name, then recents.
class _Panel extends StatelessWidget {
  const _Panel({required this.recent, required this.notice, required this.onOpenRecent, required this.onDeleteRecent});

  final List<RecentPack> recent;
  /// A problem to show instead of the packs (e.g. root denied).
  final String? notice;
  final void Function(RecentPack) onOpenRecent;
  final void Function(RecentPack) onDeleteRecent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 130, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pack Studio',
            style: TextStyle(
              fontSize: 30,
              color: StudioColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Build and edit content packs for d30mode',
            style: TextStyle(fontSize: 13, color: StudioColors.inkSoft),
          ),
          const SizedBox(height: 22),
          const Text(
            'Recent packs',
            style: TextStyle(
              fontSize: 16,
              color: StudioColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (notice != null)
            _Card(
              child: Text(
                notice!,
                style: const TextStyle(color: Color(0xFFE8463C), height: 1.4),
              ),
            )
          else if (recent.isEmpty)
            const _Card(
              child: Text(
                'No packs yet. Create or open one to get started.',
                style: TextStyle(color: StudioColors.inkSoft, height: 1.4),
              ),
            )
          else
            for (final pack in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Card(
                  onTap: () => onOpenRecent(pack),
                  child: Row(children: [
                    Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: const TextStyle(
                          fontSize: 16,
                          color: StudioColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        pack.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StudioColors.inkSoft,
                        ),
                      ),
                      Text(
                        _ago(pack.lastOpened),
                        style: const TextStyle(
                          fontSize: 12,
                          color: StudioColors.inkSoft,
                        ),
                      ),
                    ],
                  )),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: StudioColors.inkSoft),
                      tooltip: 'Delete ${pack.name}',
                      onPressed: () => onDeleteRecent(pack),
                    ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
}

/// Cream box with the game's peach outline.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: StudioColors.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: StudioColors.panelBorder, width: 2),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    ),
  );
}

/// Small square icon button (the game's gear/mail buttons).
class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: StudioColors.panel,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: StudioColors.outline, width: 3),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, size: 30, color: StudioColors.outline),
          ),
        ),
      ),
    ),
  );
}

/// Menu entry hanging off the right edge, rounded only on its left side.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: StudioColors.panel,
    elevation: 2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
      side: BorderSide(color: StudioColors.outline, width: 3),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 22, 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: StudioColors.accent, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                color: StudioColors.accent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The game's solid orange "Start" button: raised, with a darker lower face.
class _StartPill extends StatelessWidget {
  const _StartPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const edge = Color(0xFFD9743F);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
          boxShadow: [
            BoxShadow(color: edge, offset: Offset(0, 6)),
            BoxShadow(
              color: Color(0x264A2B10),
              blurRadius: 8,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFFF0915F),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
            side: BorderSide(color: edge, width: 2),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 16, 30, 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Notebook lines behind the lower panel.
class _RulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StudioColors.rule
      ..strokeWidth = 3;
    for (var y = size.height * 0.52 + 52; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter oldDelegate) => false;
}
