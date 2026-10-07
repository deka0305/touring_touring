import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../voice.dart';

/// Obrolan grup aktif: teks dan pesan suara (tahan tombol mic untuk bicara).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _tick;
  var _sec = 0;
  var _sending = false;

  @override
  void dispose() {
    _tick?.cancel();
    voice.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _send() async {
    if (_sending) return;
    final t = _text.text;
    if (t.trim().isEmpty) return;
    setState(() => _sending = true);
    final err = await trip.sendChat(t);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) return _toast(err);
    _text.clear();
  }

  Future<void> _recStart() async {
    if (!await voice.start()) {
      if (mounted) _toast('Izin mikrofon ditolak.');
      return;
    }
    _sec = 0;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _sec++);
      if (_sec >= Voice.maxSec) _recStop();
    });
    setState(() {});
  }

  Future<void> _recStop() async {
    _tick?.cancel();
    _tick = null;
    if (!voice.recording) return;
    final err = await voice.stopAndSend();
    if (mounted && err != null) _toast(err);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([trip, voice]),
      builder: (context, _) {
        final g = trip.activeOrNull;
        // Layar ini terbuka = semua pesan terbaca.
        if (trip.chatUnread > 0) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => trip.markChatSeen(),
          );
        }
        final msgs = trip.chat;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.surf,
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Obrolan', style: arch(700, 17, color: p.tx)),
                Text(
                  g?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(500, 11, color: p.tx2),
                ),
              ],
            ),
            actions: [
              Tooltip(
                message: 'Walkie-talkie: putar otomatis pesan suara baru',
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 18, color: p.tx2),
                    Switch(
                      value: trip.autoVoice,
                      activeThumbColor: accent,
                      onChanged: trip.setAutoVoice,
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: msgs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            g != null && g.onCloud
                                ? 'Belum ada pesan. Sapa rombonganmu!'
                                : 'Obrolan butuh grup yang ada di server.',
                            textAlign: TextAlign.center,
                            style: arch(400, 13, color: p.tx2, height: 1.5),
                          ),
                        ),
                      )
                    // reverse: pesan terbaru menempel di bawah tanpa perlu
                    // menggulir manual tiap ada pesan masuk.
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) {
                          final m = msgs[msgs.length - 1 - i];
                          return _Bubble(m, mine: m.uid == trip.myUid);
                        },
                      ),
              ),
              _composer(p, g),
            ],
          ),
        );
      },
    );
  }

  Widget _composer(Pal p, TripGroup? g) {
    final bisa = g != null && g.onCloud && trip.online;
    return Container(
      decoration: BoxDecoration(
        color: p.surf,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: !bisa
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    trip.cloudError ?? 'Server tidak tersambung.',
                    style: arch(400, 12, color: warn),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: voice.recording
                          ? Text(
                              '● Merekam 0:${_sec.toString().padLeft(2, '0')}'
                              '  · lepas untuk kirim',
                              style: mono(700, 13, color: bad),
                            )
                          : TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1000,
                              textCapitalization: TextCapitalization.sentences,
                              style: arch(500, 14, color: p.tx),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Tulis pesan…',
                                counterText: '',
                                filled: true,
                                fillColor: p.surf2,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    if (_text.text.trim().isNotEmpty && !voice.recording)
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        style: IconButton.styleFrom(backgroundColor: accent),
                        icon: const Icon(Icons.send, color: Color(0xFF12140F)),
                      )
                    else
                      // Tahan untuk bicara, lepas untuk kirim — seperti HT.
                      GestureDetector(
                        onLongPressStart: (_) => _recStart(),
                        onLongPressEnd: (_) => _recStop(),
                        onTap: () => _toast('Tahan tombol mic untuk bicara.'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: voice.recording ? bad : accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Color(0xFF12140F),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.mine});
  final ChatMsg m;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = mine ? const Color(0xFF12140F) : p.tx;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: mine ? accent : p.surf,
          border: mine ? null : Border.all(color: p.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) Text(m.name, style: arch(700, 12, color: accent)),
            if (m.isVoice)
              InkWell(
                onTap: () => voice.play(m.key),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      voice.playing == m.key
                          ? Icons.graphic_eq
                          : Icons.play_circle_fill,
                      size: 30,
                      color: fg,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pesan suara · ${m.voiceSec} dtk',
                      style: arch(600, 13, color: fg),
                    ),
                  ],
                ),
              )
            else
              Text(m.text, style: arch(500, 14, color: fg, height: 1.4)),
            const SizedBox(height: 2),
            Text(
              m.atMs == 0 ? 'mengirim…' : fmtClock(m.at),
              style: mono(500, 9, color: fg.withValues(alpha: .6)),
            ),
          ],
        ),
      ),
    );
  }
}
