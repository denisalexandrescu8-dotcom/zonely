// Textos de los motores (menús, avisos y selector de perfiles), en los mismos idiomas que el panel.
// El texto en español es la clave. Cada fila: [español, inglés, francés, alemán, portugués, italiano].
// `{nombre}` es un dato que se sustituye al mostrar el texto. Tras editar esto, ejecuta:  node scripts/gen-strings.js
// (genera lib/Strings.ahk para Windows y mac/Sources/ZonelyCore/Strings.swift para macOS).
const ORDER = ['es', 'en', 'fr', 'de', 'pt', 'it'];
const ROWS = [
  // ---- menú de la bandeja / barra de menús ----
  ['Abrir Zonely', 'Open Zonely', 'Ouvrir Zonely', 'Zonely öffnen', 'Abrir o Zonely', 'Apri Zonely'],
  ['Perfiles', 'Profiles', 'Profils', 'Profile', 'Perfis', 'Profili'],
  ['Vigilante de maximizado', 'Maximize watcher', 'Surveillant de maximisation', 'Maximierungs-Wächter', 'Vigia de maximização', 'Sorvegliante della massimizzazione'],
  ['Pausar atajos', 'Pause shortcuts', 'Mettre les raccourcis en pause', 'Kürzel pausieren', 'Pausar atalhos', 'Metti in pausa le scorciatoie'],
  ['Salir', 'Quit', 'Quitter', 'Beenden', 'Sair', 'Esci'],
  ['{name} (PAUSADO)', '{name} (PAUSED)', '{name} (EN PAUSE)', '{name} (PAUSIERT)', '{name} (EM PAUSA)', '{name} (IN PAUSA)'],
  ['Abrir al iniciar sesión', 'Open at login', 'Ouvrir à l’ouverture de session', 'Beim Anmelden öffnen', 'Abrir ao iniciar sessão', 'Apri all’avvio della sessione'],
  ['Permiso de Accesibilidad…', 'Accessibility permission…', 'Autorisation d’accessibilité…', 'Bedienungshilfen-Berechtigung …', 'Permissão de Acessibilidade…', 'Permesso di Accessibilità…'],
  ['Abrir carpeta de datos', 'Open data folder', 'Ouvrir le dossier de données', 'Datenordner öffnen', 'Abrir pasta de dados', 'Apri la cartella dei dati'],
  ['Abre Zonely desde la carpeta Aplicaciones', 'Open Zonely from the Applications folder', 'Ouvrez Zonely depuis le dossier Applications', 'Öffne Zonely aus dem Ordner „Programme“', 'Abra o Zonely a partir da pasta Aplicativos', 'Apri Zonely dalla cartella Applicazioni'],
  ['Falta el permiso de Accesibilidad (menú de Zonely)', 'Accessibility permission missing (Zonely menu)', 'Autorisation d’accessibilité manquante (menu de Zonely)', 'Bedienungshilfen-Berechtigung fehlt (Zonely-Menü)', 'Falta a permissão de Acessibilidade (menu do Zonely)', 'Manca il permesso di Accessibilità (menu di Zonely)'],
  ['No encuentro el panel de Zonely', 'I can’t find the Zonely panel', 'Je ne trouve pas le panneau de Zonely', 'Ich finde das Zonely-Panel nicht', 'Não encontro o painel do Zonely', 'Non trovo il pannello di Zonely'],

  // ---- avisos ----
  ['Vigilante activado', 'Watcher on', 'Surveillant activé', 'Wächter an', 'Vigia ativado', 'Sorvegliante attivato'],
  ['Vigilante desactivado', 'Watcher off', 'Surveillant désactivé', 'Wächter aus', 'Vigia desativado', 'Sorvegliante disattivato'],
  ['El vigilante ignora esta ventana (se maximiza sola)', 'The watcher ignores this window (it maximizes itself)', 'Le surveillant ignore cette fenêtre (elle se maximise seule)', 'Der Wächter ignoriert dieses Fenster (es maximiert sich selbst)', 'O vigia ignora esta janela (ela se maximiza sozinha)', 'Il sorvegliante ignora questa finestra (si massimizza da sola)'],
  ['El perfil «{name}» no tiene zonas', 'The profile “{name}” has no zones', 'Le profil « {name} » n’a pas de zones', 'Das Profil „{name}“ hat keine Zonen', 'O perfil “{name}” não tem zonas', 'Il profilo «{name}» non ha zone'],
  ['No hay ventana gestionable', 'No manageable window', 'Aucune fenêtre gérable', 'Kein verwaltbares Fenster', 'Não há janela gerenciável', 'Nessuna finestra gestibile'],
  ['Capa oscura sobre la zona {zones}', 'Dim layer over zone {zones}', 'Calque sombre sur la zone {zones}', 'Abdunkelung über Zone {zones}', 'Camada escura sobre a zona {zones}', 'Strato scuro sulla zona {zones}'],
  ['Modo juego (tamaño conservado): {w}x{h}', 'Game mode (size kept): {w}x{h}', 'Mode jeu (taille conservée) : {w}x{h}', 'Spielmodus (Größe beibehalten): {w}x{h}', 'Modo jogo (tamanho mantido): {w}x{h}', 'Modalità gioco (dimensione mantenuta): {w}x{h}'],
  ['Modo juego: {w}x{h}', 'Game mode: {w}x{h}', 'Mode jeu : {w}x{h}', 'Spielmodus: {w}x{h}', 'Modo jogo: {w}x{h}', 'Modalità gioco: {w}x{h}'],
  ['Modo juego (tamaño conservado)', 'Game mode (size kept)', 'Mode jeu (taille conservée)', 'Spielmodus (Größe beibehalten)', 'Modo jogo (tamanho mantido)', 'Modalità gioco (dimensione mantenuta)'],
  ['Modo juego', 'Game mode', 'Mode jeu', 'Spielmodus', 'Modo jogo', 'Modalità gioco'],
  ['Ventana restaurada', 'Window restored', 'Fenêtre restaurée', 'Fenster wiederhergestellt', 'Janela restaurada', 'Finestra ripristinata'],
  ['Está en modo juego: sal con el atajo del modo juego', 'It’s in game mode: leave with the game mode shortcut', 'Elle est en mode jeu : quittez avec le raccourci du mode jeu', 'Es ist im Spielmodus: Beende ihn mit dem Spielmodus-Kürzel', 'Está em modo jogo: saia com o atalho do modo jogo', 'È in modalità gioco: esci con la scorciatoia della modalità gioco'],
  ['No tengo guardado el tamaño original de esta ventana', 'I don’t have this window’s original size saved', 'Je n’ai pas enregistré la taille d’origine de cette fenêtre', 'Die Originalgröße dieses Fensters ist nicht gespeichert', 'Não tenho guardado o tamanho original desta janela', 'Non ho salvato la dimensione originale di questa finestra'],
  ['La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})', 'The window ({w}x{h}) is bigger than zone {zone} ({zw}x{zh})', 'La fenêtre ({w}x{h}) est plus grande que la zone {zone} ({zw}x{zh})', 'Das Fenster ({w}x{h}) ist größer als Zone {zone} ({zw}x{zh})', 'A janela ({w}x{h}) é maior que a zona {zone} ({zw}x{zh})', 'La finestra ({w}x{h}) è più grande della zona {zone} ({zw}x{zh})'],
  ['Colocación deshecha', 'Placement undone', 'Placement annulé', 'Platzierung rückgängig gemacht', 'Colocação desfeita', 'Posizionamento annullato'],
  ['Nada que deshacer', 'Nothing to undo', 'Rien à annuler', 'Nichts rückgängig zu machen', 'Nada para desfazer', 'Niente da annullare'],
  ['Las mitades solo funcionan en la zona B', 'Halves only work in zone B', 'Les moitiés ne fonctionnent que dans la zone B', 'Hälften funktionieren nur in Zone B', 'As metades só funcionam na zona B', 'Le metà funzionano solo nella zona B'],
  ['zones.ini no es válido: {error}', 'zones.ini is not valid: {error}', 'zones.ini n’est pas valide : {error}', 'zones.ini ist ungültig: {error}', 'zones.ini não é válido: {error}', 'zones.ini non è valido: {error}'],
  ['Error en zones.ini:', 'Error in zones.ini:', 'Erreur dans zones.ini :', 'Fehler in zones.ini:', 'Erro no zones.ini:', 'Errore in zones.ini:'],
  ['Error interno: mira el registro del panel', 'Internal error: see the panel log', 'Erreur interne : consultez le journal du panneau', 'Interner Fehler: siehe Protokoll im Panel', 'Erro interno: veja o registro do painel', 'Errore interno: guarda il registro del pannello'],

  // ---- selector de perfiles y aviso de perfil aplicado ----
  ['Elegir perfil', 'Choose profile', 'Choisir le profil', 'Profil wählen', 'Escolher perfil', 'Scegli profilo'],
  ['Monitor: {name}', 'Monitor: {name}', 'Écran : {name}', 'Monitor: {name}', 'Monitor: {name}', 'Monitor: {name}'],
  ['Aplica una distribución de zonas a tu pantalla.', 'Apply a zone layout to your screen.', 'Applique une répartition de zones à votre écran.', 'Wendet eine Zonenaufteilung auf deinen Bildschirm an.', 'Aplica uma divisão de zonas à sua tela.', 'Applica una suddivisione in zone al tuo schermo.'],
  ['Esc para cerrar', 'Esc to close', 'Échap pour fermer', 'Esc zum Schließen', 'Esc para fechar', 'Esc per chiudere'],
  ['Aplicar', 'Apply', 'Appliquer', 'Anwenden', 'Aplicar', 'Applica'],
  ['Aplicado', 'Applied', 'Appliqué', 'Angewendet', 'Aplicado', 'Applicato'],
  ['Perfil aplicado', 'Profile applied', 'Profil appliqué', 'Profil angewendet', 'Perfil aplicado', 'Profilo applicato'],
  ['●  Activo ahora', '●  Active now', '●  Actif maintenant', '●  Jetzt aktiv', '●  Ativo agora', '●  Attivo ora'],
  ['pantalla completa, sin zonas', 'full screen, no zones', 'plein écran, sans zones', 'Vollbild, ohne Zonen', 'tela cheia, sem zonas', 'schermo intero, senza zone'],
  ['Pantalla completa, sin zonas', 'Full screen, no zones', 'Plein écran, sans zones', 'Vollbild, ohne Zonen', 'Tela cheia, sem zonas', 'Schermo intero, senza zone'],
];
module.exports = { ORDER, ROWS };
