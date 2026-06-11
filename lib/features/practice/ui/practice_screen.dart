import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/click_player.dart';
import '../../../core/audio/timbre.dart';
import '../../../data/settings_repository.dart';
import '../state/practice_controller.dart';
import 'widgets/rhythm_grid_picker.dart';

const _kAmber = Color(0xFFE8A435);
const _kBg = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF181818);
const _kText = Color(0xFFDDD5C8);
const _kBorder = Color(0xFF2A2A2A);

class PracticeScreen extends StatefulWidget {
  final ClickPlayer player;
  final SettingsRepository settings;

  const PracticeScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late PracticeController _controller;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = PracticeController(
      player: widget.player,
      settings: widget.settings,
    );
    _controller.init();
  }

  @override
  void dispose() {
    // Restore portrait orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final grid = _controller.grid;
            final selectedIndices = grid.columns
                .map((col) => col.selectedPatternIndex)
                .toList();

            return Column(
              children: [
                // Top bar
                _buildTopBar(),
                const SizedBox(height: 16),
                // Grid picker
                Expanded(
                  child: RhythmGridPicker(
                    selectedIndices: selectedIndices,
                    currentBeat: grid.currentBeat,
                    onColumnChanged: (encoded) {
                      final columnIndex = encoded ~/ 100;
                      final patternIndex = encoded % 100;
                      _controller.updateColumnPattern(columnIndex, patternIndex);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Bottom controls
                _buildBottomControls(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _kText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          const Text(
            '节奏练习',
            style: TextStyle(
              color: _kText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // BPM
          _buildControlButton(
            icon: Icons.speed,
            label: '${_controller.bpm}',
            onTap: _showBpmDialog,
          ),
          // Cues
          _buildControlButton(
            icon: _controller.showCues
                ? Icons.lightbulb
                : Icons.lightbulb_outline,
            label: '提示',
            isActive: _controller.showCues,
            onTap: () => _controller.toggleCues(),
          ),
          // Play/Pause
          GestureDetector(
            onTap: () => _controller.toggle(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _controller.isPlaying ? _kAmber : _kSurface,
                border: Border.all(
                  color: _controller.isPlaying ? Colors.transparent : _kAmber,
                  width: 1.5,
                ),
                boxShadow: _controller.isPlaying
                    ? [
                        BoxShadow(
                          color: _kAmber.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: _controller.isPlaying ? Colors.black : _kAmber,
                size: 32,
              ),
            ),
          ),
          // Timbre
          _buildControlButton(
            icon: Icons.music_note,
            label: '音效',
            onTap: _showTimbreSheet,
          ),
          const SizedBox(width: 48), // Spacer for balance
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _kAmber.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? _kAmber : _kText,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _kAmber : _kText,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBpmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('速度 (BPM)', style: TextStyle(color: _kText)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_controller.bpm}',
                  style: const TextStyle(
                    color: _kAmber,
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Slider(
                  value: _controller.bpm.toDouble(),
                  min: 30,
                  max: 300,
                  divisions: 270,
                  activeColor: _kAmber,
                  inactiveColor: _kAmber.withOpacity(0.3),
                  onChanged: (value) {
                    setState(() {
                      _controller.setBpm(value.round());
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('确定', style: TextStyle(color: _kAmber)),
          ),
        ],
      ),
    );
  }

  void _showTimbreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) => _PracticeTimbreSheet(
        selected: _controller.timbre,
        onSelect: (t) {
          _controller.setTimbre(t);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

// Local TimbreSheet wrapper to avoid navigation issues
class _PracticeTimbreSheet extends StatelessWidget {
  final Timbre selected;
  final ValueChanged<Timbre> onSelect;

  const _PracticeTimbreSheet({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '音  色',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...kTimbres.map((t) {
              final isSelected = t.id == selected.id;
              return GestureDetector(
                onTap: () => onSelect(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.outline,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 18,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 15,
                            letterSpacing: 1,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
