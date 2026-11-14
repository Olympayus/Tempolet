/// Body formats supported by the note vault. The enum name doubles as the
/// file extension so index rows and files stay in sync.
enum NoteFormat {
  txt,
  md;

  /// File extension without the leading dot (`txt` / `md`).
  String get extension => name;
}
