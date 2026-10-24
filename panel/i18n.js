// Idiomas del panel. El texto en español de la interfaz es la clave del diccionario (panel/locales.js): al arrancar se
// traducen los textos y atributos de la página, y el JS que construye textos usa t('texto español', { dato }).
// El idioma sale de [General] Language en zones.ini (auto = el del sistema) y lo resuelve el proceso principal.
const LANGUAGES = [['auto', null], ['es', 'Español'], ['en', 'English'], ['fr', 'Français'], ['de', 'Deutsch'], ['pt', 'Português'], ['it', 'Italiano']];
const LANG = (window.zones && window.zones.lang) || 'es';
const I18N_MAC = /Mac/i.test(navigator.platform || navigator.userAgent || '');

// En macOS los atajos de fábrica son ⌃⌥ + tecla: los textos que dicen «Win+Alt+X» se adaptan.
function macKeys(text) {
  if (!I18N_MAC) return text;
  return text.replace(/Win\+Alt\+(?:(?:Mayús|Shift|Maj|Umschalt|Maiusc)\+)?(\w)/g, (m, k) => (/\+(?:Mayús|Shift|Maj|Umschalt|Maiusc)\+/.test(m) ? '⌃⌥⇧' : '⌃⌥') + k.toUpperCase());
}

// Traduce un texto español (con {datos} opcionales). Si no hay traducción, se devuelve tal cual.
function t(text, vars) {
  let out = (LOCALES[LANG] && LOCALES[LANG][text]) || text;
  if (vars) out = out.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m));
  return macKeys(out);
}

// Traduce los nodos de texto y los atributos title, placeholder, aria-label y alt de una parte de la página.
const I18N_ATTRS = ['title', 'placeholder', 'aria-label', 'alt'];
function i18nApply(root = document.body) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    if (!n.parentElement || /^(SCRIPT|STYLE)$/.test(n.parentElement.tagName)) continue;
    const raw = n.nodeValue;
    const key = raw.replace(/\s+/g, ' ').trim();
    if (!key) continue;
    const out = t(key);
    if (out !== key || I18N_MAC) n.nodeValue = raw.replace(key.length ? /\S[\s\S]*\S|\S/ : /^$/, () => out);
  }
  for (const attr of I18N_ATTRS) {
    for (const el of root.querySelectorAll(`[${attr}]`)) {
      const key = el.getAttribute(attr).replace(/\s+/g, ' ').trim();
      const out = t(key);
      if (out !== key) el.setAttribute(attr, out);
    }
  }
}

document.documentElement.lang = LANG;
i18nApply();
