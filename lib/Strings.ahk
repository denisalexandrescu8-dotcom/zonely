#Requires AutoHotkey v2.0
; ============================================================
;  Strings.ahk - Textos del motor en cada idioma. GENERADO por scripts/gen-strings.js desde i18n/engine.js: no editar a mano.
;  T("texto en español", "dato", valor, ...) devuelve el texto en el idioma elegido ([General] Language de zones.ini; auto = el del sistema).
; ============================================================

#Include %A_LineFile%\..\Paths.ahk      ; DataDir

StringsTable := Map(
    "en", Map(
        "Abrir Zonely", "Open Zonely",
        "Perfiles", "Profiles",
        "Vigilante de maximizado", "Maximize watcher",
        "Pausar atajos", "Pause shortcuts",
        "Salir", "Quit",
        "{name} (PAUSADO)", "{name} (PAUSED)",
        "Abrir al iniciar sesión", "Open at login",
        "Permiso de Accesibilidad…", "Accessibility permission…",
        "Abrir carpeta de datos", "Open data folder",
        "Abre Zonely desde la carpeta Aplicaciones", "Open Zonely from the Applications folder",
        "Falta el permiso de Accesibilidad (menú de Zonely)", "Accessibility permission missing (Zonely menu)",
        "No encuentro el panel de Zonely", "I can’t find the Zonely panel",
        "Vigilante activado", "Watcher on",
        "Vigilante desactivado", "Watcher off",
        "El vigilante ignora esta ventana (se maximiza sola)", "The watcher ignores this window (it maximizes itself)",
        "El perfil «{name}» no tiene zonas", "The profile “{name}” has no zones",
        "No hay ventana gestionable", "No manageable window",
        "Capa oscura sobre la zona {zones}", "Dim layer over zone {zones}",
        "Modo juego (tamaño conservado): {w}x{h}", "Game mode (size kept): {w}x{h}",
        "Modo juego: {w}x{h}", "Game mode: {w}x{h}",
        "Modo juego (tamaño conservado)", "Game mode (size kept)",
        "Modo juego", "Game mode",
        "Ventana restaurada", "Window restored",
        "Está en modo juego: sal con el atajo del modo juego", "It’s in game mode: leave with the game mode shortcut",
        "No tengo guardado el tamaño original de esta ventana", "I don’t have this window’s original size saved",
        "La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})", "The window ({w}x{h}) is bigger than zone {zone} ({zw}x{zh})",
        "Colocación deshecha", "Placement undone",
        "Nada que deshacer", "Nothing to undo",
        "Las mitades solo funcionan en la zona B", "Halves only work in zone B",
        "zones.ini no es válido: {error}", "zones.ini is not valid: {error}",
        "Error en zones.ini:", "Error in zones.ini:",
        "Error interno: mira el registro del panel", "Internal error: see the panel log",
        "Elegir perfil", "Choose profile",
        "Aplica una distribución de zonas a tu pantalla.", "Apply a zone layout to your screen.",
        "Esc para cerrar", "Esc to close",
        "Aplicar", "Apply",
        "Aplicado", "Applied",
        "Perfil aplicado", "Profile applied",
        "●  Activo ahora", "●  Active now",
        "pantalla completa, sin zonas", "full screen, no zones",
        "Pantalla completa, sin zonas", "Full screen, no zones"
    ),
    "fr", Map(
        "Abrir Zonely", "Ouvrir Zonely",
        "Perfiles", "Profils",
        "Vigilante de maximizado", "Surveillant de maximisation",
        "Pausar atajos", "Mettre les raccourcis en pause",
        "Salir", "Quitter",
        "{name} (PAUSADO)", "{name} (EN PAUSE)",
        "Abrir al iniciar sesión", "Ouvrir à l’ouverture de session",
        "Permiso de Accesibilidad…", "Autorisation d’accessibilité…",
        "Abrir carpeta de datos", "Ouvrir le dossier de données",
        "Abre Zonely desde la carpeta Aplicaciones", "Ouvrez Zonely depuis le dossier Applications",
        "Falta el permiso de Accesibilidad (menú de Zonely)", "Autorisation d’accessibilité manquante (menu de Zonely)",
        "No encuentro el panel de Zonely", "Je ne trouve pas le panneau de Zonely",
        "Vigilante activado", "Surveillant activé",
        "Vigilante desactivado", "Surveillant désactivé",
        "El vigilante ignora esta ventana (se maximiza sola)", "Le surveillant ignore cette fenêtre (elle se maximise seule)",
        "El perfil «{name}» no tiene zonas", "Le profil « {name} » n’a pas de zones",
        "No hay ventana gestionable", "Aucune fenêtre gérable",
        "Capa oscura sobre la zona {zones}", "Calque sombre sur la zone {zones}",
        "Modo juego (tamaño conservado): {w}x{h}", "Mode jeu (taille conservée) : {w}x{h}",
        "Modo juego: {w}x{h}", "Mode jeu : {w}x{h}",
        "Modo juego (tamaño conservado)", "Mode jeu (taille conservée)",
        "Modo juego", "Mode jeu",
        "Ventana restaurada", "Fenêtre restaurée",
        "Está en modo juego: sal con el atajo del modo juego", "Elle est en mode jeu : quittez avec le raccourci du mode jeu",
        "No tengo guardado el tamaño original de esta ventana", "Je n’ai pas enregistré la taille d’origine de cette fenêtre",
        "La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})", "La fenêtre ({w}x{h}) est plus grande que la zone {zone} ({zw}x{zh})",
        "Colocación deshecha", "Placement annulé",
        "Nada que deshacer", "Rien à annuler",
        "Las mitades solo funcionan en la zona B", "Les moitiés ne fonctionnent que dans la zone B",
        "zones.ini no es válido: {error}", "zones.ini n’est pas valide : {error}",
        "Error en zones.ini:", "Erreur dans zones.ini :",
        "Error interno: mira el registro del panel", "Erreur interne : consultez le journal du panneau",
        "Elegir perfil", "Choisir le profil",
        "Aplica una distribución de zonas a tu pantalla.", "Applique une répartition de zones à votre écran.",
        "Esc para cerrar", "Échap pour fermer",
        "Aplicar", "Appliquer",
        "Aplicado", "Appliqué",
        "Perfil aplicado", "Profil appliqué",
        "●  Activo ahora", "●  Actif maintenant",
        "pantalla completa, sin zonas", "plein écran, sans zones",
        "Pantalla completa, sin zonas", "Plein écran, sans zones"
    ),
    "de", Map(
        "Abrir Zonely", "Zonely öffnen",
        "Perfiles", "Profile",
        "Vigilante de maximizado", "Maximierungs-Wächter",
        "Pausar atajos", "Kürzel pausieren",
        "Salir", "Beenden",
        "{name} (PAUSADO)", "{name} (PAUSIERT)",
        "Abrir al iniciar sesión", "Beim Anmelden öffnen",
        "Permiso de Accesibilidad…", "Bedienungshilfen-Berechtigung …",
        "Abrir carpeta de datos", "Datenordner öffnen",
        "Abre Zonely desde la carpeta Aplicaciones", "Öffne Zonely aus dem Ordner „Programme“",
        "Falta el permiso de Accesibilidad (menú de Zonely)", "Bedienungshilfen-Berechtigung fehlt (Zonely-Menü)",
        "No encuentro el panel de Zonely", "Ich finde das Zonely-Panel nicht",
        "Vigilante activado", "Wächter an",
        "Vigilante desactivado", "Wächter aus",
        "El vigilante ignora esta ventana (se maximiza sola)", "Der Wächter ignoriert dieses Fenster (es maximiert sich selbst)",
        "El perfil «{name}» no tiene zonas", "Das Profil „{name}“ hat keine Zonen",
        "No hay ventana gestionable", "Kein verwaltbares Fenster",
        "Capa oscura sobre la zona {zones}", "Abdunkelung über Zone {zones}",
        "Modo juego (tamaño conservado): {w}x{h}", "Spielmodus (Größe beibehalten): {w}x{h}",
        "Modo juego: {w}x{h}", "Spielmodus: {w}x{h}",
        "Modo juego (tamaño conservado)", "Spielmodus (Größe beibehalten)",
        "Modo juego", "Spielmodus",
        "Ventana restaurada", "Fenster wiederhergestellt",
        "Está en modo juego: sal con el atajo del modo juego", "Es ist im Spielmodus: Beende ihn mit dem Spielmodus-Kürzel",
        "No tengo guardado el tamaño original de esta ventana", "Die Originalgröße dieses Fensters ist nicht gespeichert",
        "La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})", "Das Fenster ({w}x{h}) ist größer als Zone {zone} ({zw}x{zh})",
        "Colocación deshecha", "Platzierung rückgängig gemacht",
        "Nada que deshacer", "Nichts rückgängig zu machen",
        "Las mitades solo funcionan en la zona B", "Hälften funktionieren nur in Zone B",
        "zones.ini no es válido: {error}", "zones.ini ist ungültig: {error}",
        "Error en zones.ini:", "Fehler in zones.ini:",
        "Error interno: mira el registro del panel", "Interner Fehler: siehe Protokoll im Panel",
        "Elegir perfil", "Profil wählen",
        "Aplica una distribución de zonas a tu pantalla.", "Wendet eine Zonenaufteilung auf deinen Bildschirm an.",
        "Esc para cerrar", "Esc zum Schließen",
        "Aplicar", "Anwenden",
        "Aplicado", "Angewendet",
        "Perfil aplicado", "Profil angewendet",
        "●  Activo ahora", "●  Jetzt aktiv",
        "pantalla completa, sin zonas", "Vollbild, ohne Zonen",
        "Pantalla completa, sin zonas", "Vollbild, ohne Zonen"
    ),
    "pt", Map(
        "Abrir Zonely", "Abrir o Zonely",
        "Perfiles", "Perfis",
        "Vigilante de maximizado", "Vigia de maximização",
        "Pausar atajos", "Pausar atalhos",
        "Salir", "Sair",
        "{name} (PAUSADO)", "{name} (EM PAUSA)",
        "Abrir al iniciar sesión", "Abrir ao iniciar sessão",
        "Permiso de Accesibilidad…", "Permissão de Acessibilidade…",
        "Abrir carpeta de datos", "Abrir pasta de dados",
        "Abre Zonely desde la carpeta Aplicaciones", "Abra o Zonely a partir da pasta Aplicativos",
        "Falta el permiso de Accesibilidad (menú de Zonely)", "Falta a permissão de Acessibilidade (menu do Zonely)",
        "No encuentro el panel de Zonely", "Não encontro o painel do Zonely",
        "Vigilante activado", "Vigia ativado",
        "Vigilante desactivado", "Vigia desativado",
        "El vigilante ignora esta ventana (se maximiza sola)", "O vigia ignora esta janela (ela se maximiza sozinha)",
        "El perfil «{name}» no tiene zonas", "O perfil “{name}” não tem zonas",
        "No hay ventana gestionable", "Não há janela gerenciável",
        "Capa oscura sobre la zona {zones}", "Camada escura sobre a zona {zones}",
        "Modo juego (tamaño conservado): {w}x{h}", "Modo jogo (tamanho mantido): {w}x{h}",
        "Modo juego: {w}x{h}", "Modo jogo: {w}x{h}",
        "Modo juego (tamaño conservado)", "Modo jogo (tamanho mantido)",
        "Modo juego", "Modo jogo",
        "Ventana restaurada", "Janela restaurada",
        "Está en modo juego: sal con el atajo del modo juego", "Está em modo jogo: saia com o atalho do modo jogo",
        "No tengo guardado el tamaño original de esta ventana", "Não tenho guardado o tamanho original desta janela",
        "La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})", "A janela ({w}x{h}) é maior que a zona {zone} ({zw}x{zh})",
        "Colocación deshecha", "Colocação desfeita",
        "Nada que deshacer", "Nada para desfazer",
        "Las mitades solo funcionan en la zona B", "As metades só funcionam na zona B",
        "zones.ini no es válido: {error}", "zones.ini não é válido: {error}",
        "Error en zones.ini:", "Erro no zones.ini:",
        "Error interno: mira el registro del panel", "Erro interno: veja o registro do painel",
        "Elegir perfil", "Escolher perfil",
        "Aplica una distribución de zonas a tu pantalla.", "Aplica uma divisão de zonas à sua tela.",
        "Esc para cerrar", "Esc para fechar",
        "Aplicar", "Aplicar",
        "Aplicado", "Aplicado",
        "Perfil aplicado", "Perfil aplicado",
        "●  Activo ahora", "●  Ativo agora",
        "pantalla completa, sin zonas", "tela cheia, sem zonas",
        "Pantalla completa, sin zonas", "Tela cheia, sem zonas"
    ),
    "it", Map(
        "Abrir Zonely", "Apri Zonely",
        "Perfiles", "Profili",
        "Vigilante de maximizado", "Sorvegliante della massimizzazione",
        "Pausar atajos", "Metti in pausa le scorciatoie",
        "Salir", "Esci",
        "{name} (PAUSADO)", "{name} (IN PAUSA)",
        "Abrir al iniciar sesión", "Apri all’avvio della sessione",
        "Permiso de Accesibilidad…", "Permesso di Accessibilità…",
        "Abrir carpeta de datos", "Apri la cartella dei dati",
        "Abre Zonely desde la carpeta Aplicaciones", "Apri Zonely dalla cartella Applicazioni",
        "Falta el permiso de Accesibilidad (menú de Zonely)", "Manca il permesso di Accessibilità (menu di Zonely)",
        "No encuentro el panel de Zonely", "Non trovo il pannello di Zonely",
        "Vigilante activado", "Sorvegliante attivato",
        "Vigilante desactivado", "Sorvegliante disattivato",
        "El vigilante ignora esta ventana (se maximiza sola)", "Il sorvegliante ignora questa finestra (si massimizza da sola)",
        "El perfil «{name}» no tiene zonas", "Il profilo «{name}» non ha zone",
        "No hay ventana gestionable", "Nessuna finestra gestibile",
        "Capa oscura sobre la zona {zones}", "Strato scuro sulla zona {zones}",
        "Modo juego (tamaño conservado): {w}x{h}", "Modalità gioco (dimensione mantenuta): {w}x{h}",
        "Modo juego: {w}x{h}", "Modalità gioco: {w}x{h}",
        "Modo juego (tamaño conservado)", "Modalità gioco (dimensione mantenuta)",
        "Modo juego", "Modalità gioco",
        "Ventana restaurada", "Finestra ripristinata",
        "Está en modo juego: sal con el atajo del modo juego", "È in modalità gioco: esci con la scorciatoia della modalità gioco",
        "No tengo guardado el tamaño original de esta ventana", "Non ho salvato la dimensione originale di questa finestra",
        "La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})", "La finestra ({w}x{h}) è più grande della zona {zone} ({zw}x{zh})",
        "Colocación deshecha", "Posizionamento annullato",
        "Nada que deshacer", "Niente da annullare",
        "Las mitades solo funcionan en la zona B", "Le metà funzionano solo nella zona B",
        "zones.ini no es válido: {error}", "zones.ini non è valido: {error}",
        "Error en zones.ini:", "Errore in zones.ini:",
        "Error interno: mira el registro del panel", "Errore interno: guarda il registro del pannello",
        "Elegir perfil", "Scegli profilo",
        "Aplica una distribución de zonas a tu pantalla.", "Applica una suddivisione in zone al tuo schermo.",
        "Esc para cerrar", "Esc per chiudere",
        "Aplicar", "Applica",
        "Aplicado", "Applicato",
        "Perfil aplicado", "Profilo applicato",
        "●  Activo ahora", "●  Attivo ora",
        "pantalla completa, sin zonas", "schermo intero, senza zone",
        "Pantalla completa, sin zonas", "Schermo intero, senza zone"
    )
)

; Idioma de los textos: el de zones.ini o, en automático, el de Windows (A_Language es el LCID en hexadecimal).
ResolveLanguage() {
    chosen := "auto"
    try chosen := IniRead(DataDir "\zones.ini", "General", "Language", "auto")
    if chosen != "auto" && StringsTable.Has(chosen) || chosen = "es"
        return chosen
    switch Integer("0x" A_Language) & 0x3FF {      ; identificador del idioma principal
        case 0x0A: return "es"
        case 0x0C: return "fr"
        case 0x07: return "de"
        case 0x16: return "pt"
        case 0x10: return "it"
        default: return "en"
    }
}
Language := ResolveLanguage()

T(text, vars*) {
    out := text
    if StringsTable.Has(Language) && StringsTable[Language].Has(text)
        out := StringsTable[Language][text]
    i := 1
    while i < vars.Length {
        out := StrReplace(out, "{" vars[i] "}", vars[i + 1])
        i += 2
    }
    return out
}
