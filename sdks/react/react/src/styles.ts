/**
 * Plain CSS with a prefix, so the widget looks the same in any host app and needs no build setup.
 *
 * Restyle it with CSS variables on any ancestor (or `:root`), or target the stable `seaproof-*`
 * classes. Every rule is wrapped in `:where()`, so any selector of yours wins without `!important`.
 *
 * Variables: --seaproof-primary, --seaproof-on-primary, --seaproof-surface, --seaproof-surface-sunken,
 * --seaproof-text, --seaproof-text-muted, --seaproof-border, --seaproof-border-strong,
 * --seaproof-error, --seaproof-focus, --seaproof-radius, --seaproof-font, --seaproof-backdrop,
 * --seaproof-shadow, --seaproof-z-index.
 *
 * The colour set in the Seaproof admin arrives as --seaproof-brand-primary and
 * --seaproof-brand-on-primary, used only when the app sets no --seaproof-primary.
 *
 * Light and dark follow the `colorScheme` prop (`data-seaproof-theme` on the root). The defaults are
 * Seaproof's own tokens; see docs/design/tokens.md.
 */
export const css = `
:where(.seaproof-root){
  --_primary:var(--seaproof-primary,var(--seaproof-brand-primary,#0b3d5c));--_on-primary:var(--seaproof-on-primary,var(--seaproof-brand-on-primary,#fff));
  --_surface:var(--seaproof-surface,#fff);--_sunken:var(--seaproof-surface-sunken,#edf2f5);
  --_text:var(--seaproof-text,#0a1f2e);--_muted:var(--seaproof-text-muted,#4f6475);
  --_border:var(--seaproof-border,#d3dde5);--_border-strong:var(--seaproof-border-strong,#7a909f);
  --_error:var(--seaproof-error,#b42318);--_focus:var(--seaproof-focus,#e8590c);--_link:var(--seaproof-link,#145a85);
  --_radius:var(--seaproof-radius,22px);--_font:var(--seaproof-font,Inter,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif);
  --_mono:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;--_z:var(--seaproof-z-index,2147483000);
  --_raised:var(--_surface);--_ink:#0a1f2e;--_signal:#e8590c;--_recording:#ff5b4a;
  --_bug:#b42318;--_bug-tint:#fdecea;--_feedback:#1b649f;--_feedback-tint:#e8f1fa;
  --_idea:#8a5300;--_idea-tint:#fdf3de;--_question:#0b6e61;--_question-tint:#e2f4f1;
  --_ease:cubic-bezier(.2,.8,.2,1);--_swell:cubic-bezier(.32,.72,0,1)}
:where(.seaproof-root[data-seaproof-theme=dark]){
  --_primary:var(--seaproof-primary,var(--seaproof-brand-primary,#5bb4e8));--_on-primary:var(--seaproof-on-primary,var(--seaproof-brand-on-primary,#04202f));
  --_surface:var(--seaproof-surface,#0e2230);--_sunken:var(--seaproof-surface-sunken,#0a1a25);
  --_text:var(--seaproof-text,#e8f0f5);--_muted:var(--seaproof-text-muted,#9db2c2);
  --_border:var(--seaproof-border,#22405a);--_border-strong:var(--seaproof-border-strong,#5c7a92);
  --_error:var(--seaproof-error,#ff8a7a);--_focus:var(--seaproof-focus,#ff8a3d);--_link:var(--seaproof-link,#7db8f0);--_raised:#1a3346;
  --_bug:#ff8a7a;--_bug-tint:rgba(255,138,122,.12);--_feedback:#7db8f0;--_feedback-tint:rgba(125,184,240,.12);
  --_idea:#f2c14e;--_idea-tint:rgba(242,193,78,.12);--_question:#5fd3bf;--_question-tint:rgba(95,211,191,.12)}
@media (prefers-color-scheme:dark){:where(.seaproof-root[data-seaproof-theme=auto]){
  --_primary:var(--seaproof-primary,var(--seaproof-brand-primary,#5bb4e8));--_on-primary:var(--seaproof-on-primary,var(--seaproof-brand-on-primary,#04202f));
  --_surface:var(--seaproof-surface,#0e2230);--_sunken:var(--seaproof-surface-sunken,#0a1a25);
  --_text:var(--seaproof-text,#e8f0f5);--_muted:var(--seaproof-text-muted,#9db2c2);
  --_border:var(--seaproof-border,#22405a);--_border-strong:var(--seaproof-border-strong,#5c7a92);
  --_error:var(--seaproof-error,#ff8a7a);--_focus:var(--seaproof-focus,#ff8a3d);--_link:var(--seaproof-link,#7db8f0);--_raised:#1a3346;
  --_bug:#ff8a7a;--_bug-tint:rgba(255,138,122,.12);--_feedback:#7db8f0;--_feedback-tint:rgba(125,184,240,.12);
  --_idea:#f2c14e;--_idea-tint:rgba(242,193,78,.12);--_question:#5fd3bf;--_question-tint:rgba(95,211,191,.12)}}

:where(.seaproof-root) :where(*,*::before,*::after){box-sizing:border-box}
:where(.seaproof-root) :where(button,a,input,textarea,[tabindex]):focus-visible{outline:2px solid var(--_focus);outline-offset:2px}
:where(.seaproof-icon){flex:none;display:block}
:where(.seaproof-visually-hidden){position:absolute;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0}

:where(.seaproof-launcher){position:fixed;right:20px;bottom:20px;z-index:var(--_z);display:inline-flex;align-items:center;gap:8px;min-height:44px;
  border:0;border-radius:999px;padding:0 18px 0 14px;background:var(--_primary);color:var(--_on-primary);font:600 14px/1 var(--_font);
  box-shadow:0 4px 12px rgba(6,32,47,.18),0 1px 3px rgba(6,32,47,.08);cursor:pointer;transition:transform .2s var(--_ease),filter .2s var(--_ease)}
:where(.seaproof-launcher[data-position$="-left"]){left:20px;right:auto}
:where(.seaproof-launcher[data-position^="top-"]){top:20px;bottom:auto}
:where(.seaproof-launcher[data-position^="middle-"]){top:50%;bottom:auto;translate:0 -50%}
:where(.seaproof-launcher){max-width:calc(100vw - 40px);max-height:calc(100dvh - 40px)}
:where(.seaproof-launcher-label){overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
:where(.seaproof-launcher[data-orientation="vertical"]){flex-direction:column;min-width:44px;padding:14px 0}
:where(.seaproof-launcher[data-orientation="vertical"] .seaproof-launcher-label){writing-mode:vertical-rl}
:where(.seaproof-launcher[data-orientation="vertical"] .seaproof-launcher-tag){margin:0}
:where(.seaproof-launcher:hover){filter:brightness(1.15);transform:translateY(-1px)}
:where(.seaproof-launcher-tag){font:600 11px/1 var(--_mono);letter-spacing:.06em;background:#ffe8d9;color:#8a3306;border-radius:999px;padding:4px 8px;margin-right:-8px}
:where(.seaproof-launcher-dot){position:absolute;top:-2px;right:-2px;width:14px;height:14px;border-radius:999px;background:var(--_signal);border:2px solid var(--_surface)}

:where(.seaproof-backdrop){position:fixed;inset:0;z-index:calc(var(--_z) + 1);background:var(--seaproof-backdrop,rgba(6,32,47,.32));display:flex;align-items:flex-end;justify-content:flex-end;padding:20px 20px 84px}
:where(.seaproof-panel){position:relative;width:min(400px,100%);max-height:min(720px,100%);overflow:auto;display:flex;flex-direction:column;background:var(--_surface);color:var(--_text);
  border:1px solid var(--_border);border-radius:var(--_radius);font:400 14px/1.45 var(--_font);
  box-shadow:var(--seaproof-shadow,0 16px 40px rgba(6,32,47,.18),0 4px 10px rgba(6,32,47,.08));animation:seaproof-rise .32s var(--_swell)}
@keyframes seaproof-rise{from{opacity:0;transform:translateY(8px)}}
@media (max-width:520px){
  :where(.seaproof-backdrop){padding:0;align-items:flex-end}
  :where(.seaproof-panel){width:100%;max-height:92%;border-radius:var(--_radius) var(--_radius) 0 0;border-bottom:0}
  :where(.seaproof-footer-hint){visibility:hidden}}
:where(.seaproof-header){display:flex;align-items:center;gap:8px;padding:14px 8px 0 20px}
:where(.seaproof-header h2){flex:1;margin:0;display:flex;align-items:center;gap:8px;font:600 18px/1.3 var(--seaproof-heading-font,Sora,var(--_font));color:var(--_text)}
:where(.seaproof-logo){height:24px;max-width:96px;object-fit:contain}
:where(.seaproof-icon-button){width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;border:0;border-radius:10px;background:none;color:var(--_muted);cursor:pointer}
:where(.seaproof-icon-button:hover){background:var(--_sunken);color:var(--_text)}
:where(.seaproof-body){padding:14px 16px 0;display:flex;flex-direction:column;gap:12px}
:where(.seaproof-footer){display:flex;align-items:center;justify-content:flex-end;gap:8px;padding:14px 16px 16px;margin-top:14px;border-top:1px solid var(--_border)}
:where(.seaproof-footer-hint){flex:1;display:inline-flex;gap:4px;align-items:center;font-size:12px;color:var(--_muted)}
:where(.seaproof-kbd){font:500 11px/1 var(--_mono);color:var(--_text);border:1px solid var(--_border);border-bottom-width:2px;border-radius:6px;padding:3px 5px}

:where(.seaproof-tabs){display:flex;gap:3px;padding:3px;margin:10px 16px 0;background:var(--_sunken);border-radius:12px}
:where(.seaproof-tabs button){flex:1;min-height:36px;white-space:nowrap;padding:0 6px;display:inline-flex;align-items:center;justify-content:center;gap:6px;border:0;border-radius:9px;background:none;color:var(--_muted);font:600 13px var(--_font);cursor:pointer;transition:background .2s var(--_ease),color .2s var(--_ease)}
:where(.seaproof-tabs button[aria-selected=true]){background:var(--_raised);color:var(--_text);box-shadow:0 1px 2px rgba(6,32,47,.1)}
:where(.seaproof-dot){display:inline-block;flex:none;width:8px;height:8px;border-radius:50%;background:var(--_signal)}

:where(.seaproof-types){display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0;padding:0;border:0}
:where(.seaproof-type){position:relative;display:flex;align-items:center;gap:9px;min-height:46px;padding:0 12px;border:1px solid var(--_border);border-radius:12px;
  background:var(--_surface);color:var(--_text);font:600 14px/1.2 var(--_font);cursor:pointer;transition:background .2s var(--_ease),border-color .2s var(--_ease)}
:where(.seaproof-type:hover){border-color:var(--_border-strong)}
:where(.seaproof-type input){position:absolute;opacity:0;inset:0;margin:0;cursor:pointer}
:where(.seaproof-type:has(input:focus-visible)){outline:2px solid var(--_focus);outline-offset:2px}
:where(.seaproof-type-label){flex:1}
:where(.seaproof-type-check){display:none}
:where(.seaproof-type[data-type=bug]){--_tone:var(--_bug);--_tint:var(--_bug-tint)}
:where(.seaproof-type[data-type=feedback]){--_tone:var(--_feedback);--_tint:var(--_feedback-tint)}
:where(.seaproof-type[data-type=idea]){--_tone:var(--_idea);--_tint:var(--_idea-tint)}
:where(.seaproof-type[data-type=question]){--_tone:var(--_question);--_tint:var(--_question-tint)}
:where(.seaproof-type .seaproof-icon){color:var(--_tone)}
:where(.seaproof-type:has(input:checked)){border:2px solid var(--_tone);padding:0 11px;background:var(--_tint)}
:where(.seaproof-type:has(input:checked) .seaproof-type-check){display:block;color:var(--_tone)}

:where(.seaproof-field){display:flex;flex-direction:column;gap:6px;font-size:13px;font-weight:600}
:where(.seaproof-panel textarea,.seaproof-panel input[type=email],.seaproof-panel input[type=text]){width:100%;border:1px solid var(--_border-strong);border-radius:12px;padding:11px 12px;
  font:400 15px/1.45 var(--_font);background:var(--_surface);color:var(--_text);transition:border-color .2s var(--_ease),box-shadow .2s var(--_ease)}
:where(.seaproof-panel textarea){min-height:104px;resize:vertical}
:where(.seaproof-panel textarea:focus,.seaproof-panel input[type=email]:focus,.seaproof-panel input[type=text]:focus){outline:0;border-color:var(--_primary);box-shadow:0 0 0 1px var(--_primary),0 0 0 4px color-mix(in srgb,var(--_focus) 22%,transparent)}
:where(.seaproof-panel textarea[aria-invalid=true]){border-color:var(--_error);box-shadow:0 0 0 1px var(--_error)}
:where(.seaproof-panel textarea::placeholder){color:var(--_muted)}

:where(.seaproof-attachment){display:flex;align-items:center;gap:10px;min-height:56px;padding:6px 6px 6px 12px;border:1px solid var(--_border);border-radius:12px}
:where(.seaproof-attachment > .seaproof-icon){color:var(--_muted)}
:where(.seaproof-attachment-text){flex:1;display:flex;flex-direction:column;gap:2px;min-width:0}
:where(.seaproof-attachment-title){font-weight:600;font-size:13px}
:where(.seaproof-attachment-meta){font-size:12px;color:var(--_muted)}
:where(.seaproof-attachment video){width:72px;height:44px;object-fit:cover;border-radius:6px;background:#000}
:where(.seaproof-switch){position:relative;flex:none;width:44px;height:26px;margin:0 6px;appearance:none;-webkit-appearance:none;border-radius:999px;background:var(--_border-strong);cursor:pointer;transition:background .2s var(--_ease)}
:where(.seaproof-switch)::after{content:"";position:absolute;top:3px;left:3px;width:20px;height:20px;border-radius:999px;background:#fff;transition:transform .2s var(--_ease)}
:where(.seaproof-switch:checked){background:var(--_primary)}
:where(.seaproof-switch:checked)::after{transform:translateX(18px)}
:where(.seaproof-record){display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:44px;width:100%;border:1px dashed var(--_border-strong);border-radius:12px;background:none;color:var(--_text);font:600 13px var(--_font);cursor:pointer}
:where(.seaproof-record:hover){background:var(--_sunken)}
:where(.seaproof-suggestions,.seaproof-questions){display:flex;flex-direction:column;gap:6px;padding:10px 12px;border-radius:12px;background:var(--_sunken)}
:where(.seaproof-suggestions ul,.seaproof-questions ul){list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:8px}
:where(.seaproof-suggestions-title){margin:0;font-size:12px;font-weight:600;color:var(--_muted)}
:where(.seaproof-suggestion){display:flex;align-items:flex-start;gap:10px;padding:8px 0 0;border-top:1px solid var(--_border)}
:where(.seaproof-suggestion:first-child){border-top:0;padding-top:0}
:where(.seaproof-suggestion > .seaproof-icon){margin-top:2px;color:var(--_bug)}
:where(.seaproof-suggestion[data-type=idea] > .seaproof-icon){color:var(--_idea)}
:where(.seaproof-suggestion-text,.seaproof-linked-text){flex:1;display:flex;flex-direction:column;gap:3px;min-width:0}
:where(.seaproof-suggestion-title){font-weight:600;font-size:14px}
:where(.seaproof-suggestion .seaproof-link){min-height:32px;font-size:13px;white-space:nowrap}
:where(.seaproof-vote-small){width:40px;height:44px;font-size:12px}
:where(.seaproof-questions li){position:relative;padding-left:14px;font-size:14px}
:where(.seaproof-questions li)::before{content:"";position:absolute;left:2px;top:.6em;width:5px;height:5px;border-radius:999px;background:var(--_signal)}
:where(.seaproof-linked){display:flex;align-items:center;gap:10px;padding:6px 6px 6px 12px;border:1px solid var(--_border-strong);border-radius:12px}
:where(.seaproof-note){margin:0;font-size:12px;color:var(--_muted)}

:where(.seaproof-button){display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:44px;padding:0 16px;border:0;border-radius:10px;background:none;color:var(--_text);font:600 14px var(--_font);cursor:pointer}
:where(.seaproof-button:hover){background:var(--_sunken)}
:where(.seaproof-primary){padding:0 20px;background:var(--_primary);color:var(--_on-primary)}
:where(.seaproof-primary:hover){background:var(--_primary);filter:brightness(1.15)}
:where(.seaproof-secondary){border:1px solid var(--_border)}
:where(.seaproof-button:disabled){opacity:.7;cursor:default;filter:none}
:where(.seaproof-link){display:inline-flex;align-items:center;gap:2px;min-height:44px;border:0;background:none;padding:0;color:var(--_link);font:600 14px var(--_font);cursor:pointer}
:where(.seaproof-error){display:flex;gap:6px;align-items:flex-start;margin:0;color:var(--_error);font-size:13px;font-weight:500}

:where(.seaproof-view){padding:4px 16px 0;display:flex;flex-direction:column}
:where(.seaproof-view h2){margin:12px 0 4px;font:600 16px/1.3 var(--seaproof-heading-font,Sora,var(--_font))}
:where(.seaproof-list){list-style:none;margin:0;padding:0;max-height:380px;overflow:auto}
:where(.seaproof-list > li){border-bottom:1px solid var(--_border)}
:where(.seaproof-list > li:last-child){border-bottom:0}
:where(.seaproof-list > li > button){display:flex;flex-direction:column;gap:4px;width:100%;min-height:44px;text-align:left;border:0;background:none;color:inherit;font:inherit;padding:12px 2px;cursor:pointer}
:where(.seaproof-row-title){display:flex;align-items:center;gap:8px;font-weight:600;font-size:15px}
:where(.seaproof-muted){display:block;color:var(--_muted);font-size:13px}
:where(.seaproof-idea){display:flex;gap:12px;align-items:flex-start;padding:14px 0}
:where(.seaproof-idea-text){display:flex;flex-direction:column;gap:5px;min-width:0}
:where(.seaproof-vote){flex:none;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;width:48px;height:56px;border:1px solid var(--_border);border-radius:12px;
  background:var(--_surface);color:var(--_text);font:600 14px var(--_font);cursor:pointer;transition:background .2s var(--_ease)}
:where(.seaproof-vote[aria-pressed=true]){background:var(--_primary);border-color:var(--_primary);color:var(--_on-primary)}
:where(.seaproof-badge){align-self:flex-start;display:inline-block;padding:3px 9px;border-radius:999px;font-size:12px;font-weight:600;background:var(--_sunken);color:var(--_muted)}
:where(.seaproof-badge[data-status=underReview]){background:var(--_feedback-tint);color:var(--_feedback)}
:where(.seaproof-badge[data-status=inProgress]){background:var(--_idea-tint);color:var(--_idea)}
:where(.seaproof-badge[data-status=done]){background:var(--_question-tint);color:var(--_question)}
:where(.seaproof-badge[data-status=closed]){background:none;border:1px solid var(--_border)}

:where(.seaproof-messages){list-style:none;margin:8px 0;padding:12px;display:flex;flex-direction:column;gap:12px;max-height:300px;overflow:auto;background:var(--_sunken);border-radius:14px}
:where(.seaproof-message){display:flex;flex-direction:column;gap:4px;max-width:85%;white-space:pre-wrap}
:where(.seaproof-bubble){padding:10px 14px;font-size:14px;line-height:1.45}
:where(.seaproof-from-you){align-self:flex-end;align-items:flex-end}
:where(.seaproof-from-you .seaproof-bubble){background:var(--_primary);color:var(--_on-primary);border-radius:16px 4px 16px 16px}
:where(.seaproof-from-team){align-self:flex-start}
:where(.seaproof-from-team .seaproof-bubble){background:var(--_surface);border:1px solid var(--_border);border-radius:4px 16px 16px 16px}
:where(.seaproof-sender){font-size:12px;font-weight:600;color:var(--_muted)}
:where(.seaproof-reply){display:flex;gap:8px;align-items:flex-end}
:where(.seaproof-reply textarea){min-height:44px;border-radius:22px;padding:11px 16px}
:where(.seaproof-round){flex:none;width:44px;height:44px;padding:0;border-radius:999px}

:where(.seaproof-sent){display:flex;flex-direction:column;align-items:center;text-align:center;padding:40px 24px 8px;color:var(--_text)}
:where(.seaproof-sent .seaproof-mark-wrap){width:96px;height:96px;border-radius:999px;background:var(--_sunken);display:flex;align-items:center;justify-content:center;color:var(--_primary)}
:where(.seaproof-mark-water){fill:currentColor;transform-origin:50% 50%;animation:seaproof-fill .6s var(--_swell) .1s both}
:where(.seaproof-mark-line){fill:var(--_signal)}
@keyframes seaproof-fill{from{transform:scaleY(0)}}
:where(.seaproof-sent h2){margin:22px 0 0;font:600 24px/1.2 var(--seaproof-heading-font,Sora,var(--_font))}
:where(.seaproof-sent p){margin:8px 0 0;font-size:15px;color:var(--_muted)}
:where(.seaproof-ref){margin-top:16px;font:500 13px var(--_mono);background:var(--_sunken);border-radius:6px;padding:4px 10px}
:where(.seaproof-sent-actions){display:flex;flex-direction:column;gap:6px;width:100%;margin-top:28px}

:where(.seaproof-recording){position:fixed;top:12px;left:50%;transform:translateX(-50%);z-index:var(--_z);display:flex;align-items:center;gap:10px;
  background:var(--_ink);color:#fff;border-radius:999px;padding:6px 6px 6px 16px;font:600 14px var(--_font);box-shadow:0 4px 12px rgba(6,32,47,.25);white-space:nowrap}
:where(.seaproof-recording-time){font:500 14px var(--_mono);color:#b4c3cf}
:where(.seaproof-recording button){display:inline-flex;align-items:center;gap:6px;min-height:36px;border:0;border-radius:999px;background:#fff;color:#b42318;font:600 14px var(--_font);padding:0 14px 0 10px;cursor:pointer}
:where(.seaproof-recording-dot){width:10px;height:10px;border-radius:50%;background:var(--_recording);animation:seaproof-pulse 1.2s ease-in-out infinite}
@keyframes seaproof-pulse{50%{opacity:.35}}

:where(.seaproof-test-strip){display:flex;align-items:center;gap:8px;padding:8px 20px;background:var(--_ink);color:#e8f0f5;font:600 12px/1.2 var(--_font);border-radius:calc(var(--_radius) - 1px) calc(var(--_radius) - 1px) 0 0}
:where(.seaproof-test-strip .seaproof-dot){background:#ff8a3d}
:where(.seaproof-test-strip-env){font-weight:400;color:#9db2c2}

:where(.seaproof-chat-panel){height:min(640px,100%)}
:where(.seaproof-chat){flex:1;min-height:0;display:flex;flex-direction:column;margin-top:10px;border-top:1px solid var(--_border)}
:where(.seaproof-conversation){flex:1;min-height:160px;overflow:auto;list-style:none;margin:0;padding:16px;display:flex;flex-direction:column;gap:10px;background:color-mix(in srgb,var(--_sunken) 45%,var(--_surface))}
:where(.seaproof-conversation .seaproof-message){max-width:88%}
:where(.seaproof-from-assistant){align-self:flex-start;display:flex;flex-direction:column;gap:8px}
:where(.seaproof-assistant-row){display:flex;align-items:flex-start;gap:8px}
:where(.seaproof-avatar){flex:none;width:26px;height:26px;border-radius:999px;background:var(--_sunken);color:var(--_primary);display:flex;align-items:center;justify-content:center}
:where(.seaproof-from-assistant .seaproof-bubble){background:var(--_surface);border:1px solid var(--_border);border-radius:4px 16px 16px 16px}
:where(.seaproof-quick-replies){display:flex;flex-wrap:wrap;gap:6px;padding-left:34px}
:where(.seaproof-quick){display:inline-flex;align-items:center;gap:6px;min-height:40px;padding:0 14px;border:1px solid var(--_border-strong);border-radius:999px;background:var(--_surface);color:var(--_text);font:600 13px var(--_font);cursor:pointer}
:where(.seaproof-quick:hover){background:var(--_sunken)}
:where(.seaproof-quick-done){background:var(--_primary);border-color:var(--_primary);color:var(--_on-primary)}
:where(.seaproof-quick-done:hover){background:var(--_primary);filter:brightness(1.15)}
:where(.seaproof-chat-types){padding-left:34px}
:where(.seaproof-chips){display:flex;flex-wrap:wrap;gap:6px;margin:0;padding:0;border:0}
:where(.seaproof-chip){position:relative;display:inline-flex;align-items:center;gap:6px;min-height:36px;padding:0 12px;border:1px solid var(--_border);border-radius:999px;background:var(--_surface);color:var(--_tone);font:600 13px var(--_font);cursor:pointer}
:where(.seaproof-chip input){position:absolute;inset:0;opacity:0;margin:0;cursor:pointer}
:where(.seaproof-chip .seaproof-icon){width:16px;height:16px}
:where(.seaproof-chip[data-type=bug]){--_tone:var(--_bug);--_tint:var(--_bug-tint)}
:where(.seaproof-chip[data-type=feedback]){--_tone:var(--_feedback);--_tint:var(--_feedback-tint)}
:where(.seaproof-chip[data-type=idea]){--_tone:var(--_idea);--_tint:var(--_idea-tint)}
:where(.seaproof-chip[data-type=question]){--_tone:var(--_question);--_tint:var(--_question-tint)}
:where(.seaproof-chip:has(input:checked)){border:1.5px solid var(--_tone);background:var(--_tint)}
:where(.seaproof-chip:has(input:focus-visible)){outline:2px solid var(--_focus);outline-offset:2px}
:where(.seaproof-media){display:flex;flex-direction:column;gap:4px;width:220px;padding:0;border:1px solid var(--_border);border-radius:16px 4px 16px 16px;overflow:hidden;background:var(--_surface)}
:where(.seaproof-media img,.seaproof-media video){display:block;width:100%;max-height:160px;object-fit:cover;background:var(--_sunken)}
:where(.seaproof-media-label){padding:4px 10px 6px;font-size:12px;color:var(--_muted)}
:where(.seaproof-typing){display:inline-flex;gap:4px;padding:12px 14px}
:where(.seaproof-typing span){width:6px;height:6px;border-radius:999px;background:var(--_muted);animation:seaproof-pulse 1.2s ease-in-out infinite}
:where(.seaproof-typing span:nth-child(2)){animation-delay:.2s}
:where(.seaproof-typing span:nth-child(3)){animation-delay:.4s}
:where(.seaproof-chat-suggestions){padding:10px 16px 0}
:where(.seaproof-chat-error){padding:8px 16px 0}
:where(.seaproof-pending){display:flex;flex-direction:column;gap:6px;padding:10px 16px 0}
:where(.seaproof-pending-item){display:flex;align-items:center;gap:10px;padding:4px 4px 4px 6px;border:1px solid var(--_border);border-radius:12px}
:where(.seaproof-pending-item > .seaproof-icon){margin-left:6px;color:var(--_muted)}
:where(.seaproof-pending-thumb){flex:none;width:56px;height:40px;padding:0;border:1px solid var(--_border);border-radius:8px;overflow:hidden;background:var(--_sunken);cursor:pointer}
:where(.seaproof-pending-thumb img){width:100%;height:100%;object-fit:cover;display:block}
:where(.seaproof-pending-text){flex:1;display:flex;flex-direction:column;gap:1px;min-width:0}
:where(.seaproof-composer){display:flex;align-items:flex-end;gap:4px;padding:10px 10px 10px 16px}
:where(.seaproof-panel .seaproof-composer textarea){min-height:44px;max-height:140px;resize:none;border-radius:22px;padding:11px 16px;field-sizing:content}
:where(.seaproof-chat-note){padding:0 16px 12px}

:where(.seaproof-annotator){position:fixed;inset:0;z-index:calc(var(--_z) + 2);display:flex;flex-direction:column;background:var(--_ink);color:#e8f0f5;font:400 14px/1.45 var(--_font)}
:where(.seaproof-annotator-bar){display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 16px}
:where(.seaproof-annotator-title){font-weight:600}
:where(.seaproof-on-dark){color:#e8f0f5}
:where(.seaproof-on-dark:hover){background:#123a52}
:where(.seaproof-annotator-stage){flex:1;min-height:0;display:flex;align-items:center;justify-content:center;padding:0 16px}
:where(.seaproof-annotator-canvas){max-width:100%;max-height:100%;border-radius:12px;background:#fff;touch-action:none;cursor:crosshair}
:where(.seaproof-annotator-tools){display:flex;justify-content:center;gap:4px;margin:16px auto 20px;padding:6px;border:1px solid #22405a;border-radius:18px;background:#0e2230}
:where(.seaproof-annotator-tools button){display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;min-width:64px;min-height:52px;border:0;border-radius:13px;background:none;color:#9db2c2;font:500 12px var(--_font);cursor:pointer}
:where(.seaproof-annotator-tools button[aria-pressed=true]){background:#123a52;color:#e8f0f5}
:where(.seaproof-annotator-tools button:disabled){opacity:.45;cursor:default}
:where(.seaproof-recording-hint){font-weight:400;color:#9db2c2}

@media (prefers-reduced-motion:reduce){
  :where(.seaproof-root) :where(*){animation:none!important;transition:none!important}}
`;
