// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Qodi Music';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get create => 'Crear';

  @override
  String get done => 'Listo';

  @override
  String get copy => 'Copiar';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get retry => 'Reintentar';

  @override
  String get more => 'Más';

  @override
  String get close => 'Cerrar';

  @override
  String get search => 'Buscar';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get connectToServer => 'Conectar a un servidor';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String get settings => 'Ajustes';

  @override
  String get notConnected => 'Sin servidor';

  @override
  String get usingDeviceOnly => 'Usando solo la música de este dispositivo';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get playback => 'Reproducción';

  @override
  String get equalizerSubtitle => 'Preajustes y sonido personalizado';

  @override
  String get streamingQuality => 'Calidad de streaming';

  @override
  String get streamQualityOriginal => 'Original';

  @override
  String get streamQualityOriginalHint => 'Sin pérdida / archivo original';

  @override
  String get streamQualityOpus => 'Opus 128 kbps';

  @override
  String get streamQualityOpusHint => 'Ahorra datos, convertido en el servidor';

  @override
  String get musicOnThisDevice => 'Música en este dispositivo';

  @override
  String get serverLibrary => 'Biblioteca del servidor';

  @override
  String get syncOfflineLibrary => 'Sincronizar biblioteca sin conexión';

  @override
  String get syncOfflineLibraryHint =>
      'Descarga los últimos cambios de la biblioteca';

  @override
  String librarySynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Biblioteca sincronizada ($count cambios)',
      one: 'Biblioteca sincronizada (1 cambio)',
    );
    return '$_temp0';
  }

  @override
  String get syncFailed => 'No se pudo sincronizar';

  @override
  String get rescanMusicFolder => 'Volver a escanear la carpeta de música';

  @override
  String get rescanMusicFolderHint =>
      'Pide al servidor que busque canciones nuevas';

  @override
  String get scanStarted => 'Escaneo iniciado';

  @override
  String get scanFailed => 'No se pudo iniciar el escaneo';

  @override
  String get downloadedMusic => 'Música descargada';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get signInSubtitle => 'Inicia sesión en tu servidor de música';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get username => 'Usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get enterServerUrl => 'Ingresa la URL del servidor';

  @override
  String get serverUrlRule =>
      'Usa una URL completa, como http://192.168.1.10:4040';

  @override
  String get enterYourUsername => 'Ingresa tu usuario';

  @override
  String get enterYourPassword => 'Ingresa tu contraseña';

  @override
  String get wrongCredentials => 'Usuario o contraseña incorrectos';

  @override
  String loginFailed(String error) {
    return 'No se pudo iniciar sesión: $error';
  }

  @override
  String get useWithoutServer => 'Usar sin servidor';

  @override
  String get useWithoutServerHint =>
      'Reproduce la música guardada en este dispositivo. Puedes conectar un servidor más tarde en Ajustes.';

  @override
  String get errorForbidden => 'No tienes permiso para hacer eso.';

  @override
  String get errorNetwork =>
      'No se puede conectar con el servidor. Revisa la URL.';

  @override
  String get errorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get enterUsername => 'Ingresa un nombre de usuario';

  @override
  String get usernameRule => 'Usa de 3 a 32 caracteres: letras, números, _ . -';

  @override
  String get enterPassword => 'Ingresa una contraseña';

  @override
  String get passwordRule => 'Usa de 8 a 128 caracteres';

  @override
  String get passwordsDiffer => 'Las contraseñas no coinciden';

  @override
  String get enterInvite => 'Ingresa tu código de invitación';

  @override
  String get invalidInvite =>
      'Este código de invitación no es válido, venció o ya se usó.';

  @override
  String get usernameTaken => 'Ese nombre de usuario ya está en uso.';

  @override
  String get badRequest => 'Revisa las reglas del usuario y la contraseña.';

  @override
  String get wrongCurrentPassword => 'La contraseña actual es incorrecta.';

  @override
  String get haveInvite => '¿Tienes una invitación? Crea una cuenta';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get createAccountSubtitle =>
      'Únete a un servidor de Qodi Music con una invitación';

  @override
  String get inviteCode => 'Código de invitación';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get haveAccount => '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get account => 'Cuenta';

  @override
  String get admin => 'Admin';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get newPassword => 'Contraseña nueva';

  @override
  String get confirmNewPassword => 'Confirmar contraseña nueva';

  @override
  String get passwordChanged => 'Contraseña cambiada';

  @override
  String get usersAndInvites => 'Usuarios e invitaciones';

  @override
  String get usersSubtitle => 'Administra quién puede escuchar';

  @override
  String get users => 'Usuarios';

  @override
  String get invites => 'Invitaciones';

  @override
  String get you => 'Tú';

  @override
  String get deleteUser => 'Eliminar usuario';

  @override
  String get cannotDeleteSelf => 'No puedes eliminarte a ti mismo';

  @override
  String deleteUserQuestion(String name) {
    return '¿Eliminar a $name? Se borran sus listas, favoritos y reproducciones, y se cierra su sesión.';
  }

  @override
  String userDeleted(String name) {
    return '$name eliminado';
  }

  @override
  String get createInvite => 'Crear invitación';

  @override
  String get expiresInHours => 'Vence en (horas)';

  @override
  String get maxUses => 'Usos máximos';

  @override
  String get expiryRule => 'Entre 1 y 720 horas';

  @override
  String get usesRule => 'Entre 1 y 50';

  @override
  String get inviteCreated => 'Invitación creada';

  @override
  String get shareInviteHint =>
      'Envía el enlace para unirse. En Android se puede instalar la app desde el enlace del APK.';

  @override
  String get joinLink => 'Enlace para unirse';

  @override
  String get apkLink => 'App de Android (APK)';

  @override
  String get copyCode => 'Copiar código';

  @override
  String get copied => 'Copiado al portapapeles';

  @override
  String get revoke => 'Revocar';

  @override
  String get revokeInvite => 'Revocar invitación';

  @override
  String revokeInviteQuestion(String code) {
    return '¿Revocar la invitación $code? Ya no se podrá usar.';
  }

  @override
  String get inviteRevoked => 'Invitación revocada';

  @override
  String get noInvites => 'Aún no hay invitaciones';

  @override
  String get statusActive => 'Activa';

  @override
  String get statusExpired => 'Vencida';

  @override
  String get statusUsedUp => 'Agotada';

  @override
  String inviteUses(int used, int max) {
    return 'Usos $used/$max';
  }

  @override
  String expiresOn(String date) {
    return 'Vence $date';
  }

  @override
  String expiredOn(String date) {
    return 'Venció $date';
  }

  @override
  String get loadFailed => 'No se pudo cargar. Desliza para reintentar.';

  @override
  String get appUpdates => 'Actualizaciones de la app';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String currentVersion(String version) {
    return 'Versión actual $version';
  }

  @override
  String get checking => 'Buscando…';

  @override
  String get neverChecked => 'Aún no se ha buscado';

  @override
  String get upToDate => 'Tienes la versión más reciente';

  @override
  String get noPublishedUpdate =>
      'No hay actualizaciones publicadas en el servidor';

  @override
  String get checkFailed => 'No se pudo buscar actualizaciones';

  @override
  String get updateNoServer =>
      'Conéctate a un servidor para recibir actualizaciones';

  @override
  String versionAvailable(String version) {
    return 'La versión $version está disponible';
  }

  @override
  String lastChecked(String result, String when) {
    return '$result · revisado $when';
  }

  @override
  String get updateAvailable => 'Hay una actualización disponible';

  @override
  String updateQuestion(String from, String to) {
    return 'Hay una actualización disponible (v$from → v$to)';
  }

  @override
  String get update => 'Actualizar';

  @override
  String get later => 'Más tarde';

  @override
  String get downloadingUpdate => 'Descargando actualización…';

  @override
  String get checksumMismatch =>
      'La descarga está dañada (la suma de verificación no coincide). Inténtalo de nuevo.';

  @override
  String get updateDownloadFailed =>
      'La descarga falló. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get installPermission =>
      'Permite que Qodi Music instale apps para poder actualizarse.';

  @override
  String get installFailed => 'No se pudo abrir el instalador.';

  @override
  String get equalizer => 'Ecualizador';

  @override
  String get reset => 'Restablecer';

  @override
  String get equalizerHint =>
      'Ajusta el sonido con preajustes o tu propia curva';

  @override
  String get presets => 'Preajustes';

  @override
  String get bands => 'Bandas';

  @override
  String get presetCustom => 'Personalizado';

  @override
  String get equalizerUnavailableTitle => 'No disponible en esta plataforma';

  @override
  String get equalizerUnavailableBody =>
      'El ecualizador funciona en Android. En este dispositivo el motor de audio no tiene ecualizador.';

  @override
  String get equalizerWaitingBands =>
      'Reproduce una canción para cargar las bandas del ecualizador de este dispositivo.';

  @override
  String get presetFlat => 'Plano';

  @override
  String get presetBassBoost => 'Refuerzo de graves';

  @override
  String get presetTrebleBoost => 'Refuerzo de agudos';

  @override
  String get presetVocal => 'Voces';

  @override
  String get presetRock => 'Rock';

  @override
  String get presetPop => 'Pop';

  @override
  String get presetElectronic => 'Electrónica';

  @override
  String get presetAcoustic => 'Acústica';

  @override
  String get availableOffline => 'Disponible sin conexión';

  @override
  String get downloaded => 'Descargado';

  @override
  String someDownloaded(int done, int total) {
    return '$done de $total descargadas';
  }

  @override
  String get downloadAll => 'Descargar todo';

  @override
  String get qualityHiRes => 'Hi-Res';

  @override
  String get qualityLossless => 'Sin pérdida';

  @override
  String get trackInfo => 'Información de la canción';

  @override
  String get infoFormat => 'Formato';

  @override
  String get infoBitrate => 'Tasa de bits';

  @override
  String get infoSampleRate => 'Frecuencia de muestreo';

  @override
  String get infoBitDepth => 'Profundidad de bits';

  @override
  String get infoChannels => 'Canales';

  @override
  String get infoSize => 'Tamaño';

  @override
  String get channelsMono => 'Mono';

  @override
  String get channelsStereo => 'Estéreo';

  @override
  String channelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales',
      one: '1 canal',
    );
    return '$_temp0';
  }

  @override
  String kbpsValue(int value) {
    return '$value kbps';
  }

  @override
  String kHzValue(String value) {
    return '$value kHz';
  }

  @override
  String bitsValue(int value) {
    return '$value bits';
  }

  @override
  String transcodedFrom(String streamed, String source) {
    return '$streamed · desde $source';
  }

  @override
  String get playNext => 'Reproducir a continuación';

  @override
  String playingNext(String title) {
    return 'A continuación: $title';
  }

  @override
  String get addToQueue => 'Agregar a la cola';

  @override
  String get addedToQueue => 'Agregada a la cola';

  @override
  String get addToPlaylist => 'Agregar a una lista';

  @override
  String get removeDownload => 'Quitar descarga';

  @override
  String get download => 'Descargar';

  @override
  String goToAlbum(String album) {
    return 'Ir al álbum · $album';
  }

  @override
  String goToArtist(String artist) {
    return 'Ir al artista · $artist';
  }

  @override
  String get favoritesUpdateFailed => 'No se pudieron actualizar los favoritos';

  @override
  String get addToFavorites => 'Agregar a favoritos';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get songs => 'Canciones';

  @override
  String get albums => 'Álbumes';

  @override
  String get artists => 'Artistas';

  @override
  String get favorites => 'Favoritos';

  @override
  String get playlists => 'Listas';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count álbumes',
      one: '1 álbum',
    );
    return '$_temp0';
  }

  @override
  String songCountLower(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String get playAll => 'Reproducir todo';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get clear => 'Borrar';

  @override
  String get deviceUpToDate => 'La música del dispositivo está al día';

  @override
  String deviceRescanResult(int added, int removed) {
    return '$added nuevas, $removed eliminadas';
  }

  @override
  String deviceLoadFailed(String error) {
    return 'No se pudo cargar la música del dispositivo\n$error';
  }

  @override
  String get searchDeviceMusic => 'Buscar en el dispositivo';

  @override
  String get scanning => 'Escaneando…';

  @override
  String songsOnDevice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones en este dispositivo',
      one: '1 canción en este dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get rescan => 'Volver a escanear';

  @override
  String get deviceFavoritesEmpty =>
      'Toca el corazón de una canción del dispositivo para guardarla aquí.';

  @override
  String get noSongsFound => 'No se encontraron canciones';

  @override
  String get noAlbumsFound => 'No se encontraron álbumes';

  @override
  String get noArtistsFound => 'No se encontraron artistas';

  @override
  String get newDevicePlaylist => 'Nueva lista del dispositivo';

  @override
  String get importSongsHint =>
      'Importa canciones a la app para reproducirlas aquí.';

  @override
  String noMusicInFolders(String folders) {
    return 'No se encontró música en $folders.\nAgrega una carpeta en Ajustes.';
  }

  @override
  String get theScannedFolders => 'las carpetas escaneadas';

  @override
  String get importSongs => 'Importar canciones';

  @override
  String get addFolder => 'Agregar carpeta';

  @override
  String get permissionPermanentlyDenied =>
      'Qodi Music necesita acceso a tus archivos de música.\nPermítelo en los ajustes de la app.';

  @override
  String get permissionRationale =>
      'Permite el acceso a tus archivos de música para reproducir las canciones guardadas en este dispositivo.';

  @override
  String get allowAccess => 'Permitir acceso';

  @override
  String get folderPickerFailed => 'No se pudo abrir el selector de carpetas';

  @override
  String importedSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count canciones',
      one: 'Se importó 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get importFailed => 'No se pudo importar';

  @override
  String get album => 'Álbum';

  @override
  String get artist => 'Artista';

  @override
  String get playlist => 'Lista';

  @override
  String get albumGone => 'Este álbum ya no está en este dispositivo';

  @override
  String get artistGone => 'Este artista ya no está en este dispositivo';

  @override
  String get playlistGone => 'Esta lista ya no está en este dispositivo';

  @override
  String get renamePlaylist => 'Cambiar nombre de la lista';

  @override
  String get deletePlaylistQuestion => '¿Eliminar la lista?';

  @override
  String deleteDevicePlaylistBody(String name) {
    return 'Se eliminará \"$name\". Las canciones se quedan en tu dispositivo.';
  }

  @override
  String get removeFromPlaylist => 'Quitar de la lista';

  @override
  String get folderDefault => 'Predeterminada';

  @override
  String get folderAddedByYou => 'Agregada por ti';

  @override
  String get folderNotFound => 'no encontrada';

  @override
  String get removeFolder => 'Quitar carpeta';

  @override
  String get importSongsHintSettings => 'Copia archivos de audio a la app';

  @override
  String get rescanDeviceMusic => 'Volver a escanear la música del dispositivo';

  @override
  String songsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones encontradas',
      one: '1 canción encontrada',
    );
    return '$_temp0';
  }

  @override
  String scanDone(int added, int removed) {
    return 'Escaneo terminado: $added nuevas, $removed eliminadas';
  }

  @override
  String get addedToPlaylist => 'Agregada a la lista';

  @override
  String addedSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se agregaron $count canciones',
      one: 'Se agregó 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get addToPlaylistFailed => 'No se pudo agregar a la lista';

  @override
  String get listener => 'Oyente';

  @override
  String get welcomeBack => 'Hola de nuevo,';

  @override
  String get offlineModeGreeting => 'Modo sin conexión,';

  @override
  String get listenPrompt => '¿Qué quieres\nescuchar hoy?';

  @override
  String get recentlyPlayed => 'Escuchado recientemente';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get homePlaylistsHeader => 'Listas';

  @override
  String get noPlaylistsYetHome => 'Aún no hay listas. Crea una en Biblioteca.';

  @override
  String get noDevicePlaylistsYetHome =>
      'Aún no hay listas del dispositivo. Crea una en Biblioteca.';

  @override
  String get playlistsLoadFailed => 'No se pudieron cargar las listas';

  @override
  String get favoritesEmptyHint =>
      'Toca el corazón de cualquier canción para guardarla aquí.';

  @override
  String get favoritesLoadFailed => 'No se pudieron cargar los favoritos';

  @override
  String get loading => 'Cargando…';

  @override
  String get scanningYourMusic => 'Escaneando tu música…';

  @override
  String get allowAccessShort =>
      'Permite el acceso para reproducir tus archivos de música';

  @override
  String get onThisDevice => 'En este dispositivo';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get downloads => 'Descargas';

  @override
  String get libraryNeedsServer =>
      'Conéctate a un servidor en Ajustes para ver tu biblioteca.';

  @override
  String get yourLibrary => 'Tu biblioteca';

  @override
  String get createPlaylistFailed => 'No se pudo crear la lista';

  @override
  String get newPlaylist => 'Nueva lista';

  @override
  String playlistsLoadFailedDetail(String error) {
    return 'No se pudieron cargar las listas\n$error';
  }

  @override
  String get noFavoritesYet => 'Aún no hay favoritos';

  @override
  String favoritesLoadFailedDetail(String error) {
    return 'No se pudieron cargar los favoritos\n$error';
  }

  @override
  String get play => 'Reproducir';

  @override
  String downloadingSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargando $count canciones',
      one: 'Descargando 1 canción',
    );
    return '$_temp0';
  }

  @override
  String albumLoadFailed(String error) {
    return 'No se pudo cargar el álbum\n$error';
  }

  @override
  String artistLoadFailed(String error) {
    return 'No se pudo cargar el artista\n$error';
  }

  @override
  String get exploreServerTitle => 'Explora tu servidor';

  @override
  String get exploreServerMessage =>
      'Para ver los álbumes y artistas de tu servidor de música necesitas conexión. La música de tu dispositivo está en Biblioteca.';

  @override
  String get browseMusic => 'Explorar música';

  @override
  String get searchHint => 'Busca canciones, artistas, álbumes';

  @override
  String somethingWentWrongDetail(String error) {
    return 'Algo salió mal.\n$error';
  }

  @override
  String get libraryEmpty => 'Tu biblioteca está vacía';

  @override
  String get playlistSaveFailed => 'No se pudo guardar la lista';

  @override
  String get renameFailed => 'No se pudo cambiar el nombre';

  @override
  String deletePlaylistBody(String name) {
    return 'Se eliminará \"$name\". Las canciones se quedan en tu biblioteca.';
  }

  @override
  String get deleteFailed => 'No se pudo eliminar';

  @override
  String get playlistOptions => 'Opciones de la lista';

  @override
  String get emptyPlaylistHint =>
      'Lista vacía. Mantén presionada cualquier canción y elige \"Agregar a una lista\".';

  @override
  String playlistLoadFailed(String error) {
    return 'No se pudo cargar la lista\n$error';
  }

  @override
  String get playlistName => 'Nombre de la lista';

  @override
  String downloadingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargando $count canciones…',
      one: 'Descargando 1 canción…',
    );
    return '$_temp0';
  }

  @override
  String get noDownloadsYet =>
      'Aún no hay descargas. Usa \"Descargar\" en una canción, álbum o lista para escuchar sin conexión.';

  @override
  String downloadsLoadFailed(String error) {
    return 'No se pudieron leer las descargas\n$error';
  }

  @override
  String get back => 'Atrás';

  @override
  String get nowPlaying => 'Reproduciendo';

  @override
  String get queue => 'Cola';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get nothingPlaying => 'No se está reproduciendo nada';

  @override
  String get repeatOff => 'Repetir: no';

  @override
  String get repeatAll => 'Repetir: todo';

  @override
  String get repeatOne => 'Repetir: una';

  @override
  String get previous => 'Anterior';

  @override
  String get next => 'Siguiente';

  @override
  String get pause => 'Pausa';

  @override
  String get lyrics => 'Letra';

  @override
  String get noLyrics => 'Esta canción no tiene letra';

  @override
  String lyricsTitle(String title) {
    return 'Letra · $title';
  }

  @override
  String get lyricsLoadFailed => 'No se pudo cargar la letra';

  @override
  String get seek => 'Buscar posición';

  @override
  String get navHome => 'Inicio';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navStats => 'Estadísticas';

  @override
  String get browseDeviceMusic => 'Ver la música de este dispositivo';

  @override
  String get statsServerTitle => 'Las estadísticas están en tu servidor';

  @override
  String get statsServerMessage =>
      'Tu servidor de música calcula las estadísticas de escucha. Conecta uno para verlas.';

  @override
  String get yourStats => 'Tus estadísticas';

  @override
  String statsLoadFailed(String error) {
    return 'No se pudieron cargar las estadísticas\n$error';
  }

  @override
  String get listeningTime => 'Tiempo de escucha';

  @override
  String get totalPlays => 'Reproducciones';

  @override
  String get uniqueTracks => 'Canciones distintas';

  @override
  String get ofPlays => 'de las reproducciones';

  @override
  String get noPlaysYet => 'Aún no hay reproducciones';

  @override
  String get topArtist => 'Artista principal';

  @override
  String get daily => 'Diario';

  @override
  String get minutesListened => 'minutos escuchados';

  @override
  String get topTracks => 'Canciones más escuchadas';

  @override
  String get topTracksEmpty =>
      'Reproduce música para ver tus canciones más escuchadas.';

  @override
  String get range7Days => '7 días';

  @override
  String get range30Days => '30 días';

  @override
  String get rangeAllTime => 'Siempre';

  @override
  String get chooseMusicFolder => 'Elige una carpeta de música';

  @override
  String get importMusic => 'Importar música';

  @override
  String get playbackChannelName => 'Reproducción de Qodi Music';
}
