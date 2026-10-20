import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

// Timeline (30 fps): hook → title → demo (terminal, with a key masked) → desktop app → features → end card.
const HOOK = 60;
const TITLE = 66;
const DEMO = 300;
const APP = 140;
const FEATURES = 110;
const END = 90;
export const PROMO_FRAMES = HOOK + TITLE + DEMO + APP + FEATURES + END;

const SANS = '-apple-system, "SF Pro Display", "Helvetica Neue", sans-serif';
const MONO = '"SF Mono", Menlo, monospace';
const ACCENT = '#ff9e45';
const BG = '#0d0e12';

const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
const ease = Easing.bezier(0.22, 1, 0.36, 1);
const fade = (f: number, from: number, to: number) => interpolate(f, [from, to], [0, 1], { ...clamp, easing: ease });

export const Promo = () => (
  <AbsoluteFill style={{ background: BG, fontFamily: SANS }}>
    <Sequence durationInFrames={HOOK}>
      <Hook />
    </Sequence>
    <Sequence from={HOOK} durationInFrames={PROMO_FRAMES - HOOK}>
    <Sequence durationInFrames={TITLE}>
      <Title />
    </Sequence>
    <Sequence from={TITLE} durationInFrames={DEMO}>
      <Demo />
    </Sequence>
    <Sequence from={TITLE + DEMO} durationInFrames={APP}>
      <AppScene />
    </Sequence>
    <Sequence from={TITLE + DEMO + APP} durationInFrames={FEATURES}>
      <Features />
    </Sequence>
    <Sequence from={TITLE + DEMO + APP + FEATURES}>
      <EndCard />
    </Sequence>
    </Sequence>
  </AbsoluteFill>
);

// ─── Hook ────────────────────────────────────────────────────────────────

const Hook = () => {
  const f = useCurrentFrame();
  const { width } = useVideoConfig();
  const size = width > 1500 ? 76 : 64;
  const out = interpolate(f, [HOOK - 10, HOOK], [1, 0], clamp);
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: 80, opacity: out }}>
      <div style={{ color: '#fff', fontSize: size, fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.15, maxWidth: 1400, opacity: fade(f, 2, 16) }}>
        How many screenshots did you hand your agent today?
      </div>
    </AbsoluteFill>
  );
};

// ─── Title ───────────────────────────────────────────────────────────────

const Title = () => {
  const f = useCurrentFrame();
  const { fps, width } = useVideoConfig();
  const pop = spring({ frame: f, fps, config: { damping: 14 } });
  const out = interpolate(f, [TITLE - 12, TITLE], [1, 0], clamp);
  const size = width > 1500 ? 92 : 66;
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: out, textAlign: 'center', padding: 60 }}>
      <Img src={staticFile('icon.png')} style={{ width: 220, transform: `scale(${pop})` }} />
      <div style={{ color: '#fff', fontSize: size, fontWeight: 800, letterSpacing: '-0.035em', marginTop: 36, opacity: fade(f, 10, 25) }}>
        Show your agent the screen.
      </div>
      <div style={{ color: ACCENT, fontSize: size, fontWeight: 800, letterSpacing: '-0.035em', opacity: fade(f, 20, 35) }}>
        Not your keys.
      </div>
    </AbsoluteFill>
  );
};

// ─── Demo ────────────────────────────────────────────────────────────────

// The demo is laid out on a fixed 1600×1000 stage, scaled to fit the frame.
const STAGE_W = 1600;
const STAGE_H = 1000;
const SELECTION = { x: 84, y: 300, w: 872, h: 224 }; // around the error and the key below it
const KEY_NAME = 'OPENAI_API_KEY=';
const KEY_VALUE = 'sk-proj-Q7wErTy8Ui0p9AsDfGh2JkL';
const QUESTION = 'why is this broken?';
const ANSWER = [
  '⏺ `items` is undefined on the first render — the',
  '  fetch hasn\'t resolved yet. Default it to an empty',
  '  array: const [items, setItems] = useState([])',
];

// Beats, in demo-local frames.
const TAP1 = 18, TAP2 = 28, SELECT_START = 55, SELECT_END = 95, SHOT = 100;
const CARD_IN = 104, MASK_START = 120, MASK_END = 134;
const FRONT = 168, PASTE = 182, TYPE_START = 194, TYPE_END = 228, ENTER = 238, ANSWER_START = 250;

const Demo = () => {
  const f = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const vertical = height > width;

  const stageScale = vertical ? (width * 0.96) / STAGE_W : Math.min((width * 0.8) / STAGE_W, (height * 0.78) / STAGE_H);
  // Camera: close in on the capture while its key is masked, then on the terminal.
  const beats = [CARD_IN + 4, CARD_IN + 22, FRONT - 4, FRONT + 22];
  const cam = (values: number[]) => interpolate(f, beats, values, { ...clamp, easing: ease });
  const zoom = cam([1, 1.75, 1.75, 1.28]);
  const panX = cam([0, -870, -870, -300]);
  const panY = cam([0, 430, 430, -150]);
  const enter = fade(f, 0, 14);
  const exit = interpolate(f, [DEMO - 12, DEMO], [1, 0], clamp);

  const caption =
    f < SELECT_START ? 'Tap ⌘ twice'
      : f < SHOT ? 'Drag a region'
      : f < FRONT ? 'Keys blacked out, on your Mac'
      : f < ENTER ? 'It\'s already in the prompt'
      : 'Ask away';
  const captionKey = f < SELECT_START ? 0 : f < SHOT ? SELECT_START : f < FRONT ? SHOT : f < ENTER ? FRONT : ENTER;

  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: enter * exit, flexDirection: 'column' }}>
      {vertical && <Caption text={caption} startFrame={captionKey} size={68} />}
      <div style={{ width: STAGE_W * stageScale, height: STAGE_H * stageScale, borderRadius: 28 * stageScale, overflow: 'hidden', boxShadow: '0 40px 100px rgba(0,0,0,.6)', margin: vertical ? '60px 0' : 0 }}>
        <div style={{ width: STAGE_W, height: STAGE_H, transform: `scale(${stageScale})`, transformOrigin: 'top left' }}>
          <div style={{ position: 'absolute', inset: 0, transform: `translate(${panX}px, ${panY}px) scale(${zoom})`, transformOrigin: 'center' }}>
            <Desktop f={f} />
          </div>
        </div>
      </div>
      {!vertical && (
        <div style={{ position: 'absolute', bottom: 34 }}>
          <Caption text={caption} startFrame={captionKey} size={46} />
        </div>
      )}
    </AbsoluteFill>
  );
};

const Caption = ({ text, startFrame, size }: { text: string; startFrame: number; size: number }) => {
  const f = useCurrentFrame();
  const t = fade(f, startFrame, startFrame + 10);
  return (
    <div style={{ color: '#fff', fontSize: size, fontWeight: 700, letterSpacing: '-0.02em', opacity: t, transform: `translateY(${(1 - t) * 14}px)`, textAlign: 'center' }}>
      {text}
    </div>
  );
};

const Desktop = ({ f }: { f: number }) => {
  const termFront = f >= FRONT;
  const selecting = f >= SELECT_START && f < SHOT;
  const sel = interpolate(f, [SELECT_START + 5, SELECT_END], [0, 1], { ...clamp, easing: ease });
  const flash = interpolate(f, [SHOT, SHOT + 3, SHOT + 12], [0, 0.7, 0], clamp);
  const termPop = termFront ? interpolate(f, [FRONT, FRONT + 6, FRONT + 14], [1, 1.03, 1], clamp) : 1;

  return (
    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, #3b3f8f, #8a4f9e 55%, #e0806b)' }}>
      <MenuBar f={f} />
      <Window x={70} y={110} w={900} h={640} z={termFront ? 1 : 2} light>
        <div style={{ padding: 32 }}>
          <div style={{ height: 26, width: '55%', background: '#1f2330', borderRadius: 6, marginBottom: 26 }} />
          <div style={{ height: 14, width: '90%', background: '#e3e5ea', borderRadius: 7, marginBottom: 14 }} />
          <div style={{ height: 14, width: '72%', background: '#e3e5ea', borderRadius: 7 }} />
          <div style={{ marginTop: 34 }}>
            <CapturedRegion />
          </div>
          <div style={{ marginTop: 30, width: 260, height: 52, borderRadius: 10, background: '#4f63ff' }} />
        </div>
      </Window>
      <Window x={700} y={400} w={840} h={540} z={termFront ? 2 : 1} scale={termPop}>
        <Terminal f={f} />
      </Window>

      {selecting && <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.28)', zIndex: 5 }} />}
      {selecting && f >= SELECT_START + 5 && (
        <div
          style={{
            position: 'absolute', zIndex: 6,
            left: SELECTION.x, top: SELECTION.y,
            width: SELECTION.w * sel, height: SELECTION.h * sel,
            border: '3px solid #fff', background: 'rgba(255,255,255,.14)', boxShadow: '0 0 0 1px rgba(0,0,0,.3)',
          }}
        />
      )}
      <div style={{ position: 'absolute', inset: 0, background: '#fff', opacity: flash, zIndex: 9 }} />
      <CaptureCard f={f} />
      <KeyCast f={f} />
    </div>
  );
};

const MenuBar = ({ f }: { f: number }) => {
  const locked = f >= MASK_END && f < FRONT + 40;
  const count = f >= SHOT ? '1' : '';
  return (
    <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 40, background: 'rgba(20,20,30,.35)', backdropFilter: 'blur(20px)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 26, padding: '0 26px', color: '#fff', font: `500 20px ${SANS}`, zIndex: 8 }}>
      <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <Img src={staticFile('icon.png')} style={{ width: 26 }} />
        {locked && <Lock size={18} color="#fff" />}
        {count}
      </span>
      <span>Mon 9:41 AM</span>
    </div>
  );
};

const Window = ({ x, y, w, h, z, light, scale = 1, children }: {
  x: number; y: number; w: number; h: number; z: number; light?: boolean; scale?: number; children: React.ReactNode;
}) => (
  <div style={{ position: 'absolute', left: x, top: y, width: w, height: h, zIndex: z, borderRadius: 18, overflow: 'hidden', background: light ? '#fff' : '#14151b', boxShadow: '0 30px 70px rgba(0,0,0,.4)', transform: `scale(${scale})` }}>
    <div style={{ height: 46, background: light ? '#ececec' : '#22242c', display: 'flex', alignItems: 'center', gap: 10, padding: '0 18px' }}>
      {['#ff5f57', '#febc2e', '#28c840'].map((c) => <div key={c} style={{ width: 16, height: 16, borderRadius: 8, background: c }} />)}
    </div>
    {children}
  </div>
);

const Terminal = ({ f }: { f: number }) => {
  const pasted = f >= PASTE;
  const pastePop = spring({ frame: f - PASTE, fps: 30, config: { damping: 12 } });
  const typed = QUESTION.slice(0, Math.round(interpolate(f, [TYPE_START, TYPE_END], [0, QUESTION.length], clamp)));
  const sent = f >= ENTER;
  const cursorOn = Math.floor(f / 15) % 2 === 0;
  const lines = Math.floor(interpolate(f, [ANSWER_START, ANSWER_START + 36], [0, ANSWER.length], clamp));

  return (
    <div style={{ padding: '22px 26px', color: '#d8dae3', font: `24px/1.6 ${MONO}` }}>
      <div><span style={{ color: ACCENT }}>●</span> agent</div>
      <div style={{ color: '#6e7386' }}>  cwd: ~/projects/webapp</div>
      {sent && (
        <div style={{ marginTop: 18 }}>
          <span style={{ color: '#6e7386' }}>&gt; </span>
          <span style={{ color: '#8fb4ff' }}>[Image #1]</span> {QUESTION}
        </div>
      )}
      {sent && ANSWER.slice(0, lines).map((l, i) => (
        <div key={i} style={{ whiteSpace: 'pre', marginTop: i === 0 ? 14 : 0 }}>{l}</div>
      ))}
      <div style={{ marginTop: 18, border: '2px solid #3a3d4a', borderRadius: 10, padding: '10px 16px', whiteSpace: 'pre' }}>
        &gt;{' '}
        {!sent && pasted && (
          <span style={{ color: '#8fb4ff', display: 'inline-block', transform: `scale(${pastePop})` }}>[Image #1] </span>
        )}
        {!sent && typed}
        <span style={{ display: 'inline-block', width: 13, height: 28, verticalAlign: 'text-bottom', background: cursorOn ? '#d8dae3' : 'transparent' }} />
      </div>
    </div>
  );
};

// What the selection covers: the error, and an env line with a key in it.
// With `mask` (0…1), a password-field pill covers the key's value.
const CapturedRegion = ({ mask = 0 }: { mask?: number }) => (
  <div>
    <div style={{ padding: '20px 22px', borderRadius: 10, border: '2px solid #f3b4b4', background: '#fff1f1', color: '#c0392b', font: `600 24px/1.45 ${MONO}` }}>
      TypeError: Cannot read properties of undefined (reading 'map')
    </div>
    <div style={{ marginTop: 14, padding: '14px 22px', borderRadius: 10, background: '#f3f4f7', color: '#3b4050', font: `500 22px/1.4 ${MONO}`, whiteSpace: 'pre', position: 'relative' }}>
      {KEY_NAME}
      <span style={{ position: 'relative', display: 'inline-block' }}>
        {KEY_VALUE}
        {mask > 0 && <Pill width={mask} />}
      </span>
    </div>
  </div>
);

/** The mask Yetda draws: a solid pill with password dots, growing left to right. */
const Pill = ({ width }: { width: number }) => (
  <span style={{ position: 'absolute', left: -4, top: -3, bottom: -3, width: `calc(${width * 100}% + 8px)`, borderRadius: 999, background: '#1d1f27', overflow: 'hidden', display: 'flex', alignItems: 'center', paddingLeft: 14, color: '#9a9db0', letterSpacing: 4, fontSize: 18 }}>
    {'●'.repeat(Math.round(14 * width))}
  </span>
);

const Lock = ({ size, color }: { size: number; color: string }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ display: 'block' }}>
    <rect x="4" y="10" width="16" height="11" rx="2.5" fill={color} />
    <path d="M8 10V7.5a4 4 0 0 1 8 0V10" stroke={color} strokeWidth="2.4" />
  </svg>
);

// The capture, shown like macOS's floating screenshot preview: it appears
// after the shot, the key gets masked, then it drops into the terminal.
const CaptureCard = ({ f }: { f: number }) => {
  if (f < CARD_IN || f > FRONT + 16) return null;
  const inT = interpolate(f, [CARD_IN, CARD_IN + 12], [0, 1], { ...clamp, easing: ease });
  const outT = interpolate(f, [FRONT - 4, FRONT + 14], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const mask = interpolate(f, [MASK_START, MASK_END], [0, 1], { ...clamp, easing: ease });
  const badge = fade(f, MASK_END, MASK_END + 8);
  const scale = 0.62;
  return (
    <div style={{
      position: 'absolute', zIndex: 7, left: 1010 + outT * -120, top: 120 + (1 - inT) * 30 + outT * 520,
      width: SELECTION.w * scale + 36, padding: 18, borderRadius: 18, background: '#fff',
      boxShadow: '0 30px 80px rgba(0,0,0,.45)', opacity: inT * (1 - outT), transform: `scale(${1 - outT * 0.6})`, transformOrigin: 'left top',
    }}>
      <div style={{ width: SELECTION.w, transform: `scale(${scale})`, transformOrigin: 'top left', height: (SELECTION.h - 40) * scale }}>
        <CapturedRegion mask={mask} />
      </div>
      <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 10, color: '#1d1f27', font: `600 20px ${SANS}`, opacity: badge }}>
        <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: 32, height: 32, borderRadius: 16, background: '#1d1f27' }}>
          <Lock size={16} color={ACCENT} />
        </span>
        1 key hidden · never leaves your Mac
      </div>
    </div>
  );
};

// On-screen keystroke badges for the two ⌘ taps.
const KeyCast = ({ f }: { f: number }) => {
  if (f < TAP1 - 2 || f > SELECT_START + 4) return null;
  const out = interpolate(f, [SELECT_START - 6, SELECT_START + 4], [1, 0], clamp);
  const key = (tap: number) => {
    const shown = f >= tap;
    const press = interpolate(f, [tap, tap + 3, tap + 7], [1, 0.88, 1], clamp);
    return (
      <div style={{ opacity: shown ? 1 : 0, transform: `scale(${press})`, width: 130, height: 130, borderRadius: 26, background: 'rgba(20,20,28,.85)', color: '#fff', font: `600 72px ${SANS}`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 20px 50px rgba(0,0,0,.4)' }}>
        ⌘
      </div>
    );
  };
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: 560, display: 'flex', justifyContent: 'center', gap: 22, zIndex: 10, opacity: out }}>
      {key(TAP1)}
      {key(TAP2)}
    </div>
  );
};

// ─── Desktop app ─────────────────────────────────────────────────────────

const APP_PASTE = 34, APP_TYPE_START = 52, APP_TYPE_END = 84;
const APP_QUESTION = 'same error on mobile too';

const AppScene = () => {
  const f = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const vertical = height > width;
  const stageScale = vertical ? (width * 0.96) / STAGE_W : Math.min((width * 0.8) / STAGE_W, (height * 0.78) / STAGE_H);
  const enter = fade(f, 0, 14);
  const exit = interpolate(f, [APP - 12, APP], [1, 0], clamp);
  const caption = 'Or the agent\'s desktop app';
  // Close in on the composer once the capture lands in it.
  const appCam = (to: number) => interpolate(f, [APP_PASTE + 4, APP_PASTE + 28], [0, to], { ...clamp, easing: ease });
  const appZoom = 1 + appCam(0.45);
  const appPanX = appCam(-210);
  const appPanY = appCam(-400);
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: enter * exit, flexDirection: 'column' }}>
      {vertical && <Caption text={caption} startFrame={0} size={64} />}
      <div style={{ width: STAGE_W * stageScale, height: STAGE_H * stageScale, borderRadius: 28 * stageScale, overflow: 'hidden', boxShadow: '0 40px 100px rgba(0,0,0,.6)', margin: vertical ? '60px 0' : 0 }}>
        <div style={{ width: STAGE_W, height: STAGE_H, transform: `scale(${stageScale})`, transformOrigin: 'top left', position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, #2f5d8a, #4f8a9e 55%, #e0b46b)' }}>
            <MenuBar f={0} />
            <div style={{ position: 'absolute', inset: 0, transform: `translate(${appPanX}px, ${appPanY}px) scale(${appZoom})`, transformOrigin: 'center' }}>
              <Window x={120} y={90} w={1360} h={860} z={2} light>
                <AgentApp f={f} />
              </Window>
            </div>
          </div>
        </div>
      </div>
      {!vertical && (
        <div style={{ position: 'absolute', bottom: 34 }}>
          <Caption text={caption} startFrame={0} size={46} />
        </div>
      )}
    </AbsoluteFill>
  );
};

/** A generic chat-style agent app: sidebar, a thread, and the composer. */
const AgentApp = ({ f }: { f: number }) => {
  const pasted = f >= APP_PASTE;
  const pop = spring({ frame: f - APP_PASTE, fps: 30, config: { damping: 12 } });
  const typed = APP_QUESTION.slice(0, Math.round(interpolate(f, [APP_TYPE_START, APP_TYPE_END], [0, APP_QUESTION.length], clamp)));
  const cursorOn = Math.floor(f / 15) % 2 === 0;
  const chipFlash = interpolate(f, [APP_PASTE - 8, APP_PASTE - 4, APP_PASTE + 4], [0, 1, 0], clamp);
  return (
    <div style={{ display: 'flex', height: 814 }}>
      <div style={{ width: 280, background: '#f4f4f6', padding: 28, display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ height: 34, width: 150, borderRadius: 8, background: '#dfe0e6' }} />
        {[80, 65, 72, 55].map((w, i) => (
          <div key={i} style={{ height: 14, width: `${w}%`, borderRadius: 7, background: '#e4e5ea' }} />
        ))}
      </div>
      <div style={{ flex: 1, position: 'relative', padding: '40px 70px' }}>
        <div style={{ marginLeft: 'auto', width: 520, padding: '18px 22px', borderRadius: 18, background: '#f0f0f3', color: '#2a2c35', font: `400 24px/1.5 ${SANS}` }}>
          the checkout page crashes on load
        </div>
        <div style={{ marginTop: 28, width: 700, color: '#2a2c35', font: `400 24px/1.6 ${SANS}` }}>
          Can you show me what you see on screen?
        </div>
        <div style={{ position: 'absolute', left: 70, right: 70, bottom: 40, borderRadius: 24, border: '2px solid #dadbe2', background: '#fff', padding: 22, boxShadow: '0 10px 30px rgba(0,0,0,.06)' }}>
          {pasted && (
            <div style={{ transform: `scale(${pop})`, transformOrigin: 'left bottom', marginBottom: 16, width: 420, padding: 12, borderRadius: 14, border: '1px solid #e3e4ea', background: '#fafafb', position: 'relative' }}>
              <div style={{ width: SELECTION.w, transform: 'scale(0.455)', transformOrigin: 'top left', height: (SELECTION.h - 40) * 0.455 }}>
                <CapturedRegion mask={1} />
              </div>
            </div>
          )}
          <div style={{ color: typed ? '#2a2c35' : '#a0a3b1', font: `400 26px ${SANS}`, display: 'flex', alignItems: 'center' }}>
            {typed || (pasted ? '' : 'Reply…')}
            {pasted && <span style={{ display: 'inline-block', width: 3, height: 30, marginLeft: 2, background: cursorOn ? '#2a2c35' : 'transparent' }} />}
          </div>
          <div style={{ position: 'absolute', inset: 0, borderRadius: 24, boxShadow: `0 0 0 4px rgba(255,158,69,${chipFlash})` }} />
        </div>
      </div>
    </div>
  );
};

// ─── Features ────────────────────────────────────────────────────────────

const FEATURE_LINES: [string, string][] = [
  ['⌘⌘', 'Capture from anywhere'],
  ['•••', 'Secrets masked by on-device OCR + AI'],
  ['↩︎', 'Lands in your terminal or agent app'],
  ['⌘⇧1', 'Paste any of your last 10 shots'],
];

const Features = () => {
  const f = useCurrentFrame();
  const { width } = useVideoConfig();
  const size = width > 1500 ? 60 : 48;
  const exit = interpolate(f, [FEATURES - 10, FEATURES], [1, 0], clamp);
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity: exit }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 38 }}>
        {FEATURE_LINES.map(([key, label], i) => {
          const t = fade(f, 4 + i * 12, 18 + i * 12);
          return (
            <div key={key} style={{ display: 'flex', alignItems: 'center', gap: 36, opacity: t, transform: `translateX(${(1 - t) * -40}px)` }}>
              <div style={{ width: size * 2.8, boxSizing: 'border-box', padding: '10px 0', borderRadius: 18, border: '2px solid #2c2e3a', background: '#181a21', color: ACCENT, font: `700 ${size * 0.8}px ${SANS}`, textAlign: 'center' }}>
                {key}
              </div>
              <div style={{ color: '#fff', fontSize: size, fontWeight: 700, letterSpacing: '-0.025em' }}>{label}</div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

// ─── End card ────────────────────────────────────────────────────────────

const EndCard = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: f, fps, config: { damping: 14 } });
  return (
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
      <Img src={staticFile('icon.png')} style={{ width: 200, transform: `scale(${pop})` }} />
      <div style={{ color: '#fff', fontSize: 96, fontWeight: 800, letterSpacing: '-0.04em', marginTop: 28, opacity: fade(f, 6, 20) }}>Yetda</div>
      <div style={{ color: '#9a9cab', fontSize: 34, marginTop: 10, opacity: fade(f, 10, 24) }}>옜다 · Korean for “here, take it.”</div>
      <div style={{ color: '#9a9cab', fontSize: 30, marginTop: 8, opacity: fade(f, 14, 28) }}>Free &amp; open source for macOS</div>
      <div style={{ color: '#d8dae3', fontSize: 30, marginTop: 26, opacity: fade(f, 18, 32) }}>Claude Code · Codex · Gemini CLI · opencode</div>
      <div style={{ color: '#d8dae3', fontSize: 30, marginTop: 6, opacity: fade(f, 20, 34) }}>and the Claude, Codex &amp; ChatGPT apps</div>
      <div style={{ color: ACCENT, font: `500 34px ${MONO}`, marginTop: 34, opacity: fade(f, 22, 36) }}>github.com/woonmayer/yetda</div>
    </AbsoluteFill>
  );
};
