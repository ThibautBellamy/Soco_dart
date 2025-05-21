class Track {
  String? title;
  String? artist;
  String? album;
  String? albumArt;
  String? position;
  String? duration;
  String? uri;
  String? playlistPosition;
  String? metadata;

  Track({
    this.title,
    this.artist,
    this.album,
    this.albumArt,
    this.position,
    this.duration,
    this.uri,
    this.playlistPosition,
    this.metadata, required String albumArtUri, required int queuePosition,
  });

   // Constructeur nommé pour créer un Track à partir d'un tableau
  Track.fromMap(Map<String, dynamic> trackArray) {
    title = trackArray['title'];
    artist = trackArray['artist'];
    album = trackArray['album'];
    albumArt = trackArray['album_art'];
    position = trackArray['position'];
    duration = trackArray['duration'];
    uri = trackArray['uri'];
    playlistPosition = trackArray['playlist_position'];
    metadata = trackArray['metadata'];
  }

  get albumArtUri => null;
}
